#!/bin/sh
set -e

ORIG_PWD=$(pwd)
cd /usr/local/etc/privoxy/CA

if [ ! -f /usr/local/etc/privoxy/CA/trustedCAs.pem ] || [ "$FORCE_REFRESH_TRUSTED_CA" = true ]; then
    wget https://curl.se/ca/cacert.pem -O trustedCAs.pem;
fi

if [ ! -f /usr/local/etc/privoxy/CA/privoxy-ca-bundle.crt ] || [ "$FORCE_GEN_CERT_BUNDLE" = true ]; then
    openssl ecparam -out cakey.pem -name secp384r1 -genkey
    openssl req -new -x509 -key cakey.pem -sha384 -days 3650 -out privoxy-ca-bundle.crt -extensions v3_ca -subj "/C=${CERT_COUNTRY_CODE}/ST=${CERT_STATE}/L=${CERT_LOCATION}/O=${CERT_ORG} Security/OU=${CERT_ORG_UNIT} Department/CN=${CERT_CN}"
fi

cd $ORIG_PWD
exec "$@"
