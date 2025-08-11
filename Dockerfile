FROM debian:stable-slim AS build-privoxy

ARG PRIVOXY_VERSION=4.0.0
ARG PRIVOXY_SRC_SHA1SUM=d302cb0bf23536e67a1b5505d01486a335d9c4c0
ARG PRIVOXY_CONFIG_OPTIONS="--disable-toggle --disable-editor --disable-force --with-openssl --with-brotli"
ARG PRIVOXY_BUILD_EXTRA="libssl-dev libbrotli-dev"

SHELL ["/bin/bash", "-eo", "pipefail", "-c"]

WORKDIR /build

RUN set -eux; \
    apt-get update && apt-get install -y --no-install-recommends \
        build-essential \
        autoconf \
        ca-certificates \
        git \
        curl \
        libc6-dev \
        zlib1g-dev \
        libpcre2-dev \
        $PRIVOXY_BUILD_EXTRA; \
    apt-get clean; \
    rm -rf /var/lib/apt/lists/*;

# hadolint ignore=DL3003
RUN set -eux; \
    curl -L -o privoxy-src.tar.gz https://sourceforge.net/projects/ijbswa/files/Sources/${PRIVOXY_VERSION}%20%28stable%29/privoxy-${PRIVOXY_VERSION}-stable-src.tar.gz/download; \
    echo "${PRIVOXY_SRC_SHA1SUM} privoxy-src.tar.gz" | sha1sum -c; \
    tar -zxvf privoxy-src.tar.gz; \
    cd privoxy-${PRIVOXY_VERSION}-stable; \
    autoheader; \
    autoconf; \
    ./configure --prefix=/usr/local $PRIVOXY_CONFIG_OPTIONS; \
    make; \
    make install; \
    privoxy --version;


FROM haskell:slim AS build-adblock2privoxy

ARG ADBLOCK2PRIVOXY_RESOLVER=lts-21.25

SHELL ["/bin/bash", "-eo", "pipefail", "-c"]

WORKDIR /build

RUN set -eux; \
    apt-get update && apt-get install -y --no-install-recommends \
        git \
        zlib1g-dev \
        libncurses-dev; \
    apt-get clean; \
    rm -rf /var/lib/apt/lists/*;

# hadolint ignore=DL3003
RUN set -eux; \
    git clone https://github.com/essandess/adblock2privoxy.git . --depth=1; \
    export STACK_ROOT=/usr/local/etc/.stack; \
    cd adblock2privoxy; \
    stack setup --allow-different-user --resolver $ADBLOCK2PRIVOXY_RESOLVER; \
    stack build --allow-different-user --resolver $ADBLOCK2PRIVOXY_RESOLVER --allow-newer; \
    stack install --allow-different-user --local-bin-path /usr/local/bin --resolver $ADBLOCK2PRIVOXY_RESOLVER --allow-newer; \
    adblock2privoxy --version;


FROM debian:stable-slim AS runtime

ARG SYSTEM_EXTRA_PKGS="brotli net-tools"

SHELL ["/bin/bash", "-eo", "pipefail", "-c"]

ENV PRIVOXY_PORT=8118 \
    ADBLOCK_URLS="" \
    ADBLOCK_NGINX_ENABLED=true \
    ADBLOCK_CSS_DOMAIN="172.17.0.2" \
    NGINX_SERVER_NAME="172.17.0.2" \
    NGINX_PORT=80 \
    NGINX_PORT_SSL=443

# Create Privoxy User
RUN set -ex; \
    addgroup --gid 7777 --system privoxy; \
    adduser \
        --disabled-password \
        --home /var/lib/privoxy/ \
        --ingroup privoxy \
        --no-create-home \
        --system \
        --uid 7777 \
        privoxy; \
    mkdir /var/lib/privoxy/; \
    chown privoxy:privoxy /var/lib/privoxy/;

# Add system tools
RUN set -eux; \
    apt-get update && apt-get install -y --no-install-recommends \
        python3 \
        pcre2-utils \
        openssl \
        nginx \
        libgmp-dev \
        libncurses-dev \
        ca-certificates \
        gettext-base \
        $SYSTEM_EXTRA_PKGS; \
    apt-get clean; \
    rm -rf /var/lib/apt/lists/*;

# Docker Entry Point
COPY docker-entrypoint.sh /usr/local/sbin/
RUN set -ex; \
    sed -i 's/\r$//' /usr/local/sbin/docker-entrypoint.sh; \
    chmod +x /usr/local/sbin/docker-entrypoint.sh;

# Privman
COPY data/rules/ /usr/local/etc/privoxy/privman-rules/
COPY bin/privman.py /var/lib/privoxy/privman.py
RUN set -ex; \
    sed -i 's/\r$//' /var/lib/privoxy/privman.py; \
    head -1 /var/lib/privoxy/privman.py | grep -q '^#!' || \
        sed -i '1i #!/usr/bin/env python3' /var/lib/privoxy/privman.py; \
    chmod +x /var/lib/privoxy/privman.py; \
    ln -sf /var/lib/privoxy/privman.py /usr/local/sbin/privman;

# Privoxy
COPY --from=build-privoxy /usr/local /usr/local
# hadolint ignore=SC1003,SC2016
RUN set -ex; \
    mkdir -p /var/log/privoxy /usr/local/etc/privoxy/CA /usr/local/etc/privoxy/certs /usr/local/etc/privoxy/privman-rules; \
    chown -R privoxy:privoxy /var/log/privoxy /usr/local/etc/privoxy; \
    chmod +x /usr/local/sbin/privoxy; \
    cp -a /usr/local/etc/privoxy /opt/privoxy-default; \
    # Change the default config
    cp /usr/local/etc/privoxy/config /usr/local/etc/privoxy/config.orig; \
    sed -i '/^+set-image-blocker{pattern}/a +https-inspection \\' /usr/local/etc/privoxy/match-all.action; \
    sed -i \
        -e 's/^confdir .+/confdir \/usr\/local\/etc\/privoxy/' \
        -e 's/^templdir .+/templdir \/usr\/local\/etc\/privoxy\/templates/' \
        -e '/^actionsfile user.action/a actionsfile privman-rules\/user.action\nactionsfile ab2p.system.action\nactionsfile ab2p.action' \
        -e '/^filterfile user.filter/a filterfile privman-rules\/user.filter\nfilterfile ab2p.system.filter\nfilterfile ab2p.filter' \
        -e 's/^#debug     1.+/debug     1/' \
        -e 's/^#debug   512.+/debug   512/' \
        -e 's/^#debug  1024.+/debug  1024/' \
        -e 's/^#debug  8192.+/debug  8192/' \
        -e 's/^listen-address .+/listen-address  0.0.0.0:${PRIVOXY_PORT}/' \
        -e 's/^enforce-blocks .+/#enforce-blocks 0/' \
        -e 's/^buffer-limit .+/buffer-limit 25600/' \
        -e 's/^keep-alive-timeout .+/keep-alive-timeout 120/' \
        -e 's/^tolerate-pipelining .+/tolerate-pipelining 0/' \
        -e 's/^socket-timeout .+/socket-timeout 30/' \
        -e 's/^#max-client-connections .+/max-client-connections 256/' \
        -e 's/^#listen-backlog .+/listen-backlog 128/' \
        -e 's/^#ca-directory .+/ca-directory \/usr\/local\/etc\/privoxy\/CA/' \
        -e 's/^#ca-cert-file .+/ca-cert-file privoxy-ca-bundle.crt/' \
        -e 's/^#ca-key-file .+/ca-key-file cakey.pem/' \
        -e 's/^#certificate-directory .+/certificate-directory \/usr\/local\/etc\/privoxy\/certs/' \
        -e 's/^#trusted-cas-file .+/trusted-cas-file trustedCAs.pem/' \
        -e '$a\receive-buffer-size 32768' \
        -e '$a\cipher-list ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256' \
    /usr/local/etc/privoxy/config; \
    chmod +x /usr/local/sbin/privoxy;

# adblock2privoxy
COPY --from=build-adblock2privoxy /usr/local/bin/adblock2privoxy /usr/local/bin/adblock2privoxy
COPY --from=build-adblock2privoxy /build/adblock2privoxy/templates /opt/local/share/adblock2privoxy/templates
COPY templates/nginx.conf.template /etc/nginx/nginx.conf.template
RUN set -ex; \
    mkdir -p /usr/local/etc/adblock2privoxy/css; \
    echo "# Dummy file" | tee -a /usr/local/etc/privoxy/ab2p.system.action /usr/local/etc/privoxy/ab2p.action /usr/local/etc/privoxy/ab2p.system.filter /usr/local/etc/privoxy/ab2p.filter; \
    chown -R privoxy:privoxy /usr/local/etc/privoxy/ab2p.system.action /usr/local/etc/privoxy/ab2p.action /usr/local/etc/privoxy/ab2p.system.filter /usr/local/etc/privoxy/ab2p.filter; \
    chown -R privoxy:privoxy /usr/local/etc/adblock2privoxy /etc/nginx /var/log/nginx /var/lib/nginx; \
    chmod 755 /usr/local/bin/adblock2privoxy; \
    chmod -R u+rw /etc/nginx /var/log/nginx /var/lib/nginx;

# Verifications
RUN set -ex; \
    privoxy --version; \
    adblock2privoxy --version;

ENTRYPOINT ["/usr/local/sbin/docker-entrypoint.sh"]

VOLUME /usr/local/etc/privoxy

USER privoxy

WORKDIR /usr/local/etc/privoxy/
CMD ["/usr/local/sbin/privoxy", "--no-daemon"]
