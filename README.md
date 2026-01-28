# Docker Privoxy HTTPS

## :page_with_curl: About

Image with [privoxy](https://www.privoxy.org) enabled and configured to work with HTTPS.

It also includes '[ab2p](https://github.com/essandess/adblock2privoxy)' (adblock2privoxy) to translate adblock rules to privoxy with CSS hidden elements & blackhole.
This means that this image also includes an nginx server so that the advanced CSS rules work correctly.

## :bulb: Documentation

This image downloads the 'trustedCAs' file from curl.se and also generates the ca-bundle file. So, you only need copy the 'ca-bundle' file and install it on your browser/system.

- Check Privoxy Status: ```https://config.privoxy.org/show-status```
- Check *ab2p* is fully operational (needs privoxy ca-bundle to verify SSL): ```https://<ADBLOCK_CSS_DOMAIN>/ab2p.common.css```

### Notes

- The default configuration is intended for personal use only
- If you use ab2p rules, make sure that the routing to the service is configured correctly. Otherwise, you will experience significant loading delays. You can see a basic example in ```docs/traefik.md```.

### Default Ports

| PORT | Description | Required |
|----------------|-------------|-------------|
| 8118 | Privoxy | :heavy_check_mark: |
| 80 | Nginx | If you use the ab2p rules |
| 443 | Nginx SSL | If you use the ab2p rules |


### Env. Variables

| Name | Description | Default |
|----------------|-------------|-------------|
| PRIVOXY_PORT | The Privoxy port | 8118 |
| ADBLOCK_URLS | URLs separated by spaces | "" |
| ADBLOCK_CSS_DOMAIN | A domain/IP that points to the container (IP:PORT) | 172.17.0.2 |
| ADBLOCK_NGINX_ENABLED | Enable NGINX | true |
| NGINX_SERVER_NAME | The server name for verification process (must coincide with ADBLOCK_CSS_DOMAIN name part) | 172.17.0.2 |
| NGINX_PORT | The HTTP port | 80 |
| NGINX_PORT_SSL | The HTTPS port | 443 |

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
      - 80:80
      - 443:443
    environment:
      TZ: Europe/Madrid
      ADBLOCK_URLS: https://easylist.to/easylist/easylist.txt
      ADBLOCK_CSS_DOMAIN: privoxy.local
      NGINX_SERVER_NAME: privoxy.local
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
- Regenerate nginx certificates: `docker exec privoxy privman --regenerate-nginx-certs`
- Update 'adblock' filters: `docker exec privoxy privman --update-adblock-filters`
- Add a domain to the blocklist: `docker exec privoxy privman --add-blocklist .google. .facebook.`
- Remove a domain from the blocklist: `docker exec privoxy privman --remove-blocklist .facebook.`

## :page_facing_up: Configuration highlight changes

- `actionsfile privman-rules/user.action` > Where are the privman rules (empty by default)
- `filterfile privman-rules/user.filter` > Predefined privman aliases
- `actionsfile ab2p.system.action` > adblock2privoxy
- `actionsfile ab2p.action` > adblock2privoxy
- `filterfile ab2p.system.filter` > adblock2privoxy
- `filterfile ab2p.filter` > adblock2privoxy
- `buffer-limit` > Increased to 25600KB (25MB)
- `keep-alive-timeout` > Increased to 120 seconds
- `socket-timeout` > Decreased to 150 seconds
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

## :wrench: Custom configuration

- If want privman blocking need add:
    ```yaml
    actionsfile privman-rules/user.action
    filterfile privman-rules/user.filter
    ```
- If want adblock2privoxy blocking need add:
    ```yaml
    actionsfile ab2p.system.action
    actionsfile ab2p.action
    filterfile ab2p.system.filter
    filterfile ab2p.filter
    ```

## :computer: Privoxy Compiler Options

- --disable-toggle
- --disable-editor
- --disable-force
- --with-openssl
- --with-brotli
- --with-zstd
