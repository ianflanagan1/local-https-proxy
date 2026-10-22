# Caddy with two plugins: caddy-docker-proxy builds its config from container labels, and
# caddy-dns/cloudflare answers Let's Encrypt's DNS challenge, since 127.0.0.1 can't be reached
# for the HTTP one.

FROM docker.io/library/caddy:2.11.7-builder-alpine AS builder

RUN xcaddy build \
        --with github.com/lucaslorentz/caddy-docker-proxy/v2@v2.13.1 \
        --with github.com/caddy-dns/cloudflare@v0.2.4

FROM docker.io/library/caddy:2.11.7-alpine

COPY --from=builder /usr/bin/caddy /usr/bin/caddy

CMD ["caddy", "docker-proxy"]
