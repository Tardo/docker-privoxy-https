#!/bin/sh
set -e
privman --init

if $ADBLOCK_NGINX_ENABLED && [ -n "$ADBLOCK_URLS" ]; then
  envsubst '$NGINX_SERVER_NAME $NGINX_PORT $NGINX_PORT_SSL' < /etc/nginx/nginx.conf.template > /etc/nginx/nginx.conf
  nginx
fi

if [ ! -e /usr/local/etc/privoxy/config ] || [ -z "$(ls -A /usr/local/etc/privoxy)" ]; then
  echo "[entrypoint] void config, populating defaults..."
  cp -a /opt/privoxy-default/* /usr/local/etc/privoxy/
fi

echo "[entrypoint] starting..."
exec "$@"
