# TeamSubnetCN

## Computer Networks Course Project — Phase 1 and Phase 2

**Private Network Service Platform** built across four macOS laptops on a private LAN. Phase 1 established private DNS, two Express backends, an nginx HTTPS edge, load balancing, caching, and packet analysis. Phase 2 adds a backup DNS resolver, controlled DNS changes, backend isolation, backend failover, standby-edge migration.

## Current deployment — Phase 2

Use these addresses for the running Phase 2 network and all current configuration. Primary DNS and Backend A intentionally share Nishtha’s Mac; they are separate services on the same host.

| Team member | Current role | Phase 2 IP | Service |
|---|---|---:|---|
| Nishtha | Primary DNS + Backend A | `10.7.30.234` | dnsmasq `53`, Express `3001` |
| Mishti | Backup DNS | `10.7.13.67` | dnsmasq `53` |
| Aditya | nginx edge | `10.7.13.91` | nginx `80`, `443` |
| Shrijan | Backend B | `10.7.1.114` | Express `3002` |

The private service names `app.teamX.test` and `api.teamX.test` both resolve to the current edge, `10.7.13.91`. The request path is:

```text
Client → primary or backup DNS → nginx edge → Backend A or Backend B
```

### Phase 1 to Phase 2 IP change

| Role | Phase 1 original allocation | Phase 2 current allocation |
|---|---:|---:|
| Backend A | `10.7.9.8` | `10.7.30.234` |
| nginx edge | `10.7.28.24` | `10.7.13.91` |
| Backend B | `10.7.11.140` | `10.7.1.114` |
| Primary DNS | not recorded in the available Phase 1 evidence | `10.7.30.234` |
| Backup DNS | Not present in Phase 1 | `10.7.13.67` |

**Do not use the Phase 1 addresses for current service configuration.** The Phase 1 DNS address was not recorded in the available evidence; no address is inferred for it. Historical Phase 1 material below is labeled as such. Phase 2 configuration and scripts live in `Configuration_Bundle/` and `Helper_Scripts/Phase2/`.

---

## Phase 1 — Original implementation (historical)

The following numbered chapters document the original Phase 1 build. Their Backend A, edge, and Backend B addresses are historical and have been superseded by the Phase 2 allocation above. The Phase 1 DNS IP was not captured in the available evidence and is not invented below.

# 1. Project Overview

The system is deployed locally across four macOS machines. No cloud server is required.

A client accesses the service through:

```text
https://app.teamX.test
```

The domain resolves to the nginx edge machine rather than directly to either backend.

The complete request path is:

```text
Client
   |
   | DNS Query
   v
Private DNS Server
Phase 1 address not recorded
   |
   | app.teamX.test → 10.7.28.24
   v
nginx Edge
10.7.28.24
   |
   | HTTPS / TLS termination
   |
   +-------------------------+
   |                         |
   v                         v
Backend A                 Backend B
10.7.9.8:3001             10.7.11.140:3002
```

nginx acts as the single entry point and distributes requests between Backend A and Backend B.

---

# 2. Technologies Used

- macOS
- Homebrew
- dnsmasq
- nginx
- Node.js
- Express
- OpenSSL
- curl
- dig / nslookup
- netcat (`nc`)
- Wireshark
- TCP/IP
- HTTP/1.1
- HTTPS
- TLS

---

# 3. Machine Roles

## Mac 1 — Private DNS Server

**Team Member:** Mishti

```text
IP:        not recorded in available Phase 1 evidence
Interface: en0
Service:   dnsmasq
Port:      53
```

dnsmasq provides private DNS resolution for the project domains.

Configured records:

```text
app.teamX.test → 10.7.28.24
api.teamX.test → 10.7.28.24
```

Both names point to the nginx edge because nginx is the public entry point of the private application.

---

## Mac 2 — Edge / Reverse Proxy / Load Balancer

**Team Member:** Aditya

```text
IP:        10.7.28.24
Interface: en0
Service:   nginx
```

The edge machine is responsible for:

- Accepting client connections
- Redirecting HTTP to HTTPS
- TLS termination
- Reverse proxying
- Load balancing
- Forwarding requests to Backend A or Backend B
- Adding the `X-Edge: mac2` response header

The HTTPS endpoint is:

```text
https://app.teamX.test
```

nginx forwards requests to:

```text
Backend A → 10.7.9.8:3001
Backend B → 10.7.11.140:3002
```

The configuration also allows nginx to retry another upstream when the configured upstream failure conditions occur.

---

## Mac 3 — Backend A

**Team Member:** Nishtha Gupta

```text
IP:        10.7.9.8
Interface: en0
Port:      3001
Service:   Node.js + Express
```

Backend A listens on:

```text
0.0.0.0:3001
```

Endpoints:

```text
GET /
GET /api/status
```

Backend A returns this JSON body from `/api/status`:

```json
{
  "backend": "A",
  "status": "ok"
}
```

The endpoint also returns:

```text
X-Backend: A
Cache-Control: max-age=60
```

Express generates an `ETag` response header for the JSON response.

---

## Mac 4 — Backend B

**Team Member:** Shrijan

```text
IP:        10.7.11.140
Interface: en0
Port:      3002
Service:   Node.js + Express
```

Backend B listens on:

```text
0.0.0.0:3002
```

Endpoints:

```text
GET /
GET /api/status
```

Backend B returns this JSON body from `/api/status`:

```json
{
  "backend": "B",
  "status": "ok"
}
```

The endpoint also returns:

```text
X-Backend: B
Cache-Control: max-age=60
```

Express generates an `ETag` response header for the JSON response.

---

# 4. Network Architecture

```text
                         PRIVATE LAN
                         10.7.0.0/19
                              |
        +---------------------+---------------------+
        |                     |                     |
        v                     v                     v
   Mishti                  Aditya                Nishtha
   DNS Server              nginx Edge             Backend A
   DNS IP not recorded       10.7.28.24             10.7.9.8
   dnsmasq :53             HTTPS :443             HTTP :3001
        |                     |
        |                     |
        |                     +----------+
        |                                |
        |                                v
        |                             Shrijan
        |                             Backend B
        |                             10.7.11.140
        |                             HTTP :3002
        |
        +---- app.teamX.test
              api.teamX.test
                    |
                    +----> 10.7.28.24
```

---

# 5. End-to-End Request Flow

A normal request follows these stages:

```text
1. Client requests app.teamX.test
                |
                v
2. DNS query is sent to the Phase 1 resolver (address not recorded)
                |
                v
3. DNS returns 10.7.28.24
                |
                v
4. Client establishes TCP connection to port 443
                |
                v
5. TLS handshake takes place
                |
                v
6. HTTPS request reaches nginx
                |
                v
7. nginx selects an upstream backend
                |
                v
8. Backend A or Backend B processes the request
                |
                v
9. nginx returns the HTTPS response to the client
```

This allows the project to demonstrate multiple layers of the network stack using one end-to-end request.

---

# 6. Private DNS Configuration

The Phase 1 DNS host ran dnsmasq on port 53. Its IP address was not recorded in the available evidence.

The configuration is stored in:

```text
Configuration_Bundle/dnsmasq/dnsmasq.conf
```

The relevant records are:

```text
app.teamX.test → 10.7.28.24
api.teamX.test → 10.7.28.24
```

### Verify DNS

```bash
dig app.teamX.test
```

Expected result:

```text
app.teamX.test.    A    10.7.28.24
```

The Phase 1 resolver address was not recorded, so a historical direct `dig @server` command cannot be supplied. Current Phase 2 direct queries use the resolver addresses in `Helper_Scripts/Phase2/config.sh`.

### Configure a client Mac to use the project DNS

The original Phase 1 client resolver address is unavailable in the evidence. For the current Phase 2 client DNS setup, follow `Configuration_Bundle/client/CLIENT_DNS_SETUP.md`. macOS cache flush commands are documented there and in the Phase 2 DNS helper.

Verify:

```bash
networksetup -getdnsservers Wi-Fi
```

---

# 7. Backend Services

Both backend services use Node.js and Express and bind to `0.0.0.0`, allowing the nginx machine to reach them over the LAN.

## Backend A

Source:

```text
backends/backend-a/backend-A.js
```

Run:

```bash
cd backends/backend-a
npm install
npm start
```

Expected output:

```text
Backend A listening on 0.0.0.0:3001
```

Test locally or from another machine:

```bash
curl http://10.7.9.8:3001
curl http://10.7.9.8:3001/api/status
```

---

## Backend B

Source:

```text
backends/backend-b/backend-B.js
```

Run:

```bash
cd backends/backend-b
npm install
npm start
```

Expected output:

```text
Backend B listening on 0.0.0.0:3002
```

Test locally or from another machine:

```bash
curl http://10.7.11.140:3002
curl http://10.7.11.140:3002/api/status
```

---

# 8. nginx Reverse Proxy and Load Balancing

The nginx configuration used for the project is:

```text
Configuration_Bundle/nginx/teamx.conf
```

The upstream pool contains:

```text
10.7.9.8:3001
10.7.11.140:3002
```

The HTTPS server listens for:

```text
app.teamX.test
api.teamX.test
```

HTTP requests are redirected to HTTPS:

```text
http://app.teamX.test
        ↓
https://app.teamX.test
```

The reverse proxy forwards the request to the configured backend pool.

### Validate nginx configuration

```bash
nginx -t
```

### Reload nginx

```bash
nginx -s reload
```

or, when managed through Homebrew:

```bash
brew services restart nginx
```

---

# 9. Demonstrating Load Balancing

The backends identify themselves using the `X-Backend` header.

Requests handled by Backend A or Backend B return the corresponding `X-Backend` value:

```text
X-Backend: A
```

and:

```text
X-Backend: B
```

Repeated requests through the edge can therefore be used to observe which backend handled each request.

The repository contains:

```text
Helper_Scripts/test_roundrobin.sh
```

Run:

```bash
bash Helper_Scripts/test_roundrobin.sh
```

The script sends multiple requests and prints the `X-Backend` header.

A typical result may contain:

```text
X-Backend: A
X-Backend: B
X-Backend: A
X-Backend: B
```

The exact order is determined by nginx's upstream selection and connection/request behaviour.

---

# 10. HTTPS and TLS

TLS is terminated at the nginx edge.

The service is accessed through:

```text
https://app.teamX.test
```

The TLS configuration is documented in:

```text
Configuration_Bundle/tls/TLS_SETUP_NOTES.md
```

The project uses a self-signed certificate containing SAN entries for:

```text
app.teamX.test
api.teamX.test
```

Configured TLS versions:

```text
TLSv1.2
TLSv1.3
```

The certificate must be trusted on client machines if certificate validation is expected to succeed without `-k`.

### Verify the certificate

```bash
security verify-cert \
  -c ~/Downloads/edge.crt \
  -p ssl \
  -s app.teamX.test
```

### Test HTTPS

```bash
curl -v https://app.teamX.test/api/status
```

The demonstration should use normal certificate validation.

Do not use:

```bash
curl -k
```

because that bypasses certificate verification.

---

# 11. HTTP Caching and ETag

The `/api/status` endpoint returns:

```text
Cache-Control: max-age=60
```

Express also generates an `ETag` for the JSON response.

For this JSON response, Express sends `Cache-Control: max-age=60` and generates a weak ETag whose value depends on the response body:

```text
Cache-Control: max-age=60
ETag: W/"..."
```

The repository contains:

```text
Helper_Scripts/test_caching.sh
```

Run:

```bash
bash Helper_Scripts/test_caching.sh
```

The script:

1. Makes an initial request.
2. Reads the returned `ETag`.
3. Sends a conditional request using `If-None-Match`.

A `304 Not Modified` response can occur when the conditional request reaches the same backend and the representation matches.

Because Backend A and Backend B can generate different ETags for their responses, a conditional request that reaches the other backend can instead receive:

```text
200 OK
```

This is an expected consequence of having separate backend instances.

---

# 12. Layer-by-Layer Testing

The repository contains:

```text
Helper_Scripts/test_dns_and_ports.sh
```

The script checks:

```text
DNS
 ↓
TCP connectivity
 ↓
TLS / HTTPS
 ↓
HTTP response
```

Run:

```bash
bash Helper_Scripts/test_dns_and_ports.sh
```

It checks:

```text
app.teamX.test
api.teamX.test
10.7.28.24:443
10.7.9.8:3001
10.7.11.140:3002
```

It also inspects the HTTPS response for:

```text
X-Backend
```

and other connection/HTTP information.

---

# 13. Wireshark Packet Analysis

Wireshark is used to analyse the traffic generated by the system.

The repository contains the packet capture:

```text
wireshark/phase1_wireshark_dns_tcp_tls.pcapng
```

and supporting screenshots under:

```text
wireshark/
```

The packet analysis focuses on:

## DNS

The client sends a DNS query for:

```text
app.teamX.test
```

The private DNS server:

```text
not recorded in the available Phase 1 evidence
```

returns:

```text
10.7.28.24
```

## TCP

The TCP connection to the HTTPS edge demonstrates the three-way handshake:

```text
SYN
 ↓
SYN-ACK
 ↓
ACK
```

## TLS

The TLS handshake includes messages such as:

```text
ClientHello
ServerHello
Certificate
Finished
```

After the handshake, application data is encrypted.

## HTTPS

The HTTP request and response are carried inside the TLS connection and therefore appear as encrypted application data in the packet capture.

## Application-Level Backend Identification

The backend itself is identified at the HTTP layer through:

```text
X-Backend: A
```

or:

```text
X-Backend: B
```

The repository evidence combines packet-level observations with HTTP response headers to show the relationship between the network path and the selected backend.

---

# 14. Connectivity Verification

Before testing the complete application, basic LAN connectivity can be checked.

From a client:

```bash
# Historical DNS host address was not recorded; skip this Phase 1 ping.
ping -c 4 10.7.28.24
ping -c 4 10.7.9.8
ping -c 4 10.7.11.140
```

The backend ports can be checked using:

```bash
nc -vz 10.7.9.8 3001
nc -vz 10.7.11.140 3002
nc -vz 10.7.28.24 443
```

These checks help isolate whether a problem is related to:

```text
LAN connectivity
DNS
TCP port reachability
TLS
HTTP
Backend application
```

---

# 15. Recommended Startup Order

The complete system should be started in this order:

### 1. Private DNS — Mac 1

Start dnsmasq on:

```text
not recorded in the available Phase 1 evidence
```

### 2. Backend A — Mac 3

Start:

```text
10.7.9.8:3001
```

### 3. Backend B — Mac 4

Start:

```text
10.7.11.140:3002
```

### 4. nginx — Mac 2

Validate and start/reload nginx:

```bash
nginx -t
brew services restart nginx
```

### 5. Client DNS

Point the client to:

```text
The Phase 1 DNS address was not recorded in the available evidence; this historical setup cannot be replayed by IP.
```

This Phase 1 step cannot be replayed without the original resolver address. For the current system, use both Phase 2 resolver addresses in `Configuration_Bundle/client/CLIENT_DNS_SETUP.md`.

### 6. Test the complete path

```bash
curl -v https://app.teamX.test/api/status
```

---

# 16. Repository Structure

The repository is organised as follows:

```text
TeamSubnetCN-main/
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
│   ├── test_caching.sh                  # original Phase 1 check
│   ├── test_dns_and_ports.sh            # updated to current Phase 2 IPs
│   ├── test_roundrobin.sh               # original Phase 1 check
│   └── Phase2/
│       ├── config.sh
│       ├── dns/
│       ├── firewall/
│       ├── ha/
│       ├── edge-migration/
├── backends/
│   ├── backend-a/ (Express service, package.json, package-lock.json)
│   └── backend-b/ (Express service, package.json, package-lock.json)
├── architecture/
├── screenshots/
├── terminals/
├── wireshark/
└── Phase1Evidence_Document.pdf
```

---

# 17. Phase 1 Evidence

The repository includes evidence for the implemented Phase 1 system.

The main evidence document is:

```text
Phase1Evidence_Document.pdf
```

Additional supporting material is available under:

```text
screenshots/
terminals/
wireshark/
architecture/
```

The evidence covers the implemented networking components, including:

- Machine IP configuration
- LAN connectivity
- Backend A
- Backend B
- Private DNS
- nginx edge
- HTTPS
- TLS certificate validation
- Load balancing
- HTTP response headers
- Caching / ETag behaviour
- Wireshark packet analysis

---

# 18. Important Notes

### Private network only

The project is designed to run across the team's local LAN. The private IP addresses and services are not intended to represent publicly hosted infrastructure.

### DNS is intentionally private

`app.teamX.test` and `api.teamX.test` are resolved by the team's dnsmasq server rather than public DNS.

### TLS uses a self-signed certificate

The certificate is appropriate for the controlled project environment. It must be explicitly trusted on client machines for normal certificate validation.

### Backend application is intentionally simple

The purpose of the Node.js services is to make the networking behaviour observable. The primary focus is the network infrastructure rather than application complexity.

### Caching behaviour

`Cache-Control: max-age=60` is set by the backend. ETag generation is handled by Express. The caching test is therefore dependent on which backend receives the conditional request.

---

# 19. Phase 1 Learning Objectives

The Phase 1 implementation demonstrates practical understanding of:

- Private DNS and name resolution
- IP addressing and subnetting
- TCP connectivity and ports
- TCP three-way handshake
- HTTP/1.1
- HTTPS
- TLS handshake and certificate validation
- Reverse proxies
- Load balancing
- HTTP caching
- ETag and conditional requests
- Network packet analysis
- Layer-by-layer troubleshooting
- Client-to-server request flow

---

# 20. Core Principle — Both Phases

> **The application stays simple. The network is the project.**

The main objective is to understand what happens to a request from the moment a private domain is resolved until the final HTTPS response is returned through the network.


# Phase 2 — Resilience, isolation, and controlled migration

Phase 2 keeps the Phase 1 service and application architecture while using the updated addresses shown at the top of this README. Primary DNS and Backend A intentionally run on the same Mac (`10.7.30.234`); DNS listens on port 53 and Backend A listens on port 3001.

## Phase 2 extensions

### A. Backup DNS resolver

`Configuration_Bundle/dnsmasq/phase2-backup-dnsmasq.conf` is for the backup resolver at `10.7.13.67`. It contains the same `app.teamX.test` and `api.teamX.test` records as the primary config, both pointing to the current edge at `10.7.13.91`. Both configs use a 30-second local TTL. Client setup lists primary and backup resolver addresses, but macOS resolver selection is not guaranteed to switch immediately. A DNS service failure can prevent name resolution while IP connectivity still works; a backend application failure leaves DNS resolution working but can produce an upstream error at nginx. Query each resolver directly to demonstrate it independently:

```bash
dig @10.7.30.234 app.teamX.test +noall +answer +ttlid
dig @10.7.13.67 app.teamX.test +noall +answer +ttlid
```

Run `Helper_Scripts/Phase2/dns/test_primary_dns.sh` and `test_backup_dns.sh` to verify both names against each resolver. `test_dns_failover.sh before` records the healthy baseline. Stop primary dnsmasq manually on Nishtha’s Mac, then run `test_dns_failover.sh after-primary-stop`; it verifies the backup directly and prints the macOS resolver view. The helper never stops services. A system answer may still be cached or may reflect macOS resolver selection, so direct backup success and system resolver behavior are reported separately.

### B. TTL and controlled DNS changes

Run `sudo Helper_Scripts/Phase2/dns/change_dns_record.sh DNSMASQ_CONFIG NEW_APP_IP [NEW_API_IP]` on each resolver Mac. It captures direct answers before the change, updates both application records (the API IP defaults to the app IP), validates the new dnsmasq file, and asks for explicit confirmation before writing. Restart dnsmasq manually, then query both resolvers with `test_dns_ttl.sh`; direct server answers update before client caches do. `dscacheutil` output is shown separately because it may remain cached. `flush_macos_dns_cache.sh` requests a local cache flush after explicit confirmation. `sudo Helper_Scripts/Phase2/dns/restore_dns_record.sh DNSMASQ_CONFIG` restores the saved full configuration, including both records; run it on both DNS Macs to roll back the demonstration. The evidenced Homebrew config paths are `/opt/homebrew/etc/dnsmasq.conf` on primary DNS and `/opt/homebrew/etc/dnsmasq-backup.conf` on backup DNS; the backup resolver was run with its separate `--conf-file` process.

### C. Backend service isolation

The parameterized apply script generates PF rules from the shared configuration and restricts ports 3001 and 3002 to the edge (`10.7.13.91`) while retaining loopback access. The apply script has a `--dry-run` mode, requires typing `YES`, backs up the existing `teamphase2` anchor, and loads only that anchor. It reads `/etc/pf.conf` to confirm the existing anchor hook and does not modify or back up the base configuration. It stops if the expected hook is missing. If PF was disabled, it records its own enable reference so rollback can release only that reference. If standby migration is being prepared, set the confirmed `STANDBY_EDGE_IP` when applying rules on both backend hosts so the temporary standby can reach the services. For the isolation check, first run `verify_backend_isolation.sh edge` and confirm both ports are reachable, then run it from a separate client and confirm both are blocked. Restore the saved anchor backup after the demonstration; when both backend rules were installed, roll back in reverse order.

### D. Backend high availability

The nginx upstream in `Configuration_Bundle/nginx/teamx.conf` uses Backend A `10.7.30.234:3001` and Backend B `10.7.1.114:3002`, with `max_fails=1`, `fail_timeout=10s`, proxy timeouts, and `proxy_next_upstream` retries. This is **passive failure detection based on requests**, not continuous active health checking. `Helper_Scripts/Phase2/ha/test_backend_failover.sh` displays `X-Backend` and `X-Edge` for repeated requests. Stop and restart a backend manually on its Mac; the script does not terminate a remote process.

### E. Standby edge migration

`Configuration_Bundle/nginx/standby-edge.conf` provides a separate nginx configuration using the Phase 2 backend upstreams. Set `STANDBY_EDGE_IP` only after confirming the standby Mac address. Install the existing certificate and key securely; private key material is not committed. On the standby Mac, set `STANDBY_EDGE_IP` to its confirmed interface address and run `validate_standby_edge.sh "$STANDBY_EDGE_IP"` before changing DNS. It validates nginx syntax, certificate SANs and key match, backend reachability, current DNS answers, and HTTPS requests pinned to the standby while checking the certificate. Then, on each DNS Mac, run `sudo Helper_Scripts/Phase2/dns/change_dns_record.sh /opt/homebrew/etc/dnsmasq.conf "$STANDBY_EDGE_IP"` for primary or `sudo Helper_Scripts/Phase2/dns/change_dns_record.sh /opt/homebrew/etc/dnsmasq-backup.conf "$STANDBY_EDGE_IP"` for backup; this changes both `app` and `api` records after confirmation. Restart primary with `sudo brew services restart dnsmasq`; restart the separately launched backup dnsmasq process using its `--conf-file` command. Run the cutover verification on the standby Mac. Run `test_edge_cutover.sh "$STANDBY_EDGE_IP"` to verify both records on both resolvers and TLS-validated HTTPS for both hostnames. Cached clients may continue reaching the old edge until their TTL expires. Roll back on each DNS Mac with `Helper_Scripts/Phase2/edge-migration/rollback_edge_migration.sh restore primary /opt/homebrew/etc/dnsmasq.conf` on the primary Mac and `Helper_Scripts/Phase2/edge-migration/rollback_edge_migration.sh restore backup /opt/homebrew/etc/dnsmasq-backup.conf` on the backup Mac, then restart both resolvers manually and run `Helper_Scripts/Phase2/edge-migration/rollback_edge_migration.sh verify` to confirm both names on both servers return the original Phase 2 edge. This is a controlled DNS migration, not automatic edge failover, and it does not eliminate every single point of failure.

## Phase 2 helper toolkit

```text
Helper_Scripts/Phase2/
├── config.sh                 # shared current IPs, ports, names, and TLS paths
├── dns/                      # resolver checks, TTL, controlled change/restore, cache flush
├── firewall/                 # PF apply, verify, and rollback
├── ha/                       # backend health and failover demonstration
└── edge-migration/           # standby validation, cutover, and rollback
```

The current Phase 2 addresses are centralized for scripts in `Helper_Scripts/Phase2/config.sh`. Nginx and dnsmasq configurations use their native static syntax and must be kept synchronized with that shared allocation when addresses change. The DNS, HTTPS, backend failover, PF isolation, and edge migration demonstrations must be run on the team Macs; a successful syntax check alone does not demonstrate LAN failover.
