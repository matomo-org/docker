# Matomo (formerly Piwik)

[![GitHub CI build status badge](https://github.com/matomo-org/docker/workflows/GitHub%20CI/badge.svg)](https://github.com/matomo-org/docker/actions?query=workflow%3A%22GitHub+CI%22)
[![update.sh build status badge](https://img.shields.io/jenkins/s/https/doi-janky.infosiftr.net/job/update.sh/job/matomo.svg?label=Automated%20update.sh)](https://doi-janky.infosiftr.net/job/update.sh/job/matomo/)
[![amd64 build status badge](https://img.shields.io/jenkins/s/https/doi-janky.infosiftr.net/job/multiarch/job/amd64/job/matomo.svg?label=amd64)](https://doi-janky.infosiftr.net/job/multiarch/job/amd64/job/matomo)
[![arm32v5 build status badge](https://img.shields.io/jenkins/s/https/doi-janky.infosiftr.net/job/multiarch/job/arm32v5/job/matomo.svg?label=arm32v5)](https://doi-janky.infosiftr.net/job/multiarch/job/arm32v5/job/matomo)
[![arm32v6 build status badge](https://img.shields.io/jenkins/s/https/doi-janky.infosiftr.net/job/multiarch/job/arm32v6/job/matomo.svg?label=arm32v6)](https://doi-janky.infosiftr.net/job/multiarch/job/arm32v6/job/matomo)
[![arm32v7 build status badge](https://img.shields.io/jenkins/s/https/doi-janky.infosiftr.net/job/multiarch/job/arm32v7/job/matomo.svg?label=arm32v7)](https://doi-janky.infosiftr.net/job/multiarch/job/arm32v7/job/matomo)
[![arm64v8 build status badge](https://img.shields.io/jenkins/s/https/doi-janky.infosiftr.net/job/multiarch/job/arm64v8/job/matomo.svg?label=arm64v8)](https://doi-janky.infosiftr.net/job/multiarch/job/arm64v8/job/matomo)
[![i386 build status badge](https://img.shields.io/jenkins/s/https/doi-janky.infosiftr.net/job/multiarch/job/i386/job/matomo.svg?label=i386)](https://doi-janky.infosiftr.net/job/multiarch/job/i386/job/matomo)
[![mips64le build status badge](https://img.shields.io/jenkins/s/https/doi-janky.infosiftr.net/job/multiarch/job/mips64le/job/matomo.svg?label=mips64le)](https://doi-janky.infosiftr.net/job/multiarch/job/mips64le/job/matomo)
[![ppc64le build status badge](https://img.shields.io/jenkins/s/https/doi-janky.infosiftr.net/job/multiarch/job/ppc64le/job/matomo.svg?label=ppc64le)](https://doi-janky.infosiftr.net/job/multiarch/job/ppc64le/job/matomo)
[![s390x build status badge](https://img.shields.io/jenkins/s/https/doi-janky.infosiftr.net/job/multiarch/job/s390x/job/matomo.svg?label=s390x)](https://doi-janky.infosiftr.net/job/multiarch/job/s390x/job/matomo)

<img align="right" width="300px" src="https://matomo.org/wp-content/themes/website-child/assets/img/media/matomo.png" alt="Matomo logo"></img>
[Matomo](https://matomo.org/) (formerly Piwik) is the leading open-source analytics platform that gives you more than just powerful analytics:

- Free open-source software
- 100% data ownership
- User privacy protection
- User-centric insights
- Customisable and extensible

## How to use this image

You can run the Matomo container and service like so:

```bash
docker run -d --link some-mysql:db matomo
```

This assumes you've already launched a suitable MySQL or MariaDB database container.

## Persistent data

Use a Docker volume to keep persistent data:

```console
docker run -d -p 8080:80 --link some-mysql:db -v matomo:/var/www/html matomo
```

## Matomo Installation

Once you're up and running, you'll arrive at the configuration wizard page. If you're using the compose file, at the `Database Setup` step, please enter the following:

- Database Server: `db`
-	Login: MYSQL_USER
-	Password: MYSQL_PASSWORD
-	Database Name: MYSQL_DATABASE

And leave the rest as default.

Then you can continue the installation with the super user.

The following environment variables are also honored for configuring your Matomo instance:

- `MATOMO_DATABASE_HOST`
- `MATOMO_DATABASE_ADAPTER`
- `MATOMO_DATABASE_TABLES_PREFIX`
- `MATOMO_DATABASE_USERNAME`
- `MATOMO_DATABASE_PASSWORD`
- `MATOMO_DATABASE_DBNAME`

## Docker-composer examples and log import instructions

A minimal set-up using docker-compose is available in the [.examples folder](.examples/nginx/docker-compose.yml), a more complete [example can be found at IndieHosters/piwik](https://github.com/libresh/compose-matomo/blob/master/docker-compose.yml).

If you want to use the import logs script, you can then run the following container as needed, in order to execute the python import logs script:
```
docker run --rm --volumes-from="matomo_app_1" --link matomo_app_1 python:2-alpine python /var/www/html/misc/log-analytics/import_logs.py --url=http://ip.of.your.matomo --login=yourlogin --password=yourpassword --idsite=1 --recorders=4 /var/www/html/logs/access.log
```

## Contribute

Pull requests are very welcome!

We'd love to hear your feedback and suggestions in the issue tracker: [github.com/matomo-org/docker/issues](https://github.com/matomo-org/docker/issues).

## GeoIP

~~This product includes GeoLite data created by MaxMind, available from [https://www.maxmind.com](https://www.maxmind.com).~~
https://blog.maxmind.com/2019/12/18/significant-changes-to-accessing-and-using-geolite2-databases/
