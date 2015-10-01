# Piwik

Piwik is the leading open-source analytics platform that gives you more than just powerful analytics:
 - Free open-source software
 - 100% data ownership
 - User privacy protection
 - User-centric insights
 - Customisable and extensible

![logo](https://rawgit.com/piwik/docker-piwik/master/logo.svg)

# How to use this image

The easiest is to use our `docker-compose.yml`.

Make sure you have [docker-compose](http://docs.docker.com/compose/install/) installed. And then:

```
git clone https://github.com/piwik/docker-piwik.git
cd docker-piwik
# edit variables:
vi .env
docker-compose up
```

You can now access your instance on the port 80 of the IP of your machine.

## Access it from Internet

We recommend the usage of SSL, so the easiest is to modify the `nginx.conf` file.

Once it is done, you can connect to the port of the host by adding this line to `docker-compose.yml`:
```
web:
...
  - ports:
    - "443:443"
    - "80:80"
...
```

## Installation

Once started, you'll arrive at the configuration wizard.
At the `Database Setup` step, please enter the following:
  -  Database Server: `db`
  -  Login: `root`
  -  Password: MYSQL_ROOT_PASSWORD (from your `.env` file)
  -  Database Name: piwik (or you can choose)
 
And leave the rest as default.

Then you can continue the installation with the super user.

## Backup

In order to backup, just run the `./BACKUP` script. And copy all the data to a safe place.
