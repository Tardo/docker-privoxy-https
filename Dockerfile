FROM alpine:latest
MAINTAINER tardo


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
    ./configure --disable-toggle --disable-editor --disable-force --with-openssl --with-brotli --enable-compression; \
    make; \
    make -s install USER=privoxy GROUP=privoxy;

RUN set -eux; \
    yes | rm -r /usr/local/src/privoxy-${PRIVOXY_VERSION}-stable; \
    apk del build-tools;

RUN set -eux; \
    apk add --no-cache --virtual sys-tools \
    openssl;

RUN set -eux; \
    mkdir -p /usr/local/etc/privoxy/CA /usr/local/etc/privoxy/certs; \
    chown privoxy:privoxy /usr/local/etc/privoxy/CA /usr/local/etc/privoxy/certs; \
    mv /usr/local/etc/privoxy/config /usr/local/etc/privoxy/config.orig; \
    sed -i '/^+set-image-blocker{pattern}/a +https-inspection \\' /usr/local/etc/privoxy/match-all.action;

COPY config /usr/local/etc/privoxy/

VOLUME /usr/local/etc/privoxy/CA
VOLUME /usr/local/etc/privoxy/certs

EXPOSE 8118

ENV FORCE_REFRESH_TRUSTED_CA=false \
    FORCE_GEN_CERT_BUNDLE=false \
    CERT_COUNTRY_CODE=ES \
    CERT_STATE=Madrid \
    CERT_LOCATION=Madrid \
    CERT_ORG=DockerPrivoxy \
    CERT_ORG_UNIT=PROXY \
    CERT_CN=privoxy.proxy

COPY docker-entrypoint.sh /usr/local/bin/
ENTRYPOINT ["docker-entrypoint.sh"]

USER privoxy

WORKDIR /usr/local/etc/privoxy/

CMD ["privoxy", "--no-daemon"]

