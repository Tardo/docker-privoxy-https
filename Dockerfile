FROM alpine:latest

ARG PRIVOXY_VERSION=4.0.0
ARG PRIVOXY_SRC_SHA1SUM=d302cb0bf23536e67a1b5505d01486a335d9c4c0
ARG PRIVOXY_CONFIG_OPTIONS="--disable-toggle --disable-editor --disable-force --with-openssl --with-brotli"
ARG PRIVOXY_BUILD_EXTRA="openssl-dev brotli-dev"
ARG SYSTEM_EXTRA_PKGS="openssl brotli net-tools"

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

# Build Privoxy
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
        $PRIVOXY_BUILD_EXTRA; \
    wget -qO /var/lib/privoxy/privoxy-src.tar.gz https://sourceforge.net/projects/ijbswa/files/Sources/${PRIVOXY_VERSION}%20%28stable%29/privoxy-${PRIVOXY_VERSION}-stable-src.tar.gz/download; \
    echo "${PRIVOXY_SRC_SHA1SUM} /var/lib/privoxy/privoxy-src.tar.gz" | sha1sum -c; \
    tar -zxvf /var/lib/privoxy/privoxy-src.tar.gz -C /var/lib/privoxy/; \
    cd /var/lib/privoxy/privoxy-${PRIVOXY_VERSION}-stable; \
    autoheader; \
    autoconf; \
    ./configure $PRIVOXY_CONFIG_OPTIONS; \
    make; \
    make -s install USER=privoxy GROUP=privoxy; \
    chown -R privoxy:privoxy /usr/local/etc/privoxy/; \
    rm -rf /var/lib/privoxy/privoxy-src.tar.gz /var/lib/privoxy/privoxy-${PRIVOXY_VERSION}-stable; \
    apk del build-tools build-deps;

# Add system tools
RUN set -eux; \
    apk add --no-cache --virtual runtime-deps \
            python3 \
            pcre2 \
            bash \
            sed \
            $SYSTEM_EXTRA_PKGS;

# Enable Privoxy HTTPS inspection
# hadolint ignore=SC1003
RUN set -ex; \
    mv /usr/local/etc/privoxy/config /usr/local/etc/privoxy/config.orig; \
    sed -i '/^+set-image-blocker{pattern}/a +https-inspection \\' /usr/local/etc/privoxy/match-all.action;

# Copy project scripts/configs
COPY data/rules/ /usr/local/etc/privoxy/privman-rules/
COPY data/config /usr/local/etc/privoxy/
COPY data/privoxy-blocklist.conf /var/lib/privoxy/
RUN set -eux; \
    # Remove CRLF (dos2unix) and ensure LF-only
    sed -i 's/\r$//' /var/lib/privoxy/privoxy-blocklist.conf
COPY bin/privman.py /var/lib/privoxy/privman.py
RUN set -ex; \
    sed -i 's/\r$//' /var/lib/privoxy/privman.py; \
    head -1 /var/lib/privoxy/privman.py | grep -q '^#!' || \
        sed -i '1i #!/usr/bin/env python3' /var/lib/privoxy/privman.py; \
    chmod +x /var/lib/privoxy/privman.py; \
    ln -sf /var/lib/privoxy/privman.py /usr/local/sbin/privman;
COPY bin/privoxy-blocklist.sh /var/lib/privoxy/privoxy-blocklist.sh
RUN set -eux; \
    sed -i 's/\r$//' /var/lib/privoxy/privoxy-blocklist.sh; \
    chmod +x /var/lib/privoxy/privoxy-blocklist.sh; \
    ln -sf /var/lib/privoxy/privoxy-blocklist.sh /usr/local/sbin/privoxy-blocklist;
COPY docker-entrypoint.sh /usr/local/sbin/
RUN sed -i 's/\r$//' /usr/local/sbin/docker-entrypoint.sh && \
        chmod +x /usr/local/sbin/docker-entrypoint.sh;

# Set the correct permissions
RUN set -ex; \
    mkdir -p /var/log/privoxy /usr/local/etc/privoxy/CA /usr/local/etc/privoxy/certs /usr/local/etc/privoxy/privman-rules; \
    chown -R privoxy:privoxy /var/log/privoxy/ /usr/local/etc/privoxy/config /usr/local/etc/privoxy/CA /usr/local/etc/privoxy/certs /usr/local/etc/privoxy/privman-rules /var/lib/privoxy/privoxy-blocklist.conf;

ENV ADBLOCK_URLS="" \
    ADBLOCK_FILTERS=""

ENTRYPOINT ["/usr/local/sbin/docker-entrypoint.sh"]

RUN cp -a /usr/local/etc/privoxy /opt/privoxy-default

VOLUME /usr/local/etc/privoxy
EXPOSE 8118/tcp

USER privoxy

WORKDIR /usr/local/etc/privoxy/
CMD ["/usr/local/sbin/privoxy", "--no-daemon"]
