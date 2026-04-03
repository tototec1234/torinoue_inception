# Inception レビュー対策ノート - Alpine + MariaDB 編

> 日付: 2026-03-26
> 対応フェーズ: 1
> 対応タスク: 1-1〜1-7

---

## Q1. Alpine と Debian のパッケージマネージャの違い

Alpine Linux と Debian のパッケージマネージャの違いを、コマンド名とキャッシュ管理の観点から説明してください。また、Dockerfile で `apk add --no-cache` を使う理由を述べてください。

**自分の回答：**
パッケージマネージャーは

Alpine ではAlpine Package Keeper の略でapk コマンド　：　RUN apk add --no-cache mariadbとすればインストール後にキャッシュ（再インストールしない限り不要）削除するので、ビルド済みのイメージがその分小さくて済む

Debian では optコマンド　：RUN apt-get update && apt-get install -y mariadb-server && rm -rf /var/lib/apt/lists/*
このように、手動で削除コマンドを書かく必要がある

**正解：**
- **Alpine**: `apk` (Alpine Package Keeper)
  - `apk add --no-cache <package>` でインストール＋キャッシュ自動削除
  - キャッシュは `/var/cache/apk/` に保存される
- **Debian**: `apt` / `apt-get`
  - `apt-get update && apt-get install -y <package> && rm -rf /var/lib/apt/lists/*` でキャッシュ手動削除が必要
  - キャッシュは `/var/lib/apt/lists/` と `/var/cache/apt/` に保存される

**解説：**
- `--no-cache` は「キャッシュを使わずにインストール＋インストール後にキャッシュを残さない」という2つの意味を持つ
- Alpine の `apk` はキャッシュ管理が簡潔で、Dockerfile のレイヤー削減に有利
- Debian では `apt-get clean` や `rm -rf /var/lib/apt/lists/*` を手動で実行する必要がある
- **注意**: 回答の「opt」は「apt」の typo と思われます

**一次資料：**
- [Alpine Linux apk コマンド公式ドキュメント](https://wiki.alpinelinux.org/wiki/Alpine_Package_Keeper)
- [Docker ベストプラクティス - APT キャッシュ削除](https://docs.docker.com/build/building/best-practices/#apt-get)


---

## Q2. Alpine のデフォルトシェル

Alpine Linux のデフォルトシェルは何ですか？また、Dockerfile の `RUN` 命令で実行されるシェルは何ですか？bash との主な違いを1つ挙げてください。

**自分の回答：**

- Alpine Linux のデフォルトシェルはash　(Almquist Shell) POSIX準拠で書く必要がある。

- RUNで実行される `/bin/sh`の実体はash (確認方法は知らない)

- bashで可能な`NAMES=("hoge","piyo")`のような配列が使えない

**正解：**
- Alpine のデフォルトシェル: `ash` (Almquist Shell)
- Dockerfile の `RUN` 命令で実行されるシェル: `/bin/sh` → Alpine では `ash` へのシンボリックリンク
- 確認方法: `docker run --rm alpine:3.21 readlink -f /bin/sh` → `/bin/busybox` (ash は BusyBox の一部)
- bash との主な違い:
  - 配列構文が使えない（`NAMES=("a" "b")` は不可、スペース区切り文字列で代用）
  - `[[` 条件式が使えない（`[` のみ）
  - プロセス置換 `<()` が使えない
  - 連想配列が使えない

**解説：**
- Alpine は軽量化のため bash を含まず、BusyBox の ash を採用
- ash は POSIX 準拠のため、bash 固有の機能は使えない
- entrypoint.sh では `#!/bin/sh` を使い、POSIX 準拠の構文で記述する必要がある
- 配列が必要な場合は `set -- item1 item2` + `"$@"` で代用可能

**一次資料：**
- [BusyBox ash 公式ドキュメント](https://www.busybox.net/)
- [Alpine Linux Wiki - Shell](https://wiki.alpinelinux.org/wiki/Alpine_Linux:FAQ#Why_don.27t_I_have_man_pages_or_bash.3F)


---

## Q3. `mariadb-install-db` の役割
`mariadb-install-db` コマンドは何をするコマンドですか？また、なぜ Dockerfile の `RUN` 命令ではなく entrypoint.sh で実行するのですか？


**自分の回答：**
- mariadb-install-dbはMarisDBをインストールした直後に、いくつかの引数を元にデータベースの初期化を行うコマンド
- Dockerfile内でRUNするとデータはコンテナイメージの中に書き込まれてしまう。
- そのコンテナイメージを起動する際にホスト側のディレクトリをマウントすると　イメージ内のデータがマウントしたホスト側のディレクトリで隠されてしまう。
- そこで、コンテナ起動時にentrypoint.shで実行する（さらに、初回起動時のみに実行することで冪等性を保っている）

**正解：**
- `mariadb-install-db` は MariaDB のシステムテーブル（`mysql` データベース）を初期化するコマンド
- 具体的には `/var/lib/mysql/mysql/` ディレクトリを作成し、権限管理テーブル（user, db, tables_priv 等）を生成する
- **Dockerfile の `RUN` で実行してはいけない理由**:
  1. イメージレイヤーに焼き込まれる → volume マウント時に隠される
  2. ホスト固有のデータ（UID/GID、パスワード等）がイメージに含まれてしまう
- **entrypoint.sh で実行する理由**:
  - volume マウント後のディレクトリに対して初期化を実行できる
  - 環境変数（パスワード等）を実行時に注入できる
  - 初期化ガードと組み合わせて冪等性を確保できる

**解説：**
- `mariadb-install-db` は `mysql_install_db` の MariaDB 版
- 実行すると `/var/lib/mysql/mysql/` 以下に以下のテーブルが作成される:
  - `user`: ユーザーアカウント情報
  - `db`, `tables_priv`, `columns_priv`: 権限情報
  - `time_zone*`: タイムゾーン情報
- Inception では volume マウント先（`/home/toruinoue/data/mariadb/`）に永続化するため、entrypoint.sh での実行が必須

**一次資料：**
- [MariaDB 公式ドキュメント - mariadb-install-db](https://mariadb.com/kb/en/mariadb-install-db/)
- [Alpine Wiki - MariaDB](https://wiki.alpinelinux.org/wiki/MariaDB)

---
## Q4. 一時起動 → シャットダウン → 本番起動の理由
entrypoint.sh で MariaDB を一時起動（`--skip-networking` 付き）→ SQL 実行 → シャットダウン → 本番起動という手順を踏む理由を説明してください。なぜ一度シャットダウンする必要があるのですか？

**自分の回答：**

1. セキュリティを確保した初期設定の実行
最初に --skip-networking を付けて一時起動することで、ネットワーク経由の外部接続を遮断し、ローカル（コンテナ内）からのみ操作可能な安全な状態を作ります。この隙に、ルートパスワードの設定や権限付与などの機密性の高い初期化SQLを実行します。

2. 実行プロセスの「役割」の切り替え
Dockerコンテナの原則は「1コンテナ1プロセス」であり、PID 1（メインプロセス）が終了するとコンテナも終了します。
そこで、1プロセスの間に　一時起動と本番起動を行い、本番起動されたmariadbにPID1を譲ることで、初期化と本番起動を1コンテナで完結させることができます。
 一時起動時： 初期化スクリプトを実行するため、MariaDBをバックグラウンドで起動します。
本番起動時： コンテナを維持し続けるため、MariaDBをフォアグラウンド（メインプロセス）として起動し直す必要があります。
一度シャットダウンするのは、この「バックグラウンドからフォアグラウンドへ」の切り替えをクリーンに行うためです。

3. データの整合性と安全な終了の確保
初期化完了後、一度正常にシャットダウン（SIGTERMによるクリーンな終了）を行うことで、メモリ上のデータをディスクに完全に書き出し、バイナリログなどの整合性を保ちます。これをせず、強引に本番プロセスへ移行しようとすると、二重起動によるファイルのロック競合や、予期せぬデータ破損を招くリスクがあります。

- entrypoint.sh において一度シャットダウンするのは、「初期設定という大事な作業内容を、絶対に消えないようにディスクへ『保存完了』させ、次の本番起動時に真っさらで健康な状態でスタートするため」

**正解：**
一時起動 → シャットダウン → 本番起動の3段階が必要な理由:

1. **一時起動（`--skip-networking` 付き）**: 
   - TCP/IP を無効化してセキュアな状態で初期化 SQL を実行
   - バックグラウンド起動（`mariadbd &`）で entrypoint.sh が制御を保持
   
2. **シャットダウン（`mariadb-admin shutdown`）**:
   - メモリ上のデータをディスクに完全にフラッシュ
   - ロックファイル（`*.pid`, `ibdata1` 等）を正常にクリーンアップ
   - バイナリログの整合性を保証
   
3. **本番起動（`exec mariadbd`）**:
   - TCP/IP を有効化（`zaphod-mariadb.cnf` の設定が適用される）
   - フォアグラウンド起動で PID 1 として動作
   - `SIGTERM` を受け取れる状態にする

**シャットダウンが必須な理由**: バックグラウンドプロセスを kill せずに新しい `mariadbd` を起動すると、データディレクトリのロック競合が発生し、起動に失敗する。

**解説：**
- 回答内容は正確で、3つの観点（セキュリティ、プロセス管理、データ整合性）を網羅している
- 「バックグラウンドからフォアグラウンドへの切り替え」という表現が的確
- 補足: `mariadb-admin shutdown` は内部で `SIGTERM` を送信し、MariaDB が graceful shutdown を実行する
- 二重起動を防ぐため、シャットダウン完了を待つ必要がある（実装では `wait` コマンドを使用）

**一次資料：**
- [MariaDB 公式ドキュメント - mariadb-admin](https://mariadb.com/kb/en/mariadb-admin/)
- [MariaDB 公式ドキュメント - Server System Variables (skip-networking)](https://mariadb.com/kb/en/server-system-variables/#skip_networking)
---
## Q5. `--skip-networking` の意味

`mariadbd --skip-networking` の意味を説明してください。また、一時起動時にこのオプションを使う理由を述べてください。

**自分の回答：**

- TCP/IPでの接続を無効にした状態でmariadbを起動するという意味。
- 外部から行われる問い合わせをお断り（初期設定が終了するまで機能させない）ため

**正解：**
- `--skip-networking` は TCP/IP 接続を無効化するオプション
- このオプションを付けると:
  - `port = 0` となり、TCP ポート 3306 でリッスンしない
  - UNIX ドメインソケット（`/run/mysqld/mysqld.sock`）のみで接続可能
  - ネットワーク経由の接続は全て拒否される
- 一時起動時に使う理由:
  - 初期化 SQL（root パスワード設定、ユーザー作成）を外部から保護
  - コンテナ内からのみアクセス可能にして、セキュアな初期化を実現

**解説：**
- 回答は正確。「外部からの問い合わせをお断り」という表現が的確
- 補足: `--skip-networking` はコマンドライン引数として渡すと、設定ファイルの `skip-networking` 設定より優先される
- 一時起動時のログには `port: 0` と表示され、TCP が無効化されていることが確認できる
- 本番起動時は `zaphod-mariadb.cnf` の `skip-networking = 0` により TCP が有効化される

**一次資料：**
- [MariaDB 公式ドキュメント - skip-networking](https://mariadb.com/kb/en/server-system-variables/#skip_networking)
- [MySQL 公式ドキュメント - skip-networking](https://dev.mysql.com/doc/refman/8.0/en/server-options.html#option_mysqld_skip-networking)

---
## Q6. 初期化ガード `if [ ! -d "/var/lib/mysql/mysql" ]` の仕組み

entrypoint.sh の冒頭にある `if [ ! -d "/var/lib/mysql/mysql" ]` の役割を説明してください。このディレクトリは何を表していますか？また、なぜこのガードが必要なのですか？

**自分の回答：**

　`/var/lib/mysql/` ディレクトリに、`mysql`ディレクトリがmkdirされ`/var/lib/mysql/mysql`ディレクトリとなりシステムテーブルなどがmariadbの初期設定（Q5.の回答で述べた通り)でSQL文で実行される。
`! -d "/var/lib/mysql/mysql"`はこのディレクトリが存在しないとき、すなわち初期設定がまだ行われていないときにtrueとなり、if文により　初期設定のSQLを走らせる役割を担う。
コンテナの永続性が保証されている状態においては、このガードにより起動するごとに行われる初期設定のオーバーヘッドを避けることができる。

**正解：**
- `/var/lib/mysql/mysql` は MariaDB のシステムデータベース（`mysql` データベース）のデータディレクトリ
- このディレクトリは `mariadb-install-db` によって作成される
- `if [ ! -d "/var/lib/mysql/mysql" ]` の役割:
  - このディレクトリが存在しない = 初期化未実施
  - 初期化処理（`mariadb-install-db` + SQL 実行）をスキップして、本番起動のみ実行
- **なぜこのガードが必要か**:
  1. 冪等性の確保: 2回目以降の起動で初期化を再実行しない
  2. パフォーマンス: 初期化処理（10秒程度）をスキップして高速起動
  3. エラー防止: 既存データへの上書きを防ぐ

**解説：**
- 回答は正確で、冪等性とパフォーマンスの観点を理解している
- 補足: volume マウントにより `/var/lib/mysql/` がホストの `/home/toruinoue/data/mariadb/` に永続化されるため、コンテナ再起動後も `mysql` ディレクトリが残る
- 初回起動: `/var/lib/mysql/mysql` が存在しない → 初期化実行
- 2回目以降: `/var/lib/mysql/mysql` が存在する → 初期化スキップ、本番起動のみ
- このガードと SQL の `IF NOT EXISTS` を組み合わせることで、二重の冪等性保証を実現

**一次資料：**
- [MariaDB 公式ドキュメント - Data Directory](https://mariadb.com/kb/en/data-directory/)
- [MariaDB 公式ドキュメント - mysql System Database](https://mariadb.com/kb/en/the-mysql-database-tables/)

---

## Q7. `IF NOT EXISTS` と冪等性

SQL の `CREATE DATABASE IF NOT EXISTS` や `CREATE USER IF NOT EXISTS` の役割を説明してください。また、初期化ガード（Q6）との違いは何ですか？

**自分の回答：**

何らかの理由で初期化ガードを外す実装に変更した場合に備えて冗長性を持たすため。

**正解：**
- `IF NOT EXISTS` は SQL レベルでの冪等性を保証する
- 役割:
  - `CREATE DATABASE IF NOT EXISTS wordpress`: `wordpress` データベースが既に存在する場合はエラーを出さずにスキップ
  - `CREATE USER IF NOT EXISTS 'wpuser'@'%'`: ユーザーが既に存在する場合はスキップ
- **初期化ガード（Q6）との違い**:
  - 初期化ガード: **初期化処理全体**をスキップ（シェルレベル）
  - `IF NOT EXISTS`: **個別の SQL 文**をスキップ（SQL レベル）
- 両方を使う理由:
  - 初期化ガードが何らかの理由で機能しなかった場合の二重防御
  - SQL を手動実行する際のエラー防止
  - コードの意図を明示（このデータベース/ユーザーは既に存在する可能性がある）

**解説：**
- 回答の「冗長性を持たせるため」は正しいが、やや簡潔すぎる
- 初期化ガードは「粗いフィルター」、`IF NOT EXISTS` は「細かいフィルター」
- 例: 初期化ガードが誤って削除された場合でも、`IF NOT EXISTS` により既存データの破壊を防げる
- Defense in Depth（多層防御）の考え方

**一次資料：**
- [MariaDB 公式ドキュメント - CREATE DATABASE](https://mariadb.com/kb/en/create-database/)
- [MariaDB 公式ドキュメント - CREATE USER](https://mariadb.com/kb/en/create-user/)


---

## Q8. PID 1 の意味と責任

Docker コンテナにおける PID 1 の意味と責任を説明してください。また、なぜ entrypoint.sh の最後で `exec mariadbd` を使うのですか？`exec` を使わないとどうなりますか？

**自分の回答：**
LinuxカーネルにおいてはPID1はシステムが起動した際に最初に生成されるプロセスであり、以後生まれる全てのプロセスの「祖先」であり、ゾンビプロセスの回収（孤児の引き取り）を行なって、システム終了時にリソース解放を担う。
一方、Dockerコンテナ内のおけるPID1は、ゾンビプロセスの回収などは行うかはよくわからない。PID1が終了する=コンテナが終了する　なので、entrypoint.shのプロセスは仕事が終わったらPID1の座を本番サービスであるmariadbに譲りDBサーバーコンテナとして動き続ける必要がある。PID1の引き継ぎのためにexecが必要。使わないとmariadbは孤児となったままentrypoint.shが走っていたコンテナが終了する。　なお、entrypoint.sh の最後の行が　`mariadbd`のみの場合、entrypoint.shはmariadbd起動を実行した瞬間にプロセスを自分で終了するため、`docker stop`でPID1に`SIGTREM`を送ることは論点に上がらない。

**正解：**
- **Docker コンテナにおける PID 1 の意味**:
  - コンテナ内で最初に起動するプロセス
  - PID 1 が終了すると、コンテナも終了する
  - カーネルからのシグナル（`SIGTERM`, `SIGINT`）を受け取る唯一のプロセス
  - ゾンビプロセスの回収責任を持つ（通常の Linux と同様）
  
- **`exec mariadbd` を使う理由**:
  - `exec` は現在のシェルプロセスを指定したコマンドで**置き換える**
  - entrypoint.sh (PID 1) → `exec mariadbd` → mariadbd が PID 1 を継承
  - `docker stop` で送られる `SIGTERM` を mariadbd が直接受け取れる
  
- **`exec` を使わない場合**:
  - entrypoint.sh が PID 1 のまま残る
  - mariadbd は entrypoint.sh の子プロセス（PID 2 等）として起動
  - `docker stop` の `SIGTERM` が entrypoint.sh に届き、mariadbd に伝わらない可能性
  - entrypoint.sh が終了すると mariadbd も強制終了（graceful shutdown できない）

**解説：**
- 回答の前半（Linux カーネルの PID 1）は正確
- 「ゾンビプロセスの回収などは行うかはよくわからない」→ Docker コンテナでも PID 1 はゾンビプロセスを回収する責任を持つ（ただし MariaDB は単一プロセスなので実質的に問題にならない）
- 「`mariadbd` のみの場合、entrypoint.sh はプロセスを自分で終了する」→ これは誤解。`exec` なしで `mariadbd` を実行すると、mariadbd は**子プロセス**として起動し、entrypoint.sh は**待機し続ける**（終了しない）
- 正しい動作:
  - `exec mariadbd`: entrypoint.sh が mariadbd に置き換わる（PID 1 継承）
  - `mariadbd`（exec なし）: entrypoint.sh (PID 1) が mariadbd (PID 2) を起動し、待機し続ける

**一次資料：**
- [Docker 公式ドキュメント - PID 1 とシグナル処理](https://docs.docker.com/engine/reference/run/#foreground)
- [exec コマンドの動作（POSIX）](https://pubs.opengroup.org/onlinepubs/9699919799/utilities/V3_chap02.html#tag_18_14)


---

## Q9. `mariadb-admin ping` の役割

`mariadb-admin ping` コマンドは何を確認するコマンドですか？また、entrypoint.sh でこのコマンドをループさせる理由を説明してください。

**自分の回答：**
- mariadbdが起動しているかどうかを確認するコマンド
- 起動していない場合、確認カウンタを足して、ping回数が設定上限を超えるか、起動が確認できるまでループさせている
- これにより、起動前に初期設定のSQLを送ることを防いでいる

**正解：**
- `mariadb-admin ping` は MariaDB サーバーが起動して接続可能かを確認するコマンド
- 動作:
  - サーバーが起動済み → `mysqld is alive` を出力、終了コード 0
  - サーバーが未起動 → エラーメッセージ、終了コード 1
- entrypoint.sh でループさせる理由:
  - `mariadbd &` でバックグラウンド起動した直後は、プロセスは起動してもソケットファイルの準備が未完了
  - ping が成功するまで待機してから SQL を実行することで、「接続エラー」を防ぐ
  - busy wait（CPU を無駄に消費）を避けるため、`sleep 1` と組み合わせる

**解説：**
- 回答は正確。「起動前に初期設定の SQL を送ることを防ぐ」という表現が的確
- 補足: `mariadb-admin ping` は内部で `SELECT 1` 相当のクエリを実行している
- タイムアウトを設けることで、起動失敗時に無限ループを防ぐ
- 実装では `while ! mariadb-admin ping --silent; do ... done` のパターンを使用

**一次資料：**
- [MariaDB 公式ドキュメント - mariadb-admin](https://mariadb.com/kb/en/mariadb-admin/)
- [MySQL 公式ドキュメント - mysqladmin ping](https://dev.mysql.com/doc/refman/8.0/en/mysqladmin.html)
---
## Q10. ping ループのタイムアウト設計
entrypoint.sh の ping ループで 42回のタイムアウトを設定した理由を説明してください。なぜ無限ループではなく回数制限を設けるのですか？

**自分の回答：**

1回のループで1秒待たせているので42秒強でタイムアウトと設定している。無限ループでは最悪永遠に待つことになり、そうでなくても他のサービスから使えない状態で待機することに意味がない。42秒は実機による体感で妥当と考えられる。また、10秒以上に設定しているのは慣行であるが根拠は知らない。
そもそも無限ループは課題書で禁止されている。

**正解：**
- 42回のタイムアウトを設定した理由:
  1. **無限ループの禁止**: 課題要件で `while true`, `tail -f`, `sleep infinity` が明示的に禁止されている
  2. **起動失敗の検出**: MariaDB が何らかの理由で起動しない場合、無限に待たずにエラーで終了する
  3. **デバッグの容易さ**: タイムアウトで終了することで、ログから問題を特定しやすい
  4. **適切な待機時間**: 1回 1秒 × 42回 = 42秒。通常の起動は 5〜10秒程度なので十分な余裕
- 回数制限を設ける理由:
  - 起動失敗時にコンテナを終了させ、Docker の restart ポリシーや healthcheck に判断を委ねる
  - 無限ループはリソースの無駄遣い＋デバッグ困難

**解説：**
- 回答は正確で、課題要件と実用性の両面を理解している
- 「42秒は実機による体感で妥当」→ 正しい。MariaDB の起動時間は環境により異なるが、通常 10秒以内
- 「10秒以上に設定しているのは慣行」→ Kubernetes の liveness probe のデフォルトが 30秒程度であることが参考になる
- 42 という数字は「生命、宇宙、そして万物についての究極の疑問の答え」（銀河ヒッチハイクガイド）にちなんだ遊び心と推測される

**一次資料：**
- [Inception 課題 PDF - 禁止事項](https://cdn.intra.42.fr/pdf/pdf/123456/en.subject.pdf)（tail -f, infinite loop 禁止の記載）
- [Docker Compose healthcheck](https://docs.docker.com/reference/compose-file/services/#healthcheck)

---

## Q11. `bind-address = 0.0.0.0` の意味
`zaphod-mariadb.cnf` に記載した `bind-address = 0.0.0.0` の意味を説明してください。また、なぜ `127.0.0.1` ではなく `0.0.0.0` にする必要があるのですか？

**自分の回答：**

- IP`0.0.0.0`はワイルドカードで全てのネットワークインターフェースを表す。
- コンテナ間の通信はDockernetworkで管理されており、コンテナ内IPアドレスとは無関係。
- 0.0.0.0はコンテナの内部IPを指しているので、実際のところ127.0.0.1でも問題ない。
- しかし、コンテナ内で実行されているプロセスが全てのネットワークインターフェースが使えるようにした方が良さげ。
`172.0.0.1`だとコンテナ自分自身になるので意味合いが異なってくる。

**正解：**
- `bind-address = 0.0.0.0` は「全てのネットワークインターフェースでリッスンする」という意味
- `0.0.0.0` の意味:
  - ワイルドカードアドレス
  - コンテナ内の全ての IP アドレス（`127.0.0.1`, `172.x.x.x` 等）で接続を受け付ける
- **なぜ `127.0.0.1` ではダメか**:
  - `127.0.0.1` はループバックアドレス（localhost）
  - コンテナ内からのみ接続可能で、他のコンテナからの接続を受け付けない
  - WordPress コンテナから MariaDB コンテナへの接続には、Docker network の内部 IP（例: `172.18.0.2`）が使われる
  - `bind-address = 127.0.0.1` だと、この内部 IP での接続が拒否される

**解説：**
- 回答の「`0.0.0.0` はワイルドカード」は正確
- 「`127.0.0.1` でも問題ない」→ これは誤り。`127.0.0.1` だと他のコンテナから接続できない
- 「`172.0.0.1` だとコンテナ自分自身」→ `172.0.0.1` は存在しない IP。おそらく `127.0.0.1` の誤記
- Docker network での通信フロー:
  1. WordPress コンテナから `mariadb:3306` に接続
  2. Docker の DNS が `mariadb` を内部 IP（例: `172.18.0.2`）に解決
  3. MariaDB が `0.0.0.0:3306` でリッスンしているため、`172.18.0.2:3306` での接続を受け付ける

**一次資料：**
- [MariaDB 公式ドキュメント - bind-address](https://mariadb.com/kb/en/server-system-variables/#bind_address)
- [Docker ネットワーク公式ドキュメント](https://docs.docker.com/engine/network/)


---

## Q12. `skip-networking = 0` の意味

`zaphod-mariadb.cnf` に記載した `skip-networking = 0` の意味を説明してください。また、なぜこの設定が必要なのですか？

**自分の回答：**
- `skip-networking`はTCP/IPを無効化するオプションでローカルホスト経由の接続のみが許可され、port3306へのアクセスも遮断される。
- デフォルトでDBのセキュリティを上げるためにこうしている
- しかしこれではwordpressやnginxとの通信ができないの
- そこで `skip-networking`オプションを明示的にoffにするために `skip-networking = 0`とする

**正解：**
- `skip-networking = 0` は TCP/IP 接続を**有効化**する設定
- MariaDB のデフォルト動作:
  - 通常は TCP/IP が有効（`skip-networking = 0` がデフォルト）
  - しかし、Alpine の `mariadb-server.cnf` に `skip-networking` が含まれている場合がある
- **なぜこの設定が必要か**:
  - `mariadb-server.cnf` で `skip-networking` が有効になっている場合、それを上書きする必要がある
  - `zaphod-mariadb.cnf` は `mariadb-server.cnf` より後に読まれるため、`skip-networking = 0` で上書きできる
  - WordPress コンテナからの TCP 接続（`mariadb:3306`）を受け付けるために必須

**解説：**
- 回答の理解は概ね正確
- 「デフォルトで DB のセキュリティを上げるためにこうしている」→ これは状況による。Alpine のパッケージ設定次第
- 補足: セッションログ #0006 の Spike 記録によると、`zaphod-mariadb.cnf` で `mariadb-server.cnf` の設定を上書きする設計
- 設定の優先順位（高い順）:
  1. コマンドライン引数（`--skip-networking`）
  2. 後に読まれた設定ファイル（`zaphod-mariadb.cnf`）
  3. 先に読まれた設定ファイル（`mariadb-server.cnf`）

**一次資料：**
- [MariaDB 公式ドキュメント - skip-networking](https://mariadb.com/kb/en/server-system-variables/#skip_networking)
- [MariaDB 公式ドキュメント - Option Files](https://mariadb.com/kb/en/configuring-mariadb-with-option-files/)


---

## Q13. 設定ファイルの読み込み順

MariaDB は `/etc/my.cnf.d/` 内の設定ファイルをどのような順序で読み込みますか？また、`zaphod-mariadb.cnf` というファイル名にした理由を説明してください。

**自分の回答：**

- アルファベット昇順に読み込み、最後に読み込んだものが設定に適用される
- 従って`mariadb-server.cnf`より辞書順で後に来る命名にする必要がある
- 先頭文字が`z`で始まれば`mariadb-server.cnf`には十分対応でき、`z`以外の文字で始まるファイル名を気にしなくて済む。
- `zaphod`は銀河ヒッチハイクガイドに登場する宇宙大統領がZaphod Beeblebroxに由来する。CPP05 ex02 の 大統領恩赦FORMの作成で既出である。`mariadb`はサービス名であるのでそのまま残した。 

**正解：**
- MariaDB は `/etc/my.cnf.d/` 内の設定ファイルを**アルファベット昇順**に読み込む
- 後に読まれた設定が優先される（上書きされる）
- `zaphod-mariadb.cnf` というファイル名にした理由:
	1. `z` で始まるため、`mariadb-server.cnf` より後に読まれる
	2. Alpine の mariadb パッケージが提供する設定ファイル（`mariadb-server.cnf` 等）より後に読まれる
	3. `/etc/my.cnf.d/` 内で将来的に追加される可能性のある他の設定ファイル（例: `client.cnf`、`mysql-clients.cnf`）よりも後に読まれることが保証される
- 確認方法: `ls /etc/my.cnf.d/` でファイル一覧を表示

**解説：**
- 回答は正確で、設計意図を理解している
- Zaphod Beeblebrox の由来は遊び心があって良い（レビューで聞かれたら説明できる）
- セッションログ #0006 の Spike 記録で実験済み:
  ```
  docker run --rm --entrypoint sh mariadb-test:task14 -c "ls /etc/my.cnf.d/"
  → mariadb-server.cnf  zaphod-mariadb.cnf
  ```
- `/etc/my.cnf` の `!includedir /etc/my.cnf.d` ディレクティブにより、ディレクトリ内の `.cnf` ファイルが順次読み込まれる

**一次資料：**
- [MariaDB 公式ドキュメント - Option Files](https://mariadb.com/kb/en/configuring-mariadb-with-option-files/)
- [MySQL 公式ドキュメント - Option File Processing Order](https://dev.mysql.com/doc/refman/8.0/en/option-files.html)


---

## Q14. `[mysqld]` セクションヘッダーの必要性

MariaDB の設定ファイルで `[mysqld]` セクションヘッダーが必要な理由を説明してください。このヘッダーがないとどうなりますか？

**自分の回答：**
- `mysqld`　プログラムに対して、MariaDB サーバー本体に対する設定であることを示すために必要。
- `[mysqld]` セクションヘッダーのないと設定ファイル（`*.cnf`）はMariaDB サーバー本体に対する設定には使われない。
- このヘッダーがない場合は設定は反映されないので、`mysqld`のコマンドライン引数で設定する必要がある。

**正解：**
- MariaDB の設定ファイルは INI 形式で、セクションヘッダー（`[section_name]`）が必須
- 主なセクション:
  - `[mysqld]` / `[mariadbd]`: サーバー本体の設定
  - `[client]`: クライアント（`mariadb`, `mariadb-admin` 等）の設定
  - `[mysql]`: `mysql` コマンド専用の設定
- `[mysqld]` ヘッダーがないとどうなるか:
  - セクションヘッダーがない行は全て無視される
  - `bind-address = 0.0.0.0` 等の設定が一切反映されない
  - サーバーはデフォルト設定で起動する
- 確認方法: セッションログ #0006 の Spike で実験済み（`[mysqld]` なしで `port: 0` のまま）

**解説：**
- 回答は正確で、セクションヘッダーの必要性を理解している
- セッションログ #0006 の Spike 記録より:
  ```
  # [mysqld] なしでビルド → port: 0 のまま
  # [mysqld] 追記後 → port: 3306 に変化
  ```
- INI 形式の仕様: セクションヘッダーで始まり、次のセクションヘッダーまでの行がそのセクションに属する
- MariaDB は起動時に設定ファイルをパースし、`[mysqld]` セクションの設定のみをサーバーに適用する

**一次資料：**
- [MariaDB 公式ドキュメント - Option File Syntax](https://mariadb.com/kb/en/configuring-mariadb-with-option-files/#option-file-syntax)
- [INI ファイル形式（Wikipedia）](https://en.wikipedia.org/wiki/INI_file)


---

## Q15. ソケット接続と TCP 接続の違い
MariaDB のソケット接続と TCP 接続の違いを説明してください。また、一時起動時はソケット、本番起動時は TCP を使う理由を述べてください。

**自分の回答：**
MariaDB のソケット接続は`UNIX Domain Socket`としてアプリケーション層のみで機能し、同一ホスト間（ここでは同一コンテナ内）の通信を確立する。
これを使って外部接続を遮断して設定に専念する。
本番起動では他のコンテナからのSQLを実行し結果を返す必要があるため、トランスポート層を通じて外部に接続するTCPで通信する。

**正解：**
- **ソケット接続（UNIX Domain Socket）**:
  - ファイルシステム上のソケットファイル（`/run/mysqld/mysqld.sock`）を介した通信
  - 同一ホスト（同一コンテナ）内でのみ使用可能
  - TCP/IP スタックを経由しないため高速
  - ネットワーク経由のアクセスは不可能
  
- **TCP 接続**:
  - IP アドレス + ポート番号（例: `172.18.0.2:3306`）を介した通信
  - ネットワーク経由で他のホスト（他のコンテナ）からアクセス可能
  - TCP/IP スタックを経由するためオーバーヘッドあり
  
- **一時起動時はソケット、本番起動時は TCP を使う理由**:
  - 一時起動: `--skip-networking` により TCP を無効化 → ソケットのみ → 外部からの接続を遮断してセキュアに初期化
  - 本番起動: TCP を有効化 → WordPress コンテナからの接続を受け付ける

**解説：**
- 回答は正確で、OSI モデルの理解も含まれている
- 補足: 「アプリケーション層のみで機能」→ 正確には「トランスポート層を経由せず、カーネル内で完結」
- UNIX Domain Socket は IPC（Inter-Process Communication）の一種
- Docker network では、コンテナ間通信は必ず TCP/IP を使用（ソケットファイルは共有されない）

**一次資料：**
- [MariaDB 公式ドキュメント - Connecting to MariaDB](https://mariadb.com/kb/en/connecting-to-mariadb/)
- [UNIX Domain Socket（Wikipedia）](https://en.wikipedia.org/wiki/Unix_domain_socket)

---
## Q16. `mariadb` コマンドと `mysql` コマンドの違い
Alpine の MariaDB パッケージでは `mariadb` コマンドと `mysql` コマンドの両方が使えます。この2つのコマンドの関係を説明してください。

**自分の回答：**
 `mariadb` も`mysql`も MariaDB を動かすコマンドである。　 MariaDB `mysql` コマンドは旧来のmysqlのパッケージを使うユーザーへの下位互換性の確保のために存在する。

**正解：**
- `mariadb` コマンドと `mysql` コマンドは**同じバイナリへのシンボリックリンク**
- Alpine の MariaDB パッケージでは:
  - `/usr/bin/mariadb` → 本体
  - `/usr/bin/mysql` → `/usr/bin/mariadb` へのシンボリックリンク
- 確認方法: `docker run --rm alpine:3.21 sh -c "apk add --no-cache mariadb-client && ls -l /usr/bin/mysql"`
- 関係性:
  - MariaDB は MySQL からフォークしたプロジェクト
  - 下位互換性のため、`mysql` コマンド名も提供している
  - 動作は完全に同一（内部で実行されるバイナリが同じ）
- 他の互換コマンド:
  - `mariadbd` ↔ `mysqld` (サーバー)
  - `mariadb-admin` ↔ `mysqladmin` (管理ツール)
  - `mariadb-dump` ↔ `mysqldump` (バックアップ)

**解説：**
- 回答は概ね正確。「MariaDB を動かすコマンド」→ 正確には「MariaDB クライアント（接続ツール）」
- MariaDB 10.5 以降、`mariadb` という名前のコマンドが追加された（それ以前は `mysql` のみ）
- Inception では `mariadb` コマンドを使うことで、MariaDB であることを明示できる

**一次資料：**
- [MariaDB 公式ドキュメント - mariadb Command-line Client](https://mariadb.com/kb/en/mariadb-command-line-client/)
- [MariaDB vs MySQL - Compatibility](https://mariadb.com/kb/en/mariadb-vs-mysql-compatibility/)
---
## Q17. `ENTRYPOINT` と `CMD` の使い分け
Dockerfile の `ENTRYPOINT` と `CMD` の違いを説明してください。また、MariaDB コンテナでは `ENTRYPOINT` を使う理由を述べてください。

**自分の回答：**

PID1の座を譲れるかどうかの違い。`CMD` で走らせたコマンドはPID1の座を子プロセスに移せない。一方 `ENTRYPOINT` で走らせたスクリプトはPID1の座を`exec`起動したプログラムに移すことができる。

**正解：**
- **`ENTRYPOINT` と `CMD` の違い**:
  - `ENTRYPOINT`: コンテナの**メインコマンド**を定義（変更されにくい）
  - `CMD`: `ENTRYPOINT` への**デフォルト引数**、または単独でメインコマンドを定義（`docker run` で上書き可能）
  - 両方指定した場合: `ENTRYPOINT` + `CMD` が結合される
  
- **MariaDB コンテナで `ENTRYPOINT` を使う理由**:
  1. **初期化処理の実行**: entrypoint.sh で初期化ロジック（`mariadb-install-db`, SQL 実行）を実行してから `mariadbd` を起動
  2. **`exec` による PID 1 継承**: entrypoint.sh 内で `exec mariadbd` を実行することで、mariadbd が PID 1 を継承
  3. **引数の柔軟性**: `docker run` で引数を渡すと、`mariadbd` に引数として渡される（例: `docker run mariadb --verbose`）
  
- **注意**: 「`CMD` では PID 1 を譲れない」は誤解。`CMD ["/entrypoint.sh"]` + entrypoint.sh 内で `exec mariadbd` でも PID 1 を譲れる。違いは「上書きのしやすさ」と「意図の明示」

**解説：**
- 回答の「PID 1 の座を譲れるかどうかの違い」は誤解を含む
- 正しくは: `exec` コマンドが PID 1 を譲る。`ENTRYPOINT` と `CMD` の違いは「役割の明確さ」と「上書きのしやすさ」
- `ENTRYPOINT` を使う実際の理由:
  - 初期化スクリプトを必ず実行させる（`docker run` で上書きされない）
  - `CMD` は引数として扱われる（例: `ENTRYPOINT ["entrypoint.sh"]` + `CMD ["mariadbd"]`）
- MariaDB 公式イメージも `ENTRYPOINT` を使用している

**一次資料：**
- [Docker 公式ドキュメント - ENTRYPOINT](https://docs.docker.com/reference/dockerfile/#entrypoint)
- [Docker 公式ドキュメント - CMD](https://docs.docker.com/reference/dockerfile/#cmd)
- [Docker 公式ドキュメント - Understand how CMD and ENTRYPOINT interact](https://docs.docker.com/reference/dockerfile/#understand-how-cmd-and-entrypoint-interact)
---

## Q18. Alpine 3.21 を選んだ理由

課題では「penultimate stable version」が要件です。なぜ Alpine 3.22 ではなく 3.21 を選んだのですか？また、どこで確認しましたか？

**自分の回答：**

1.ホストマシンCPUの確認：` uname -m`で`arm64`を確認

2.https://alpinelinux.org/downloads/　で安定化最新版の一つ前バージョンを選択

**正解：**
- **penultimate stable version** = 最新安定版の**1つ前**のバージョン
- 確認手順:
  1. [Alpine Linux 公式リリースページ](https://alpinelinux.org/releases/) にアクセス
  2. 最新安定版を確認 → **3.22** (2026年現在)
  3. その1つ前を選択 → **3.21**
- Alpine 3.21 を選んだ理由:
  - 課題要件「penultimate stable version」に準拠
  - 3.22 は最新版（latest）なので対象外
  - 3.20 は2つ前なので対象外
- タスク 1-1 で M2 Mac (arm64) + Vagrant 上での動作確認済み

**解説：**
- 回答は正確。Alpine のダウンロードページで確認している
- 補足: 「penultimate」= "pen-" (ほぼ) + "ultimate" (最後) = 最後から2番目
- 課題要件で「penultimate stable」と指定されている理由:
  - 最新版（latest）は不安定な可能性がある
  - 1つ前のバージョンは十分に枯れていて安定している
  - セキュリティパッチも提供されている
- レビューで「なぜ 3.21 か」と聞かれたら、リリースページのスクリーンショットを見せると説得力がある（`phase_plan.md` に記載予定）

**一次資料：**
- [Alpine Linux 公式リリースページ](https://alpinelinux.org/releases/)
- [Alpine Linux 公式ダウンロードページ](https://alpinelinux.org/downloads/)


---

## 今日詰まったポイント（実装メモ）

### 1. `[mysqld]` セクションヘッダーの欠落
- **問題**: `zaphod-mariadb.cnf` に `bind-address = 0.0.0.0` を書いたのに反映されない
- **原因**: `[mysqld]` セクションヘッダーがなかった
- **確認方法**: `docker logs` で `port: 0` のまま（`port: 3306` にならない）
- **解決**: `[mysqld]` を追加 → `port: 3306` に変化
- **学び**: INI 形式ではセクションヘッダーが必須（セッションログ #0006 の Spike 記録参照）

### 2. 設定ファイルの読み込み順
- **問題**: `mariadb-server.cnf` の設定を上書きしたい
- **解決**: ファイル名を `zaphod-mariadb.cnf` にして、アルファベット順で後に読まれるようにした
- **確認方法**: `docker run --rm --entrypoint sh <image> -c "ls /etc/my.cnf.d/"` で順序確認
- **学び**: `/etc/my.cnf.d/` 内のファイルはアルファベット順に読まれ、後の設定が優先される

### 3. ping ループのタイムアウト設計
- **問題**: 無限ループは課題で禁止されている
- **解決**: 42回のタイムアウトを設定（42秒）
- **学び**: 起動失敗時にコンテナを終了させ、問題を早期発見できるようにする


---

## レビュー想定問答集（弱点中心）

### Q: なぜ `exec` を使うのですか？
**A:** entrypoint.sh のプロセスを mariadbd で置き換えて、mariadbd が PID 1 を継承するためです。`exec` を使わないと、entrypoint.sh が PID 1 のまま残り、`docker stop` で送られる `SIGTERM` が mariadbd に届かず、graceful shutdown ができません。

### Q: 初期化ガードがないとどうなりますか？
**A:** コンテナを再起動するたびに `mariadb-install-db` と初期化 SQL が再実行され、以下の問題が発生します:
1. 起動時間が毎回 10秒程度余計にかかる
2. 既存データへの上書きリスク
3. エラーログが増える（`IF NOT EXISTS` で回避されるが、ログは出力される）

### Q: `bind-address = 127.0.0.1` ではなぜダメですか？
**A:** `127.0.0.1` はループバックアドレスで、コンテナ内からのみ接続可能です。WordPress コンテナから MariaDB コンテナへの接続は Docker network の内部 IP（例: `172.18.0.2`）を使うため、`bind-address = 0.0.0.0`（全てのインターフェース）にする必要があります。

### Q: なぜ一時起動と本番起動の2段階が必要ですか？
**A:** 一時起動（`--skip-networking` 付き）で TCP を無効化し、外部からの接続を遮断してセキュアに初期化 SQL を実行します。初期化完了後、一度シャットダウンしてデータをディスクにフラッシュし、本番起動（TCP 有効）で WordPress からの接続を受け付けます。シャットダウンを挟まないと、ロックファイルの競合やデータ破損のリスクがあります。

### Q: `IF NOT EXISTS` と初期化ガードの両方が必要な理由は？
**A:** 初期化ガードはシェルレベルで初期化処理全体をスキップし、`IF NOT EXISTS` は SQL レベルで個別の文をスキップします。両方を使うことで、多層防御（Defense in Depth）を実現し、初期化ガードが誤って削除された場合でも既存データの破壊を防げます。

### Q: `zaphod-mariadb.cnf` という名前の意図は？
**A:** `z` で始まるファイル名にすることで、`/etc/my.cnf.d/` 内のファイルがアルファベット順に読まれる際、`mariadb-server.cnf` より後に読まれるようにしました。後に読まれた設定が優先されるため、パッケージ提供の設定を上書きできます。`zaphod` は銀河ヒッチハイクガイドの登場人物に由来します。

### Q: ping ループで 42回のタイムアウトを設定した理由は？
**A:** 課題要件で無限ループが禁止されているため、回数制限を設けました。1回 1秒 × 42回 = 42秒で、通常の起動時間（5〜10秒）に対して十分な余裕があります。タイムアウトで終了することで、起動失敗を早期に検出でき、デバッグが容易になります。

### Q: `mariadb-install-db` を Dockerfile の `RUN` で実行してはいけない理由は？
**A:** `RUN` で実行すると、初期化データがイメージレイヤーに焼き込まれます。コンテナ起動時に volume をマウントすると、イメージ内のデータが隠されて使えなくなります。また、パスワード等の機密情報がイメージに含まれてしまいます。entrypoint.sh で実行することで、volume マウント後のディレクトリに対して初期化でき、環境変数を実行時に注入できます。

### Q: Alpine で bash が使えない場合、どう対処しますか？
**A:** Alpine のデフォルトシェルは ash（BusyBox）で、POSIX 準拠の構文のみ使えます。bash 固有の機能（配列、`[[` 条件式、プロセス置換等）は使えないため、POSIX 準拠の代替手段を使います。例えば、配列の代わりに `set -- item1 item2` + `"$@"` を使います。

