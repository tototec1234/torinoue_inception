# フェーズ3 事前クイズ - WordPress Alpine 編

> 作成日: 2026-04-07
> 採点日: 2026-04-09
> 対象フェーズ: 3（WordPress コンテナ再構築）
> 実施タイミング: フェーズ3 開始前（タスク 3-1 実施前）
> 採点結果: 記述16問中 — 正解10 / ほぼ正解2 / 部分正解3 / 不正解1

---

## Q1. PHP-FPM の役割

NGINX が PHP ファイルのリクエストを受けたとき、NGINX 自身は PHP を実行できません。
なぜ NGINX は直接 PHP を実行できないのか、また代わりに何が PHP を実行するのかを説明してください。

**自分の回答：**
- NginxはPHPインタプリタを内蔵しておらず、PHPコードを実行する能力がない。
- 代わりに、NGINXとは別のWordPressコンテナ内で動くPHP-FPM(FastCGI Process Magager)がPHPインタプリタとしてWordPressのコードを実行し、その結果をNGINXに返す。
- NGINXはその結果をHTTPレスポンスとしてアドレスに返す。

参考：
- NGINXからFastCGIサーバーへのリクエスト転送：
  https://nginx.org/en/docs/http/ngx_http_fastcgi_module.html
- PHP-FPM（FastCGI Process Manager）の概要：
  https://www.php.net/manual/ja/install.fpm.php

**正解：** ✅ 正解

NGINX は静的ファイル配信・リバースプロキシに特化した Web サーバーであり、PHP インタプリタを内蔵していない。PHP の実行は PHP-FPM（FastCGI Process Manager）が担当し、NGINX は FastCGI プロトコルでリクエストを転送する。

**解説：**

回答は正確。「PHPインタプリタを内蔵していない」「PHP-FPM が実行して結果を返す」「NGINX がレスポンスとして返す」という3段階の流れを正しく捉えている。

補足: Apache の `mod_php` のように、Web サーバーに PHP モジュールを組み込む方式もあるが、NGINX はモジュール方式を採用していない。そのため外部プロセス（PHP-FPM）との連携が必須。

**一次資料：**
- [NGINX FastCGI モジュール公式ドキュメント](https://nginx.org/en/docs/http/ngx_http_fastcgi_module.html)
- [PHP-FPM 公式ドキュメント](https://www.php.net/manual/ja/install.fpm.php)

---

## Q2. FastCGI とポート 9000

NGINX の設定ファイルに `fastcgi_pass wordpress:9000;` と書かれています。
この設定の意味を説明してください。「9000」は何のポートで、「wordpress」は何を指しますか？

**自分の回答：**
- `fastcgi_pass`はNGINXがFastCGIプロトコルでリクエストを転送する宛先を指定するディレクティブ

- `wordpress`はPHP-FPMがWordPressのコードを実行しているコンテナの名前。

- `9000`番はPHP-FPMがListenしているポート。
デフォルトが9000番。

- docker-compoeを使用した場合サービス＝コンテナ名になるので、サービス名と`fastcgi_pass`ディレクティブに書いた名前がwordpressで一致すれば名前解決できる。

- docker-composeなしで3コンテナをつなぐ場合は、`docker network create test-net` でユーザー定義ネットワークを作成し、`docker run --name wordpress --network test-net` で起動することで、同一ネットワーク内の他のコンテナから wordpress というコンテナ名でDNS解決できるようになる。`fastcgi_pass wordpress:9000` の `wordpress` がこのコンテナ名を指している。

**正解：** ✅ 正解

- `fastcgi_pass` は NGINX が FastCGI プロトコルでリクエストを転送する宛先を指定するディレクティブ。
- `wordpress` は WordPress コンテナ名（＝ Docker DNS で解決されるホスト名）。
- `9000` は PHP-FPM がリッスンしている TCP ポート。

**解説：**

非常に優れた回答。docker-compose の場合（サービス名 = DNS 名）と、compose なしの場合（`docker network create` + `--name` + `--network`）の両方のシナリオを正確に説明している点が秀逸。フェーズ2のタスク2-5・2-6で実験したユーザ定義ネットワークの知識が活きている。

**一次資料：**
- [ngx_http_fastcgi_module - fastcgi_pass](https://nginx.org/en/docs/http/ngx_http_fastcgi_module.html#fastcgi_pass)

---

## Q3. www.conf の `listen` ディレクティブ

以下の `www.conf` の抜粋があります。

```ini
[www]
user = nobody
group = nobody
listen = 9000
```

`listen = 9000` は何を意味しますか？
また、ここを `listen = /run/php-fpm.sock` のように Unix ソケットにした場合、NGINX の `fastcgi_pass` の書き方はどう変わりますか？

**自分の回答：**
- `listen = 9000`の意味
  - `www.conf`はPHP-FPM(FastCGI Process Manager)のプール設定ファイルである。
  - `[www]`はプール名であり、このプール配下のワーカープロセス群がFastCGIリクエストを処理する。

- `listen = 9000`は、PHP-FPMが`0.0.0.0:9000`（全インターフェース）でTCPソケットをlistenすることを意味する。
  - NGINXはFastCGIプロトコルで PHP の実行リクエストをkのポートに転送し、PHP-FPM のワーカープロセスがPHPを実行してレスポンスを返す。

  - 厳密に記述する場合は`listen = 127.0.0.1:9000`とするのが望ましいが、InceptionのようにNGINXとPHP-FPMが別コンテナの構成では`0.0.0.0:9000`が必要になる。

- Unixソケットに変更した場合
  - `www.conf`側:
    ```ini
    listen = /run/php-fpm.sock
    ```
  - NGINXの`fastcgi_pass`:
    ```nginx
    fastcgi_pass unix:/run/php-fpm.sock;
    ```
    両側の設定を一致する必要がある。

    UnixソケットはTCPと異なりカーネル内で通信が完結するため、オーバヘッドが小さくパフォーマンスが高い。
    ただし、同一ホスト（同一コンテナ）内でしか使えない。

**正解：** ✅ 正解

- `listen = 9000` は PHP-FPM が TCP ポート 9000 で全インターフェース（`0.0.0.0:9000`）からの接続を受け付けることを意味する。
- Unix ソケットに変更する場合: `www.conf` で `listen = /run/php-fpm.sock`、NGINX 側は `fastcgi_pass unix:/run/php-fpm.sock;`。

**解説：**

優れた回答。以下の点が特に良い:
- `[www]` がプール名である点を正確に把握
- `listen = 9000` が `0.0.0.0:9000` を意味する点（PHP-FPM の仕様: ポート番号のみ指定時は全インターフェースでリッスン）
- 別コンテナ構成では `127.0.0.1:9000` だと外部から到達できない、という指摘
- Unix ソケットの NGINX 側記法（`unix:` プレフィックス）が正しい
- 「カーネル内で通信が完結」「同一ホスト内のみ」という TCP vs Unix ソケットの特性比較

Inception では NGINX と PHP-FPM が別コンテナなので、TCP（ポート 9000）が必須。この理解は的確。

**一次資料：**
- [PHP-FPM www.conf 設定リファレンス](https://www.php.net/manual/ja/install.fpm.configuration.php)

---

## Q4. Alpine での PHP パッケージ名

Alpine Linux で PHP 8.3 と PHP-FPM をインストールする `apk add` コマンドを書いてください。
また、Debian/Ubuntu での `apt install php8.3-fpm` と比べてパッケージ名の違いを説明してください。

**自分の回答：**
```bash
# Based on: https://make.wordpress.org/hosting/handbook/server-environment/
RUN apk add --no-cache \
        php83 \
        php83-json \
        php83-mysql \
        php83-curl \
        php83-dom \
        php83-mbstring \
        php83- \
        php83- \
        ...
```    
- バージョンのドットを省略
- php83（コア本体）とphp83-fpm（FPMモジュール）に分かれている
- モジュールは必ずコア本体と別にインストールが必要　→　手間はかかるが、イメージが軽量になる　必要なものだけを明示的に入れる思想

**正解：** ⚠️ 部分正解

```bash
apk add --no-cache \
    php83 php83-fpm \
    php83-phar php83-curl php83-mysqli \
    php83-dom php83-mbstring php83-openssl \
    php83-xml php83-zip php83-fileinfo \
    php83-exif php83-intl php83-igbinary \
    php83-imagick php83-json
```

Debian との違い:
- Debian: `php8.3-fpm`（ドット付きバージョン番号、FPM 込み）
- Alpine: `php83`（コア）+ `php83-fpm`（FPM 別パッケージ）+ 各拡張を個別に追加

**解説：**

命名規則（バージョンのドット省略）、コア本体と FPM の分離、Alpine の「必要なものだけ入れる」思想はすべて正確。

不足点:
- `php83-fpm` が明示されていない（記述中に「php83-fpmに分かれている」と理解は示しているが、コマンド例に含まれていない）
- コマンド例が途中で `php83-` と空のまま中断している。WordPress に必要な拡張一覧（[WordPress Server Environment](https://make.wordpress.org/hosting/handbook/server-environment/)）を参照してタスク 3-2 で完成させること。

なお、Alpine 3.21 + PHP 8.3 では `php83-json` は PHP コアに統合済みのため別パッケージ不要（`apk add php83-json` してもメタパッケージとして `php83` に解決される）。

**一次資料：**
- [Alpine Linux パッケージ検索](https://pkgs.alpinelinux.org/packages)
- [Alpine Linux Wiki - PHP](https://wiki.alpinelinux.org/wiki/PHP)
- [WordPress Server Environment](https://make.wordpress.org/hosting/handbook/server-environment/)

---

## Q5. PHP-FPM の設定ファイルのパス

Alpine 3.21 に `php83-fpm` をインストールしたとき、デフォルトの PHP-FPM 設定ディレクトリはどこですか？
`www.conf` をコンテナにコピーする際の宛先パスとして正しいのはどれですか？

1. `/etc/php/8.3/fpm/pool.d/www.conf`
2. `/etc/php83/php-fpm.d/www.conf`
3. `/usr/local/etc/php-fpm.d/www.conf`
4. `/etc/php-fpm.d/www.conf`

**自分の回答：**
https://pkgs.alpinelinux.org/packages?name=php83-fpm
のどこを見ても設定ファイルのパスは例示されていません。
```bash
docker run --rm alpine:3.21 sh -c \
  "apk add --no-cache php83-fpm && find /etc -name 'www.conf' 2>/dev/null"
  ```
  の結果`/etc/php-fpm.d/www.conf`が出力され確認できます。

**正解：** ❌ 不正解 — 正解は **2. `/etc/php83/php-fpm.d/www.conf`**

**解説：**

実機で `find` コマンドを使って確認した姿勢は非常に良い。しかし結果の解釈に誤りがある可能性がある。

Alpine で `php83-fpm` をインストールすると、設定ファイルの階層は以下の通り:
```
/etc/php83/
├── php-fpm.conf          ← PHP-FPM メイン設定
├── php-fpm.d/
│   └── www.conf          ← プール設定（★ここにコピーする）
└── php.ini
```

Vagrant使用の参考実装（`Vagrant_sample`）でも `COPY conf/www.conf /etc/php83/php-fpm.d/` が使われている。

選択肢の整理:
- 1番 `/etc/php/8.3/fpm/pool.d/` → Debian/Ubuntu の構成
- 2番 `/etc/php83/php-fpm.d/` → **Alpine（php83-fpm パッケージ）の構成** ✅
- 3番 `/usr/local/etc/php-fpm.d/` → Docker 公式 PHP イメージ（php:X.X-fpm-alpine）の構成
- 4番 `/etc/php-fpm.d/` → バージョン番号なしのメタパッケージ `php-fpm` の構成の可能性

再検証で確定:
```bash
$ docker run --rm alpine:3.21 sh -c "apk add --no-cache php83-fpm && find /etc -name '*.conf' -path '*fpm*'"
/etc/php83/php-fpm.conf
/etc/php83/php-fpm.d/www.conf
```
Alpine 3.21 + php83-fpm のパスは **`/etc/php83/php-fpm.d/www.conf`（選択肢2）** で確定。

**一次資料：**
- [Alpine Linux パッケージ中身検索 - php83-fpm](https://pkgs.alpinelinux.org/contents?name=php83-fpm&branch=v3.21) — パッケージがインストールするファイル一覧（`packages` ページではなく `contents` ページ）
- 実機確認: `docker run --rm alpine:3.21 sh -c "apk add --no-cache php83-fpm && find /etc -name '*.conf' -path '*fpm*'"`

---

## Q6. wp-cli のインストール方法

wp-cli は Alpine の `apk` でインストールできません。
Dockerfile でどのようにして wp-cli をインストールしますか？手順を説明してください（curl でダウンロードし、実行可能にする手順）。

**自分の回答：**
`docker run --rm alpine:3.21 sh -c "apk search wp-cli"`で`no such file or directory`なので
https://wp-cli.org/#installing　を参考にすると
```dockerfile
# wp-cli.phar を公式配布元からカレントディレクトリにダウンロード
# ダウンロードした phar が PHP で正常に動作するか確認
# 実行権限を付与し、PATH の通ったディレクトリに移動して `wp` コマンドとして使えるようにする
RUN curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar \
    && php wp-cli.phar --info \
    && chmod +x wp-cli.phar \
    && mv wp-cli.phar /usr/local/bin/wp
    ```


**正解：** ✅ 正解

```dockerfile
RUN curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar \
    && php wp-cli.phar --info \
    && chmod +x wp-cli.phar \
    && mv wp-cli.phar /usr/local/bin/wp
```

**解説：**

正確な手順。公式インストールガイドに沿った3ステップ（ダウンロード → 実行権限付与 → PATH 配置）を正しく記述している。

`php wp-cli.phar --info` による検証ステップは公式ガイドにも記載されているベストプラクティス。ビルド時にダウンロードした phar が壊れていないか確認できる。ただし、本番 Dockerfile ではビルド時間短縮のために省略することも多い。

`apk` で入らないことを `apk search` で確認してからインストール方法を調べた手順も適切。

**一次資料：**
- [wp-cli 公式インストールガイド](https://wp-cli.org/#installing)
- [wp-cli GitHub - builds](https://github.com/wp-cli/builds)

---

## Q7. wp core download のタイミング

以下の2つの方針があります。

- **方針 A（Dockerfile 内）**: `RUN wp core download` → ビルド時に WordPress ソースをイメージに焼き込む
- **方針 B（entrypoint.sh 内）**: コンテナ起動時に `wp core download` → 起動のたびにダウンロード

Inception 課題の要件（volumes でデータ永続化）の観点から、どちらが適切ですか？その理由も説明してください。

**自分の回答：**
B.
データの永続化のためには、WordPressソース自体が、前回コンテナ終了時の状態をDocker volumesに保持している必要がある。ビルド時にWordPressソースをイメージに焼き込むとコンテナ起動時にビルド時の状態に戻ってしまう。


根拠として使えるURL（一次資料）
https://docs.docker.com/engine/storage/volumes/
ここから引用できる根拠は2つ。
- ① コンテナが消えるとデータも消える（だからイメージに焼き込むのはダメ）
デフォルトではコンテナ内で作成されたファイルはすべてコンテナの書き込み可能レイヤーに保存されており、コンテナが削除されるとそのデータも消える。 Docker Docs
- ② volumeを使えばコンテナのライフサイクルに依存せずデータが残る（だからBが正解）
コンテナが削除されても、volumeを使えばデータは保持される。

下記の一次資料は論点がずれている。

**正解：** ⚠️ 部分正解 — **方針 A が基本だが、entrypoint.sh 側の補完が必要になる場合がある**

**解説：**

Vagrant使用の参考実装は方針 A（`RUN wp core download`）を採用している。方針 A の利点:
- ビルド時にレイヤーキャッシュが効く（再ビルド高速化）
- 起動時のネットワーク依存がない
- 起動が高速

ただし、volume の種類によって挙動が異なる:

| volume の種類 | 初回起動時のイメージデータ → volume コピー | Inception での使用 |
|---|---|---|
| **純粋な named volume** | ✅ 起きる | — |
| **`driver_opts: type: none, o: bind`** | ❌ 起きない（bind mount 相当） | ✅ 課題要件 |

Inception では `driver_opts: type: none, o: bind` を使うため、ビルド時にイメージに焼き込んだデータは volume に**自動コピーされない**。これは `quizzes/0102_mariadb_reference_post_quiz_inception.md` Q2 の「ビルド時の `mariadb-install-db` は無意味」と同じ原理。

したがって:
- **方針 A のみでは不十分**: `driver_opts: type: none` の場合、コンテナ起動時に `/var/www/html/` はホスト側のディレクトリ（空）で上書きされるため、イメージ内の WordPress ソースが見えなくなる
- **entrypoint.sh での補完が必要**: 「WordPress ソースがなければコピーする」ガードを entrypoint.sh に入れるか、方針 B のように entrypoint.sh でダウンロードする

ドライバーの回答「B」の根拠は一部正しい:
- ✅ 「ビルド時にイメージに焼き込むとコンテナ起動時にビルド時の状態に戻る」→ bind mount では volume が上書きするのでイメージのデータが見えなくなる（「戻る」ではなく「消える」が正確）
- ✅ volume にデータを残す必要がある
- ❌ ただし「起動のたびにダウンロード」は不正確。ガード（`if [ ! -f /var/www/html/wp-settings.php ]`）で初回のみ実行するべき

**結論**: 方針 A（ビルド時ダウンロード）+ entrypoint.sh でのガード付きコピー/展開がベストプラクティス。この設計はフェーズ3のタスク 3-4 で詰める。

**一次資料：**
- [Docker Volumes - Populate a volume using a container](https://docs.docker.com/engine/storage/volumes/#populate-a-volume-using-a-container) — named volume の初回コピー動作の説明（bind mount では適用されない点に注意）
- [Docker bind mounts](https://docs.docker.com/engine/storage/bind-mounts/) — bind mount はコンテナ内のデータを上書きする挙動の説明
- [Docker Volumes - Use a volume driver](https://docs.docker.com/engine/storage/volumes/#use-a-volume-driver) — local ドライバの `--opt` オプションの説明。ただし `type: none, o: bind` が bind mount 相当になる根拠は Docker 公式ドキュメントには明示的に記載されておらず、Linux の `mount(2)` システムコールの仕様（`mount -t none -o bind` → bind mount）に由来する。Docker の local ドライバはこれらのオプションをそのまま `mount(2)` に渡す。

# Q7. wp core download のタイミング — 修正パッチ

> 作成日: 2026-04-11
> 対象ファイル: `0300_wordpress_alpine_pre_quiz_inception.md`
> 対象箇所: Q7（288〜344行目）

---

## 修正理由

元の正解では「方針 A が基本」としていたが、Inception 課題で `driver_opts: type: none, o: bind` を使う場合、方針 A のメリット（ビルドキャッシュ、起動高速化）は実質的に無効化される。

具体的には：
1. ビルド時に `wp core download` でイメージにファイルを焼き込んでも、起動時に bind mount で上書きされて「見えなくなる」
2. 結局 entrypoint.sh で再度 `wp core download` が必要（インターネットから再ダウンロード）
3. つまりビルド時のダウンロードは**完全に無駄**（ビルド時間とイメージサイズが増えるだけ）

ビルドキャッシュのメリットは「イメージを再ビルドするとき」にしか効かず、コンテナ起動時には関係ない。Inception 課題では頻繁なイメージリビルドを想定しないため、方針 B が合理的。

---

## 修正後の正解・解説

**正解：** ✅ 正解 — **方針 B（entrypoint.sh 内）が適切**

**解説：**

Inception 課題では `driver_opts: type: none, o: bind` を使用するため、**方針 B が合理的**。

### なぜ方針 A は不適切か

| volume の種類 | 初回起動時のイメージデータ → volume コピー | Inception での使用 |
|---|---|---|
| **純粋な named volume** | ✅ 起きる | — |
| **`driver_opts: type: none, o: bind`** | ❌ 起きない（bind mount 相当） | ✅ 課題要件 |

`driver_opts: type: none, o: bind` を使う場合：
1. ビルド時に `RUN wp core download` → イメージ内の `/var/www/html` にファイル保存
2. 起動時に volume（ホスト側の空ディレクトリ）がマウント → イメージ内のファイルは「隠れて」見えなくなる
3. entrypoint.sh で再度 `wp core download` が必要 → **インターネットから再ダウンロード**

つまり、方針 A でビルド時にダウンロードしても、起動時に再ダウンロードが必要なため**完全に無駄**（ビルド時間とイメージサイズが増えるだけ）。

### 方針 A の「メリット」は Inception では無効

| 方針 A のメリット | Inception での実態 |
|---|---|
| ビルド時にレイヤーキャッシュが効く | イメージ再ビルド時のみ有効。起動時には関係ない |
| 起動時のネットワーク依存がない | bind mount で上書きされるため、結局起動時にダウンロード必要 |
| 起動が高速 | 初回起動時は結局ダウンロードが発生 |

Inception 課題では頻繁なイメージリビルドを想定しないため、これらのメリットは実質的に意味がない。

### 方針 B の正しい実装

```bash
# entrypoint.sh
if [ ! -f /var/www/html/wp-settings.php ]; then
    wp core download
fi
```

- 初回起動時のみダウンロード
- 2回目以降は volume にファイルが残っているためスキップ
- 「起動のたびにダウンロード」ではなく、ガード付きで冪等性を確保

### ドライバーの回答「B」の評価

- ✅ 方針 B を選択したのは正しい
- ✅ 「ビルド時にイメージに焼き込むとコンテナ起動時にビルド時の状態に戻る」→ bind mount では volume が上書きするのでイメージのデータが見えなくなる（「戻る」ではなく「消える」が正確）
- ✅ volume にデータを残す必要がある
- ⚠️ 「起動のたびにダウンロード」は不正確。ガードで初回のみ実行するべき

**結論**: Inception 課題（`driver_opts: type: none, o: bind` 使用）では、**方針 B（entrypoint.sh でガード付き `wp core download`）が合理的**。kamitsui のVagrant使用の参考実装もこの方針を採用している。

**一次資料：**
- [Docker Volumes - Populate a volume using a container](https://docs.docker.com/engine/storage/volumes/#populate-a-volume-using-a-container) — named volume の初回コピー動作の説明（bind mount では適用されない点に注意）
- [Docker bind mounts](https://docs.docker.com/engine/storage/bind-mounts/) — bind mount はコンテナ内のデータを上書きする挙動の説明
- [kamitsui Vagrant使用の参考実装 - WordPress](https://kamitsui.github.io/Inception/mandatory/svc_wordpress.html) — `setup.sh` 内で `wp core download` を実行

---

## 採点結果の修正

| 修正前 | 修正後 |
|--------|--------|
| ⚠️ 部分正解 | ✅ 正解（ガードの説明が不足していたため「ほぼ正解」でも可） |
---

## Q8. wp config create コマンド

`wp config create` コマンドの以下の引数について、それぞれ何を意味するか説明してください。

```bash
wp config create \
  --dbhost=mariadb \
  --dbname=wordpress \
  --dbuser=wpuser \
  --dbpass=secret
```

また、このコマンドは何というファイルを生成しますか？

**自分の回答：**

コマンドの引数の意味は上から順に
- このコマンドを使用するWordPressの実態が、動的に生成するものすべてを保存するデータベースサーバーのホスト名を`mariadb`とする
- 使用するデータベースの名前は`wordpress`とする（`mariadb`というサーバーの中に`wordpress`というデータベースがあるという前提）
- 上記データベースには`wpuser`というユーザー名でSQLを行う
- 上記ユーザーの`wordpress`データベースへのログインパスワードは`secret`とする
なお、`--dbhost=mariadb`は`--dbhost=mariadb:3306`と明示的に書いた方がよい。

このコマンドは、`wp-config.php` というファイルを生成する

**正解：** ✅ ほぼ正解

- `--dbhost=mariadb`: データベースサーバーのホスト名（Docker DNS でコンテナ名 `mariadb` に解決）
- `--dbname=wordpress`: 使用するデータベース名
- `--dbuser=wpuser`: データベース接続ユーザー名
- `--dbpass=secret`: データベース接続パスワード
- 生成ファイル: `wp-config.php`

**解説：**

各引数の説明と生成ファイルは正確。

軽微な指摘: `--dbhost=mariadb:3306` と明示すべきという意見は不要。MariaDB/MySQL のデフォルトポートが 3306 であるため、ポートを省略すると自動的に 3306 が使われる（[wp-config.php の DB_HOST 仕様](https://developer.wordpress.org/advanced-administration/wordpress/wp-config/#set-database-host)）。デフォルトポートを明示するのは冗長であり、ポートが非デフォルトの場合のみ `host:port` 形式で指定する。

**一次資料：**
- [wp config create - WP-CLI コマンドリファレンス](https://developer.wordpress.org/cli/commands/config/create/)

---

## Q9. wp core install コマンド

`wp core install` と `wp core download` の違いを説明してください。
また、`wp core install` に必要な引数（`--url`, `--title`, `--admin_user`, `--admin_password`, `--admin_email`）はそれぞれ何を設定しますか？

**自分の回答：**

違い
-  `wp core download` WordPressのコアファイルをダウンロードして展開するだけ
- `wp core install` それらのファイルを元にDBにWordPressのテーブルを作成し、引数を情報を設定する。
引数
- `--url`サイトのアドレス
- `--title`サイトのタイトル
- `--admin_user`管理者ユーザーの名前
- `--admin_password`管理者ユーザーがブラウザから操作する際のパスワード
- `--admin_email`管理者ユーザーのメールアドレス

 wp core install - WP-CLI コマンドリファレンスには　The aaa of the new site.新しいサイトのaaa　と書いてあるが、新しいの意味が掴めない。`--url` `--title`を起動のたびに書き換えたら、同じデータベースを使った異なるサイトが作成されるのか？　だとしたらサイトの移転が楽になるのか？

**正解：** ✅ 正解

- `wp core download`: WordPress のコアファイル（PHP ソースコード）をダウンロードして展開する。ファイルシステムのみの操作。
- `wp core install`: データベースに WordPress のテーブルを作成し、サイトの初期設定（URL、タイトル、管理者アカウント）を登録する。

引数:
- `--url`: サイトの URL（Inception では `https://toruinoue.42.fr`）
- `--title`: サイトのタイトル（ブラウザのタブ等に表示される）
- `--admin_user`: 管理者ユーザー名（"admin" を含んではならない）
- `--admin_password`: 管理者パスワード
- `--admin_email`: 管理者メールアドレス

**解説：**

download と install の違いを正確に理解している。

「新しいサイト」への疑問について: `wp core install` のドキュメントで "new site" と言っているのは「まだインストールされていない WordPress サイトの初期セットアップ」の意味。既にインストール済みの DB に対して `--url` や `--title` を変更して再度 `wp core install` を実行すると、同じ DB 内のオプション（`siteurl`、`blogname`）が**上書き更新**される。新しい別サイトは作成されない。サイト移転の文脈では `wp search-replace` コマンドの方が適切。

**一次資料：**
- [wp core install - WP-CLI コマンドリファレンス](https://developer.wordpress.org/cli/commands/core/install/)
- [wp core download - WP-CLI コマンドリファレンス](https://developer.wordpress.org/cli/commands/core/download/)

---

## Q10. --allow-root オプション

wp-cli を `root` ユーザーで実行すると以下のような警告が出ます。

```
Error: YIKES! It looks like you're running this as root. You might want to run this as a non-root user.
```

Inception 課題では `--allow-root` を使うべきですか？使わないべきですか？その理由を答えてください。

**自分の回答：**
 `--allow-root` を使うべき。根拠は3つ。

-1 外部から隔離されたコンテナ内で実行されるため警告はスルーして良い
-2 設計の一貫性MariaDBと同じ「rootで初期化→適切なユーザーに変更」パターン
-3 Alpine互換性`nobody` はログインシェルを持たないため`su`経由の実行が不安定(下記にて検証済み)
```bash
for img in alpine debian:bookworm; do
  echo "========== Testing on: ${img} =========="

  # Docker コンテナ内で一連のテストを実行
  docker run --rm --user root "${img}" /bin/sh -c '
    # 1) 前準備: Debian 系の場合のみ sudo をインストール
    if [ -f /usr/bin/apt-get ]; then
      apt-get update --quiet
      apt-get install --yes --quiet sudo >/dev/null
    fi

    # 2) テスト実行
    # - 通常の su: nologin のため失敗を期待
    printf "%-20s" "[1. su default]"
    su nobody -c "whoami" || echo "FAILED"

    # - shell 指定 su: /bin/sh を明示して実行
    printf "%-20s" "[2. su --shell]"
    su --shell /bin/sh nobody --command "whoami" 2>/dev/null || echo "FAILED"
  '
done

```

結果
```bash
========== Testing on: alpine ==========
[1. su default]     This account is not available
FAILED
[2. su --shell]     FAILED
========== Testing on: debian:bookworm ==========
Fetched 9242 kB in 2s (5215 kB/s)
Reading package lists...
debconf: delaying package configuration, since apt-utils is not installed
[1. su default]     This account is currently not available.
FAILED
[2. su --shell]     nobody
```
runuser / sudo はユーザー切り替えの代替手段として有用だが、--allow-root の是非という本論からは外れるため本編では扱わない。
比較結果と実行ログは学習用の補助資料 dev_docs/0408su_runuser_sudo_comparison_notes.md に分離した。
なお、現在、一時資料は404でした。

**正解：** ✅ 正解

Inception では `--allow-root` を使うのが現実的な選択。

**解説：**

3つの根拠がすべて的確:
1. **コンテナ隔離**: Docker コンテナ内での root は、ホスト OS の root とは異なる名前空間で動作するため、wp-cli が想定する「本番サーバーでの root 実行リスク」は大幅に軽減される。
2. **設計の一貫性**: MariaDB entrypoint.sh でも root で初期化 → `exec mariadbd`（mariadbd が内部的にユーザーを切り替え）というパターンを採用済み。
3. **Alpine 互換性**: `nobody` ユーザーは `nologin` シェルのため `su` での切り替えが困難。実機テストで検証済みなのが優秀。

なお、一次資料（wp-cli FAQ）が 404 だった件は、wp-cli サイトのリニューアルで URL が変更された可能性がある。代替: [wp-cli handbook - running-wp-cli](https://make.wordpress.org/cli/handbook/)

**一次資料：**
- [wp-cli FAQ - Running as root](https://wp-cli.org/docs/common-issues/#error-yikes-it-looks-like-youre-running-this-as-root)

---

## Q11. MariaDB 待機ループの設計

WordPress の `entrypoint.sh` では MariaDB が起動するまで待機する必要があります。
以下の2つの実装を比較して、どちらが本番環境向けとして適切か、またその理由を答えてください。

**実装 A（タイムアウトなし）:**
```sh
until mariadb-admin ping -h mariadb -u "$MARIADB_USER" -p"$MARIADB_PASSWORD" --silent 2>/dev/null; do
    sleep 3
done
```

**実装 B（タイムアウト付き）:**
```sh
i=0
until mariadb-admin ping -h mariadb -u "$MARIADB_USER" -p"$MARIADB_PASSWORD" --silent 2>/dev/null; do
    i=$((i + 1))
    if [ "$i" -ge 42 ]; then
        echo "MariaDB did not become ready in time" >&2
        exit 1
    fi
    sleep 3
done
```

**自分の回答：**

B.MariaDBが一定時間内に起動しない場合WopdPressコンテナをタイムアウトで落とす必要がある。A.の実装では、MariaDBが起動しない状態でWordPressがエラーを吐き、未定義動作になるおそれがある。
一次資料では、Dockercompose.yml内での`healthcheck:`でタイムアウトを機能させているが。Inceptionの実装ではWordPress の `entrypoint.sh` のレイヤーでもタイムアウトを機能させる。

**正解：** ✅ ほぼ正解 — 実装 B（タイムアウト付き）

**解説：**

B を選んだ判断と理由は正しい。`healthcheck` との多層防御の視点も良い。

軽微な不正確さ: 「MariaDBが起動しない状態でWordPressがエラーを吐き、**未定義動作**になるおそれがある」は不正確。実装 A の問題点は「未定義動作」ではなく、**コンテナが `until` ループから永久に抜けられなくなること（ハング）**。WordPress の初期化処理に到達しないので「エラーを吐く」こともない。ログに出力が出ず、問題の診断が困難になることが本質的な問題。

まとめ:
- タイムアウトなし → **無限ハング**（リソース浪費 + 診断困難）
- タイムアウトあり → **明確なエラーメッセージ + exit 1**（`docker logs` で原因特定可能、`restart: always` で再試行もできる）

**一次資料：**
- [Docker Compose depends_on vs healthcheck](https://docs.docker.com/compose/how-tos/startup-order/)

---

## Q12. PHP-FPM のフォアグラウンド起動

entrypoint.sh の最後に `exec php-fpm83 -F` と書かれています。
`-F` オプションと `exec` のそれぞれの役割を説明してください。

**自分の回答：**

`exec `の役割について
- `docker stop` の SIGTERM の送り先がコンテナの PID 1 である。
`exec`は実行しているプロセスのPIDを引数で指定した実行ファイルを実行したプロセスに譲る、
- ここでの役割は`entrypoint.sh`のPID1をphp-fpm83に譲ることで、`docker stop`でphp-fpm83を安全に確実に停止することを可能にする。

`-F` オプションのそ役割
- php-fpmはデフォルトがデーモンなので明示的に `-F` が必要

- なおMariaDBの mysqld はデフォルトでフォアグラウンド動作するため特に指定不要

- `-F` 一次資料は役に立たなかったので、オンラインマニュアルで確認した。
	```bash
	docker run --rm php:8.3-fpm-alpine php-fpm --help
	```

**正解：** ✅ 正解

- `exec`: 現在のシェルプロセス（PID 1）を `php-fpm83` に**置き換える**。これにより `php-fpm83` が PID 1 となり、`docker stop` の SIGTERM を直接受信できる。
- `-F`: PHP-FPM をフォアグラウンドモードで起動する。デフォルトはデーモン（バックグラウンド）モード。

**解説：**

PID 1 と exec の関係はフェーズ1（MariaDB `entrypoint.sh` の `exec mariadbd`）で学んだ概念がそのまま活きている。

`-F` オプションについて「一次資料は役に立たなかった」として `php-fpm --help` で確認した姿勢が非常に良い。一次資料が不十分な場合にコマンドの `--help` で確認するのはエンジニアの基本スキル。

補足: `mariadbd` がデフォルトでフォアグラウンド動作するという指摘も正確。Docker で使うプロセスはフォアグラウンドで動く必要があり、各デーモンごとにデフォルト挙動とオプションが異なる:
- `mariadbd`: デフォルトでフォアグラウンド → オプション不要
- `php-fpm`: デフォルトでデーモン → `-F` が必要
- `nginx`: デフォルトでデーモン → `daemon off;` が必要

**一次資料：**
- [PHP-FPM マニュアル - オプション](https://www.php.net/manual/ja/install.fpm.php)
- [Docker ベストプラクティス - PID 1](https://docs.docker.com/develop/develop-images/dockerfile_best-practices/#entrypoint)

---

## Q13. www.conf の pm 設定

以下の `www.conf` の `pm`（プロセスマネージャー）設定について、各ディレクティブが何を意味するか説明してください。

```ini
pm = dynamic
pm.max_children = 5
pm.start_servers = 2
pm.min_spare_servers = 1
pm.max_spare_servers = 3
```

また、`pm = static` との違いは何ですか？

**自分の回答：**

- ワーカープロセス（以下、子プロセス）の管理方法　動的に走らせる　`pm = dynamic`
	`pm = dynamic`の場合、下記の4つは必須
- 子プロセスの最大数　`pm.max_children = 5`
- サーバー起動時に作成される子プロセスの数`pm.start_servers = 2`
- アイドル状態のサーバープロセス数の最小値`pm.min_spare_servers = 1`
- アイドル状態のサーバープロセス数の最大値`pm.max_spare_servers = 3`

`pm = static` の場合
- 子プロセスの数は`pm.max_children`のみ必須で、これで指定した値に固定される。
- `pm.start_servers` `min_spare_servers` `max_spare_servers` は書いても無視される 


**正解：** ✅ 正解

- `pm = dynamic`: 負荷に応じてワーカープロセス数を動的に増減
- `pm.max_children = 5`: 同時に存在できる子プロセスの最大数
- `pm.start_servers = 2`: 起動時に作成される子プロセス数
- `pm.min_spare_servers = 1`: アイドル状態の子プロセスの最小数（これを下回ると新規生成）
- `pm.max_spare_servers = 3`: アイドル状態の子プロセスの最大数（超過分は終了）

`pm = static` では `pm.max_children` で固定数のプロセスを常時維持。動的な増減は行わない。

**解説：**

すべてのディレクティブを正確に説明している。`pm = static` との違いも的確。

補足として、`pm = dynamic` が Inception のような小規模環境に適している理由: コンテナのメモリが限られるため、常時 max_children 分のプロセスを起動しておく static より、負荷に応じて増減する dynamic の方がリソース効率が良い。

**一次資料：**
- [PHP-FPM 設定リファレンス - pm](https://www.php.net/manual/ja/install.fpm.configuration.php)

---

## Q14. wp user create コマンド

Inception 課題では管理者ユーザーに加え、「admin」を含まないユーザー名の一般ユーザーを1名追加する必要があります。
以下のコマンドの `--role=editor` の部分について:

1. WordPress のデフォルトのロール一覧を挙げてください（5種類）
2. なぜ2番目のユーザーに `subscriber` ではなく `editor` が推奨されることが多いのか説明してください

```bash
wp user create editor_user editor@example.com --role=editor --user_pass=secret
```

**自分の回答：**

WordPress のデフォルトのロール一覧
1. 管理者：`administrator` – 単一サイト内のすべての管理機能にアクセスできる人物。
2. エディター：`editor` – 他​​のユーザーの投稿を含め、投稿を公開および管理できる人。
3. 著者  ：`author` – 自分の投稿を公開および管理できる人。
4. 投稿者：`contributor` – 自分の投稿を作成および管理することはできるが、公開することはできない人。
5. 購読者：`subscriber` – 自分のプロフィールのみを管理できるユーザー。

2番目のユーザーに `subscriber` ではなく `editor` が推奨される理由
- 2番目のユーザーというのはID2のことである。

- ID1はWordPressのプロビジョニング (Provisioning): OSのセットアップからWordPressのインストール、プラグインの導入までを自動で行う一連の流れ　の中で
	```bash
	# 1. まずインストール（ここで ID 1 ができる）
	# 	ID 1 の固定: WordPressの仕様上、最初に作成されるユーザーには必ず自動インクリメント（Auto Increment）によって ID 1 が割り当てられる
	docker-compose run --rm wordpress-cli wp core install \
	  --url=http://localhost:8080 \
	  --title="My Docker Site" \
	  --admin_user=admin \
	  --admin_password=password \
	  --admin_email=admin@example.com
	```
	が実行され完了してコンテナが終了するまでの間に、最初に必ず ID 1 の「管理者（Administrator）」アカウントが作成される。

	```bash
	# 2. 直後に作成したユーザーにはインクリメントされ自動的にID 2 が割り振られる
	wp user create editor_user editor@example.com --role=editor
	```

	これがID2であるが、「IDの番号＝何番目に作られたか」と、権限や優先順位ば無関係である（`0409wp-user-list-order-effects.md`参照）。

	上記の前提で
	「2番目のユーザー（管理者以外で最初に作るユーザー）」に `editor`（編集者） が推奨されるのは、セキュリティと運用の役割分担のためです。
	1. セキュリティ：最小権限の原則（Principle of Least Privilege）
サイトの所有者であっても、日常的な記事の投稿や管理に常に「管理者（`administrator`）」アカウントを使うのはリスクがあります。

		- **万が一の被害を抑える:** もしログイン状態のブラウザが乗っ取られたり、パスワードが漏洩したりした場合、管理者権限だとテーマの削除、プラグインの改ざん、他のユーザーの削除など、サイトを完全に破壊される恐れがあります。

		- **編集者の制限:** `editor` 権限であれば、コンテンツ（記事や画像）の管理はフルにできますが、システム設定やプラグインの変更はできません。これにより、「うっかりミス」によるサイト停止も防げます。
	2. 「購読者（`subscriber`）」では実務ができない

		- **購読者の権限:** 基本的に「自分のプロフィールを更新する」ことしかできない。記事を書くことも、画像をアップロードすることも不可能。
		- **編集者の権限:** 自分の記事だけでなく、他のユーザーが書いた記事の編集・公開も可能。また、カテゴリーの管理やコメントの承認も行える。

	よって、**「サイトの運営・更新業務」を丸ごと任せられる最低限かつ十分な権限**として `editor` が推奨される。

**正解：** ✅ 正解

WordPress のデフォルトロール（権限の強い順）:
1. **Administrator** — サイト全体の管理（テーマ、プラグイン、ユーザー管理等）
2. **Editor** — 全投稿の管理（自分・他人の記事の編集・公開・削除、カテゴリ管理）
3. **Author** — 自分の投稿の公開・管理
4. **Contributor** — 自分の投稿の作成（公開は不可、レビュー待ち）
5. **Subscriber** — 自分のプロフィール管理のみ

**解説：**

5ロールの列挙、各ロールの説明が正確。editor 推奨理由として「最小権限の原則」「subscriber では実務ができない」の2点を挙げているのが良い。

ID の自動インクリメントに関する補足説明は興味深いが、この問題の論点（なぜ editor か）からは少し逸れている。核心は:
- **subscriber**: 記事投稿・管理が一切できない → レビューアーに「2番目のユーザーでログインして記事を書いてみて」と言われた時に何もできない
- **editor**: コンテンツ管理のフル権限はあるが、システム設定（プラグイン・テーマ）は変更不可 → レビューで「記事を書く」「記事を編集する」等のデモが可能

**一次資料：**
- [wp user create - WP-CLI コマンドリファレンス](https://developer.wordpress.org/cli/commands/user/create/)
- [WordPress ユーザーロールと権限](https://wordpress.org/documentation/article/roles-and-capabilities/)

---

## Q15. wp core is-installed による冪等性

entrypoint.sh で `wp core is-installed` を使って初期化ガードを実装します。

```sh
if ! wp core is-installed 2>/dev/null; then
    wp core install ...
    wp user create ...
fi
```

このガードがないと何が起きますか？また `2>/dev/null` の役割は何ですか？

**自分の回答：**
- このガードがないと冪等性が保証されないので、（mariadbコンテナと異なりデータの上書きなどは心配しなくて良いが）再度インストールと初期設定が行われ時間がかかる。
- もし 2>/dev/null を付けずに、WordPressがまだインストールされていない環境でこの`core is-installed`が実行されると、ターミナルに赤色でエラーメッセージが表示され、見た目がスクリプト自体がエラーを起こしているように見えてしまう。
- また、MariaDB サーバーが起動していない状態で `wp core is-installed` を叩くと、ターミナルには 「Error: Error establishing a database connection（データベース接続確立のエラー）」 というかなり目立つ警告がです。
-　これらを防ぐことが `2>/dev/null` の役割。
-　なおインストール時の標準出力（成功時のメッセージ）も消したいなら、`wp core is-installed > /dev/null 2>&1` 
	memo:`0409_what_is_wp_cli_identity.md` `0409_wp_is_installed_logic.md`

**正解：** ⚠️ 部分正解

- ガードがないと: コンテナ再起動のたびに `wp core install` と `wp user create` が再実行され、**エラーが発生する**。
- `2>/dev/null`: 標準エラー出力を抑制する。

**解説：**

`2>/dev/null` の説明は正確。「WordPress 未インストール時のエラー表示を抑制する」「MariaDB 未起動時の DB 接続エラーを抑制する」という2つのケースを挙げている点も良い。

不足点: ガードがない場合の影響を「時間がかかる」と表現しているが、実際にはもっと深刻:
- `wp core install` を既にインストール済みの環境で実行すると: 「WordPress is already installed.」と**エラー**で終了する（致命的ではないが不要なエラーログが出る）
- `wp user create` を既存ユーザーに対して実行すると: 「Error: 'editor_user' is an existing user.」と**エラーで失敗する**

つまり、ガードの役割は単なる時間短縮ではなく、**エラーの発生を防止して冪等性を保証する**こと。MariaDB の `entrypoint.sh` では `if [ ! -d "/var/lib/mysql/mysql" ]` で初期化ガードしたのと同じ考え方。

**一次資料：**
- [wp core is-installed - WP-CLI コマンドリファレンス](https://developer.wordpress.org/cli/commands/core/is-installed/)

---

## Q16. NGINX と WordPress 間の通信経路

3コンテナ構成において、ブラウザから WordPress のページが表示されるまでの通信経路を説明してください。
以下の空欄を埋めてください。

```
ブラウザ
  ↓ (1) プロトコル: ___、ポート: ___
NGINX コンテナ
  ↓ (2) プロトコル: ___、ポート: ___
WordPress コンテナ（PHP-FPM）
  ↓ (3) プロトコル: ___、ポート: ___
MariaDB コンテナ
```

**自分の回答：**

```
ブラウザ
  ↓ (1) プロトコル: **HTTPS**、ポート: **443**
NGINX コンテナ
  ↓ (2) プロトコル: **FastCGI**、ポート: **9000**
WordPress コンテナ（PHP-FPM）
  ↓ (3) プロトコル: **MySQLプロトコル:**、ポート: **3306**
MariaDB コンテナ
```
補足、HTTPS、FastCGI、MySQLプロトコルのレイヤー関係
- これらはすべて、OSI参照モデルにおける 「第7層：アプリケーション層」 に属する。
- したがって、レイヤーが異なるわけではなく、「同じ階層で、用途が異なるプロトコル」 という関係。
- 階層が異なるプロトコルの例は

階層のイメージ（上が上位レイヤー）
| OSI参照モデルにおける階層 | プロトコル | 用途 |
| :--- | :--- | :--- |
| アプリケーション層 | HTTPS|何を話すか：Webページをくれ|
| トランスポート層 |TCP|どう運ぶか：確実に、順番通りに|
| ネットワーク層 |IP|どこへ運ぶか：宛先IPアドレス|
memo:`0300_wordpress_alpine_pre_quiz_inception.md`



**正解：** ✅ 正解

```
ブラウザ
  ↓ (1) プロトコル: HTTPS、ポート: 443
NGINX コンテナ
  ↓ (2) プロトコル: FastCGI、ポート: 9000
WordPress コンテナ（PHP-FPM）
  ↓ (3) プロトコル: MySQL プロトコル、ポート: 3306
MariaDB コンテナ
```

**解説：**

3つの通信経路すべて正確。OSI 参照モデルとの対応付けも適切で、HTTPS / FastCGI / MySQL プロトコルがすべてアプリケーション層（L7）で動作し、その下を TCP（L4）/ IP（L3）が支えるという構造を正しく理解している。

補足として、Inception の通信セキュリティ設計:
- **(1) HTTPS（TLS）**: ブラウザ → NGINX 間は暗号化。課題要件で TLSv1.2/1.3 のみ許可。
- **(2) FastCGI**: NGINX → WordPress 間は**平文**。Docker の内部ネットワーク内なので暗号化不要（ネットワークが隔離されている）。
- **(3) MySQL プロトコル**: WordPress → MariaDB 間も**平文**。同じく Docker 内部ネットワーク。

**一次資料：**
- [NGINX FastCGI モジュール](https://nginx.org/en/docs/http/ngx_http_fastcgi_module.html)
- [MariaDB デフォルトポート](https://mariadb.com/docs/server/ref/mdb/system-variables/port/)
