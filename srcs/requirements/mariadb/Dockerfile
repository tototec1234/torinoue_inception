# ベースイメージ: penultimate stable version
# 根拠: https://alpinelinux.org/releases/
FROM alpine:3.21

# データの保存場所を一括管理
ENV MYSQL_DATA_DIR=/var/lib/mysql \
    MYSQL_RUN_DIR=/run/mysqld



# キャッシュを迂回するので、常にリモートからインデックスを取得するため最新版しかインストールされない。したがって下の2行は不要
#RUN apk update && \
#    apk upgrade && \

# 1. パッケージのインストール
# 根拠: https://wiki.alpinelinux.org/wiki/MariaDB
# レイヤーを統合し、キャッシュを残さないことでイメージサイズを最小化します
RUN apk add --no-cache \
        mariadb \
        mariadb-client


# 2. 環境の準備 ランタイムディレクトリの準備
# mariadbd が PID 1 として動作する際に必要
RUN mkdir -p ${MYSQL_RUN_DIR} ${MYSQL_DATA_DIR} && \
    chown -R mysql:mysql ${MYSQL_RUN_DIR} ${MYSQL_DATA_DIR}
# The datadir located at /var/lib/mysql must be owned by the mysql user and group. 

# 3. データベースの初期化 entrypoint.sh で行うためDockerfileには行わなず、起動時に行う設計に変更。理由はbuild時に初期化してしまうとvolumeマウント時に上書きされて意味がなくなるから。
# OSユーザー「mysql」を指定して、システムテーブルを作成します
# RUN mariadb-install-db \
#     --user=mysql \
#     --datadir=${MYSQL_DATA_DIR} \
#     --basedir=/usr

# 4. 設定ファイルの配置
# Alpine の !includedir 構造を利用
# 根拠: /etc/my.cnf の !includedir /etc/my.cnf.d
COPY conf/my.cnf /etc/my.cnf.d/my.cnf

# 5. エントリポイントスクリプトの配置
# ここで指定するスクリプトが、最終的に「exec」魔法を使って PID 1 を MariaDB に譲ります
COPY tools/entrypoint.sh /
RUN chmod +x /entrypoint.sh

# MariaDB のデフォルトポート
EXPOSE 3306

# コンテナ起動時の実行コマンド
ENTRYPOINT ["/entrypoint.sh"]
