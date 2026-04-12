docker network create test-net

docker run -d \
  --name mariadb \
  --network test-net \
  -e MARIADB_DATABASE=wordpress \
  -e MARIADB_USER=wpuser \
  -e MARIADB_PASSWORD=wppassword \
  mariadb-test:task36

  docker run -d \
  --name wordpress \
  --network test-net \
  --dns 8.8.8.8 \
  -e DOMAIN_NAME=torinoue.42.fr \
  -e WP_ADMIN_USER=boss42 \
  -e WP_ADMIN_PASSWORD=wpadminpass \
  -e WP_ADMIN_EMAIL=admin@example.com \
  -e WP_USER=wpeditor \
  -e WP_USER_EMAIL=editor@example.com \
  -e WP_USER_PASSWORD=wpeditorpass \
  -e MARIADB_ROOT_PASSWORD=rootpassword \
  -e MARIADB_DATABASE=wordpress \
  -e MARIADB_USER=wpuser \
  -e MARIADB_PASSWORD=wppassword \
  wordpress-test:task36

docker exec wordpress wp --allow-root --path=/var/www/html db check

  docker run -d \
  --name nginx \
  --network test-net \
  -p 443:443 \
  nginx-test:task36

# fastcgi_pass wordpress:9000 なので WP コンテナ名は wordpress にしてください。


docker ps
docker logs wordpress   # mariaDB is ready / php-fpm まで進むか
docker logs nginx         # emerg が出ないか
