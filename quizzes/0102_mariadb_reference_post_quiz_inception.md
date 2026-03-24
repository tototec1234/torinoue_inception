# Inception 事後ミニクイズ - 参考実装 MariaDB 精読編（タスク1-2）

> 実施日: 2026-03-24
> 目的: 参考実装（Vagrant_sample）の MariaDB 関連ファイル精読後の理解度確認

---

## Q1. `mariadb-install-db` の役割

参考実装では `mariadb-install-db` を Dockerfile の `RUN` で実行しています。このコマンドは何をしますか？また、ボリュームマウント（`mariadb_data:/var/lib/mysql`）がある場合、ビルド時にこれを実行する意味はありますか？

**自分の回答：**
RUN は引数のシェルコマンドを実行する。ここでは install とあるがこれは apk add でダウンロードした mariadb をインストールさせ mysql に所有権を持たせる。所有権の概念は未学習で説明できない。/run/mysqld /var/lib/mysql については意味がわからない。

**評価：** `RUN` の理解はOK。ただし `mariadb-install-db` と `apk add` を混同している。

**正解：**
`apk add mariadb` と `mariadb-install-db` は別々の手順：

| コマンド | 役割 |
|---------|------|
| `apk add mariadb` | MariaDB のプログラム（バイナリ）を `/usr/bin/` にインストール |
| `mariadb-install-db` | MariaDB の内部管理用データベース（権限テーブル等）を `/var/lib/mysql/` 内に作成 |

ディレクトリの意味：

| パス | 用途 |
|------|------|
| `/run/mysqld/` | ソケットファイル（`.sock`）の置き場所。同一コンテナ内でクライアント ↔ サーバー間の通信に使う |
| `/var/lib/mysql/` | MariaDB の全データが入る場所。ボリュームマウントの対象 |

`chown -R mysql:mysql`（所有権）について：Linux ではすべてのファイルに「誰のものか」という情報がある。`mariadbd` は `root` ではなく `mysql` ユーザーとして動くので、データディレクトリを `mysql` ユーザーが読み書きできるようにする必要がある。

ボリュームマウントがある場合、ビルド時に `/var/lib/mysql/` に作ったデータは実行時にボリュームが上書きマウントされるため消える。つまりビルド時の `mariadb-install-db` は**無意味**。

**一次資料：**
- [mariadb-install-db](https://mariadb.com/kb/en/mariadb-install-db/)

---

## Q2. 一時起動 → シャットダウン → 本番起動の理由

entrypoint.sh はなぜ `mariadbd` を一度バックグラウンドで起動し、SQL を流してから `mariadb-admin shutdown` で停止し、もう一度 `exec mariadbd` で起動しているのですか？1回の起動だけではダメな理由は？

**自分の回答：**
よくわからないが設定のために起動したのでちゃんと終了できることを確認しないと、本番使用に出せないから。

**評価：** 方向性は悪くないが、核心が違う。

**正解：**
SQL を実行するには、MariaDB サーバーが起動している必要がある。止まっているサーバーには SQL を流せない。

```
1. mariadbd &              ← SQL を受け付けるためにまず起動（一時）
2. mariadb <<EOF ...       ← 起動中のサーバーに SQL を送信（DB作成・ユーザー作成）
3. mariadb-admin shutdown  ← 初期化完了、一時サーバーを正常停止
4. exec mariadbd           ← 本番起動（PID 1 として）
```

一度止めて再起動する理由：
- 一時起動は `&`（バックグラウンド）なので PID 1 ではない
- 既に動いているプロセスの PID は変えられない（Linux の制約）
- `exec mariadbd` で PID 1 として起動し直す必要がある（事前クイズ Q5）
- 止めずに `exec mariadbd` すると 2 つの `mariadbd` が同時起動し、ポートやデータファイルの競合でクラッシュする

**一次資料：**
- [Dockerfile reference - ENTRYPOINT](https://docs.docker.com/reference/dockerfile/#entrypoint)

---

## Q3. `sleep 2` の問題点

参考実装は `mariadbd &` の後に `sleep 2` で固定時間待機しています。この方法の問題点は何ですか？自分の実装ではどう改善する予定ですか？

**自分の回答：**
バックグラウンドでの起動処理が2秒以内に終わらない場合、mariadb コマンドで呼び出した時に実体が存在しないため予期せぬエラーを起こすから。

**評価：** **正解。** 的確に理解している。

**正解：**
`sleep 2` は固定時間待機なので、起動が遅い環境では不十分。改善方法は ping ループ：

```sh
while ! mariadb-admin ping --silent 2>/dev/null; do
    sleep 1
done
```

実際に MariaDB が応答可能になるまで待てる。さらにタイムアウトを付ければ無限ループも防げる。

---

## Q4. `IF NOT EXISTS` の意味

SQL文で `CREATE DATABASE IF NOT EXISTS` や `CREATE USER IF NOT EXISTS` を使っている理由は何ですか？これがないとどうなりますか？

**自分の回答：**
冪等性を保証するため。よくわからないがすでにあるものを上書きするとエラーを起こすのか、それとも、キャッシュが無駄になるからか。

**評価：** 冪等性の概念は正しい。「エラーを起こすのか」が正解。

**正解：**
`IF NOT EXISTS` がない場合、2 回目の起動で SQL がエラーになる：
- `CREATE DATABASE db;` → 既に存在する → **ERROR 1007: Can't create database; database exists**
- `CREATE USER 'user'@'%';` → 既に存在する → **ERROR 1396: Operation CREATE USER failed**

コンテナは `restart: always` で再起動されるので、entrypoint.sh は何度も実行される。毎回安全に動く（=冪等）ことが重要。

---

## Q5. Dockerfile の改善点（イメージサイズ）

参考実装の Dockerfile（`apk update && apk add mariadb mariadb-client`）にはイメージサイズの観点で改善すべき点があります。具体的に何をどう直すべきですか？

**自分の回答：**
冪等性を保証し、すでに最新のものがダウンロードされキャッシュに残っているならそれを使うようにする。イメージサイズの観点では効果がある理由は知らないが、すくなくともダウンロードしたり展開する時間のロスは防げそう。

**評価：** 方向性が違う。冪等性の話ではなく、キャッシュファイルの削除の話。

**正解：**
```
問題:  apk update && apk add mariadb mariadb-client
改善:  apk add --no-cache mariadb mariadb-client
```

`apk update` はパッケージインデックス（どんなパッケージがあるかのリスト）を `/var/cache/apk/` にダウンロードする。これがイメージのレイヤーに残る。`--no-cache` はインデックスを一時的に取得して、インストール後に自動的に削除する。結果としてイメージサイズが小さくなる。

**一次資料：**
- [Alpine Package Keeper](https://wiki.alpinelinux.org/wiki/Alpine_Package_Keeper)

---

## 理解度サマリ

| Q | トピック | 結果 |
|---|---------|------|
| Q1 | mariadb-install-db の役割 | 混同あり → 解説で整理済み |
| Q2 | 2段階起動の理由 | 方向性OK → SQL実行のため＋PID 1 |
| Q3 | sleep の問題点 | **正解** |
| Q4 | IF NOT EXISTS と冪等性 | 概念OK → エラー防止が正解 |
| Q5 | --no-cache | 混同あり → キャッシュ削除によるサイズ削減 |

**追加で得た知識（チャットでの質疑応答）：**
- `apk add mariadb` のバイナリは `/usr/bin/` に保存される
- ソケットファイルは `mariadbd` が起動時に自動作成する（ディレクトリは事前に作る必要あり）
- 一時起動を止めるのは課題の縛りではなく技術的必然（PID の変更不可 + プロセス競合防止）
