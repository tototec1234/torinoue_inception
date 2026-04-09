#!/bin/sh

# 初期化ガード: mysql システムテーブルが未作成の場合のみ実行
if [ ! -d "/var/lib/mysql/mysql" ]; then
	mariadb-install-db \
		--user=mysql \
		--datadir=${MYSQL_DATA_DIR} \
		--basedir=/usr


	# 一時起動: ソケット経由のみ受け付け（TCP無効）
	# & をつけてバックグラウンドで起動する
	mariadbd --user=mysql --skip-networking &

	# MariaDB が起動するまで待機
	# mariadb-admin ping が成功するまでループ
	# --silent: エラー出力を抑制
	# タイムアウト対策: ループ回数に上限を設ける
	i=0
	while ! mariadb-admin ping --silent; do
		i=$((i + 1))
		if [ $i -gt 42 ]; then
			echo "MariaDB did not start in time" >&2
			exit 1
		fi
		sleep 1
	done

	# SQL実行（CREATE DATABASE / USER / GRANT / FLUSH）
	# DBのrootユーザーとしてログイン（「d」がない）
	# User Accounts Created by Defaul
	# https://mariadb.com/docs/server/clients-and-utilities/deployment-tools/mariadb-install-db
	# 
	# unix_socket認証: OSのmysqlユーザーとして動作中のプロセスはパスワードなしでroot接続可能
	# 根拠: https://mariadb.com/kb/en/unix_socket-authentication-plugin/
	mariadb --user root <<EOF
	DELETE FROM mysql.user WHERE User='';
	DROP DATABASE IF EXISTS test;
	DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';
	CREATE DATABASE IF NOT EXISTS $MARIADB_DATABASE;
	CREATE USER IF NOT EXISTS '$MARIADB_USER'@'%' IDENTIFIED BY '$MARIADB_PASSWORD';
	GRANT ALL PRIVILEGES ON $MARIADB_DATABASE.* TO '$MARIADB_USER'@'%';
	FLUSH PRIVILEGES;
EOF
	
	# 一時起動をシャットダウン
	mariadb-admin --user=root shutdown
fi

# 本番起動(PID 1 として)
exec mariadbd --user=mysql

