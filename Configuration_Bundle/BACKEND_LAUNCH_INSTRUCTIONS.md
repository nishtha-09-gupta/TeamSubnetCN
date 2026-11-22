# Phase 2 service launch

The Phase 2 allocation is: Nishtha `10.7.30.234` (primary DNS and Backend A), Mishti `10.7.13.67` (backup DNS), Aditya `10.7.13.91` (nginx edge), and Shrijan `10.7.1.114` (Backend B). DNS and Backend A are separate services sharing Nishtha’s Mac. The Phase 1 backend and edge addresses are historical and are not used by these commands. The original Phase 1 DNS IP was not provided.

Run the backend commands from the repository root. Both services bind to `0.0.0.0` on the existing ports.

## Backend A — Nishtha, port 3001

```bash
cd backends/backend-a
npm install
node backend-A.js
```

## Backend B — Shrijan, port 3002

```bash
cd backends/backend-b
npm install
node backend-B.js
```

## Verify backend services

From Nishtha’s Mac:

```bash
lsof -nP -iTCP:3001 -sTCP:LISTEN
curl -i http://10.7.30.234:3001/api/status
```

From Shrijan’s Mac:

```bash
lsof -nP -iTCP:3002 -sTCP:LISTEN
curl -i http://10.7.1.114:3002/api/status
```

From the nginx edge, both status endpoints should return the matching backend identifier and `X-Backend` response header.

## DNS configuration files

Install `Configuration_Bundle/dnsmasq/dnsmasq.conf` as the primary config at `$(brew --prefix)/etc/dnsmasq.conf`. Install `Configuration_Bundle/dnsmasq/phase2-backup-dnsmasq.conf` on Mishti’s Mac as `$(brew --prefix)/etc/dnsmasq-backup.conf`. Preserve any unrelated local dnsmasq settings when installing. Validate each file with `dnsmasq --test --conf-file=PATH` before starting its resolver.

## Start order

1. On Nishtha’s Mac, start primary dnsmasq with `brew services restart dnsmasq`, then start Backend A.
2. On Mishti’s Mac, run the backup resolver in its separate foreground process: `sudo "$(brew --prefix)/sbin/dnsmasq" --no-daemon --conf-file="$(brew --prefix)/etc/dnsmasq-backup.conf"`.
3. On Shrijan’s Mac, start Backend B.
4. On Aditya’s Mac, validate and start nginx: `nginx -t && brew services restart nginx`.
5. On client Macs, configure both DNS resolvers using `client/CLIENT_DNS_SETUP.md`.
