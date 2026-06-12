---
name: expose-service-public
description: "Add a service Web UI to the public domain for remote access using exactly one exposure method: Caddy reverse proxy or Cloudflare Tunnel routing. Usually follows pve-service and can consume its handoff output."
usage_hint: "Trigger on: expose service, public URL, add subdomain, reverse proxy, Caddy route, Cloudflare Tunnel, make service accessible, domain for app."
related_skills:
  - pve-service
metadata:
  trigger_text:
    - expose service
    - public URL
    - add subdomain
    - reverse proxy
    - Caddy route
    - Cloudflare Tunnel
    - make service accessible
    - domain for app
---

# Expose Service Public

Use this skill when T4tsster asks to expose a new self-hosted service Web UI on a domain/subdomain for public remote access.

This skill usually runs immediately after `pve-service`. When it does, consume the `pve-service` handoff values instead of asking again.

Prefer simple, stable, auditable changes. Expose only what is necessary. Do **not** configure both Caddy and Cloudflare Tunnel for the same new Web UI unless the user explicitly starts a separate follow-up task.

## Handoff from `pve-service`

If `pve-service` was just used, read its final response and reuse these values:

```text
Service handoff for expose-service-public:
- Service name: <service>
- Internal service URL: http://<ip>:<port>
- Internal IP: <ip>
- Web UI port: <port>
- CTID: <ctid>
- Hostname: <hostname>
- Auth status: known-auth / no-auth / unknown
- Notes: <anything needed for proxying, no secrets>
```

Minimum required handoff fields for this skill:

- `Service name`
- `Internal service URL`

If those are present, do **not** ask for them again. Only ask for missing information such as the desired public FQDN or chosen exposure method.

If there is no handoff, collect the normal inputs below.

## Required behavior

- Verify both Cloudflare Tunnel tooling and Caddy are available before making changes.
- Ask the user to choose **one** method:
  - `caddy`
  - `tunnel`
- If user chooses `caddy`:
  - Find the Caddyfile in the proxy LXC.
  - Back it up.
  - Add/update one reverse-proxy rule for the new service Web UI.
  - Validate the Caddyfile.
  - Reload/restart Caddy.
- If user chooses `tunnel`:
  - Use the tunnel MCP/tooling in the proxy LXC.
  - Add/update the Cloudflare routing rule with the new service Web UI.
  - Verify the route.
- Always verify public access after the change.

## Inputs to collect

Ask only for missing information:

- Service name.
- Desired public hostname/FQDN, e.g. `service.example.com`.
- Internal service URL, e.g. `http://192.168.1.50:8080`.
- Exposure method: `caddy` or `tunnel`.
- Any special WebSocket/header/auth requirements from service docs.

If the user does not know the internal URL, inspect the service LXC or recent install output to identify the Web UI IP and port.

## Step 1 — Find proxy LXC and current environment

Identify the proxy LXC from current homelab state. Known environment pattern: CT 201 / `192.168.1.201` is commonly the proxy LXC running Caddy + Cloudflare Tunnel + Cloudflare MCP, but always verify rather than assuming.

Look for containers named like `proxy`, `caddy`, `cloudflare`, `tunnel`, or similar:

```bash
pct list
for id in $(pct list | awk 'NR>1 {print $1}'); do
  echo "===== CT $id ====="
  pct config "$id" | sed -n '1,80p'
  pct exec "$id" -- sh -lc 'hostname; command -v caddy || true; command -v cloudflared || true; systemctl is-active caddy 2>/dev/null || true; systemctl is-active cloudflared 2>/dev/null || true' 2>/dev/null || true
done
```

If multiple candidate proxy LXCs exist, ask the user which one to use.

## Step 2 — Verify Caddy and Cloudflare Tunnel availability

Inside the chosen proxy LXC, check both before asking for method:

```bash
pct exec <proxy-ctid> -- sh -lc '
set -eu
printf "Caddy: "; command -v caddy || true
printf "Cloudflared: "; command -v cloudflared || true
systemctl status caddy --no-pager --lines=20 || true
systemctl status cloudflared --no-pager --lines=20 || true
'
```

Also check for tunnel MCP/tooling/configs used by the homelab:

```bash
pct exec <proxy-ctid> -- sh -lc '
find / -maxdepth 4 \( -iname "*mcp*" -o -iname "*cloudflare*" -o -iname "config.yml" -o -iname "*.json" \) 2>/dev/null | head -100
'
```

If Caddy is unavailable, do not offer `caddy` as an option until clarified. If Cloudflare/tunnel MCP tooling is unavailable, do not offer `tunnel` as an option until clarified. If neither is available, stop and report what is missing.

## Step 3 — Ask method

Ask the user to select exactly one:

```text
How should I expose <service> at <fqdn>?
1. Caddy reverse proxy
2. Cloudflare Tunnel route
```

Do not configure both. If the user asks for both, explain that this skill handles one route per run and ask which to do first.

## Caddy path

### Find Caddyfile

Inside the proxy LXC:

```bash
pct exec <proxy-ctid> -- sh -lc '
for p in /etc/caddy/Caddyfile /usr/local/etc/caddy/Caddyfile /opt/caddy/Caddyfile; do
  test -f "$p" && echo "$p"
done
find /etc /opt /srv -name Caddyfile -type f 2>/dev/null
'
```

If multiple Caddyfiles exist, inspect the systemd unit to find the active one:

```bash
pct exec <proxy-ctid> -- sh -lc 'systemctl cat caddy --no-pager | sed -n "1,160p"'
```

### Backup and edit

Before editing:

```bash
pct exec <proxy-ctid> -- sh -lc 'cp <Caddyfile> <Caddyfile>.bak.$(date +%Y%m%d-%H%M%S)'
```

Add a simple reverse proxy block, preserving existing style where possible:

```caddyfile
<fqdn> {
    reverse_proxy <internal-host>:<internal-port>
}
```

For services needing WebSocket support, Caddy usually handles it automatically with `reverse_proxy`. Only add custom headers if service docs require them.

Do not remove unrelated Caddyfile blocks. Do not expose additional internal ports.

### Validate and reload

Validate formatting/config before reload:

```bash
pct exec <proxy-ctid> -- sh -lc 'caddy validate --config <Caddyfile>'
```

If validation passes, reload or restart:

```bash
pct exec <proxy-ctid> -- sh -lc 'systemctl reload caddy || systemctl restart caddy'
```

Verify:

```bash
pct exec <proxy-ctid> -- sh -lc 'systemctl is-active caddy && systemctl status caddy --no-pager --lines=30'
curl -Ik https://<fqdn>/
curl -fsS https://<fqdn>/ | head -40 || true
```

If reload fails, restore the backup and report the error.

## Cloudflare Tunnel path

Use the tunnel MCP/tooling configured in the proxy LXC. Do not hand-edit Cloudflare routing if an MCP/helper is the established local method.

### Discover current tunnel config

Inside the proxy LXC:

```bash
pct exec <proxy-ctid> -- sh -lc '
cloudflared tunnel list 2>/dev/null || true
find /etc /opt /root -maxdepth 4 \( -path "*cloudflared*" -o -iname "config.yml" -o -iname "*.json" -o -iname "*mcp*" \) 2>/dev/null
systemctl cat cloudflared --no-pager 2>/dev/null || true
'
```

Identify the active tunnel, credentials/config path, and existing ingress/routing rules.

### Add/update route

Using the local tunnel MCP/helper, add a routing rule mapping:

```text
hostname: <fqdn>
service: <internal-url>
```

Rules must preserve existing routes and should be inserted before any catch-all rule such as `http_status:404`.

If the local method is a `cloudflared` config file rather than MCP, update the active YAML safely:

```yaml
ingress:
  - hostname: <fqdn>
    service: <internal-url>
  - service: http_status:404
```

Then validate and restart/reload cloudflared:

```bash
pct exec <proxy-ctid> -- sh -lc 'cloudflared tunnel ingress validate --config <config.yml>'
pct exec <proxy-ctid> -- sh -lc 'systemctl restart cloudflared'
```

If the homelab has a specific tunnel MCP command/API, use that instead of manual YAML editing and record the exact command used in the final report.

### Verify tunnel route

```bash
pct exec <proxy-ctid> -- sh -lc 'systemctl is-active cloudflared && systemctl status cloudflared --no-pager --lines=30'
cloudflared tunnel route dns <tunnel-name-or-id> <fqdn> 2>/dev/null || true
curl -Ik https://<fqdn>/
curl -fsS https://<fqdn>/ | head -40 || true
```

If route verification fails, check cloudflared logs:

```bash
pct exec <proxy-ctid> -- journalctl -u cloudflared --no-pager -n 100
```

## Security and credential rules

- Do not expose secrets/API tokens/tunnel credentials in the final response.
- Redact credentials as `[REDACTED]`.
- Do not broaden public access beyond the requested hostname and Web UI URL.
- Prefer HTTPS public URLs.
- If the service has no authentication, warn the user before exposing it publicly and recommend adding auth/access controls.

## Final verification checklist

Before reporting success:

- Proxy LXC identified.
- Caddy and Cloudflare Tunnel availability checked.
- Exactly one method selected and configured.
- Config backup made before edits.
- Config validation passed.
- Relevant service restarted/reloaded.
- Public HTTPS endpoint responds.
- No secrets printed.

## Final response format

```text
Added public access for <service>
- Public URL: https://<fqdn>/
- Internal URL: <internal-url>
- Method: Caddy / Cloudflare Tunnel
- Proxy LXC: <ctid>/<hostname>
- Config changed: <path or MCP/helper name>
- Backup: <backup path, if Caddy/file edit>
- Validation: passed
- Reload/restart: passed
- Public check: <HTTP status or brief result>
- Notes: <auth warning/credential location if relevant, no secrets>
```

If failed, report:

- What failed.
- Whether any config was changed.
- Backup path and restore status.
- Exact next step.

## Pitfalls

- Do not configure both Caddy and Cloudflare Tunnel in one run.
- Do not edit the wrong Caddyfile; confirm active config via systemd when needed.
- Do not put new Cloudflare Tunnel ingress rules after a catch-all rule.
- Do not print Cloudflare credentials or API tokens.
- Do not expose unauthenticated admin panels without warning the user.
- Do not assume proxy LXC CTID; discover it from current PVE state.
