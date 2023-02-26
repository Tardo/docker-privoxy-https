# Docker Privoxy HTTPS

## :page_with_curl: About

Alpine docker with [privoxy](https://www.privoxy.org) enabled to work with HTTPS.

## :bulb: Documentation

This image downloads the 'trustedCAs' file from curl.se and also generates the ca-bundle file. So, you only need copy the 'ca-bundle' file and install it on your browser/system.

1. Start to use this image with:
   
   `docker run -d --restart unless-stopped --name privoxy -p 8118:8118 -v privoxy-ca:/usr/local/etc/privoxy/CA -v privoxy-certs:/usr/local/etc/privoxy/certs ghtardo/docker-privoxy-https`

2. Get the 'ca-bundle' file with:

   `docker cp privoxy:/usr/local/etc/privoxy/CA/privoxy-ca-bundle.crt .`

## :triangular_ruler: Env. Variables

| Name | Description | Default |
|------|-------------|---------|
| FORCE_REFRESH_TRUSTED_CA | Force the download of the trustedCAs file | false |
| FORCE_GEN_CERT_BUNDLE | Force the generation of the privoxy-ca-bundle.crt file | false |
| CERT_COUNTRY_CODE | The country code used for the 'ca-bundle' file | ES |
| CERT_STATE | The state used for the 'ca-bundle' file | Madrid |
| CERT_LOCATION | The location used for the 'ca-bundle' file | Madrid |
| CERT_ORG | The organization used for the 'ca-bundle' file | DockerPrivoxy |
| CERT_ORG_UNIT | The organization unit used for the 'ca-bundle' file | PROXY |
| CERT_CN | The common name used for the 'ca-bundle' file | privoxy.proxy |

## :bookmark: Points of Interest

| Container Path | Description |
|----------------|-------------|
| /usr/local/etc/privoxy/ | Where privoxy files are located |
| /usr/local/etc/privoxy/config | The configuration file |
| /usr/local/etc/privoxy/CA | Where auth. certs are located |
| /usr/local/etc/privoxy/certs | Where privoxy stores the downloaded certificates|

## :bookmark_tabs: Privoxy Compiler Options

- --disable-toggle
- --disable-editor 
- --disable-force 
- --with-openssl 
- --with-brotli 
- --enable-compression