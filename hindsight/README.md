# Hindsight LXC Setup

Hindsight is the persistent memory backend used by Hermes.

Current Hermes client config points to this LXC API:

```text
http://192.168.1.111:8888
```

Hermes uses bank ID:

```text
hermes
```

## Live target

| Item | Current value |
|---|---|
| CT ID | `109` |
| Hostname | `hindsight` |
| IP | `192.168.1.111/24` |
| OS | Debian 12 bookworm |
| LXC type | privileged, `unprivileged: 0` |
| LXC feature | `features: nesting=1` |
| CPU | `cores: 2`, `cpulimit: 4` |
| Memory | `8192` MB |
| Swap | `1024` MB |
| Rootfs | `vm_storage:subvol-109-disk-0,size=20G` |
| Tag | `agent` |

Keep these settings for a like-for-like rebuild unless intentionally resizing.

## Current live deployment model

The live Hindsight LXC runs Hindsight with Docker, not a bare-metal Python service.

| Item | Current value |
|---|---|
| Docker container | `hindsight` |
| Image | `ghcr.io/vectorize-io/hindsight:latest` |
| Restart policy | `unless-stopped` |
| Container command | `/app/start-all.sh` |
| API port | `8888` |
| Control plane/UI port | `9999` |
| Persistent data bind mount | `/root/.hindsight-docker -> /home/hindsight/.pg0` |
| API health endpoint | `http://<hindsight-lxc-ip>:8888/health` |
| API docs | `http://<hindsight-lxc-ip>:8888/docs` |
| Control plane | `http://<hindsight-lxc-ip>:9999/dashboard` |

The data directory is the important part for backup/restore:

```text
/root/.hindsight-docker
```

This contains the embedded `pg0` PostgreSQL data used by the all-in-one Docker image.

## Install / rebuild

Start OmniRoute first, because Hindsight's LLM extraction calls route through the OmniRoute OpenAI-compatible API.

From the Proxmox host, either run the repo script:

```bash
cd /root/repos/multimedia-server
CTID=109 \
HOSTNAME=hindsight \
IP_CIDR=192.168.1.111/24 \
PASSWORD='replace-with-temporary-root-password' \
bash scripts/pve/create-hindsight-lxc.sh
```

Or, inside an already-created Hindsight LXC, install Docker and start the container manually:

```bash
apt-get update
DEBIAN_FRONTEND=noninteractive apt-get install -y ca-certificates curl gnupg
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc
. /etc/os-release
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian ${VERSION_CODENAME} stable" > /etc/apt/sources.list.d/docker.list
apt-get update
DEBIAN_FRONTEND=noninteractive apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
systemctl enable --now docker
```

Create a local env file with placeholders first:

```bash
install -d -m 0700 /root/.hindsight-docker
cat >/root/.hindsight.env <<'EOF'
# Hindsight API listens on all interfaces inside the LXC.
HINDSIGHT_API_HOST=0.0.0.0
HINDSIGHT_API_PORT=8888
HINDSIGHT_ENABLE_API=true
HINDSIGHT_ENABLE_CP=true
HINDSIGHT_CP_DATAPLANE_API_URL=http://localhost:8888
HINDSIGHT_API_LOG_LEVEL=info

# Current live setup routes Hindsight LLM calls through OmniRoute.
HINDSIGHT_API_LLM_PROVIDER=openai
HINDSIGHT_API_LLM_BASE_URL=http://192.168.1.109:20128/v1
HINDSIGHT_API_LLM_MODEL=gemini/gemini-3-flash-preview

# Secret. Create this in OmniRoute or use the provider token OmniRoute expects.
# Do not commit the real value.
HINDSIGHT_API_LLM_API_KEY=replace-with-omniroute-or-provider-api-key
EOF
chmod 0600 /root/.hindsight.env
```

Start Hindsight:

```bash
docker run -d \
  --name hindsight \
  --restart unless-stopped \
  --env-file /root/.hindsight.env \
  -p 8888:8888 \
  -p 9999:9999 \
  -v /root/.hindsight-docker:/home/hindsight/.pg0 \
  ghcr.io/vectorize-io/hindsight:latest
```

## Secrets / where to create them

Do not store real values in this repo.

| Secret | Used by | Where to get/create it |
|---|---|---|
| `HINDSIGHT_API_LLM_API_KEY` | Hindsight container | OmniRoute provider/API key settings, or the upstream provider account used by OmniRoute |
| Provider tokens behind OmniRoute | OmniRoute | OmniRoute admin UI / provider account dashboards |

The current live LXC has a real `HINDSIGHT_API_LLM_API_KEY` in the Docker container environment. It was inspected only to confirm the variable name and was not copied into this repo.

## Integration with Hermes

On Hermes LXC, use the Hindsight client config:

```json
{
  "mode": "local_external",
  "api_url": "http://192.168.1.111:8888",
  "bank_id": "hermes",
  "recall_budget": "mid"
}
```

Expected path on Hermes:

```text
/root/.hermes/hindsight/config.json
```

Then verify Hermes has memory enabled and provider set to Hindsight:

```bash
hermes config get memory
hermes config set memory.provider hindsight
```

Restart the system-level Hermes gateway if needed:

```bash
hermes gateway restart --system
hermes gateway status --system
```

Use the system gateway consistently so Discord/API traffic and CLI checks read the same Hermes config.

## Verification

From the Hindsight LXC:

```bash
docker ps --filter name=hindsight
curl -fsS http://127.0.0.1:8888/health
curl -fsS http://127.0.0.1:8888/docs >/dev/null
curl -I http://127.0.0.1:9999/dashboard
```

Expected health response:

```json
{"status":"healthy","database":"connected"}
```

From Hermes or another LXC on the LAN:

```bash
curl -fsS http://192.168.1.111:8888/health
```

Then test through Hermes:

1. Retain a test memory from Hermes.
2. Recall/search the same memory.
3. Restart Hindsight:

   ```bash
   docker restart hindsight
   ```

4. Confirm the memory still exists.
5. Back up and restore `/root/.hindsight-docker`, then repeat recall.

## Backup and restore

Stop the container before a consistent filesystem backup:

```bash
docker stop hindsight
tar -C /root -czf /root/hindsight-pg0-backup.tgz .hindsight-docker
docker start hindsight
```

Restore on a fresh LXC:

```bash
docker stop hindsight 2>/dev/null || true
rm -rf /root/.hindsight-docker
tar -C /root -xzf /root/hindsight-pg0-backup.tgz
docker start hindsight
curl -fsS http://127.0.0.1:8888/health
```

## Troubleshooting

### Hindsight API is healthy but retain/extract logs show provider errors

Live logs showed errors like:

```text
Provider gemini circuit breaker is open
HTTP 503 provider_circuit_open
```

That means Hindsight itself and its database can be healthy, but the configured LLM provider behind OmniRoute is unavailable or rate-limited.

Check:

```bash
docker logs --tail 100 hindsight
curl -fsS http://192.168.1.109:20128/v1/models
```

Then either wait for the provider circuit breaker to recover or change `HINDSIGHT_API_LLM_MODEL` / OmniRoute provider settings.

### Container lost memory after rebuild

Most likely `/root/.hindsight-docker` was not restored or not mounted into `/home/hindsight/.pg0`.

Verify:

```bash
docker inspect hindsight --format '{{range .Mounts}}{{println .Source "->" .Destination}}{{end}}'
du -sh /root/.hindsight-docker
```
