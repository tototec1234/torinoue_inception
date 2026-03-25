# Inception レビュー対策ノート - MariaDB entrypoint.sh 編
## Q1. `--skip-networking` の意味
`mariadbd --user=mysql --skip-networking &` の `--skip-networking` は何を無効にするか。
また、なぜ一時起動時にこのオプションが必要か。
**自分の回答：**
TCP/IP での接続を無効にする。初期設定時に外部から書き込まれないようにするため。
**正解：**
TCP/IP ネットワーク接続を全て無効にする。Unix ドメインソケット経由のローカル接続のみ許可される。
初期化中はユーザー・権限設定が未完了であり、外部からの接続を受け付けるのはセキュリティ上危険なため。
**解説：**
コマンドライン引数は設定ファイルより優先される。そのため zaphod-mariadb.cnf に `skip-networking = 0` があっても、
`--skip-networking` が引数で渡されている間は TCP が無効になる。
ログで `port: 0` と表示されることで確認できる。
**一次資料：**
- [skip_networking - MariaDB Knowledge Base](https://mariadb.com/kb/en/server-system-variables/#skip_networking)
---
## Q2. 初期化ガードの仕組み
`if [ ! -d "/var/lib/mysql/mysql" ]; then` の `/var/lib/mysql/mysql` は何か。
なぜここを確認することで「初回起動かどうか」を判定できるか。
**自分の回答：**
`/var/lib/mysql/` に初回起動時に `$MARIADB_DATABASE` の設定を流し込むために作られるディレクトリ。
初回起動後はこのディレクトリが作られているので `-d` が true を返すことで判定できる。
**正解：**
`/var/lib/mysql/mysql` は MariaDB のシステムテーブルが格納されるディレクトリ。
`mariadb-install-db` が実行されたときに作成される。
ユーザー一覧・権限情報などの内部管理データ（`user` テーブル等）が入る。
`$MARIADB_DATABASE`（例: wordpress）は別ディレクトリ（`/var/lib/mysql/wordpress/`）に作られる。
/var/lib/mysql/ ├── mysql/ ← システムテーブル（mariadb-install-db が作成）← ここを確認 ├── wordpress/ ← ユーザーDB（CREATE DATABASE が作成） └── performance_schema/

**解説：**
`/var/lib/mysql/mysql` が存在する = `mariadb-install-db` 実行済み = 初期化済み。
なぜ両方 mysql という名前か：
- `/var/lib/mysql/` はデータディレクトリ（MySQL 時代からの慣習）
- `/var/lib/mysql/mysql` はシステムスキーマ（MySQL の管理用DBの名前が "mysql"）

**一次資料：**
- [mariadb-install-db](https://mariadb.com/docs/server/clients-and-utilities/deployment-tools/mariadb-install-db)

---

## Q3. `exec` を使わないとどうなるか

`exec mariadbd --user=mysql` の `exec` を外した場合に何が起きるか。

**自分の回答：**
PID 1 がエントリーポイントのシェルスクリプトのままになり、子プロセスである mariadbd に
コンテナ外部からシグナルを送れない。PID 1 を殺しても mariadbd がゾンビになる可能性がある。
Docker は mariadbd を制御できなくなる。

**正解：**
`exec` なし → シェルスクリプトが PID 1 のまま → mariadbd はその子プロセス（別PID）になる。
`docker stop` は PID 1 に SIGTERM を送る。シェルはそれを mariadbd に転送しないため
グレースフルシャットダウンができない。10秒後に Docker が SIGKILL で強制終了する。

**解説：**
`exec` は「現在のプロセスを新しいプロセスで置き換える」システムコール。
`exec mariadbd` を実行すると entrypoint.sh 自身が mariadbd に置き換わり PID 1 を引き継ぐ。
ログで `as process 1` と表示されることで確認できる。
「ゾンビプロセス」は厳密には「終了したが親が wait() していない状態」。
この場合は「孤立プロセス（orphan）」がより正確。

**一次資料：**
- [exec - GNU Bash Manual](https://www.gnu.org/software/bash/manual/bash.html#Bourne-Shell-Builtins)

---

## Q4. ソケット vs TCP 接続の違い

`--skip-networking` 中でも `mariadb-admin ping` が成功した理由。

**自分の回答：**
ソケット接続は同じコンテナ内であれば PORT と無関係に接続できる。
TCP が無効でもソケットファイル `/run/mysqld/mysqld.sock` を見に行けば通信できる。

**正解：** 正解。

**解説：**
Unix ドメインソケット（`/run/mysqld/mysqld.sock`）はファイルシステム上のファイルを使った
プロセス間通信。ネットワークスタック（TCP/IP）を使わないので `--skip-networking` の影響を受けない。
同一ホスト（コンテナ）内のプロセスからしか接続できないため、外部からのアクセスは不可。

| 接続方式 | 経路 | `--skip-networking` の影響 | 外部からの接続 |
|---------|------|--------------------------|-------------|
| Unix ソケット | ファイル | なし | 不可 |
| TCP/IP | ネットワーク | 無効化される | 可（ポート開放時）|

**一次資料：**
- [unix_socket Authentication Plugin](https://mariadb.com/kb/en/unix_socket-authentication-plugin/)

---

## 今日詰まったポイント（実装メモ）

- `zaphod-mariadb.cnf` に `[mysqld]` ヘッダーを忘れると設定が全て無視される
- `EOF` は行頭に置く。インデントすると heredoc の終端として認識されない
- コマンドライン引数（`--skip-networking`）は設定ファイルより優先される
- 匿名ユーザー（User=''）が `mariadb-install-db` によりデフォルト作成される（フェーズ4で対処予定）

## レビュー想定問答集

**Q: なぜ `sleep 2` ではなく ping ループを使っているか？**
A: `sleep 2` は固定待機で、マシンが遅ければ足りない。ping ループは実際に応答するまで待つので確実。42秒のタイムアウトで無限ループも防いでいる。

**Q: なぜ一時起動が必要なのか？**
A: `mariadb-install-db` はシステムテーブルを作るだけで、ユーザーやDBは作らない。SQL（CREATE DATABASE等）を実行するにはサーバーが起動している必要がある。ただし初期化中に外部からアクセスされないよう `--skip-networking` でTCPを無効にして起動する。

**Q: `exec` の役割は？**
A: entrypoint.sh 自身を mariadbd プロセスに置き換え PID 1 を引き継がせる。これにより `docker stop` の SIGTERM が直接 mariadbd に届き、グレースフルシャットダウンが可能になる。
