# Matomo (formerly Piwik)

[![GitHub CI build status badge](https://github.com/matomo-org/docker/workflows/GitHub%20CI/badge.svg)](https://github.com/matomo-org/docker/actions?query=workflow%3A%22GitHub+CI%22)
[![update.sh build status badge](https://img.shields.io/jenkins/s/https/doi-janky.infosiftr.net/job/update.sh/job/matomo.svg?label=Automated%20update.sh)](https://doi-janky.infosiftr.net/job/update.sh/job/matomo/)
[![Docker Pulls](https://img.shields.io/docker/pulls/library/matomo)](https://hub.docker.com/_/matomo)
[![Docker Image Version](https://img.shields.io/docker/v/library/matomo?sort=semver&logo=matomo&label=Matomo)](https://hub.docker.com/_/matomo/tags)

<img align="right" width="300px" src="https://matomo.org/wp-content/themes/website-child/assets/img/media/matomo.png" alt="Matomo logo"></img>
[Matomo](https://matomo.org/) (formerly Piwik) is the leading open-source analytics platform that gives you more than just powerful analytics:

- Free open-source software
- 100% data ownership
- User privacy protection
- User-centric insights
- Customisable and extensible

# How to use this image

You can run the Matomo container and service like so:

```bash
docker run -d --link some-mysql:db matomo
```

This assumes you've already launched a suitable MySQL or MariaDB database container.

## Persistent data

Use a Docker volume to keep persistent data:

```bash
docker run -d -p 8080:80 --link some-mysql:db -v matomo:/var/www/html matomo
```

## Matomo Installation

Once you're up and running, you'll arrive at the configuration wizard page. If you're using the compose file, at the `Database Setup` step, please enter the following:

- Database Server: `db`
- Login: MYSQL_USER
- Password: MYSQL_PASSWORD
- Database Name: MYSQL_DATABASE

And leave the rest as default.

Then you can continue the installation with the super user.

The following environment variables are also honored for configuring your Matomo instance:

- `MATOMO_DATABASE_HOST`
- `MATOMO_DATABASE_ADAPTER`
- `MATOMO_DATABASE_TABLES_PREFIX`
- `MATOMO_DATABASE_USERNAME`
- `MATOMO_DATABASE_PASSWORD`
- `MATOMO_DATABASE_DBNAME`

The PHP memory limit can be configured with the following environment variable:

- `PHP_MEMORY_LIMIT`

## Docker Compose examples and log import instructions

A minimal set-up using docker-compose is available in the [.examples folder](.examples/nginx/docker-compose.yml).

If you want to use the import logs script, you can then run the following container as needed, in order to execute the python import logs script:

```bash
docker run --rm --volumes-from="matomo-app-1" --link matomo-app-1 python:3-alpine python /var/www/html/misc/log-analytics/import_logs.py --url=http://ip.of.your.matomo.example --login=yourlogin --password=yourpassword --idsite=1 --recorders=4 /var/www/html/logs/access.log
```

## Contribute

Pull requests are very welcome!

We'd love to hear your feedback and suggestions in the issue tracker: [github.com/matomo-org/docker/issues](https://github.com/matomo-org/docker/issues).

## GeoIP

~~This product includes GeoLite data created by MaxMind, available from [https://www.maxmind.com](https://www.maxmind.com).~~ https://blog.maxmind.com/2019/12/18/significant-changes-to-accessing-and-using-geolite2-databases/
