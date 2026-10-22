# local-https-proxy

One HTTPS reverse proxy for every Docker Compose stack on a development machine. Each stack gets a real hostname on port 443 with a publicly trusted certificate, so local development runs on origins shaped like production's: `https://main.myapp.dev.example.com`, not `http://localhost:8080`.

- **No ports to juggle.** Stacks publish no host ports; the proxy serves them all on `127.0.0.1:443`, by hostname.
- **Routes follow containers.** A stack labels its web service with its hostname. When it starts, the proxy starts routing to it; when it stops, the route goes away. The proxy's own config never changes.
- **Real certificates, nothing to trust.** Caddy gets them from Let's Encrypt through the DNS challenge, using a Cloudflare API token, and keeps them in a volume, so each hostname's certificate is issued once and renewed after that.

It's [Caddy](https://caddyserver.com) with [caddy-docker-proxy](https://github.com/lucaslorentz/caddy-docker-proxy) and [caddy-dns/cloudflare](https://github.com/caddy-dns/cloudflare). It listens on loopback only, so nothing is served to your local network.

Runs on macOS (Docker Desktop, OrbStack or Colima) and Linux.

## Setup

Once per machine. You need Docker and a domain whose DNS is on Cloudflare. Below it's `example.com`, with dev names under `dev.example.com`.

1. **DNS record.** In Cloudflare, add a record for `*.dev.example.com`, type A, content `127.0.0.1`, proxy status **DNS only** (grey cloud). A DNS wildcard matches names at any depth under it, so every project's names resolve without further records. If Cloudflare proxied it (orange cloud), requests would go to Cloudflare instead of your machine.
2. **Check your resolver allows it.** `dig +short anything.dev.example.com` should print `127.0.0.1`. Some resolvers (Pi-hole, NextDNS, some routers) block public names that point at private addresses, as protection against DNS rebinding. If yours does, allow `dev.example.com` there.
3. **API token.** In Cloudflare, under *My Profile → API Tokens*, create a token from the *Edit zone DNS* template with permissions *Zone → Zone → Read* and *Zone → DNS → Edit*, and *Zone Resources* set to only your domain's zone. Caddy uses it to add and remove the `_acme-challenge` TXT records Let's Encrypt checks.
4. **Save the token** in this repo's `.env`, which git ignores, readable only by you:
   ```sh
   cp .env.example .env && chmod 600 .env
   ```
   Then open `.env` in an editor and paste the token after `CLOUDFLARE_API_TOKEN=`. An editor keeps it out of your shell history.
5. **Start it.**
   ```sh
   devbox run up
   ```
   It restarts with Docker. `devbox run logs` shows each certificate as it's issued.

Ports 80 and 443 must be free on 127.0.0.1.

## Routing a stack through it

Join the stack's web service to the `local-https-proxy` network and label it with the site's address and upstream:

```yaml
services:
  web:
    labels:
      caddy: https://main.myapp.dev.example.com
      caddy.reverse_proxy: "{{upstreams 80}}"
    networks:
      - local-https-proxy

networks:
  local-https-proxy:
    external: true
```

Put this in a compose override file (such as `compose.local-https-proxy.yaml`), not the stack's main compose file: the external network only exists where this proxy runs, and Compose won't start a stack whose external network is missing. Each person who uses the proxy enables the override in their own `.env`, with `COMPOSE_FILE=compose.yaml:compose.local-https-proxy.yaml`. Anyone else keeps the stack's default.

The labels are a [Caddyfile written as labels](https://github.com/lucaslorentz/caddy-docker-proxy#labels-to-caddyfile-conversion). `caddy.tls: internal` uses Caddy's own CA instead of Let's Encrypt, for a name outside your Cloudflare zone.

The proxy passes `X-Forwarded-For`, `X-Forwarded-Proto` and `X-Forwarded-Host` upstream, and redirects HTTP to HTTPS.

[worktree-env](https://github.com/ianflanagan1/worktree-env) sets these names up for a project's git worktrees: `main.<project>.dev.example.com` for the main checkout and `wt1` to `wt9` for the others.

## Commands

| | |
|---|---|
| `devbox run up` | Build and start the proxy |
| `devbox run down` | Stop it. Certificates are kept |
| `devbox run logs` | Follow Caddy's log: routes as they change, certificates as they're issued |
| `devbox run config` | Show the config Caddy is running, built from every running container's labels |

## Notes

- **Certificate Transparency.** Every certificate Let's Encrypt issues is published in public logs, so hostnames you use are visible there.
- **Rate limits.** Let's Encrypt allows 50 certificates per registered domain each week and 5 identical ones. The volume keeps certificates across restarts, so a fixed set of names stays well inside them. Avoid deleting the `caddy-data` volume.
- **Docker API access.** Caddy reads the Docker API through [docker-socket-proxy](https://github.com/Tecnativa/docker-socket-proxy), which allows only reading containers, networks, events and system info. Caddy never gets the socket itself.

## License

MIT
