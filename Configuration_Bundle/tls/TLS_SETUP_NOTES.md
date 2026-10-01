# TLS setup (Mac 2, edge)

Self-signed certificate for app.teamX.test (valid 1 year), with SAN so modern clients accept the name.

```bash
mkdir -p /opt/homebrew/etc/nginx/certs && cd /opt/homebrew/etc/nginx/certs
openssl req -x509 -newkey rsa:2048 -nodes \
  -keyout edge.key -out edge.crt -days 365 \
  -subj "/CN=app.teamX.test" \
  -addext "subjectAltName=DNS:app.teamX.test,DNS:api.teamX.test"

# verify SAN
openssl x509 -in edge.crt -noout -text | grep -A1 "Subject Alternative Name"
```

## Trust on every client Mac (so curl/browser need no -k)
Copy `edge.crt` to the client (e.g. ~/Downloads), then:

```bash
sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain ~/Downloads/edge.crt
security verify-cert -c ~/Downloads/edge.crt -p ssl -s app.teamX.test
```

Before trust: `curl: (60) SSL certificate problem: self signed certificate`.
After trust: `curl -v https://app.teamX.test/api/status` shows `SSL certificate verify ok`.

Never use `curl -k` in the demo.
