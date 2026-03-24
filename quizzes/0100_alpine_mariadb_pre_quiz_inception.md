# Inception 事前理解クイズ - Alpine 3.21 + MariaDB編（フェーズ1）

> 実施日: 2026-03-24
> 目的: フェーズ1開始前の理解度ベースライン測定

---

## Q1. Alpine と Debian の違い

Alpine Linux と Debian の主な違いを3つ挙げてください。（パッケージマネージャ、デフォルトシェル、Cライブラリの観点から）

**自分の回答：**
わからない

**正解：**

| 観点 | Alpine | Debian |
|------|--------|--------|
| パッケージマネージャ | `apk` | `apt` |
| デフォルトシェル | `ash`（BusyBox 提供） | `bash` |
| C ライブラリ | **musl libc** | **glibc** |
| ベースイメージサイズ | 約 5MB | 約 120MB |

**解説：**
Alpine が軽量な理由は musl libc + BusyBox の組み合わせにある。musl と glibc の違いにより、一部のバイナリやライブラリが Alpine 上で動かないことがある。

**一次資料：**
- [Alpine Linux About](https://alpinelinux.org/about/)
- [musl libc](https://musl.libc.org/)

---

## Q2. `apk` の基本コマンド

Alpine のパッケージマネージャ `apk` で以下の操作をするコマンドは？
- (a) パッケージリストの更新
- (b) パッケージのインストール
- (c) キャッシュを残さずインストール（Dockerfile向け）

**自分の回答：**
わからない

**正解：**

| 操作 | コマンド |
|------|---------|
| パッケージリスト更新 | `apk update` |
| インストール | `apk add <パッケージ名>` |
| キャッシュなしインストール | `apk add --no-cache <パッケージ名>` |

**解説：**
Dockerfile では `--no-cache` を使うのが鉄則。`apk update && apk add ... && rm -rf /var/cache/apk/*` と同等のことを1コマンドでやってくれ、イメージサイズの削減になる。

**一次資料：**
- [Alpine Package Keeper](https://wiki.alpinelinux.org/wiki/Alpine_Package_Keeper)

---

## Q3. `ash` と `bash` の違い

Alpine のデフォルトシェル `ash`（BusyBox sh）と `bash` の違いは何ですか？Dockerfile や entrypoint.sh を書くときに注意すべき点を挙げてください。

**自分の回答：**
わからない

**正解：**
`ash` は BusyBox が提供する POSIX 準拠の最小シェル。以下の bash 固有機能（bashism）は使えない：

| 使えない機能 | bash での書き方 | ash での代替 |
|-------------|----------------|-------------|
| 配列 | `arr=(a b c)` | 使えない |
| `[[` 条件式 | `[[ -f file ]]` | `[ -f file ]` |
| brace 展開 | `{1..5}` | `seq 1 5` |
| `source` | `source file.sh` | `. file.sh` |
| プロセス置換 | `<(command)` | 使えない |

**Dockerfile / entrypoint.sh での注意点：**
- shebang は `#!/bin/sh`（`#!/bin/bash` は Alpine にデフォルトでは存在しない）
- bash が必要なら `apk add bash` で入れられるが、通常は不要

---

## Q4. `mariadb` コマンドと `mysql` コマンドの違い

MariaDB 10.5 以降、CLI クライアントコマンド名が変わりました。何がどう変わったか、また古いコマンド名はまだ使えるか答えてください。

**自分の回答：**
わからない

**正解：**
MariaDB 10.5 以降、MySQL 由来のコマンド名が MariaDB 固有名にリネームされた：

| 旧名（MySQL由来） | 新名（MariaDB固有） |
|-------------------|-------------------|
| `mysql` | `mariadb` |
| `mysqld` | `mariadbd` |
| `mysqladmin` | `mariadb-admin` |
| `mysql_install_db` | `mariadb-install-db` |
| `mysqldump` | `mariadb-dump` |

旧名はシンボリックリンクとして残っているので現時点ではまだ使えるが、将来廃止予定。新しく書くなら新名を使うべき。

**一次資料：**
- [MariaDB 10.5.2 Release Notes](https://mariadb.com/kb/en/mariadb-10-5-2-release-notes/) (Renaming executables)

---

## Q5. PID 1 と `exec`

Docker コンテナにおける PID 1 とは何ですか？entrypoint.sh で `exec mariadbd` のように `exec` をつける理由は何ですか？`exec` をつけない場合、何が問題になりますか？

**自分の回答：**
PID 1 はコンテナの外から止めることができる唯一のプロセスの ID。exec をつける理由はわからない。

**評価：** 部分的に正しい。方向性は合っている。

**正解：**

**PID 1 とは：**
- コンテナのメインプロセス。Docker は `docker stop` 時に PID 1 に SIGTERM を送る
- PID 1 が終了するとコンテナ全体が停止する
- Linux カーネルは PID 1 を特別扱いし、明示的にシグナルハンドラを設定しない限り SIGTERM で死なない

**`exec` の役割：**
```
exec なし:
  PID 1: /bin/sh (entrypoint.sh)
  PID 2: mariadbd (子プロセス)

exec あり:
  PID 1: mariadbd (シェルが置き換わる)
```

`exec` をつけるとシェルプロセスが `mariadbd` に置き換わり、`mariadbd` が PID 1 になる。

**`exec` がないと何が問題か：**
1. シェルが PID 1 のまま → Docker が送る SIGTERM をシェルが受け取る
2. シェルはデフォルトで子プロセスに SIGTERM を転送しない → `mariadbd` が graceful shutdown できない
3. Docker は 10 秒待ってから SIGKILL で強制終了 → データ破損のリスク

**一次資料：**
- [Dockerfile reference - ENTRYPOINT](https://docs.docker.com/reference/dockerfile/#entrypoint)
- [Docker stop](https://docs.docker.com/reference/cli/docker/container/stop/)

**注:**
````
結論から言うと、entrypoint.sh のシェルプロセスは kill されるのではなく、消滅します。プロセスIDが「何かになる」のでもありません。

exec はシェルの組み込みコマンドで、やっていることは「現在のプロセスイメージを新しいプログラムで置き換える」です。

これは内部的には Linux の execve(2) システムコールに対応しています。
C を書いたことがあるなら、fork() と execve() の関係をイメージするとわかりやすいはずです。

具体的に何が起きるかというと、PID 1 で /bin/sh（entrypoint.sh）が走っている状態で exec mariadbd が実行されると、PID 1 のプロセスの中身（コードセグメント、データセグメント、スタックなど）が mariadbd のものに丸ごと上書きされます。PID はそのまま 1 のまま変わりません。シェルのプロセスが別のところに移動するのではなく、同じ PID 1 の「中身」が入れ替わるイメージです。

なので、entrypoint.sh のシェルプロセスは kill もされないし、別の PID を持つこともありません。exec の実行後はもう存在しないんです。

42 で C をやっているなら、実際に確認してみると理解が深まると思います。fork() せずに execve() を呼ぶと呼び出し元のプログラムに戻ってこない、というのと同じ話です。
````
---

## Q6. `CMD` vs `ENTRYPOINT`

Dockerfile の `CMD` と `ENTRYPOINT` の違いを説明してください。両方指定した場合はどうなりますか？Inception 課題ではどちらを使うべきですか？

**自分の回答：**
わからない

**正解：**

| | `ENTRYPOINT` | `CMD` |
|--|-------------|-------|
| 役割 | コンテナの**メインコマンド** | ENTRYPOINT への**デフォルト引数** |
| `docker run` で上書き | `--entrypoint` が必要 | 引数を渡すだけで上書き |

**両方指定した場合：**
```dockerfile
ENTRYPOINT ["mariadbd"]
CMD ["--user=mysql"]
```
→ 実行されるのは `mariadbd --user=mysql`。`docker run <image> --verbose` とすると CMD が上書きされ `mariadbd --verbose` になる。

**Inception 課題では：**
`ENTRYPOINT` を使う。コンテナの主プロセス（`mariadbd` 等）が確実に起動されることを保証するため。

**一次資料：**
- [Dockerfile reference - CMD vs ENTRYPOINT](https://docs.docker.com/reference/dockerfile/#understand-how-cmd-and-entrypoint-interact)

---

## 理解度サマリ

| Q | トピック | 結果 |
|---|---------|------|
| Q1 | Alpine vs Debian | 未知 |
| Q2 | apk コマンド | 未知 |
| Q3 | ash vs bash | 未知 |
| Q4 | mariadb vs mysql コマンド | 未知 |
| Q5 | PID 1 / exec | **部分理解**（PID 1 の役割は直感的に把握、exec の仕組みは未知） |
| Q6 | CMD vs ENTRYPOINT | 未知 |

**重点学習ポイント（フェーズ1の実装中に意識すること）：**
- Q3（ash の制約）: entrypoint.sh を書くとき、bashism を避ける
- Q5（exec）: entrypoint.sh の最終行で必ず `exec` をつける理由を体感する
- Q4（コマンド名）: Alpine の MariaDB パッケージでは新名（`mariadbd`, `mariadb-install-db` 等）を使う
