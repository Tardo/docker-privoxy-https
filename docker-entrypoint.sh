#!/bin/sh
set -e
privman --init

if [ -n "$ADBLOCK_URLS" ]; then
  nginx
fi

if [ ! -e /usr/local/etc/privoxy/config ] || [ -z "$(ls -A /usr/local/etc/privoxy)" ]; then
  echo "[entrypoint] void config, populating defaults..."
  cp -a /opt/privoxy-default/* /usr/local/etc/privoxy/
fi

echo "[entrypoint] starting..."
exec "$@"
