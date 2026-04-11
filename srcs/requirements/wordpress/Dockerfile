# ベースイメージ: penultimate stable version
# 根拠: https://alpinelinux.org/releases/
FROM alpine:3.21

# 1. 実行時に必要なパッケージのインストール
# 選定理由は下記参照
# dev_docs/0409php_packages.md
RUN apk add --no-cache \
    # 1. 基盤
    php83 php83-fpm php83-phar \
    # 2. 通信・DB
    php83-curl php83-mysqli \
    # 3. データ形式
    php83-xml php83-dom \
    # 4. 文字処理
    php83-mbstring

# 2. インストールしたパッケージをCLIで実行できるようにする。
#  docker run --rm alpine:3.21 sh -c "apk search wp-cli"でno such file or directoryなので https://wp-cli.org/#installing　を参考にすると
# wp-cli.phar を公式配布元からカレントディレクトリにダウンロード
# ダウンロードした phar が PHP で正常に動作するか確認
# 実行権限を付与し、PATH の通ったディレクトリに移動して `wp` コマンドとして使えるようにする
RUN curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar \
&& php wp-cli.phar --info \
&& chmod +x wp-cli.phar \
&& mv wp-cli.phar /usr/local/bin/wp

# 3.　作業（WordPressファイルを置くところ）の用意と指定
RUN mkdir -p /var/www/html && chown -R nobody:nobody /var/www/html
WORKDIR /var/www/html

# 4. 設定ファイルの配置
# Alpine の !includedir 構造を利用
# docker run --rm alpine:3.21 sh -c "apk add --no-cache php83-fpm && find /etc -name '*.conf' -path '*fpm*'"
# で確認
COPY  conf/www.conf /etc/php83/php-fpm.d/
COPY tools/entrypoint.sh
RUN chmod +x /entrypoint.sh

# 5. コンテナ起動時の実行コマンド
ENTRYPOINT ["/entrypoint.sh"]