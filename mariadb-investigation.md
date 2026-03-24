# MariaDB Docker イメージ調査メモ

## 1. イメージ内部の調査コマンド

### 基本調査（ENTRYPOINTなし版）
```bash
vagrant ssh -c "docker run --rm mariadb-test:alpine321 sh -c '
echo \"=== mysql user ===\"
id mysql
echo \"\"
echo \"=== /var/lib/mysql ===\"
ls -la /var/lib/mysql/
echo \"\"
echo \"=== /run/mysqld ===\"
ls -la /run/mysqld/
echo \"\"
echo \"=== /etc/my.cnf.d/ ===\"
ls -la /etc/my.cnf.d/
echo \"\"
echo \"=== my.cnf content ===\"
cat /etc/my.cnf.d/my.cnf
echo \"\"
echo \"=== mariadbd version ===\"
mariadbd --version
echo \"\"
echo \"=== which mariadb-install-db ===\"
which mariadb-install-db
'" 2>&1
```

- `docker run --rm` : コンテナ終了後に自動削除（使い捨て）
- `mariadb-test:alpine321` : ローカルでビルドしたイメージ
- ENTRYPOINTが設定されている場合、`ENTRYPOINT + sh -c '...'` として実行される

### ENTRYPOINT上書き版（より安全）
```bash
vagrant ssh -c 'docker run -RYPOINT + sh -c '...'` になる可能性あり
- ENTRYPOINT上書き版: 確実に `sh -c "..."` が走る

## 2. イメージサイズ確認

```bash
vagrant ssh -c "docker images mariadb-test:alpine321 --format 'table {{.Repository}}\t{{.Tag}}\t{{.Size}}'" 2>&1
```

- `--format` はDockerの機能（GoのテンプレートエンジンGoの `text/template` 構文）
- SQLとは無関係

### 結果
```
REPOSITORY     TAG         SIZE
mariadb-test   alpine321   313MB
```

- Alpineベースで313MBはかなり大きい（公式は100MB前後）
- ビルドキャッシュや不要パッケージが残っている可能性

## 3. apk add mariadb が自動作成するもの

```bash
vagrant ssh -c 'docker run --rm --entrypoint sh mariadb-test:alpine321 -c "
grep mysql /etc/passwd
grep mysql /etc/group
cat /etc/my.cnf.d/mariadb-server.cnf
cat /etc/my.cnf
"' 2>&1
```

### mysqlユーザー（自動作成される）
```
mysql:x:100:101:mysql:/var/lib/mysql:/sbin/nologin
mysql:x:101:mysql
```

- UID 100, GID 101
mysqlユーザーと一致しないとパーミッションエラーになる

## 4. MariaDB設定ファイルの構造

### /etc/my.cnf（メイン設定）
```ini
[client-server]

[mysqld]
symbolic-links=0

!includedir /etc/my.cnf.d
```

### /etc/my.cnf.d/mariadb-server.cnf（サブ設定）
```ini
[mysqld]
skip-networking
```

### 読み込み順序
```
/etc/my.cnf                          ← 親
  └── !includedir /etc/my.cnf.d/     ← ディレクトリ以下を全部読む
        └── mariadb-server.cnf       ← skip-networking がここ
        └── 自分の設定ファイル        ← ここに置く
```

## 5. 重要な発見: skip-networking

`skip-networking` はTCP接続を完全に無効化し、UNIXソケットのみで接続を受け付ける設定。

**Inceptionでは別コンテナ（WordPress等）からMariaDBにTCPで接続する必要があるので、これを無効化しないとコンテナ間通信ができない。**

### 対処法
- 自分の設定ファイル
