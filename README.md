# Piwik

[![Build Status](https://travis-ci.org/piwik/docker-piwik.svg?branch=master)](https://travis-ci.org/piwik/docker-piwik)

Piwik is the leading open-source analytics platform that gives you more than just powerful analytics:

- Free open-source software
- 100% data ownership
- User privacy protection
- User-centric insights
- Customisable and extensible

![logo](https://rawgit.com/piwik/docker-piwik/master/logo.svg)

# How to use this image

```bash
docker run --link some-mysql:mysql -d piwik
```

For testing purpose, you might want to be able to access the instance from the host without the container's IP, standard port mappings can be used:

```bash
docker run --link some-mysql:mysql -p 8080:80 -d piwik
```

Then, access it via `http://localhost:8080` or `http://host-ip:8080` in a browser.

For production, we recommend the use of TLS.

## Via docker-compose

You can use a setup that is used in production at [IndieHosters/piwik](https://github.com/indiehosters/piwik).

## Installation

Once started, you'll arrive at the configuration wizzard. At the `Database Setup` step, please enter the following:

- Database Server: `db`
- Login: `root`
- Password: MYSQL_ROOT_PASSWORD
- Database Name: piwik (or you can choose)

And leave the rest as default.

Then you can continue the installation with the super user.

## Contribute

Pull requests are very welcome!

We'd love to hear your feedback and suggestions in the issue tracker: [github.com/piwik/docker-piwik/issues](https://github.com/piwik/docker-piwik/issues).

## GeoIP

This product includes GeoLite data created by MaxMind, available from [http://www.maxmind.com](http://www.maxmind.com).
