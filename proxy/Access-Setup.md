# Proxy LXC: Caddy, Cloudflare Tunnel, and Cloudflare MCP

This LXC handles public/private access for services.

Recommended current pattern:

- One dedicated **proxy LXC** for Cloudflare Tunnel + Caddy + optional Cloudflare MCP.
- Keep it separate from app LXCs so proxy CPU/network issues do not take down media or AI services.
- Use Cloudflare Tunnel for most public services.
- Use Caddy with Cloudflare DNS challenge where direct reverse proxy / wildcard certs are simpler.

## LXC requirements

When recreating the proxy LXC, keep the current homelab LXC defaults:

```text
features: nesting=1
unprivileged: 0
```

In Proxmox UI this means:

- Enable nesting.
- `Unprivileged container = No`.
- CPU advanced setting: cores unlimited, CPU limit as needed.

Record final CT ID/IP in:

```text
../inventory/lxc-map.md
```

## Secrets policy

Do **not** commit real Cloudflare tokens/API keys.

Use placeholders in repo examples and store real values only on the LXC, password manager, or sealed backup.

Relevant example file:

```text
../.env.example
```

## Access with Cloudflared Tunnel

To prevent one app LXC hitting max CPU and degrading access for everything, deploy Cloudflared Tunnel in a separate proxy LXC.

Simple install option:

```text
https://community-scripts.github.io/ProxmoxVE/scripts?id=cloudflared
```

Follow the script instructions to create the Cloudflared LXC/package. Then create the tunnel in Cloudflare:

```text
Cloudflare Dashboard -> Zero Trust -> Networks -> Tunnels
```

After creating the tunnel, add public hostnames for each service:

1. Enter the service subdomain.
2. Choose the owned domain.
3. Enter the internal LAN URL and port.
4. Type:
   - `HTTP`: simplest, no additional TLS work.
   - `HTTPS`: if the service enables HTTPS by default, open `Additional settings -> TLS` and enable `No TLS Verify` for self-signed/internal certs.

### Tunnel token

Where to get it:

```text
Cloudflare Dashboard -> Zero Trust -> Networks -> Tunnels -> your tunnel -> Install and run connector
```

Copy the token/connector command from Cloudflare. Store it on the proxy LXC only.

Do not commit it.

## Add Cloudflare Access login

Use this for services that are publicly reachable but should require login first.

Cloudflare path:

```text
Zero Trust -> Access -> Applications -> Add an application -> Self-hosted
```

Steps:

1. Enter application name, usually the service name.
2. Add the public hostname.
3. Add an Access policy.
4. Finish.

Policy identity providers can be Google, GitHub, etc. Creating those providers requires OAuth credentials from the provider dashboard.

Reference followed before:

```text
https://www.youtube.com/watch?v=Ynr8VubJqvY&t
```

## Dynamic DNS resolver

Create a Cloudflare API token to periodically update public IP / complete DNS challenges.

Cloudflare path:

```text
Profile -> API Tokens -> Create Token -> Custom Token
```

Recommended token permissions:

```text
Zone -> Zone -> Read
Zone -> DNS -> Edit
```

Zone resources:

```text
Include -> Specific zone -> your-domain.example
```

The older note used `Include All zones`; prefer a specific zone if possible.

Store the resulting token as an environment variable on the proxy LXC:

```bash
CF_API_TOKEN='<cloudflare-api-token>'
```

## Caddy

Caddy is used for services that do not use Cloudflare Tunnel or where local wildcard TLS/reverse proxy is preferred.

Install option:

```text
https://community-scripts.github.io/ProxmoxVE/scripts?id=caddy
```

Because Cloudflare manages DNS, install/build Caddy with the Cloudflare DNS plugin for certificate challenges:

```bash
xcaddy build --with github.com/caddy-dns/cloudflare
sudo mv ./caddy "$(which caddy)"
sudo chmod +x "$(which caddy)"
caddy list-modules
```

If using Caddy as DDNS updater too, build with both modules:

```bash
xcaddy build \
  --with github.com/mholt/caddy-dynamicdns \
  --with github.com/caddy-dns/cloudflare
sudo mv ./caddy "$(which caddy)"
sudo chmod +x "$(which caddy)"
caddy list-modules
```

Expected modules include:

```text
dns.providers.cloudflare
```

and, if using DDNS:

```text
dynamic_dns
```

## Caddyfile

Current real config is tracked here:

```text
config/Caddyfile
```

Sanitized reusable template:

```text
config/Caddyfile.example
```

When rebuilding:

```bash
cp config/Caddyfile.example Caddyfile
nano Caddyfile
caddy fmt --overwrite Caddyfile
sudo cp Caddyfile /etc/caddy/Caddyfile
sudo systemctl restart caddy
sudo systemctl status caddy --no-pager
```

If running Caddy manually instead of systemd:

```bash
caddy start --config /etc/caddy/Caddyfile
```

## Persist Cloudflare token for Caddy

Recommended systemd override:

```bash
sudo systemctl edit caddy
```

Add:

```ini
[Service]
Environment=CF_API_TOKEN=replace-with-real-token
```

Then reload and restart:

```bash
sudo systemctl daemon-reload
sudo systemctl restart caddy
```

Alternative current/simple approach: save export in `/etc/profile`, but systemd services may not always read shell profile files. Prefer the systemd override for Caddy.

## Cloudflare MCP

TODO: document the exact current Cloudflare MCP installation and config after checking the live proxy LXC.

What should be captured:

- Install method/package.
- Config path.
- How Hermes or other agents call it.
- Required Cloudflare token scopes.
- Whether it runs under systemd, Docker, or directly.

Secret guidance:

- Create Cloudflare API token from Cloudflare profile/API Tokens.
- Scope token only to required operations if possible.
- Store token in the MCP service environment, not in Git.

## Verification

After rebuild:

```bash
cloudflared tunnel list
cloudflared tunnel info <tunnel-name-or-id>
systemctl status cloudflared --no-pager
caddy validate --config /etc/caddy/Caddyfile
systemctl status caddy --no-pager
```

Then test from LAN and outside LAN:

- Public Cloudflare Tunnel hostname resolves.
- Cloudflare Access login appears where expected.
- Caddy wildcard hosts obtain certificates.
- Internal reverse proxies reach the correct LXC IP/port.
