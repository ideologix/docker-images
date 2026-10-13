# docker-images

Our PHP base images, so we don't have to repeat the same Dockerfile boilerplate in every
project. They're built on top of the excellent
[serversideup/php](https://serversideup.net/open-source/docker-php/) images, with a few
extensions and tools added that most of our apps need anyway.

> **Free to use, no guarantees.** We don't provide public support for these images.
> They're used by various apps in our organization and will change as we shape our
> software. If you use them, pin a dated tag so changes don't surprise you.

## What's in the box

All images are **PHP 8.5** on serversideup v5 (`fpm-nginx`, Debian trixie): nginx and
php-fpm supervised by s6, listening on port **8080**.

| Image | Good for | Extras on top of serversideup |
|---|---|---|
| `ghcr.io/ideologix/php:8.5-laravel` | Laravel apps and APIs | exif, gd, imagick, intl, bcmath, gmp |
| `ghcr.io/ideologix/php:8.5-laravel-ssr` | Laravel + Inertia with server-side rendering | everything above, plus Node 24 and a ready-made SSR service |
| `ghcr.io/ideologix/php:8.5-wordpress` | WordPress and Bedrock sites | exif, gd, imagick, intl, mysqli, WP-CLI, MariaDB client |

serversideup already ships pcntl, pdo_mysql, pdo_pgsql, pdo_sqlite, redis, zip, curl,
mbstring, xml and OPcache, so those are covered too.

## Using them

Each build publishes a moving tag (`8.5-laravel`) and a dated one (`8.5-laravel-20261013`).
We recommend pinning the dated tag, so a base update only reaches your app when you bump
it on purpose:

```dockerfile
FROM ghcr.io/ideologix/php:8.5-laravel-20261013
COPY --chown=www-data:www-data . /var/www/html
```

Need something extra? Just add it in your own Dockerfile:

```dockerfile
USER root
RUN install-php-extensions soap
USER www-data
```

## Server-side rendering (`8.5-laravel-ssr`)

This one runs an `inertia-ssr` service next to nginx and php-fpm, serving your SSR bundle
on `127.0.0.1:13714` (the Inertia default). It picks up the first bundle it finds in
`bootstrap/ssr/` (`ssr.mjs`, `ssr.js`, `app.mjs` or `app.js`).

- Bundle somewhere else? Set `INERTIA_SSR_ENTRY=path/to/bundle.js`.
- Don't want it? Set `INERTIA_SSR_ENABLED=false`.
- No bundle at all? It logs a message and idles, and Inertia falls back to client-side
  rendering. No crash loops.

Don't register your own service under `/etc/s6-overlay/s6-rc.d/user/contents.d`. That's
the old v4 location, and on v5 the container won't start
(`cannot create /etc/s6-overlay/s6-rc.d/user/type: Permission denied`). The service here
is registered through `/etc/s6-overlay/user-bundles.d`, which is how v5 wants it.

## Things serversideup v5 does differently

- **OPcache doesn't recheck files** (`PHP_OPCACHE_VALIDATE_TIMESTAMPS=0`). Great for
  immutable images, but if something changes PHP files at runtime (a plugin update from
  wp-admin, say), restart the container to pick it up.
- **Trusted proxies** default to `cloudflare`, which also covers the private ranges
  (10/8, 172.16/12, 192.168/16). Real client IPs survive a reverse proxy on a private
  network.
- **PHP-FPM can fork up to 20 workers** (`PHP_FPM_PM_MAX_CHILDREN`). If traffic bursts make
  memory spike, lower it.

## How updates work

- serversideup and Node are pinned by digest, so nothing changes under us unannounced.
  Dependabot opens a PR when a new version lands.
- Every PR is built and smoke-tested (`php/smoke-test.sh`): extensions are present, nginx
  actually starts, the SSR service serves a bundle, and WP-CLI works.
- A weekly rebuild picks up PHP and OS security patches and publishes a fresh dated tag.

Want to try a change locally?

```sh
docker build --target laravel -t php-test php
bash php/smoke-test.sh php-test laravel
```
