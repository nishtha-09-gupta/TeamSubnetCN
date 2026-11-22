# Launching the backends

Current Phase 2 allocation: Backend A and primary DNS share Nishtha’s Mac at `10.7.30.234`; Backend B is Shrijan’s Mac at `10.7.1.114`. The Phase 1 Backend A (`10.7.9.8`), Backend B (`10.7.11.140`), and edge (`10.7.28.24`) addresses are historical and must not be used for the current deployment. The Phase 1 DNS address is not confirmed here.

Requires Node.js. Backends bind to 0.0.0.0 so Mac 2 can reach them over the LAN.

## Backend A (Nishtha, 10.7.30.234, port 3001)
```bash
cd 3_Backend_Source_Code/backend-a
npm install
node backend-A.js
```

## Backend B (Shrijan, 10.7.1.114, port 3002)
```bash
cd 3_Backend_Source_Code/backend-b
npm install
node backend-B.js
```

## Verify
```bash
lsof -nP -iTCP:3001 -sTCP:LISTEN                  # on Mac 3
curl -i http://10.7.30.234:3001/api/status            # from another Mac
curl -i http://10.7.1.114:3002/api/status         # from another Mac
```
Expected: `{"backend":"A","status":"ok"}` with `X-Backend: A` (or B).

## Start order
1. Mac 1: dnsmasq  2. Mac 3 and Mac 4: backends  3. Mac 2: nginx (`nginx -t && brew services restart nginx`)
