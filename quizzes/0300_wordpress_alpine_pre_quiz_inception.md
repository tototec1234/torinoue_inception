# フェーズ3 事前クイズ - WordPress Alpine 編

> 作成日: 2026-04-07
> 対象フェーズ: 3（WordPress コンテナ再構築）
> 実施タイミング: フェーズ3 開始前（タスク 3-1 実施前）

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

**正解：**

**解説：**

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

**正解：**

**解説：**

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

**正解：**

**解説：**

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

**正解：**

**解説：**

**一次資料：**
- [Alpine Linux パッケージ検索](https://pkgs.alpinelinux.org/packages)
- [Alpine Linux Wiki - PHP](https://wiki.alpinelinux.org/wiki/PHP)

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
**正解：**

**解説：**

**一次資料：**
- [Alpine Linux パッケージ検索 - php83-fpm](https://pkgs.alpinelinux.org/packages?name=php83-fpm)

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


**正解：**

**解説：**

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

**正解：**

**解説：**

**一次資料：**
- [Docker ベストプラクティス - レイヤーキャッシュ](https://docs.docker.com/develop/develop-images/dockerfile_best-practices/)

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
（ここに記入）

**正解：**

**解説：**

**一次資料：**
- [wp config create - WP-CLI コマンドリファレンス](https://developer.wordpress.org/cli/commands/config/create/)

---

## Q9. wp core install コマンド

`wp core install` と `wp core download` の違いを説明してください。
また、`wp core install` に必要な引数（`--url`, `--title`, `--admin_user`, `--admin_password`, `--admin_email`）はそれぞれ何を設定しますか？

**自分の回答：**
（ここに記入）

**正解：**

**解説：**

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
（ここに記入）

**正解：**

**解説：**

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
（ここに記入）

**正解：**

**解説：**

**一次資料：**
- [Docker Compose depends_on vs healthcheck](https://docs.docker.com/compose/how-tos/startup-order/)

---

## Q12. PHP-FPM のフォアグラウンド起動

entrypoint.sh の最後に `exec php-fpm83 -F` と書かれています。
`-F` オプションと `exec` のそれぞれの役割を説明してください。

**自分の回答：**
（ここに記入）

**正解：**

**解説：**

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
（ここに記入）

**正解：**

**解説：**

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
（ここに記入）

**正解：**

**解説：**

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
（ここに記入）

**正解：**

**解説：**

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
（ここに記入）

**正解：**

**解説：**

**一次資料：**
- [NGINX FastCGI モジュール](https://nginx.org/en/docs/http/ngx_http_fastcgi_module.html)
- [MariaDB デフォルトポート](https://mariadb.com/docs/server/ref/mdb/system-variables/port/)
