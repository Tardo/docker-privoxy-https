FROM alpine:latest

RUN set -eux; \
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

RUN set -eux; \
    apk add --no-cache --virtual build-tools \
        gcc \
        autoconf \
        make \
        git; \
    apk add --no-cache --virtual build-deps \
        libc-dev \
        zlib-dev \
        pcre-dev \
        openssl-dev \
        brotli-dev;

ARG PRIVOXY_VERSION=3.0.34

RUN set -eux; \
    mkdir -p /usr/local/src/privoxy-${PRIVOXY_VERSION}-stable; \
    wget -O privoxy-src.tar.gz -P /var/lib/privoxy/ https://sourceforge.net/projects/ijbswa/files/Sources/${PRIVOXY_VERSION}%20%28stable%29/privoxy-${PRIVOXY_VERSION}-stable-src.tar.gz/download; \
    tar -zxvf privoxy-src.tar.gz -C /usr/local/src/; \
    cd /usr/local/src/privoxy-${PRIVOXY_VERSION}-stable; \
    autoheader; \
    autoconf; \
    ./configure --disable-toggle --disable-editor --disable-force --with-openssl; \
    make; \
    make -s install USER=privoxy GROUP=privoxy;

RUN set -eux; \
    rm -rf /usr/local/src/privoxy-${PRIVOXY_VERSION}-stable; \
    apk del build-tools;

RUN set -eux; \
    apk add --no-cache --virtual sys-tools \
        openssl \
        python3 \
        py3-setuptools \
        py3-pip \
        supervisor;

RUN set -eux; \
    mv /usr/local/etc/privoxy/config /usr/local/etc/privoxy/config.orig; \
    sed -i '/^+set-image-blocker{pattern}/a +https-inspection \\' /usr/local/etc/privoxy/match-all.action;

COPY rules/ /usr/local/etc/privoxy/privman-rules
COPY supervisord.conf /usr/local/etc/privoxy/
COPY config /usr/local/etc/privoxy/

RUN set -eux; \
    mkdir -p /usr/local/etc/privoxy/CA /usr/local/etc/privoxy/certs /usr/local/etc/privoxy/privman-rules; \
    chown -R privoxy:privoxy /usr/local/etc/privoxy/config /usr/local/etc/privoxy/CA /usr/local/etc/privoxy/certs /usr/local/etc/privoxy/privman-rules;

COPY bin/privman /usr/local/bin/
COPY docker-entrypoint.sh /usr/local/bin/
RUN chmod a+x /usr/local/bin/privman /usr/local/bin/docker-entrypoint.sh;

ENTRYPOINT ["docker-entrypoint.sh"]

VOLUME /usr/local/etc/privoxy
EXPOSE 8118/tcp

USER privoxy

WORKDIR /usr/local/etc/privoxy/
CMD ["/usr/bin/supervisord", "-c", "supervisord.conf"]
