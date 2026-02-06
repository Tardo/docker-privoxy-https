#!/bin/sh
set -e

echo "[entrypoint] loading privoxy environment..."

privman --init


if $ADBLOCK_NGINX_ENABLED && [ -n "$ADBLOCK_URLS" ]; then
  echo "[entrypoint] launching nginx..."
  envsubst '$NGINX_SERVER_NAME $NGINX_PORT $NGINX_PORT_SSL' < /etc/nginx/nginx.conf.template > /etc/nginx/nginx.conf
  nginx
fi

envsubst '$NGINX_SERVER_NAME' < /usr/local/etc/privoxy/privman-rules/common.filter.template > /usr/local/etc/privoxy/privman-rules/common.filter

if [ ! -e /usr/local/etc/privoxy/config ] || [ -z "$(ls -A /usr/local/etc/privoxy)" ]; then
  echo "[entrypoint] void config, populating defaults..."
  cp -a /opt/privoxy-default/* /usr/local/etc/privoxy/
  cp /usr/local/etc/privoxy/config.orig /usr/local/etc/privoxy/config
  sed -i \
    -e 's/^confdir .*/confdir \/usr\/local\/etc\/privoxy/' \
    -e 's/^templdir .*/templdir \/usr\/local\/etc\/privoxy\/templates/' \
    -e '/^actionsfile user.action/a actionsfile ab2p.system.action\nactionsfile ab2p.action\nactionsfile privman-rules\/user.action\nactionsfile privman-rules\/common.action' \
    -e '/^filterfile user.filter/a filterfile ab2p.system.filter\nfilterfile ab2p.filter\nfilterfile privman-rules\/user.filter\nfilterfile privman-rules\/common.filter' \
    -e 's/^listen-address .*/listen-address  0.0.0.0:'"${PRIVOXY_PORT}"'/' \
    -e 's/^enforce-blocks .*/#enforce-blocks 0/' \
    -e 's/^buffer-limit .*/buffer-limit 25600/' \
    -e 's/^keep-alive-timeout .*/keep-alive-timeout 120/' \
    -e 's/^socket-timeout .*/socket-timeout 150/' \
    -e 's/^#max-client-connections .*/max-client-connections 256/' \
    -e 's/^#listen-backlog .*/listen-backlog 128/' \
    -e 's/^#ca-directory .*/ca-directory \/usr\/local\/etc\/privoxy\/CA/' \
    -e 's/^#ca-cert-file .*/ca-cert-file privoxy-ca-bundle.crt/' \
    -e 's/^#ca-key-file .*/ca-key-file cakey.pem/' \
    -e 's/^#certificate-directory .*/certificate-directory \/usr\/local\/etc\/privoxy\/certs/' \
    -e 's/^#trusted-cas-file .*/trusted-cas-file trustedCAs.pem/' \
    -e '$a\receive-buffer-size 32768' \
    -e '$a\cipher-list ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256' \
  /usr/local/etc/privoxy/config
fi

echo "[entrypoint] starting..."
exec "$@"
