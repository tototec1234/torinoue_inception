# ベースイメージ: penultimate stable version
# 根拠: https://alpinelinux.org/releases/
FROM alpine:3.21

# 証明書と鍵を一括管理
ENV SSL_DIR=/etc/nginx/ssl

# 1. 実行時に必要なパッケージ（TLS 用 openssl と Web サーバ）のインストール
# 根拠（Alpine）: https://wiki.alpinelinux.org/wiki/Nginx
# NGINX 公式ドキュメント（挙動・設定の一次資料）:
#   https://nginx.org/en/docs/beginners_guide.html
#   https://nginx.org/en/docs/http/ngx_http_ssl_module.html
#   https://nginx.org/en/docs/http/ngx_http_fastcgi_module.html
RUN apk add --no-cache \
        nginx \
        openssl


# 2. 証明書・鍵の置き場所を先に用意
RUN mkdir -p ${SSL_DIR} 

# 3. 秘密鍵 (Private Key) の生成
RUN openssl genrsa -out ${SSL_DIR}/torinoue_server.key 2048

# 4. 証明書署名要求 (CSR) の生成
# 秘密鍵を元に、「この内容で証明書を作って」という申請書を作る
RUN openssl req -new \
-key ${SSL_DIR}/torinoue_server.key \
-out ${SSL_DIR}/torinoue_server.csr \
-subj "/C=JP/ST=Tokyo/L=Minatoku/O=42Tokyo/OU=42cursus/CN=torinoue"

# 5. 自己署名証明書の生成
# 自己署名証明書 (CRT) の発行
# 本来は認証局(CA)に送るCSRを、自分の秘密鍵で承認して証明書にする
RUN openssl x509 -req -days 365 \
    -in ${SSL_DIR}/torinoue_server.csr \
    -signkey ${SSL_DIR}/torinoue_server.key \
    -out ${SSL_DIR}/torinoue_server.crt


# CSRを介さず一撃で作成する書き方の例
# RUN openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
#     -keyout ${SSL_DIR}/torinoue_server.key \
#     -out ${SSL_DIR}/torinoue_server.crt \
#     -subj "/C=JP/ST=Tokyo/L=Minatoku/O=42Tokyo/OU=42cursus/CN=torinoue"

# 6. 設定ファイルの配置
# Alpine の !includedir 構造を利用
# コピー元を確認したい場合は、cat /vagrant/srcs/requirements/mariadb/conf/zaphod-mariadb.cnf
COPY conf/torinoue_nginx.conf /etc/nginx/nginx.conf
# docker run --rm --entrypoint sh mariadb-test:task14 -c "cat /etc/my.cnf"

# 7. ポートの公開　
# ドキュメント用。実際の公開は compose の ports 側
EXPOSE 443


# 8. コンテナ起動時の実行コマンド
ENTRYPOINT [ "nginx", "-g", "daemon off;" ]
# デバッグ時にdocker run myimage hoge.shなどで上書してテストすることができる
# CMD ["nginx", "-g", "daemon off;"]

# 自分の課題との差（phase_plan より）: あなたは Docker secrets や healthcheck などを足す想定。参考実装は「証明書を Dockerfile 内で生成」なので、秘密情報の扱い方だけは設計が異なる、とメモしておくとよいです。