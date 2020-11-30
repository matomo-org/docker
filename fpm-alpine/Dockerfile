FROM php:7.4-fpm-alpine

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
	docker-php-ext-configure gd --with-freetype --with-jpeg; \
	docker-php-ext-configure ldap; \
	docker-php-ext-install -j "$(nproc)" \
		gd \
		ldap \
		mysqli \
		opcache \
		pdo_mysql \
		zip \
	; \
	\
# pecl will claim success even if one install fails, so we need to perform each install separately
	pecl install APCu-5.1.18; \
	pecl install redis-5.3.1; \
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
	apk add --no-cache --virtual .matomo-phpext-rundeps $runDeps mariadb-client; \
	apk del .build-deps

# set recommended PHP.ini settings
# see https://secure.php.net/manual/en/opcache.installation.php
RUN { \
		echo 'opcache.memory_consumption=128'; \
		echo 'opcache.interned_strings_buffer=8'; \
		echo 'opcache.max_accelerated_files=4000'; \
		echo 'opcache.revalidate_freq=2'; \
		echo 'opcache.fast_shutdown=1'; \
	} > /usr/local/etc/php/conf.d/opcache-recommended.ini

ENV MATOMO_VERSION 4.0.3

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

RUN curl -fsSL -o geoip.gz \
        "https://download.db-ip.com/free/dbip-city-lite-$(date +%Y-%m).mmdb.gz" && \
    mkdir -p /var/geoip/ && \
    gunzip -c geoip.gz > /var/geoip/DBIP-City.mmdb && \
	rm geoip.gz

COPY php.ini /usr/local/etc/php/conf.d/php-matomo.ini

# https://blog.maxmind.com/2019/12/18/significant-changes-to-accessing-and-using-geolite2-databases/
#RUN set -ex; \
#	curl -fsSL -o GeoIPCity.tar.gz \
#		"https://geolite.maxmind.com/download/geoip/database/GeoLite2-City.tar.gz"; \
#	curl -fsSL -o GeoIPCity.tar.gz.md5 \
#		"https://geolite.maxmind.com/download/geoip/database/GeoLite2-City.tar.gz.md5"; \
#	echo "$(cat GeoIPCity.tar.gz.md5)  GeoIPCity.tar.gz" | md5sum -c -; \
#	mkdir /usr/src/GeoIPCity; \
#	tar -xf GeoIPCity.tar.gz -C /usr/src/GeoIPCity --strip-components=1; \
#	mv /usr/src/GeoIPCity/GeoLite2-City.mmdb /usr/src/matomo/misc/GeoLite2-City.mmdb; \
#	rm -rf GeoIPCity*
RUN set -ex; \
    apk add --no-cache --virtual .fetch-deps unzip; \
    curl -fsSL -o EnvironmentVariables.zip \
        "https://plugins.matomo.org/api/2.0/plugins/EnvironmentVariables/download/4.0.1"; \
    unzip '*.zip' -d /usr/src/matomo/plugins; \
	apk del .fetch-deps; \
    rm *.zip;

COPY --chown=1000:1000 common.config.ini.php /usr/src/matomo/config/common.config.ini.php

COPY --chown=1000:1000 bootstrap.php /usr/src/matomo/bootstrap.php

COPY docker-entrypoint.sh /entrypoint.sh

# WORKDIR is /var/www/html (inherited via "FROM php")
# "/entrypoint.sh" will populate it at container startup from /usr/src/matomo
VOLUME /data

ENTRYPOINT ["/entrypoint.sh"]
CMD ["php-fpm"]
