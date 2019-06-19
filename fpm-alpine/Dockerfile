FROM php:7.3-fpm-alpine

LABEL maintainer="pierre@piwik.org"

RUN set -ex; \
	\
	apk add --no-cache --virtual .build-deps \
		$PHPIZE_DEPS \
		autoconf \
		freetype-dev \
		icu-dev \
		libjpeg-turbo-dev \
		libpng-dev \
		libzip-dev \
		openldap-dev \
		pcre-dev \
	; \
	\
	docker-php-ext-configure gd --with-freetype-dir=/usr --with-png-dir=/usr --with-jpeg-dir=/usr; \
	docker-php-ext-configure ldap; \
	docker-php-ext-install \
		gd \
		ldap \
		mysqli \
		opcache \
		pdo_mysql \
		zip \
	; \
	\
# pecl will claim success even if one install fails, so we need to perform each install separately
	pecl install APCu-5.1.17; \
	pecl install redis-4.3.0; \
	\
	docker-php-ext-enable \
		apcu \
		redis \
	; \
	\
	runDeps="$( \
		scanelf --needed --nobanner --format '%n#p' --recursive /usr/local/lib/php/extensions \
		| tr ',' '\n' \
		| sort -u \
		| awk 'system("[ -e /usr/local/lib/" $1 " ]") == 0 { next } { print "so:" $1 }' \
	)"; \
	apk add --virtual .matomo-phpext-rundeps $runDeps; \
	apk del .build-deps

ENV MATOMO_VERSION 3.9.1

RUN set -ex; \
	apk add --no-cache --virtual .fetch-deps \
		gnupg \
	; \
	\
	curl -fsSL -o matomo.tar.gz \
		"https://builds.matomo.org/matomo-${MATOMO_VERSION}.tar.gz"; \
	curl -fsSL -o matomo.tar.gz.asc \
		"https://builds.matomo.org/matomo-${MATOMO_VERSION}.tar.gz.asc"; \
	export GNUPGHOME="$(mktemp -d)"; \
	gpg --batch --keyserver ha.pool.sks-keyservers.net --recv-keys 814E346FA01A20DBB04B6807B5DBD5925590A237; \
	gpg --batch --verify matomo.tar.gz.asc matomo.tar.gz; \
	gpgconf --kill all; \
	rm -rf "$GNUPGHOME" matomo.tar.gz.asc; \
	tar -xzf matomo.tar.gz -C /usr/src/; \
	rm matomo.tar.gz; \
	apk del .fetch-deps

COPY php.ini /usr/local/etc/php/conf.d/php-matomo.ini

RUN set -ex; \
	curl -fsSL -o GeoIPCity.tar.gz \
		"https://geolite.maxmind.com/download/geoip/database/GeoLite2-City.tar.gz"; \
	curl -fsSL -o GeoIPCity.tar.gz.md5 \
		"https://geolite.maxmind.com/download/geoip/database/GeoLite2-City.tar.gz.md5"; \
	echo "$(cat GeoIPCity.tar.gz.md5)  GeoIPCity.tar.gz" | md5sum -c -; \
	mkdir /usr/src/GeoIPCity; \
	tar -xf GeoIPCity.tar.gz -C /usr/src/GeoIPCity --strip-components=1; \
	mv /usr/src/GeoIPCity/GeoLite2-City.mmdb /usr/src/matomo/misc/GeoLite2-City.mmdb; \
	rm -rf GeoIPCity*

COPY docker-entrypoint.sh /entrypoint.sh

# WORKDIR is /var/www/html (inherited via "FROM php")
# "/entrypoint.sh" will populate it at container startup from /usr/src/matomo
VOLUME /var/www/html

ENTRYPOINT ["/entrypoint.sh"]
CMD ["php-fpm"]
