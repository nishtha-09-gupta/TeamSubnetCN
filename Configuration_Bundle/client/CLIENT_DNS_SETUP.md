# Client DNS for Phase 2

Phase 2 terminal evidence: primary resolver `10.7.30.234`, backup resolver `10.7.13.67`. macOS may select or cache resolvers in ways that do not guarantee immediate failover. Use direct `dig @server` checks to distinguish resolver health from the system resolver result.

Set both resolvers on the Wi-Fi service (run manually on each client Mac):

```bash
sudo networksetup -setdnsservers Wi-Fi 10.7.30.234 10.7.13.67
networksetup -getdnsservers Wi-Fi
sudo dscacheutil -flushcache; sudo killall -HUP mDNSResponder
```

Check independently and then through the system resolver:

```bash
dig @10.7.30.234 app.teamX.test +noall +answer +ttlid
dig @10.7.13.67 app.teamX.test +noall +answer +ttlid
dig app.teamX.test
scutil --dns
```

For cache/failover demonstrations use `Helper_Scripts/Phase2/dns/`. Stop primary dnsmasq manually on its host; scripts do not stop services. Flush local macOS cache only when deliberately testing the uncached result. Restore the network's prior DNS addresses manually after evaluation.
