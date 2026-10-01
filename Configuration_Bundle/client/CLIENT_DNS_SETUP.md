# Point a client Mac at the team DNS (Mac 1 = 10.7.30.18)

```bash
sudo networksetup -setdnsservers Wi-Fi 10.7.30.18
sudo dscacheutil -flushcache; sudo killall -HUP mDNSResponder
networksetup -getdnsservers Wi-Fi
dig app.teamX.test            # SERVER should be 10.7.30.18#53
```

Optional scoped resolver (used on Mac 3):
```bash
sudo mkdir -p /etc/resolver
sudo sh -c 'echo "nameserver 10.7.30.18" > /etc/resolver/teamX.test'
```

Restore after failure demos:
```bash
sudo networksetup -setdnsservers Wi-Fi 10.7.30.18
sudo dscacheutil -flushcache; sudo killall -HUP mDNSResponder
```
