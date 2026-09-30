# TeamSubnetCN
# Private Network Service Platform

## Computer Networks Course Project

A fully local private network service platform built using four macOS laptops connected to the same private LAN.

The project demonstrates how a network request travels through:

**DNS → TCP → TLS → HTTPS → nginx Reverse Proxy → Load Balancer → Backend Server**

The application layer is intentionally simple. The primary focus of the project is the networking infrastructure, protocol behaviour, packet analysis, load balancing, and controlled failure handling.

---

## Team Members

| Member        | Machine Role                         | Private IP    | Interface |
| ------------- | ------------------------------------ | ------------- | --------- |
| Nishtha Gupta | Backend A                            | `10.7.9.8`    | `en0`     |
| Aditya        | Edge / Reverse Proxy / Load Balancer | `10.7.28.24`  | `en0`     |
| Shrijan       | Backend B                            | `10.7.11.140` | `en0`     |
| Mishti        | Private DNS Server                   | `10.7.30.18`  | `en0`     |

### Common Network Configuration

* Network: `10.7.0.0/19`
* Subnet Mask: `255.255.224.0`
* Default Gateway: `10.7.0.1`
* Private DNS Server: `10.7.30.18`
* Private Domain: `app.teamX.test`

---

# 1. Project Overview

The project implements a private service environment without cloud hosting or dedicated servers.

A client accesses the service using a private `.test` domain:

```text
https://app.teamX.test
```

The request flow is:

```text
Client
   |
   | DNS Query
   v
Private DNS Server
10.7.30.18
   |
   | Resolves app.teamX.test
   v
nginx Edge / Reverse Proxy
10.7.28.24
   |
   | HTTPS / TLS Termination
   |
   +----------------------+
   |                      |
   v                      v
Backend A              Backend B
10.7.9.8:3001          10.7.11.140:3002
```

The nginx edge distributes requests between Backend A and Backend B using load balancing.

---

# 2. Technologies Used

* macOS
* Homebrew
* dnsmasq
* nginx
* Node.js
* Express
* OpenSSL
* curl
* dig / nslookup
* Wireshark
* TCP/IP
* HTTP/1.1
* HTTPS
* TLS

The complete running system is deployed locally on the team's macOS machines.

---

# 3. Machine Roles

## Mac 1 — Private DNS Server

**Team Member:** Mishti

**IP Address:**

```text
10.7.30.18
```

**Interface:**

```text
en0
```

**Service:**

```text
dnsmasq
```

The DNS machine provides private DNS resolution for the project domain.

The DNS records point the application domain to the nginx edge machine.

```text
app.teamX.test → 10.7.28.24
api.teamX.test → 10.7.28.24
```

---

## Mac 2 — Edge / Reverse Proxy / Load Balancer

**Team Member:** Aditya

**IP Address:**

```text
10.7.28.24
```

**Interface:**

```text
en0
```

**Service:**

```text
nginx
```

The edge machine acts as the single entry point for clients.

Responsibilities:

* Reverse proxy
* HTTPS termination
* TLS certificate handling
* Load balancing
* Routing requests to Backend A and Backend B

Clients access the service using:

```text
https://app.teamX.test
```

Clients do not need to know the backend IP addresses during normal operation.

---

## Mac 3 — Backend A

**Team Member:** Nishtha Gupta

**IP Address:**

```text
10.7.9.8
```

**Interface:**

```text
en0
```

**Port:**

```text
3001
```

Backend A is a simple HTTP/REST service.

Endpoints:

```text
GET /
GET /api/status
```

Example `/api/status` response:

```json
{
  "backend": "A",
  "status": "ok"
}
```

The response identifies Backend A using:

```text
X-Backend: A
```

---

## Mac 4 — Backend B

**Team Member:** Shrijan

**IP Address:**

```text
10.7.11.140
```

**Interface:**

```text
en0
```

**Port:**

```text
3002
```

Backend B is a simple HTTP/REST service.

Endpoints:

```text
GET /
GET /api/status
```

Example `/api/status` response:

```json
{
  "backend": "B",
  "status": "ok"
}
```

The response identifies Backend B using:

```text
X-Backend: B
```

---

# 4. Network Architecture

The complete Phase 1 architecture is:

```text
                         Private LAN
                    10.7.0.0/19
                         |
        +----------------+----------------+
        |                |                |
        v                v                v
  Mishti            Aditya            Nishtha
  DNS Server        nginx Edge        Backend A
  10.7.30.18        10.7.28.24        10.7.9.8
  dnsmasq           HTTPS :443        HTTP :3001
        |                |
        |                |
        |                +----------+
        |                           |
        |                           |
        |                       Shrijan
        |                       Backend B
        |                       10.7.11.140
        |                       HTTP :3002
        |
        +---- app.teamX.test
              → 10.7.28.24
```

---

# 5. Request Flow

A normal client request follows these steps:

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
4. Client establishes a TCP connection
             |
             v
5. TLS handshake takes place
             |
             v
6. HTTPS request reaches nginx
             |
             v
7. nginx selects Backend A or Backend B
             |
             v
8. Backend returns the response
             |
             v
9. nginx sends the response back to the client
```

This allows the team to observe the relationship between DNS, TCP, TLS, HTTP, and load balancing.

---

# 6. Backend Services

Both backend services provide a minimal REST API.

## Backend A

Backend A listens on:

```text
0.0.0.0:3001
```

Endpoints:

```text
GET /
GET /api/status
```

Expected status response:

```json
{
  "backend": "A",
  "status": "ok"
}
```

Response header:

```text
X-Backend: A
```

## Backend B

Backend B listens on:

```text
0.0.0.0:3002
```

Endpoints:

```text
GET /
GET /api/status
```

Expected status response:

```json
{
  "backend": "B",
  "status": "ok"
}
```

Response header:

```text
X-Backend: B
```

---

# 7. Running the Backend Services

## Backend A

On Nishtha's machine:

```bash
cd backend-a
npm install
node server.js
```

Backend A runs on:

```text
10.7.9.8:3001
```

## Backend B

On Shrijan's machine:

```bash
cd backend-b
npm install
node server.js
```

Backend B runs on:

```text
10.7.11.140:3002
```

The backends are configured to listen on a LAN-accessible interface rather than only `127.0.0.1`.

---

# 8. Private DNS

The project uses the reserved `.test` namespace.

The private DNS server runs on Mishti's machine:

```text
10.7.30.18
```

using `dnsmasq`.

The project DNS records are:

```text
app.teamX.test → 10.7.28.24
api.teamX.test → 10.7.28.24
```

The nginx edge IP is returned by the DNS server because nginx is the single entry point for the application.

DNS resolution can be verified using:

```bash
dig app.teamX.test
```

or:

```bash
nslookup app.teamX.test
```

The final application is accessed using the domain name rather than directly entering the edge IP.

---

# 9. nginx Reverse Proxy and Load Balancing

nginx runs on:

```text
10.7.28.24
```

The configured backend servers are:

```text
Backend A → 10.7.9.8:3001
Backend B → 10.7.11.140:3002
```

The edge acts as a reverse proxy and load balancer.

The client only needs to know:

```text
app.teamX.test
```

nginx handles communication with the backend servers.

Repeated requests demonstrate load balancing through the `X-Backend` response header.

Example:

```text
X-Backend: A
X-Backend: B
X-Backend: A
X-Backend: B
```

This demonstrates that requests can be distributed between the two backend services.

---

# 10. HTTPS and TLS

The nginx edge terminates TLS for the application.

The service is accessed through:

```text
https://app.teamX.test
```

The project uses a local certificate for the private `.test` domain.

The TLS process includes:

```text
ClientHello
     ↓
ServerHello
     ↓
Certificate
     ↓
Key Exchange
     ↓
Finished
     ↓
Encrypted Application Data
```

The certificate is trusted on the required client machines.

The final demonstration does not bypass certificate validation using:

```text
curl -k
```

---

# 11. HTTP Caching

The project demonstrates HTTP caching behaviour using response headers.

A cache-control response can contain:

```text
Cache-Control: max-age=60
```

Response headers can be inspected using:

```bash
curl -I https://app.teamX.test/api/status
```

The project can also demonstrate conditional HTTP requests using an `ETag` and a `304 Not Modified` response.

The caching demonstration helps distinguish between:

* A fresh cache hit
* A conditional request
* A full new request

---

# 12. Packet Analysis

Wireshark is used to capture and analyse the network traffic generated by the project.

The captured protocol flow includes:

## DNS

```text
Client → DNS Server
DNS Query → DNS Response
```

The DNS response contains the nginx edge IP.

## TCP

The TCP three-way handshake is:

```text
SYN
   ↓
SYN-ACK
   ↓
ACK
```

The source and destination ports can be identified from the packet capture.

## TLS

The TLS handshake includes packets such as:

```text
ClientHello
ServerHello
Certificate
Key Exchange
Finished
```

After TLS establishment, application data is encrypted.

## HTTPS

HTTP request and response data is protected by TLS and therefore appears encrypted in the packet capture.

## Load Balancing

Repeated HTTPS requests are correlated with the `X-Backend` response header to identify which backend served each request.

---

# 13. Phase 1 Evidence

The Phase 1 evidence covers:

* IP configuration of all four machines
* MAC address and network interface information
* Subnet and gateway configuration
* Ping connectivity
* Private DNS resolution
* Backend A operation
* Backend B operation
* nginx reverse proxy
* Load balancing
* HTTPS
* TLS certificate validation
* HTTP caching
* DNS packet capture
* TCP three-way handshake
* TLS handshake
* HTTP headers
* Backend failure demonstration

Evidence is organised under:

```text
evidence/phase1/
```

---

# 14. Phase 1 Failure Demonstration

The project includes a controlled backend failure demonstration.

Before failure, repeated requests can be served by both backends:

```text
X-Backend: A
X-Backend: B
X-Backend: A
X-Backend: B
```

Backend A can then be stopped deliberately.

The resulting behaviour is observed through the nginx edge and analysed to determine the affected layer.

The demonstration distinguishes between:

```text
DNS
↓
TCP
↓
TLS
↓
nginx / Reverse Proxy
↓
Backend Application
```

The purpose is to demonstrate that a failure at one layer does not necessarily mean that every other layer has failed.

---

# 15. Useful Network Commands

## Check IP Address

```bash
ipconfig getifaddr en0
```

## Check MAC Address

```bash
ifconfig en0 | grep ether
```

## Check Default Gateway

```bash
route -n get default
```

## Test Connectivity

```bash
ping -c 4 <IP_ADDRESS>
```

## Test DNS

```bash
dig app.teamX.test
```

## Test Backend A

```bash
curl http://10.7.9.8:3001/api/status
```

## Test Backend B

```bash
curl http://10.7.11.140:3002/api/status
```

## Test HTTPS Through the Domain

```bash
curl -si https://app.teamX.test/api/status
```

## Inspect HTTP Headers

```bash
curl -I https://app.teamX.test/api/status
```

## Test nginx Configuration

```bash
nginx -t
```

---

# 16. Repository Structure

```text
TeamSubnetCN/
│
├── README.md
│
├── backend-a/
│
├── backend-b/
│
├── dns/
│
├── nginx/
│
├── tls/
│
├── scripts/
│
├── docs/
│
└── evidence/
    ├── phase1/
    └── phase2/
```

---

# 17. Phase 2

Phase 2 extends the Phase 1 infrastructure rather than rebuilding it.

The planned Phase 2 work includes:

* Backup DNS resolver
* DNS failover
* DNS TTL behaviour
* Controlled DNS record changes
* Backend service isolation
* Firewall rules
* High-availability backend failover
* Edge migration
* Controlled failure testing
* Faculty-injected troubleshooting challenge

Phase 2 evidence will be organised under:

```text
evidence/phase2/
```

---

# 18. Learning Objectives

This project provides practical experience with:

* Private DNS
* DNS resolution
* TCP/IP communication
* TCP three-way handshake
* Ports and sockets
* HTTP/1.1
* HTTPS
* TLS
* Reverse proxies
* Load balancing
* HTTP caching
* Network packet analysis
* Service failure diagnosis
* Network resilience
* Layer-by-layer troubleshooting

---

# 19. Core Principle

> **The application stays simple. The network is the project.**

The project focuses on understanding what happens to a request from the moment a private domain is resolved until the final response is returned through the network.

