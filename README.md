# sysscripts

`status` checks the configured servers. `wake <name>` sends a Wake-on-LAN
packet to one server, and `wake all` sends one to each server.

Create `servers.local` beside the scripts with one name, IP address, and MAC
address per line. For example:

```text
build 192.0.2.10 02:00:00:00:00:01
```

Use a unique, single-word name for each server. Names are case-insensitive in
`wake`, and `all` is reserved. Git ignores this file.
