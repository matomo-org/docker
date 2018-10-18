FROM php:7.1-fpm-alpine

LABEL maintainer="pierre@piwik.org"

RUN set -ex; \
	\
	apk add --no-cache --virtual .build-deps \
		$PHPIZE_DEPS \
		autoconf \
		freetype-dev \
		geoip-dev \
		icu-dev \
		libjpeg-turbo-dev \
		libpng-dev \
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
	pecl install APCu-5.1.12; \
	pecl install geoip-1.1.1; \
	pecl install redis-3.1.6; \
	\
	docker-php-ext-enable \
		apcu \
		geoip \
		redis \
	; \
	\
	runDeps="$( \
		scanelf --needed --nobanner --format '%n#p' --recursive /usr/local/lib/php/extensions \
		| tr ',' '\n' \
		| sort -u \
		| awk 'system("[ -e /usr/local/lib/" $1 " ]") == 0 { next } { print "so:" $1 }' \
	)"; \
	apk add --virtual .piwik-phpext-rundeps $runDeps; \
	apk del .build-deps

ENV MATOMO_VERSION 3.6.1

RUN set -ex; \
	apk add --no-cache --virtual .fetch-deps \
		gnupg \
	; \
	\
	curl -fsSL -o piwik.tar.gz \
		"https://builds.matomo.org/piwik-${MATOMO_VERSION}.tar.gz"; \
	curl -fsSL -o piwik.tar.gz.asc \
		"https://builds.matomo.org/piwik-${MATOMO_VERSION}.tar.gz.asc"; \
	export GNUPGHOME="$(mktemp -d)"; \
	gpg --keyserver ha.pool.sks-keyservers.net --recv-keys 814E346FA01A20DBB04B6807B5DBD5925590A237; \
	gpg --batch --verify piwik.tar.gz.asc piwik.tar.gz; \
	gpgconf --kill all; \
	rm -rf "$GNUPGHOME" piwik.tar.gz.asc; \
	tar -xzf piwik.tar.gz -C /usr/src/; \
	rm piwik.tar.gz; \
	apk del .fetch-deps

COPY php.ini /usr/local/etc/php/conf.d/php-piwik.ini

RUN set -ex; \
	curl -fsSL -o /usr/src/piwik/misc/GeoIPCity.dat.gz https://geolite.maxmind.com/download/geoip/database/GeoLiteCity.dat.gz; \
	gunzip /usr/src/piwik/misc/GeoIPCity.dat.gz

COPY docker-entrypoint.sh /entrypoint.sh

# WORKDIR is /var/www/html (inherited via "FROM php")
# "/entrypoint.sh" will populate it at container startup from /usr/src/piwik
VOLUME /var/www/html

ENTRYPOINT ["/entrypoint.sh"]
CMD ["php-fpm"]
