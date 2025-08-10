FROM alpine:latest AS build-privoxy

ARG PRIVOXY_VERSION=4.0.0
ARG PRIVOXY_SRC_SHA1SUM=d302cb0bf23536e67a1b5505d01486a335d9c4c0
ARG PRIVOXY_CONFIG_OPTIONS="--disable-toggle --disable-editor --disable-force --with-openssl --with-brotli"
ARG PRIVOXY_BUILD_EXTRA="openssl-dev brotli-dev"

SHELL ["/bin/ash", "-eo", "pipefail", "-c"]

WORKDIR /build

RUN set -eux; \
    apk add --no-cache --virtual build-tools \
        gcc \
        autoconf \
        make \
        git; \
    apk add --no-cache --virtual build-deps \
        libc-dev \
        zlib-dev \
        pcre2-dev \
        $PRIVOXY_BUILD_EXTRA;

RUN set -eux; \
    wget -qO privoxy-src.tar.gz https://sourceforge.net/projects/ijbswa/files/Sources/${PRIVOXY_VERSION}%20%28stable%29/privoxy-${PRIVOXY_VERSION}-stable-src.tar.gz/download; \
    echo "${PRIVOXY_SRC_SHA1SUM} privoxy-src.tar.gz" | sha1sum -c; \
    tar -zxvf privoxy-src.tar.gz; \
    cd privoxy-${PRIVOXY_VERSION}-stable; \
    autoheader; \
    autoconf; \
    ./configure --prefix=/usr/local $PRIVOXY_CONFIG_OPTIONS; \
    make; \
    make install; \
    privoxy --version;


FROM alpine:latest AS build-adblock2privoxy

ARG ADBLOCK2PRIVOXY_RESOLVER=lts-21.25

SHELL ["/bin/ash", "-eo", "pipefail", "-c"]

WORKDIR /build

RUN set -eux; \
    apk add --no-cache --virtual build-tools \
        gcc \
        g++ \
        make \
        curl \
        gmp \
        git \
        ghc \
        cabal \
        stack; \
    apk add --no-cache --virtual build-deps \
        musl-dev \
        zlib-dev \
        gmp-dev \
        ncurses-libs \
        ncurses-dev \
        xz;
    #curl -sSL https://get.haskellstack.org/ | sh;

RUN set -eux; \
    git clone https://github.com/essandess/adblock2privoxy.git . --depth=1; \
    export STACK_ROOT=/usr/local/etc/.stack; \
    cd adblock2privoxy; \
    stack setup --allow-different-user --resolver $ADBLOCK2PRIVOXY_RESOLVER; \
    stack build --allow-different-user --resolver $ADBLOCK2PRIVOXY_RESOLVER --allow-newer; \
    stack install --allow-different-user --local-bin-path /usr/local/bin --resolver $ADBLOCK2PRIVOXY_RESOLVER --allow-newer; \
    adblock2privoxy --version;


FROM alpine:latest AS runtime

ARG SYSTEM_EXTRA_PKGS="brotli net-tools"

SHELL ["/bin/ash", "-eo", "pipefail", "-c"]

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
    apk add --no-cache --virtual runtime-deps \
        python3 \
        pcre2 \
        openssl \
        nginx \
        gmp \
        ncurses \
        $SYSTEM_EXTRA_PKGS;

# Docker Entry Point
COPY docker-entrypoint.sh /usr/local/sbin/
RUN sed -i 's/\r$//' /usr/local/sbin/docker-entrypoint.sh && \
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
COPY data/config /usr/local/etc/privoxy/
# hadolint ignore=SC1003
RUN set -ex; \
    #mv /usr/local/etc/privoxy/config /usr/local/etc/privoxy/config.orig; \
    mkdir -p /var/log/privoxy /usr/local/etc/privoxy/CA /usr/local/etc/privoxy/certs /usr/local/etc/privoxy/privman-rules; \
    chown -R privoxy:privoxy /var/log/privoxy /usr/local/etc/privoxy; \
    sed -i '/^+set-image-blocker{pattern}/a +https-inspection \\' /usr/local/etc/privoxy/match-all.action; \
    cp -a /usr/local/etc/privoxy /opt/privoxy-default;

# adblock2privoxy
COPY --from=build-adblock2privoxy /usr/local/bin/adblock2privoxy /usr/local/bin/adblock2privoxy
COPY --from=build-adblock2privoxy /build/adblock2privoxy/templates /opt/local/share/adblock2privoxy/templates
COPY data/nginx.conf /etc/nginx/nginx.conf
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

# Common
ENV ADBLOCK_URLS=""
ENV ADBLOCK_CSS_DOMAIN="172.17.0.2:8119"

ENTRYPOINT ["/usr/local/sbin/docker-entrypoint.sh"]

VOLUME /usr/local/etc/privoxy
EXPOSE 8118/tcp
EXPOSE 8119/tcp

USER privoxy

WORKDIR /usr/local/etc/privoxy/
CMD ["/usr/local/sbin/privoxy", "--no-daemon"]
