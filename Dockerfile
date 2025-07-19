FROM alpine:latest

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

ARG PRIVOXY_VERSION=4.0.0

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
        openssl-dev \
        brotli-dev; \
    mkdir -p /usr/local/src/privoxy-${PRIVOXY_VERSION}-stable; \
    wget -O /var/lib/privoxy/privoxy-src.tar.gz https://sourceforge.net/projects/ijbswa/files/Sources/${PRIVOXY_VERSION}%20%28stable%29/privoxy-${PRIVOXY_VERSION}-stable-src.tar.gz/download; \
    tar -zxvf /var/lib/privoxy/privoxy-src.tar.gz -C /usr/local/src/; \
    cd /usr/local/src/privoxy-${PRIVOXY_VERSION}-stable; \
    autoheader; \
    autoconf; \
    ./configure --disable-toggle --disable-editor --disable-force --with-openssl --with-brotli; \
    make; \
    make -s install USER=privoxy GROUP=privoxy; \
    chown -R privoxy:privoxy /usr/local/etc/privoxy/; \
    rm -rf /var/lib/privoxy/privoxy-src.tar.gz /usr/local/src/privoxy-${PRIVOXY_VERSION}-stable; \
    apk del build-tools build-deps;

# Add system tools
RUN set -eux; \
    apk add --no-cache --virtual runtime-deps \
            openssl \
            python3 \
            pcre2 \
            brotli \
            supervisor \
            bash \
            sed \
            net-tools;

# Enable Privoxy HTTPS inspection
RUN set -ex; \
    mv /usr/local/etc/privoxy/config /usr/local/etc/privoxy/config.orig; \
    sed -i '/^+set-image-blocker{pattern}/a +https-inspection \\' /usr/local/etc/privoxy/match-all.action;

# Copy project scripts/configs
COPY data/rules/ /usr/local/etc/privoxy/privman-rules/
COPY data/supervisord.conf /usr/local/etc/privoxy/
COPY data/config /usr/local/etc/privoxy/
COPY data/privoxy-blocklist.conf /var/lib/privoxy/
RUN set -eux; \
    sed -i 's/\r$//' /var/lib/privoxy/privoxy-blocklist.conf
COPY bin/privman.py /var/lib/privoxy/privman.py
COPY bin/privoxy-blocklist.sh /var/lib/privoxy/privoxy-blocklist.sh
RUN set -eux; \
    # Remove CRLF (dos2unix) and ensure LF-only
    sed -i 's/\r$//' /var/lib/privoxy/privoxy-blocklist.sh; \
    # Make executable
    chmod +x /var/lib/privoxy/privoxy-blocklist.sh; \
    # (Re)create the symlink
    ln -sf /var/lib/privoxy/privoxy-blocklist.sh /usr/local/bin/privoxy-blocklist
COPY docker-entrypoint.sh /usr/local/bin/
RUN sed -i 's/\r$//' /usr/local/bin/docker-entrypoint.sh \
 && chmod +x /usr/local/bin/docker-entrypoint.sh

# Set the correct permissions
RUN set -ex; \
    sed -i 's/\r$//' /var/lib/privoxy/privman.py /var/lib/privoxy/privoxy-blocklist.sh; \
    head -1 /var/lib/privoxy/privman.py | grep -q '^#!' || \
      sed -i '1i #!/usr/bin/env python3' /var/lib/privoxy/privman.py; \
    mkdir -p /usr/local/etc/privoxy/CA /usr/local/etc/privoxy/certs /usr/local/etc/privoxy/privman-rules; \
    chown -R privoxy:privoxy /usr/local/etc/privoxy/config /usr/local/etc/privoxy/CA /usr/local/etc/privoxy/certs /usr/local/etc/privoxy/privman-rules /var/lib/privoxy/privoxy-blocklist.conf; \
    chmod +x /var/lib/privoxy/privman.py; \
    ln -sf /var/lib/privoxy/privman.py /usr/local/bin/privman; \
    ln -sf /var/lib/privoxy/privoxy-blocklist.sh /usr/local/bin/privoxy-blocklist;

ENV ADBLOCK_URLS="" \
    ADBLOCK_FILTERS=""

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]

RUN cp -a /usr/local/etc/privoxy /opt/privoxy-default

VOLUME /usr/local/etc/privoxy
EXPOSE 8118/tcp

USER privoxy

WORKDIR /usr/local/etc/privoxy/
CMD ["/usr/bin/supervisord", "-c", "supervisord.conf"]
