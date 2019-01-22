FROM php:7.2-fpm

LABEL maintainer="pierre@piwik.org"

RUN set -ex; \
	\
	savedAptMark="$(apt-mark showmanual)"; \
	\
	apt-get update; \
	apt-get install -y --no-install-recommends \
		libfreetype6-dev \
		libjpeg-dev \
		libldap2-dev \
		libpng-dev \
	; \
	\
	debMultiarch="$(dpkg-architecture --query DEB_BUILD_MULTIARCH)"; \
	docker-php-ext-configure gd --with-freetype-dir=/usr --with-png-dir=/usr --with-jpeg-dir=/usr; \
	docker-php-ext-configure ldap --with-libdir="lib/$debMultiarch"; \
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
	pecl install APCu-5.1.16; \
	pecl install redis-3.1.6; \
	\
	docker-php-ext-enable \
		apcu \
		redis \
	; \
	\
# reset apt-mark's "manual" list so that "purge --auto-remove" will remove all build dependencies
	apt-mark auto '.*' > /dev/null; \
	apt-mark manual $savedAptMark; \
	ldd "$(php -r 'echo ini_get("extension_dir");')"/*.so \
		| awk '/=>/ { print $3 }' \
		| sort -u \
		| xargs -r dpkg-query -S \
		| cut -d: -f1 \
		| sort -u \
		| xargs -rt apt-mark manual; \
	\
	apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false; \
	rm -rf /var/lib/apt/lists/*

ENV MATOMO_VERSION 3.8.0

RUN set -ex; \
	fetchDeps=" \
		dirmngr \
		gnupg \
	"; \
	apt-get update; \
	apt-get install -y --no-install-recommends \
		$fetchDeps \
	; \
	\
	curl -fsSL -o piwik.tar.gz \
		"https://builds.matomo.org/piwik-${MATOMO_VERSION}.tar.gz"; \
	curl -fsSL -o piwik.tar.gz.asc \
		"https://builds.matomo.org/piwik-${MATOMO_VERSION}.tar.gz.asc"; \
	export GNUPGHOME="$(mktemp -d)"; \
	gpg --batch --keyserver ha.pool.sks-keyservers.net --recv-keys 814E346FA01A20DBB04B6807B5DBD5925590A237; \
	gpg --batch --verify piwik.tar.gz.asc piwik.tar.gz; \
	gpgconf --kill all; \
	rm -rf "$GNUPGHOME" piwik.tar.gz.asc; \
	tar -xzf piwik.tar.gz -C /usr/src/; \
	rm piwik.tar.gz; \
	apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false $fetchDeps; \
	rm -rf /var/lib/apt/lists/*

COPY php.ini /usr/local/etc/php/conf.d/php-piwik.ini

RUN set -ex; \
	curl -fsSL -o GeoIPCity.tar.gz \
		"https://geolite.maxmind.com/download/geoip/database/GeoLite2-City.tar.gz"; \
	curl -fsSL -o GeoIPCity.tar.gz.md5 \
		"https://geolite.maxmind.com/download/geoip/database/GeoLite2-City.tar.gz.md5"; \
	echo "$(cat GeoIPCity.tar.gz.md5)  GeoIPCity.tar.gz" | md5sum -c -; \
	mkdir /usr/src/GeoIPCity; \
	tar -xf GeoIPCity.tar.gz -C /usr/src/GeoIPCity --strip-components=1; \
	mv /usr/src/GeoIPCity/GeoLite2-City.mmdb /usr/src/piwik/misc/GeoLite2-City.mmdb; \
	rm -rf GeoIPCity*

COPY docker-entrypoint.sh /entrypoint.sh

# WORKDIR is /var/www/html (inherited via "FROM php")
# "/entrypoint.sh" will populate it at container startup from /usr/src/piwik
VOLUME /var/www/html

ENTRYPOINT ["/entrypoint.sh"]
CMD ["php-fpm"]
