# Docker Privoxy HTTPS

## :page_with_curl: About

Alpine docker with [privoxy](https://www.privoxy.org) enabled and configured to work with HTTPS.

It also includes '[adblock2privoxy](https://github.com/essandess/adblock2privoxy)' to translate adblock rules to privoxy with CSS hidden elements & blackhole.

**The default configuration is intended for personal use only (ex. raspberry)**

## :bulb: Documentation

This image downloads the 'trustedCAs' file from curl.se and also generates the ca-bundle file. So, you only need copy the 'ca-bundle' file and install it on your browser/system.

Privoxy Status Page: https://config.privoxy.org/show-status


### Env. Variables

| Name | Description | Default |
|----------------|-------------|-------------|
| ADBLOCK_URLS | String of urls separated by spaces | "" |
| ADBLOCK_CSS_DOMAIN | A domain/IP that points to the container (IP:PORT) | 172.17.0.2:8119 |

- Can get urls from: https://easylist.to/

### Docker
```sh
docker run -d --restart unless-stopped --name privoxy -p 8118:8118 -v privoxy-ca:/usr/local/etc/privoxy/CA ghtardo/docker-privoxy-https
```


### Docker Compose
```yml
services:
  privoxy:
    image: ghtardo/docker-privoxy-https
    container_name: privoxy
    ports:
      - 8118:8118
      - 8119:8119
    environment:
      TZ: Europe/Madrid
      ADBLOCK_URLS: https://easylist.to/easylist/easylist.txt
      ADBLOCK_CSS_DOMAIN: privoxy.local:8119
    volumes:
      - privoxy-ca:/usr/local/etc/privoxy/CA
    restart: unless-stopped
    hostname: "privoxy"

volumes:
    privoxy-ca:
```

** privoxy.local must point to the container

### Get ca-bundle
```sh
docker cp privoxy:/usr/local/etc/privoxy/CA/privoxy-ca-bundle.crt .
```

## :triangular_ruler: Privoxy Manager Script (privman)

- Update the Trusted CA file: `docker exec privoxy privman --update-trusted-ca`
- Regenerate the .crt bundle: `docker exec privoxy privman --regenerate-crt-bundle`
- Update 'adblock' filters: `docker exec privoxy privman --update-adblock-filters`
- Add a domain to the blocklist: `docker exec privoxy privman --add-blocklist .google. .facebook.`
- Remove a domain from the blocklist: `docker exec privoxy privman --remove-blocklist .facebook.`

## :page_facing_up: Configuration highlight changes

- `actionsfile privman-rules/user.action` > Where are the privman rules (empty by default)
- `filterfile privman-rules/user.filter` > Predefined privman aliases
- `buffer-limit` > Increased to 25600KB (25MB)
- `keep-alive-timeout` > Increased to 120 seconds
- `socket-timeout` > Decreased to 30 seconds
- `max-client-connections` > Increased to 256
- `listen-backlog` > Set to 128
- `receive-buffer-size` > Increased to 32768 bytes

## :bookmark: Points of Interest

| Container Path | Description |
|----------------|-------------|
| /usr/local/etc/privoxy/ | Where privoxy files are located |
| /usr/local/etc/privoxy/config | The configuration file |
| /usr/local/etc/privoxy/CA | Where auth. certs are located |
| /usr/local/etc/privoxy/certs | Where privoxy stores the downloaded certificates |
| /var/lib/privoxy | Where are the scripts related to privoxy |

## :computer: Privoxy Compiler Options

- --disable-toggle
- --disable-editor
- --disable-force
- --with-openssl
- --with-brotli
