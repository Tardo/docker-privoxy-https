```yaml
...
    labels:
      ...
      - traefik.tcp.routers.privoxy-https.rule=HostSNI(`privoxy.local`)
      - traefik.tcp.routers.privoxy-https.entrypoints=websecure
      - traefik.tcp.routers.privoxy-https.tls=true
      - traefik.tcp.routers.privoxy-https.tls.certresolver=
      - traefik.tcp.routers.privoxy-https.tls.passthrough=true
      - traefik.tcp.routers.privoxy-https.service=privoxy-https-service
      - traefik.tcp.services.privoxy-https-service.loadbalancer.server.port=443
...
```
