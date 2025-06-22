#!/bin/sh
set -e
privman --init


if [ ! -e /usr/local/etc/privoxy/config ] || [ -z "$(ls -A /usr/local/etc/privoxy)" ]; then
  echo "[entrypoint] void config, populating defaults..."
  cp -a /opt/privoxy-default/* /usr/local/etc/privoxy/
fi

exec "$@"
