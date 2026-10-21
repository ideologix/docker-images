# syntax=docker/dockerfile:1
#
# PHP 8.5 base images built on serversideup/php v5.
# Targets (one tag each, see README.md):
#   laravel      -> ghcr.io/ideologix/php:8.5-laravel
#   laravel-ssr  -> ghcr.io/ideologix/php:8.5-laravel-ssr
#   wordpress    -> ghcr.io/ideologix/php:8.5-wordpress
#
# serversideup is pinned by digest so a new major can never land unannounced
# (v5.0.0 broke s6 user bundles on 2026-10-08). Dependabot opens a PR when it moves.
# Already in the base: pcntl pdo_mysql pdo_pgsql pdo_sqlite redis zip curl mbstring xml opcache.

FROM ghcr.io/serversideup/php:8.5-fpm-nginx-v5.0.2@sha256:0b3d79815a1c8f06bb923a4cfdaf515ff9b466271c41428d61f08b29e6c4ac5a AS base
USER root
RUN install-php-extensions exif gd imagick intl
USER www-data

# Laravel APIs, portals and backends.
FROM base AS laravel
USER root
RUN install-php-extensions bcmath gmp
USER www-data

# Laravel + Inertia SSR: Node 24 and an s6 longrun that serves the SSR bundle on
# 127.0.0.1:13714 next to nginx and php-fpm. Registered the v5 way, through
# user-bundles.d (the old s6-rc.d/user location makes v5 crash at init).
FROM node:24-trixie-slim@sha256:173f125896c3b47ddf056734c7ea789d04595a6a08769a8f78e0df642781fb66 AS node

FROM laravel AS laravel-ssr
USER root
COPY --from=node /usr/local/bin/node /usr/local/bin/node
COPY s6/inertia-ssr/ /etc/s6-overlay/s6-rc.d/inertia-ssr/
RUN chmod +x /etc/s6-overlay/s6-rc.d/inertia-ssr/run \
    && touch /etc/s6-overlay/user-bundles.d/user/contents.d/inertia-ssr \
    && node --version
USER www-data

# WordPress / Bedrock sites: mysqli, WP-CLI and the MariaDB client for wp db commands.
FROM base AS wordpress
ARG WP_CLI_VERSION=2.12.0
USER root
RUN install-php-extensions mysqli \
    && apt-get update \
    && apt-get install -y --no-install-recommends mariadb-client \
    && rm -rf /var/lib/apt/lists/* \
    && curl -fsSL -o /usr/local/bin/wp \
       "https://github.com/wp-cli/wp-cli/releases/download/v${WP_CLI_VERSION}/wp-cli-${WP_CLI_VERSION}.phar" \
    && chmod +x /usr/local/bin/wp \
    && wp --info --allow-root >/dev/null
USER www-data
