# TeamSubnetCN

## Computer Networks Course Project — Phase 1

A private network service platform built using four macOS laptops connected over the same LAN.

The project focuses on the networking path of a client request:

**DNS → TCP → TLS → HTTPS → nginx Reverse Proxy → Load Balancing → Backend**

The application layer is intentionally minimal. The main objective is to demonstrate practical concepts from Computer Networks including private DNS, TCP connectivity, TLS, HTTPS, reverse proxying, load balancing, HTTP caching, and packet analysis using Wireshark.

---

## Team Members and Machine Roles

| Team Member | Machine Role | Private IP | Interface |
|---|---|---:|---|
| Nishtha Gupta | Backend A | `10.7.9.8` | `en0` |
| Aditya | Edge / nginx / Load Balancer | `10.7.28.24` | `en0` |
| Shrijan | Backend B | `10.7.11.140` | `en0` |
| Mishti | Private DNS Server | `10.7.30.18` | `en0` |

### Common Network Configuration

```text
Network:        10.7.0.0/19
Subnet Mask:    255.255.224.0
Gateway:        10.7.0.1
DNS Server:     10.7.30.18
Domain:         app.teamX.test
```

The project uses the reserved `.test` domain for the private network environment.

---

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
10.7.30.18
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
IP:        10.7.30.18
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

Example response from `/api/status`:

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

Example response from `/api/status`:

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
   10.7.30.18              10.7.28.24             10.7.9.8
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
2. DNS query is sent to 10.7.30.18
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

The private DNS server runs dnsmasq on:

```text
10.7.30.18
```

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

To explicitly query the project DNS server:

```bash
dig @10.7.30.18 app.teamX.test
```

The DNS server should appear as:

```text
SERVER: 10.7.30.18#53
```

### Configure a client Mac to use the project DNS

```bash
sudo networksetup -setdnsservers Wi-Fi 10.7.30.18
sudo dscacheutil -flushcache
sudo killall -HUP mDNSResponder
```

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

Example responses:

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

Example headers include:

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
10.7.30.18
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
ping -c 4 10.7.30.18
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
10.7.30.18
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
10.7.30.18
```

Then verify:

```bash
dig @10.7.30.18 app.teamX.test
```

### 6. Test the complete path

```bash
curl -v https://app.teamX.test/api/status
```

---

# 16. Repository Structure

The repository is organised as follows:

```text
TeamSubnetCN-main/
│
├── README.md
│
├── Configuration_Bundle/
│   ├── BACKEND_LAUNCH_INSTRUCTIONS.md
│   │
│   ├── client/
│   │   └── CLIENT_DNS_SETUP.md
│   │
│   ├── dnsmasq/
│   │   └── dnsmasq.conf
│   │
│   ├── nginx/
│   │   └── teamx.conf
│   │
│   └── tls/
│       └── TLS_SETUP_NOTES.md
│
├── Helper_Scripts/
│   ├── test_caching.sh
│   ├── test_dns_and_ports.sh
│   └── test_roundrobin.sh
│
├── backends/
│   ├── backend-a/
│   │   ├── backend-A.js
│   │   ├── package.json
│   │   └── package-lock.json
│   │
│   └── backend-b/
│       ├── backend-B.js
│       ├── package.json
│       └── package-lock.json
│
├── architecture/
│   └── network topology images
│
├── wireshark/
│   ├── phase1_wireshark_dns_tcp_tls.pcapng
│   ├── dns.png
│   └── packet-analysis screenshots
│
├── screenshots/
│   └── terminal/evidence screenshots
│
├── terminals/
│   └── saved terminal outputs
│
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

# 19. Learning Objectives

This Phase 1 project demonstrates practical understanding of:

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

# 20. Core Principle

> **The application stays simple. The network is the project.**

The main objective is to understand what happens to a request from the moment a private domain is resolved until the final HTTPS response is returned through the network.
