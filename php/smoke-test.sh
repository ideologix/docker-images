#!/usr/bin/env bash
# Smoke test one built target: ./php/smoke-test.sh <image> <target>
# Fails if extensions are missing, if s6 cannot start nginx (the v5 user-bundle
# breakage), if the SSR service does not serve a bundle, or if WP-CLI is broken.
set -euo pipefail
IMAGE="$1" TARGET="$2"
fail() { echo "FAIL: $*" >&2; exit 1; }

case "$TARGET" in
  laravel|laravel-ssr) EXT="bcmath exif gd gmp imagick intl pcntl pdo_mysql pdo_pgsql redis zip" ;;
  wordpress)           EXT="exif gd imagick intl mysqli pdo_mysql redis zip" ;;
  *) fail "unknown target $TARGET" ;;
esac

mods=$(docker run --rm --entrypoint php "$IMAGE" -m)
for e in $EXT; do grep -qix "$e" <<<"$mods" || fail "extension $e missing"; done
echo "ok: extensions ($EXT)"

cid=$(docker run -d "$IMAGE"); trap 'docker rm -f "$cid" >/dev/null 2>&1 || true' EXIT
for i in $(seq 1 20); do
  code=$(docker exec "$cid" curl -s -o /dev/null -w '%{http_code}' http://localhost:8080/ 2>/dev/null || true)
  [ "$code" != "000" ] && [ -n "$code" ] && break; sleep 1
done
docker logs "$cid" 2>&1 | grep -q 'Permission denied' && fail "s6 init: Permission denied"
[ "$code" != "000" ] && [ -n "$code" ] || fail "nginx not answering on :8080"
echo "ok: s6 started nginx + php-fpm (:8080 -> $code)"
docker rm -f "$cid" >/dev/null

if [ "$TARGET" = laravel-ssr ]; then
  tmp=$(mktemp -d); mkdir -p "$tmp/ssr"; chmod -R a+rX "$tmp"
  echo 'require("http").createServer((q,r)=>r.end("ssr-ok")).listen(13714,"127.0.0.1")' > "$tmp/ssr/app.js"
  chmod a+r "$tmp/ssr/app.js"
  cid=$(docker run -d -v "$tmp/ssr:/var/www/html/bootstrap/ssr:ro" "$IMAGE")
  for i in $(seq 1 20); do
    out=$(docker exec "$cid" curl -s http://127.0.0.1:13714/ 2>/dev/null || true)
    [ "$out" = ssr-ok ] && break; sleep 1
  done
  [ "$out" = ssr-ok ] || fail "inertia-ssr did not serve the bundle"
  echo "ok: inertia-ssr serves bootstrap/ssr/app.js on 127.0.0.1:13714"
fi

if [ "$TARGET" = wordpress ]; then
  docker run --rm --entrypoint wp "$IMAGE" --version --allow-root | grep -q 'WP-CLI' || fail "wp-cli"
  docker run --rm --entrypoint mariadb "$IMAGE" --version >/dev/null || fail "mariadb client"
  echo "ok: wp-cli + mariadb client"
fi
echo "PASS: $TARGET"
