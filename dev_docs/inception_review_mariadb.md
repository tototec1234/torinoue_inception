# Inception レビュー対策ノート - MariaDB編

---

## Q1. `FROM debian:bookworm` は何をしていますか？

**自分の回答：**
VMの中のOSをホストとして、そのホスト上にDockerコンテナを建て、そのコンテナ内のアプリケーションを動かすためのゲストOSとしてbookwormというバージョンのdebianを使うことを宣言。

**正解：**
コンテナの**ベースイメージ**を指定している。

**解説：**
DockerはVMとは根本的に異なる仕組みです。VMはOSを丸ごと仮想化しますが、Dockerはホスト（今回はUbuntu VM）のLinuxカーネルを共有しながら、プロセスを隔離して動かします。`FROM debian:bookworm` は「このコンテナをDebian bookworm（Debian 12）のイメージをベースに作る」という宣言です。ゲストOSではなく「ベースイメージ」という言葉を使います。

**図解：**
```
Mac（M2）
└── VMware Fusion
    └── Ubuntu 22.04 VM  ← Linuxカーネルはここ
        └── Docker
            └── コンテナ（debian:bookwormベース）← カーネルはUbuntuと共有
```

**ペアレビューで聞かれそうな追加質問：**
- `bookworm` とは何ですか？ → Debian 12のコードネーム
- なぜAlpineではなくDebianを使ったのですか？ → パッケージが揃っており初心者に扱いやすい（Alpineはより軽量だが癖がある）

---

## Q2. `volumes: mariadb_data:/var/lib/mysql` は何のためですか？

**自分の回答：**
VM内の `/var/lib/mysql` にmariadbのデータを永続化する場所を指定。

**正解：**
Dockerが管理する**名前付きボリューム**を使って、コンテナを削除してもDBのデータが消えないようにしている。

**解説：**
`mariadb_data` はVM内の特定パスではなく、Dockerが管理するボリュームです。実体はVM内の `/var/lib/docker/volumes/srcs_mariadb_data/_data/` にあります。コンテナ内の `/var/lib/mysql`（MariaDBがデータを書く場所）をこのボリュームにマウントすることで、コンテナを `docker compose down -v` しない限りデータが残ります。

**図解：**
```
コンテナ内
/var/lib/mysql  ←→  Docker Volume（srcs_mariadb_data）
                     実体: VM内 /var/lib/docker/volumes/srcs_mariadb_data/_data/
```

**ペアレビューで聞かれそうな追加質問：**
- `-v` なしの `docker compose down` と `docker compose down -v` の違いは？ → `-v` をつけるとボリュームも削除される
- ボリュームを使わないとどうなりますか？ → コンテナを削除するとDBのデータが全て消える

---

## Q3. なぜ `mysqld` を一度起動して止めて、もう一度起動しているのですか？

**自分の回答：**
WordPressが呼びに行った時に、止まっている状態で存在していなければWordPressがmysqldを探しにいくから。

**正解：**
**初期化（DB作成・ユーザー作成）のSQL文を実行するため**に一度起動し、設定完了後に止めて本番用設定で再起動している。

**解説：**
`mysql -u root` でSQL文を実行するには、MySQLサーバーが起動していないと接続できません。しかしコンテナ初回起動時にはまだDBやユーザーが存在しません。そのため：

1. `--skip-networking` で外部からの接続を遮断した状態で一時起動
2. SQL文でDB・ユーザーを作成
3. 一時停止
4. `--bind-address=0.0.0.0` で外部（WordPress）からの接続を許可して本番起動

という2段階の起動をしています。

**`mysqld` の `d` について：**
`d` は **daemon（デーモン）** の略です。デーモンとは、バックグラウンドで常駐して動き続けるプロセスのことです。`mysqld`、`nginx`、`sshd` など、サーバー系のプロセスには `d` がつくことが多いです。

**init.shのフルパス付き流れ：**
```bash
#!/bin/bash
set -e

# 1. ソケットファイル用ディレクトリ作成（コンテナ内）
mkdir -p /var/run/mysqld
chown mysql:mysql /var/run/mysqld

# 2. DB初期化（初回のみ）
#    データの実体は /var/lib/mysql/（Dockerボリュームにマウント済み）
if [ ! -d "/var/lib/mysql/mysql" ]; then
    mysql_install_db --user=mysql --datadir=/var/lib/mysql
fi

# 3. 一時起動（外部接続なし・ソケット経由のみ）
#    ソケットファイル: /var/run/mysqld/mysqld.sock
mysqld --user=mysql --skip-networking --socket=/var/run/mysqld/mysqld.sock &
MYSQL_PID=$!
sleep 5

# 4. DB・ユーザー作成（ソケット経由で接続）
mysql --socket=/var/run/mysqld/mysqld.sock -u root --skip-password <<SQL
ALTER USER 'root'@'localhost' IDENTIFIED BY '${MYSQL_ROOT_PASSWORD}';
CREATE DATABASE IF NOT EXISTS ${MYSQL_DATABASE};
CREATE USER IF NOT EXISTS '${MYSQL_USER}'@'%' IDENTIFIED BY '${MYSQL_PASSWORD}';
GRANT ALL PRIVILEGES ON ${MYSQL_DATABASE}.* TO '${MYSQL_USER}'@'%';
FLUSH PRIVILEGES;
SQL

# 5. 一時停止
kill $MYSQL_PID
wait $MYSQL_PID 2>/dev/null || true
sleep 2

# 6. 本番起動（全IPからの接続を許可、ポート3306で待ち受け）
exec mysqld --user=mysql --bind-address=0.0.0.0
```

**ペアレビューで聞かれそうな追加質問：**
- `--bind-address=0.0.0.0` とは何ですか？ → 全てのIPアドレスからの接続を受け付ける設定
- `exec` をつける理由は？ → PID 1をmysqldにするため。DockerはコンテナのPID 1が終了するとコンテナを停止する
- ソケット（`/var/run/mysqld/mysqld.sock`）とTCP（ポート3306）の違いは？ → ソケットは同一ホスト内の通信、TCPは別ホスト（別コンテナ）からの通信

---

## 今日詰まったポイント（実装メモ）

| エラー | 原因 | 解決策 |
|--------|------|--------|
| `Access denied for root` | debianのmariadbは初期rootパスワードが設定済み | `--skip-password` オプションを使う |
| `Bind on unix socket: No such file or directory` | `/var/run/mysqld/` が存在しない | init.shで `mkdir -p /var/run/mysqld` を追加 |
| `Can't lock aria_log_control` | 別のコンテナが同じボリュームを掴んでいた | `docker kill $(docker ps -q)` で古いコンテナを強制終了 |
| `mysqld_safe` がループ | クラッシュ時に自動再起動する仕組みがある | `mysqld` 直接起動に変更 |

---

## ファイル構成（MariaDB完成時点）

```
~/torinoue_inception/               # Mac上のパス
/vagrant/                           # VM内から見たパス（同じ場所）
└── srcs/
    ├── .env                        # DB認証情報（gitignore済み）
    ├── docker-compose.yml
    └── requirements/
        └── mariadb/
            ├── Dockerfile
            └── conf/
                └── init.sh
```
