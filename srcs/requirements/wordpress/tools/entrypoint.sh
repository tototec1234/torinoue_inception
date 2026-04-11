#!/bin/sh

# 1. MariaDB が起動するまで待機
# mariadb-admin ping が成功するまでループ
# --silent: エラー出力を抑制
# タイムアウト対策: ループ回数に上限を設ける
# ${MARIADB_PASSWORD} は将来的に secrets から読み取る（タスク 4-5）
i=0
while ! mariadb-admin ping -h mariadb -u ${MARIADB_USER} -p${MARIADB_PASSWORD} --silent; do
	i=$((i + 1))
	if [ $i -gt 42 ]; then
		echo "MariaDB did not start in time" >&2
		exit 1
	fi
	sleep 1
done
echo "mariaDB is ready"


# 3. 初回起動時のみコアファイルダウンロード
# WordPressのコアファイル（PHPソースコード）をダウンロートして展開する。
# Dockerfilen で　WORKDIR /var/www/html　指定なのでフルパスは冗長だが、明示的に記載
if [ ! -f /var/www/html/wp-settings.php ]; then
    wp core download
fi

# 2. WordPressコンテナが、MariaDBコンテナを使うための設定
# ポート番号を明示（レビュー時のライブコーディングで変更しやすくするため）
# ポート番号を省略すると自動的に3306が使われる
if [ ! -f wp-config.php ]; then
	wp config create \
		--dbhost=mariadb:3306 \
		--dbname=${MARIADB_DATABASE} \
		--dbuser=${MARIADB_USER} \
		--dbpass=${MARIADB_PASSWORD}
fi

# 4. コアファイルを元にデータベースにWordPressのテーブルを作成し、サイトの初期設定を登録する
# （URL, タイトル、管理者アカウント、編集者アカウント）
if ! wp core is-installed 2>/dev/null; then
	wp core install \
	--url=$DOMAIN_NAME \
	--title="Inception" \
	--admin_user=$WP_ADMIN_USER \
	--admin_password=$WP_ADMIN_PASSWORD \
	--admin_email=$WP_ADMIN_EMAIL

	wp user create \
		$WP_USER \
		$WP_USER_EMAIL \
		--role=editor \
		--user_pass=$WP_USER_PASSWORD
fi

# 5. PHP-FPMをファオグラウンドで起動
# php-fpmはデフォルトがデーモンなので明示的に-Fが必要。下記で確認。
# docker run  --rm php:8.3-fpm-alpine php-fpm --help
# なお、MariaDBのmariadbd（旧mysqld）はデフォルトでフォアグラウンド動作するため-F指定不要

exec php-fpm83 -F

