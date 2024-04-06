# Docker Privoxy HTTPS

## :page_with_curl: About

Alpine docker with [privoxy](https://www.privoxy.org) enabled and configured to work with HTTPS.

It also includes the script made by '[Andrwe Lord Weber](https://github.com/Andrwe/privoxy-blocklist)' to translate adblock rules to privoxy.

**The default configuration is intended for personal use only (ex. raspberry)**

## :bulb: Documentation

This image downloads the 'trustedCAs' file from curl.se and also generates the ca-bundle file. So, you only need copy the 'ca-bundle' file and install it on your browser/system.

Privoxy Status Page: https://config.privoxy.org/show-status


### Env. Variables

| Name | Description | Default |
|----------------|-------------|-------------|
| ADBLOCK_URLS | String of urls separated by spaces | "" |
| ADBLOCK_FILTERS | String of filters separated by spaces | "" |

- Can get urls from: https://easylist.to/
- Can know the available filters with ```docker exec privoxy privoxy-blocklist --help```

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
    environment:
      - TZ=Europe/Madrid
      - ADBLOCK_URLS=https://easylist.to/easylist/easylist.txt
    volumes:
      - privoxy-ca:/usr/local/etc/privoxy/CA
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
- Update 'adblock' filters: `docker exec privoxy privman --update-adblock-filters`
- Block a domain to the blacklist: `docker exec privoxy privman --add-blacklist .google. .facebook.`
- Remove a domain from the blacklist: `docker exec privoxy privman --remove-blacklist .facebook.`

## :page_facing_up: Configuration highlight changes

- `actionsfile privman-rules/user.action` > Where are the privman rules (empty by default)
- `filterfile privman-rules/user.filter` > Predefined privman aliases
- `buffer-limit` > Increased to 25600KB (25MB)
- `keep-alive-timeout` > Increased to 600 seconds
- `socket-timeout` > Decreased to 5 seconds
- `max-client-connections` > Increased to 512
- `listen-backlog` > Set to -1 (maximum queue length allowed)
- `receive-buffer-size` > Increased to 65536 bytes

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
