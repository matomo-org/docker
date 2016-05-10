FROM php:5.6-fpm

MAINTAINER pierre@piwik.org

RUN apt-get update && apt-get install -y \
      libjpeg-dev \
      libfreetype6-dev \
      libgeoip-dev \
      libpng12-dev \
      ssmtp \
      zip \
 && rm -rf /var/lib/apt/lists/*

RUN docker-php-ext-configure gd --with-freetype-dir=/usr --with-png-dir=/usr --with-jpeg-dir=/usr \
 && docker-php-ext-install gd mbstring mysql pdo_mysql zip

RUN pecl install APCu geoip

ENV PIWIK_VERSION 2.16.1

RUN curl -fsSL -o piwik.tar.gz \
      "https://builds.piwik.org/piwik-${PIWIK_VERSION}.tar.gz" \
 && curl -fsSL -o piwik.tar.gz.asc \
      "https://builds.piwik.org/piwik-${PIWIK_VERSION}.tar.gz.asc" \
 && export GNUPGHOME="$(mktemp -d)" \
 && gpg --keyserver ha.pool.sks-keyservers.net --recv-keys 814E346FA01A20DBB04B6807B5DBD5925590A237 \
 && gpg --batch --verify piwik.tar.gz.asc piwik.tar.gz \
 && rm -r "$GNUPGHOME" piwik.tar.gz.asc \
 && tar -xzf piwik.tar.gz -C /usr/src/ \
 && rm piwik.tar.gz \
 && chfn -f 'Piwik Admin' www-data

COPY php.ini /usr/local/etc/php/php.ini

RUN curl -fsSL -o /usr/src/piwik/misc/GeoIPCity.dat.gz http://geolite.maxmind.com/download/geoip/database/GeoLiteCity.dat.gz \
 && gunzip /usr/src/piwik/misc/GeoIPCity.dat.gz

COPY docker-entrypoint.sh /entrypoint.sh

# WORKDIR is /var/www/html (inherited via "FROM php")
# "/entrypoint.sh" will populate it at container startup from /usr/src/piwik
VOLUME /var/www/html

ENTRYPOINT ["/entrypoint.sh"]
CMD ["php-fpm"]
