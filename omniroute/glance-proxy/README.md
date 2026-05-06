# OmniRoute Glance proxy

Small local proxy for the Glance OmniRoute widget.

Why this exists:

- OmniRoute `/api/usage/analytics` is a dashboard endpoint.
- It accepts the dashboard `auth_token` cookie, not the normal `/v1` API key.
- Browser `auth_token` cookies expire and should not be copied into Glance config.
- This proxy reads the local OmniRoute `JWT_SECRET`, creates a fresh short-lived cookie JWT, calls OmniRoute, and returns widget-friendly JSON.

## Live target

```text
CTID: 107
OmniRoute: http://127.0.0.1:20128
Proxy: http://192.168.1.109:20129
OmniRoute data: /root/omniroute/data/server.env
```

## Files

```text
omniroute/glance-proxy/server.js
omniroute/glance-proxy/package.json
omniroute/glance-proxy/Dockerfile
omniroute/glance-proxy/docker-compose.example.yml
omniroute/glance-proxy/.env.example
```

## API

### Health

```bash
curl http://127.0.0.1:20129/health
```

Expected:

```json
{"status":"ok"}
```

### Summary for Glance

```bash
curl -H "Authorization: Bearer $OMNIROUTE_GLANCE_TOKEN" \
  "http://127.0.0.1:20129/summary?range=7d" | jq
```

Response shape:

```json
{
  "status": "ok",
  "summary": {
    "totalRequests": 123,
    "promptTokens": 1000,
    "completionTokens": 200,
    "totalTokens": 1200,
    "cacheReadTokens": 500,
    "cacheHitRatePct": 33.33,
    "successRatePct": 99.1,
    "avgLatencyMs": 1200,
    "fallbackCount": 0,
    "lastRequest": "2026-05-06T11:48:37.702Z"
  }
}
```

## Build on CT107

From inside CT `107`:

```bash
cd /root/repos/multimedia-server/omniroute/glance-proxy
docker build -t omniroute-glance-proxy:local .
```

## Configure secrets

Create a private env file on CT `107`:

```bash
cp /root/repos/multimedia-server/omniroute/glance-proxy/.env.example /root/omniroute/glance-proxy.env
chmod 600 /root/omniroute/glance-proxy.env
```

Generate the shared Glance/proxy token:

```bash
TOKEN="$(openssl rand -hex 32)"
sed -i "s/^OMNIROUTE_GLANCE_TOKEN=.*/OMNIROUTE_GLANCE_TOKEN=$TOKEN/" /root/omniroute/glance-proxy.env
printf 'Use this in Glance as OMNIROUTE_GLANCE_TOKEN: %s\n' "$TOKEN"
```

Do not commit `/root/omniroute/glance-proxy.env` or the generated token.

## Run with Docker

```bash
docker run -d \
  --name omniroute-glance-proxy \
  --restart unless-stopped \
  --env-file /root/omniroute/glance-proxy.env \
  -p 20129:20129 \
  -v /root/omniroute/data:/app/omniroute-data:ro \
  omniroute-glance-proxy:local
```

Verify:

```bash
curl -s http://127.0.0.1:20129/health
TOKEN="$(grep '^OMNIROUTE_GLANCE_TOKEN=' /root/omniroute/glance-proxy.env | cut -d= -f2-)"
curl -s -H "Authorization: Bearer $TOKEN" \
  "http://127.0.0.1:20129/summary?range=7d" | jq '.summary'
```

## Run with Compose

Copy the example compose file next to your private env file if you prefer Compose:

```bash
mkdir -p /root/omniroute/glance-proxy
cp /root/repos/multimedia-server/omniroute/glance-proxy/docker-compose.example.yml /root/omniroute/glance-proxy/docker-compose.yml
cd /root/omniroute/glance-proxy
docker compose up -d --build
```

## Glance configuration

Set these in the Glance stack/container env:

```text
OMNIROUTE_GLANCE_PROXY_URL=http://192.168.1.109:20129
OMNIROUTE_GLANCE_TOKEN=<same token from /root/omniroute/glance-proxy.env>
```

The widget file is:

```text
glance/widgets/omniroute.yml
```

It calls:

```text
${OMNIROUTE_GLANCE_PROXY_URL}/summary?range=7d
```

with:

```text
Authorization: Bearer ${OMNIROUTE_GLANCE_TOKEN}
```

## Security notes

- Keep the proxy on LAN/internal networks only.
- The proxy token is only for Glance; it is not an OmniRoute API key.
- Do not expose `/root/omniroute/data/server.env` to any container except this proxy.
- The mounted OmniRoute data directory is read-only.
- The proxy creates 5-minute JWTs internally and does not log secrets.
- Do not manually add `JWT_SECRET` to `/root/omniroute/.env`; OmniRoute manages it in `/root/omniroute/data/server.env`.
