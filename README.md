# TeamSubnetCN

## Private Network Service Platform

A Computer Networks course project that serves a private web application across four macOS laptops. The project follows a request from private DNS resolution through TCP and TLS to an nginx edge, then to one of two Node.js/Express backends.

Phase 1 established the service and its network path. Phase 2 retains that application architecture and adds DNS redundancy, controlled DNS changes, backend isolation, passive backend failover, and a DNS-controlled standby-edge migration.

> **Addressing note:** Phase 1 and Phase 2 used different IP allocations. Use the Phase 2 values for the current deployment and its configuration. Phase 1 values below are historical only.

## Contents

- [Current deployment: Phase 2](#current-deployment-phase-2)
- [Request path and service behavior](#request-path-and-service-behavior)
- [Setup and operation](#setup-and-operation)
- [Phase 2 extensions](#phase-2-extensions)
- [Phase 1: original implementation](#phase-1-original-implementation)
- [Repository map](#repository-map)
- [Known limits](#known-limits)

## Current deployment: Phase 2

### Machine roles and addresses

| Team member | Role | Phase 2 address | Services |
|---|---|---:|---|
| Nishtha | Primary DNS and Backend A | `10.7.30.234` | dnsmasq on 53; Express on 3001 |
| Mishti | Backup DNS | `10.7.13.67` | dnsmasq on 53 |
| Aditya | nginx edge | `10.7.13.91` | HTTP on 80; HTTPS on 443 |
| Shrijan | Backend B | `10.7.1.114` | Express on 3002 |

Primary DNS and Backend A intentionally share Nishtha’s Mac and IP address. They are independent services using their own ports.

### Historical allocation and change between phases

| Role | Phase 1 address | Phase 2 address |
|---|---:|---:|
| Backend A | `10.7.9.8` | `10.7.30.234` |
| nginx edge | `10.7.28.24` | `10.7.13.91` |
| Backend B | `10.7.11.140` | `10.7.1.114` |
| Primary DNS | Not recorded in available Phase 1 evidence | `10.7.30.234` |
| Backup DNS | Not part of the Phase 1 allocation | `10.7.13.67` |

The Phase 1 DNS address is intentionally unspecified because the available evidence does not record it. Phase 1 addresses appear only in historical descriptions and evidence; do not copy them into current configuration.

### Current service names

Both private names resolve to the active nginx edge in the current Phase 2 configuration:

```text
app.teamX.test  → 10.7.13.91
api.teamX.test  → 10.7.13.91
```

The API name is a second DNS name for the same proxied service. The current application endpoint is available at either name:

```text
https://app.teamX.test/api/status
https://api.teamX.test/api/status
```

### Phase 2 request path

```text
Client
  │  resolves app.teamX.test or api.teamX.test
  ▼
Primary DNS (10.7.30.234) or Backup DNS (10.7.13.67)
  │  returns active edge address
  ▼
nginx edge (10.7.13.91:443)
  │  completes TLS termination, proxies HTTP
  ├──────────────────────────┐
  ▼                          ▼
Backend A                    Backend B
10.7.30.234:3001             10.7.1.114:3002
```

### Phase 2 configuration values

The Phase 2 helper scripts share their defaults in [`Helper_Scripts/Phase2/config.sh`](Helper_Scripts/Phase2/config.sh). The dnsmasq and nginx files use their native configuration formats and contain the corresponding Phase 2 service values. When an address or port changes, keep those native configuration files synchronized with the shared script settings.

## Request path and service behavior

### Backend responses

Each Express service exposes `GET /` and `GET /api/status`. The status route returns a small JSON body identifying the responding backend. Backend A returns:

```json
{"backend":"A","status":"ok"}
```

Backend B returns:

```json
{"backend":"B","status":"ok"}
```

The status responses include `X-Backend: A` or `X-Backend: B` and `Cache-Control: max-age=60`. Express generates a weak ETag based on the JSON representation. nginx adds the `X-Edge` response header at the edge. These identifiers make backend selection and edge traversal visible in HTTP responses.

### nginx, HTTPS, and upstream behavior

The active nginx configuration is [`Configuration_Bundle/nginx/teamx.conf`](Configuration_Bundle/nginx/teamx.conf). It accepts both application hostnames, redirects HTTP to HTTPS, terminates TLS, and proxies to the two backend ports. Its upstream uses `max_fails=1`, `fail_timeout=10s`, connection/read/send timeouts, and `proxy_next_upstream` retry settings.

Upstream failure detection is passive: nginx marks an upstream unavailable in response to failed requests. This configuration does not run continuous active health checks. When both backends are available, repeated edge requests can show both `X-Backend` values.

TLS uses a self-signed certificate with SAN entries for `app.teamX.test` and `api.teamX.test`. The certificate and private key are local deployment files and are not committed. Clients must trust the certificate for ordinary certificate validation to succeed; do not use `curl -k` for validation.

## Setup and operation

### Prerequisites

On the team Macs, install the locally used tools with the project’s Homebrew-based setup as needed:

- macOS and Homebrew
- Node.js and npm
- dnsmasq
- nginx
- OpenSSL, `curl`, `dig`, `nc`, and macOS network utilities

The repository does not require cloud services or containers. Service paths can differ between Intel and Apple Silicon Homebrew installations; the supplied Phase 2 configuration and helper scripts use the evidenced Apple Silicon paths where a default is needed. Override script variables when local paths differ.

### Configure client DNS

On each client Mac, configure the network service to use both current resolvers. The service name may be `Wi-Fi` or may differ on a particular Mac.

```bash
sudo networksetup -setdnsservers Wi-Fi 10.7.30.234 10.7.13.67
networksetup -getdnsservers Wi-Fi
```

For direct checks that avoid ambiguity about macOS resolver selection, query each server explicitly:

```bash
dig @10.7.30.234 app.teamX.test +noall +answer +ttlid
dig @10.7.13.67 app.teamX.test +noall +answer +ttlid
dig app.teamX.test
scutil --dns
```

The final `dig` uses the system resolver path. It may be affected by resolver ordering or cached data. The direct `@server` queries test the named resolver independently. Client DNS setup details are in [`Configuration_Bundle/client/CLIENT_DNS_SETUP.md`](Configuration_Bundle/client/CLIENT_DNS_SETUP.md).

### Start the Phase 2 services

The role-specific launch notes are in [`Configuration_Bundle/BACKEND_LAUNCH_INSTRUCTIONS.md`](Configuration_Bundle/BACKEND_LAUNCH_INSTRUCTIONS.md). In brief:

1. On Nishtha’s Mac, start primary dnsmasq with `brew services restart dnsmasq`, then start Backend A.
2. On Mishti’s Mac, start the backup resolver using its separate config:
   ```bash
   sudo "$(brew --prefix)/sbin/dnsmasq" --no-daemon --conf-file="$(brew --prefix)/etc/dnsmasq-backup.conf"
   ```
3. On Shrijan’s Mac, start Backend B.
4. On Aditya’s Mac, validate nginx with `nginx -t`, then start or restart it with `brew services restart nginx`.
5. Configure client DNS as described above, then verify name resolution and HTTPS.

To run a backend from the repository, use the matching directory and start command:

```bash
cd backends/backend-a && npm install && npm start
```

```bash
cd backends/backend-b && npm install && npm start
```

Direct health requests from the LAN should identify the expected backend:

```bash
curl -i http://10.7.30.234:3001/api/status
curl -i http://10.7.1.114:3002/api/status
```

### Verify the application path

Run these from a client configured to use the project DNS and trust the project certificate:

```bash
dig app.teamX.test +noall +answer +ttlid
curl -i https://app.teamX.test/api/status
curl -i https://api.teamX.test/api/status
```

The HTTPS response should have a successful HTTP status, an `X-Backend` value of `A` or `B`, and an `X-Edge` value identifying the serving nginx host. If a request fails, check the layers in order: DNS answer, TCP reachability to port 443, certificate/SAN validation, HTTP response, and backend availability.

### Certificate setup and trust

TLS notes and certificate commands are in [`Configuration_Bundle/tls/TLS_SETUP_NOTES.md`](Configuration_Bundle/tls/TLS_SETUP_NOTES.md). Generate or install the certificate and key on the edge and any standby edge, ensuring the certificate SAN covers both service names. Trust the certificate on each client Mac if the demo requires normal verification without a trust warning. Keep private key material out of the repository.

## Phase 2 extensions

Phase 2 operational helpers are grouped under `Helper_Scripts/Phase2/`. They are demonstrations and checks; they do not automatically stop remote services or silently alter network settings. DNS and firewall changes require explicit operator action.

### A. Backup DNS resolver

The primary config is [`Configuration_Bundle/dnsmasq/dnsmasq.conf`](Configuration_Bundle/dnsmasq/dnsmasq.conf); the backup config is [`Configuration_Bundle/dnsmasq/phase2-backup-dnsmasq.conf`](Configuration_Bundle/dnsmasq/phase2-backup-dnsmasq.conf). Both contain `app.teamX.test` and `api.teamX.test`, targeting the active edge and using a local TTL of 30 seconds.

Verify each resolver directly:

```bash
Helper_Scripts/Phase2/dns/test_primary_dns.sh
Helper_Scripts/Phase2/dns/test_backup_dns.sh
```

For a controlled primary outage demonstration, first record the baseline and then stop primary dnsmasq manually on Nishtha’s Mac:

```bash
Helper_Scripts/Phase2/dns/test_dns_failover.sh before
# Stop primary dnsmasq manually on Nishtha's Mac.
Helper_Scripts/Phase2/dns/test_dns_failover.sh after-primary-stop
```

The script tests both hostnames directly against the resolvers and reports the macOS system resolver view separately. It does not stop services. Two configured DNS addresses do not guarantee instantaneous macOS failover: resolver choice, cache state, and network behavior can affect the client result. Demonstrate backup resolver health independently from client-side behavior.

### B. DNS TTL and controlled record changes

The dnsmasq records use a 30-second local TTL. The TTL helper queries both names on both resolvers and compares direct answers with the system resolver view:

```bash
Helper_Scripts/Phase2/dns/test_dns_ttl.sh
```

To change records, run the helper with administrator privileges on each DNS Mac and pass that host’s active dnsmasq config path. The API address defaults to the new app address if omitted:

```bash
sudo Helper_Scripts/Phase2/dns/change_dns_record.sh /opt/homebrew/etc/dnsmasq.conf 10.7.13.91
```

The helper saves a validated `.phase2-original` copy before the first change, validates a candidate config, prompts for explicit confirmation, and replaces the active file atomically while preserving its owner and mode. It does not restart dnsmasq. For the backup resolver, use its separate `dnsmasq-backup.conf` path and restart its foreground process manually after the edit.

To compare the changed direct answers, specify the expected address:

```bash
Helper_Scripts/Phase2/dns/test_dns_ttl.sh 10.7.13.91
```

Direct DNS answers describe the server’s current record. A client may continue using a cached earlier answer until the TTL expires. The local system cache can be flushed deliberately with:

```bash
Helper_Scripts/Phase2/dns/flush_macos_dns_cache.sh
```

Restore each resolver’s saved full config on that resolver Mac, then restart its dnsmasq service/process and verify both names against both DNS servers:

```bash
sudo Helper_Scripts/Phase2/dns/restore_dns_record.sh /opt/homebrew/etc/dnsmasq.conf
```

The backup resolver uses its own config path. Restoration is local to the selected Mac; run it on both DNS hosts to restore the pair.

### C. Backend service isolation

`Helper_Scripts/Phase2/firewall/apply_backend_firewall.sh` generates macOS PF rules for Backend A or B from the shared Phase 2 settings. On `en0`, the rules allow the nginx edge and loopback to reach the selected backend port and block other inbound connections to that port. A standby edge is allowed only when an operator explicitly supplies a confirmed `STANDBY_EDGE_IP`.

Inspect candidate rules without applying them:

```bash
Helper_Scripts/Phase2/firewall/apply_backend_firewall.sh --dry-run A
Helper_Scripts/Phase2/firewall/apply_backend_firewall.sh --dry-run B
```

Applying requires administrator privileges and typing `YES`. The script checks for the existing `teamphase2` anchor hook in `/etc/pf.conf`, backs up only the anchor file, and loads only that anchor. It does not rewrite or reload the base PF config. Run the matching role on its corresponding backend Mac, after reviewing the dry run. Do not apply both roles on one Mac:

```bash
# On Nishtha's Mac (Backend A):
Helper_Scripts/Phase2/firewall/apply_backend_firewall.sh --dry-run A
Helper_Scripts/Phase2/firewall/apply_backend_firewall.sh A

# On Shrijan's Mac (Backend B):
Helper_Scripts/Phase2/firewall/apply_backend_firewall.sh --dry-run B
Helper_Scripts/Phase2/firewall/apply_backend_firewall.sh B
```

The installer prints the anchor backup path and rollback command. The rollback helper restores the saved anchor; if both backend rules were installed, roll them back in reverse application order.

Verify from the edge first, then from a separate client Mac:

```bash
Helper_Scripts/Phase2/firewall/verify_backend_isolation.sh edge
Helper_Scripts/Phase2/firewall/verify_backend_isolation.sh client
```

Expected results are edge-to-A `3001` and edge-to-B `3002` allowed, with client-to-backend service connections blocked. Use the helper’s printed rollback command and saved anchor path to revert the rule change.

### D. Backend high availability

The active nginx upstream retains both current backends and uses passive upstream failure parameters and retry directives. The test helper checks backend health, then sends repeated HTTPS requests and reports the `X-Backend`, `X-Edge`, and HTTP status for each response. Set the number of requests with `COUNT` if desired:

```bash
Helper_Scripts/Phase2/ha/check_backend_health.sh
COUNT=20 Helper_Scripts/Phase2/ha/test_backend_failover.sh
```

Run the script once while both services are healthy. Stop Backend A manually on Nishtha’s Mac; run the test again and confirm successful responses come from Backend B. Restart Backend A manually and repeat the test to observe recovery and resumed balancing. The script never stops or restarts a remote process. This is request-driven passive failure detection, not continuous active health checking.

### E. Controlled standby-edge migration

`Configuration_Bundle/nginx/standby-edge.conf` provides the standby virtual servers and backend upstreams. The standby address is not assigned by default: confirm the standby Mac’s actual address, assign it to `STANDBY_EDGE_IP`, and use that same address for validation and DNS changes. Do not assume an address in advance.

Before cutover, the standby Mac must have nginx, a certificate/key pair valid for both names, and connectivity to both backends. Set `STANDBY_EDGE_IP` in the standby Mac's shell to the IPv4 address actually assigned to that Mac. Validate the standby configuration, certificate names and key match, current DNS answers, backend reachability, and pinned TLS requests:

```bash
Helper_Scripts/Phase2/edge-migration/validate_standby_edge.sh
```

After validation, change both records on each DNS Mac using its own config path and the controlled DNS change helper described in extension B. Restart each resolver manually. Run the cutover check from the standby Mac, with the same `STANDBY_EDGE_IP` still set:

```bash
Helper_Scripts/Phase2/edge-migration/test_edge_cutover.sh
```

This checks both names on both resolvers and TLS-validated requests pinned to the standby. Some clients can continue using the old edge address while their prior DNS answer is cached. Migration is an operator-controlled DNS cutover, not automatic edge failover, and it does not remove every single point of failure.

To roll back, restore the saved DNS config independently on the two resolver Macs. Run the matching command on each host:

```bash
# On Nishtha's primary DNS Mac:
Helper_Scripts/Phase2/edge-migration/rollback_edge_migration.sh restore primary /opt/homebrew/etc/dnsmasq.conf

# On Mishti's backup DNS Mac:
Helper_Scripts/Phase2/edge-migration/rollback_edge_migration.sh restore backup /opt/homebrew/etc/dnsmasq-backup.conf
```

Restart both resolver services/processes manually. From a host that can reach both resolvers, verify the restored records:

```bash
Helper_Scripts/Phase2/edge-migration/rollback_edge_migration.sh verify
```

The verify mode reports rollback as complete only when both names on both resolvers return the original Phase 2 edge address.

## Phase 1: original implementation

Phase 1 is the historical baseline preserved in the repository. Its addresses below must not be used for the current Phase 2 deployment.

### Phase 1 machine roles

| Team member | Phase 1 role | Historical address | Service |
|---|---|---:|---|
| Mishti | Primary/private DNS | Not recorded in available evidence | dnsmasq on 53 |
| Aditya | nginx edge | `10.7.28.24` | nginx; HTTPS on 443 |
| Nishtha | Backend A | `10.7.9.8` | Express on 3001 |
| Shrijan | Backend B | `10.7.11.140` | Express on 3002 |

The original Phase 1 DNS records mapped `app.teamX.test` and `api.teamX.test` to the Phase 1 edge, `10.7.28.24`. The Phase 1 DNS server’s own IP was not captured in the available evidence, so no address or direct-server command is inferred here.

### Phase 1 architecture and features

The original Phase 1 path was:

```text
Client
  │  DNS lookup for app.teamX.test or api.teamX.test
  ▼
Private dnsmasq resolver (IP not recorded in available evidence)
  │  both names resolved to 10.7.28.24
  ▼
nginx edge (10.7.28.24:443)
  │  TLS termination, reverse proxy, load balancing
  ├──────────────────────────┐
  ▼                          ▼
Backend A                    Backend B
10.7.9.8:3001                10.7.11.140:3002
```

Phase 1 used the same logical application path as Phase 2. It established the initial private DNS, HTTPS edge, and two-backend service before Phase 2 changed the IP allocation and added redundancy and controlled resilience demonstrations. Its implemented features included:

- Private LAN connectivity across four macOS machines.
- dnsmasq private DNS records for the application names.
- Backend A and Backend B on ports 3001 and 3002.
- nginx reverse proxy and load balancing.
- TLS termination at nginx with a self-signed certificate.
- Backend identification through `X-Backend` and edge identification through `X-Edge`.
- Express ETag generation and `Cache-Control: max-age=60`.
- Phase 1 helper scripts and Wireshark packet evidence.

### Phase 1 backend and edge checks

The following commands describe the historical allocation only. They are included to explain Phase 1 evidence and are not current Phase 2 test commands:

```bash
curl http://10.7.9.8:3001/api/status
curl http://10.7.11.140:3002/api/status
```

The old edge address was `10.7.28.24`; the original DNS server address is unavailable, so a Phase 1 direct DNS query by server IP cannot be reproduced from the repository evidence.

### DNS, TLS, caching, and packet analysis

The original Phase 1 project used dnsmasq to resolve the private service names, nginx to terminate TLS and proxy HTTP traffic, and Wireshark to inspect DNS, TCP, and TLS traffic. The DNS, TCP/TLS, and application response evidence is preserved in `Phase1Evidence_Document.pdf`, `terminals/`, `screenshots/`, and `wireshark/`. HTTPS packet captures show handshake metadata and encrypted application data; HTTP response headers such as `X-Backend` provide application-layer evidence of backend selection.

The self-signed certificate requires client trust for normal certificate validation. The caching helper sends a conditional request using `If-None-Match`; whether it receives `304 Not Modified` depends on whether the request reaches the backend that generated the matching ETag. Separate backend instances can generate different ETags.

## Helper scripts

### Phase 1 scripts

| Script | Purpose |
|---|---|
| `Helper_Scripts/test_roundrobin.sh` | Sends repeated HTTPS requests and displays backend identity headers. |
| `Helper_Scripts/test_caching.sh` | Observes ETag and conditional HTTP request behavior. |
| `Helper_Scripts/test_dns_and_ports.sh` | Checks current Phase 2 DNS, TCP ports, and HTTPS path; its endpoints use current Phase 2 addresses. |

### Phase 2 scripts

| Directory | Scripts and purpose |
|---|---|
| `Helper_Scripts/Phase2/dns/` | Check primary/backup DNS, observe resolver behavior during a manually stopped primary, inspect TTL, change/restore records, and flush the local macOS DNS cache. |
| `Helper_Scripts/Phase2/firewall/` | Dry-run/apply backend PF rules, verify connectivity from edge/client roles, and roll back the team anchor. |
| `Helper_Scripts/Phase2/ha/` | Check both backend services and exercise nginx backend failover/recovery with repeated requests. |
| `Helper_Scripts/Phase2/edge-migration/` | Validate standby nginx/TLS/backend readiness, verify cutover, and restore/verify original DNS answers. |

Use the scripts from the repository root unless a script’s usage text says otherwise. The scripts do not substitute for live demonstration on the team LAN.

## Evidence and repository map

The repository retains Phase 1 implementation evidence and adds current configuration and Phase 2 helpers:

```text
TeamSubnetCN/
├── README.md
├── Configuration_Bundle/
│   ├── BACKEND_LAUNCH_INSTRUCTIONS.md
│   ├── client/CLIENT_DNS_SETUP.md
│   ├── dnsmasq/
│   │   ├── dnsmasq.conf
│   │   └── phase2-backup-dnsmasq.conf
│   ├── nginx/
│   │   ├── teamx.conf
│   │   ├── phase2-ha.conf
│   │   └── standby-edge.conf
│   └── tls/TLS_SETUP_NOTES.md
├── Helper_Scripts/
│   ├── test_caching.sh
│   ├── test_dns_and_ports.sh
│   ├── test_roundrobin.sh
│   └── Phase2/
│       ├── config.sh
│       ├── dns/
│       ├── firewall/
│       ├── ha/
│       └── edge-migration/
├── backends/
│   ├── backend-a/
│   └── backend-b/
├── architecture/
├── screenshots/
├── terminals/
├── wireshark/
├── Phase1Evidence_Document.pdf
└── README.md
```

The Phase 1 PDF, terminal output, screenshots, architecture images, and Wireshark captures remain historical evidence. They do not imply that the old addresses are active in Phase 2.

## Known limits

- The Phase 1 primary DNS address is absent from available evidence.
- macOS resolver selection and caching do not guarantee immediate DNS failover when one server stops.
- DNS record edits affect authoritative/local dnsmasq data first; client caches may retain older answers until expiry or deliberate flush.
- PF enforcement, DNS failover, backend outage/recovery, and edge migration require manual tests on the assigned Macs. Static checks do not establish live LAN behavior.
- Standby edge IP and local certificate/key installation must be confirmed on the standby Mac before migration.
- nginx upstream failure handling is passive; this repository does not configure continuous active health checks.
- The normal architecture depends on the original edge. DNS-controlled standby migration can redirect clients after a controlled change and cache expiry, but it is not instantaneous automatic failover.

## Project objective

> **The application stays simple. The network is the project.**

The project demonstrates how private name resolution, IP addressing, TCP, TLS, reverse proxying, backend selection, caching, and controlled resilience mechanisms combine to deliver one HTTPS response.
