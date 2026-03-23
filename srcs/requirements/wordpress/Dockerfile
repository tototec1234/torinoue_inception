FROM debian:bookworm

RUN apt-get update && apt-get install -y \
    php-fpm \
	php-mysql \
	wget \
	&& rm -rf /var/lib/apt/lists/*

# wp-cli をインストール
RUN wget -q https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar \
	-O /usr/local/bin/wp \
	&& chmod +x /usr/local/bin/wp

COPY conf/init.sh /init.sh
RUN chmod +x /init.sh

EXPOSE 9000

CMD ["/init.sh"]
