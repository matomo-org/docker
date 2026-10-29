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

## Upgrading

Matomo lives in the volume on `/var/www/html`, which the container fills from the image only if it doesn't contain Matomo yet. A newer image alone therefore doesn't upgrade an installed Matomo. There are two ways to do it:

- **In Matomo**, as before: the one-click update in the web interface (or `php console core:update` after replacing the files yourself). The version of the image doesn't matter then.
- **With the image**: set `MATOMO_AUTO_UPGRADE=1` and start a newer image on the same volume, e.g. `docker run -d -e MATOMO_AUTO_UPGRADE=1 -v matomo:/var/www/html --link some-mysql:db matomo`.

With `MATOMO_AUTO_UPGRADE=1`, every start of the container does this for an installed Matomo (one with `config/config.ini.php`):

1. If the image has a newer version of Matomo than the volume, it copies the files of the new release over those in the volume, and deletes the files that the new release no longer has: exactly those that the manifest of the installed release (`config/manifest.inc.php`) lists and the new one doesn't, unless they were modified. Everything else stays, like `config/config.ini.php`, plugins from the Marketplace, `misc/user/`, GeoIP databases, the containers of the Tag Manager in `js/`, `tmp/` and files of your own. Changes to files of the release are lost, as with the one-click update.
2. It runs `php console core:update --yes` and `php console custom-matomo-js:update`.

Both steps run as the user of Apache or PHP-FPM (`www-data`, or `APACHE_RUN_USER`), or as the user of the container if it doesn't run as root. It never downgrades: if the volume has a newer Matomo than the image (e.g. after a one-click update), it leaves it alone with a warning. When several containers share the volume, one upgrades it and the others wait for it (with a lock on `tmp/matomo-upgrade.lock`, so `tmp/` must be on the shared volume). If a step fails, the container logs the error and starts anyway; Matomo then asks for the database upgrade in the browser, as after a manual upgrade, and the next start tries again. A container that doesn't run as root upgrades the volume only if it can write to it.

Back up the database and the volume before upgrading. The web server starts only after the database upgrade, which takes a while for big databases, especially with a new major version of Matomo (use a tag like `matomo:5` to stay on one). For a large instance, better upgrade it manually with Matomo's [tips for high traffic servers](https://matomo.org/faq/on-premise/how-to-upgrade-matomo-to-the-latest-release/), e.g. in [maintenance mode](https://matomo.org/faq/how-to/faq_111/) and with a single container.

## Docker Compose examples and log import instructions

A minimal set-up using docker-compose is available in the [.examples folder](.examples/nginx/compose.yml).

If you want to use the import logs script, you can then run the following container as needed, in order to execute the python import logs script:

```bash
docker run --rm --volumes-from="matomo-app-1" --link matomo-app-1 python:3-alpine python /var/www/html/misc/log-analytics/import_logs.py --url=http://ip.of.your.matomo.example --login=yourlogin --password=yourpassword --idsite=1 --recorders=4 /var/www/html/logs/access.log
```

## Contribute

Pull requests are very welcome!

We'd love to hear your feedback and suggestions in the issue tracker: [github.com/matomo-org/docker/issues](https://github.com/matomo-org/docker/issues).

## GeoIP

~~This product includes GeoLite data created by MaxMind, available from [https://www.maxmind.com](https://www.maxmind.com).~~ https://blog.maxmind.com/2019/12/18/significant-changes-to-accessing-and-using-geolite2-databases/
