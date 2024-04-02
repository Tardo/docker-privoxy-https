# Docker Privoxy HTTPS

## :page_with_curl: About

Alpine docker with [privoxy](https://www.privoxy.org) enabled and configured to work with HTTPS.

**The default configuration is intended for personal use only (ex. raspberry)**

## :bulb: Documentation

This image downloads the 'trustedCAs' file from curl.se and also generates the ca-bundle file. So, you only need copy the 'ca-bundle' file and install it on your browser/system.

### Docker
```sh
docker run -d --restart unless-stopped --name privoxy -p 8118:8118 -v privoxy-ca:/usr/local/etc/privoxy/CA -v privoxy-certs:/usr/local/etc/privoxy/certs ghtardo/docker-privoxy-https
```


### Docker Compose
```yml
services:
  privoxy:
    image: ghtardo/docker-privoxy-https
    container_name: privoxy
    ports:
      - 8118:8118
    environment:
      - TZ=Europe/Madrid
    volumes:
      - privoxy-ca:/usr/local/etc/privoxy/CA
      - privoxy-certs:/usr/local/etc/privoxy/certs
    restart: unless-stopped
    hostname: "privoxy"

volumes:
    privoxy-ca:
    privoxy-certs:
```

### Get ca-bundle
```sh
docker cp privoxy:/usr/local/etc/privoxy/CA/privoxy-ca-bundle.crt .
```

## :triangular_ruler: Privoxy Manager Script (privman)

- Update the Trusted CA file: `docker exec privoxy privman --update-trusted-ca`
- Regenerate the .crt bundle: `docker exec privoxy privman --regenerate-crt-bundle`
- Block a domain to the blacklist: `docker exec privoxy privman --add-blacklist .google. .facebook.`
- Remove a domain from the blacklist: `docker exec privoxy privman --remove-blacklist .facebook.`

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
