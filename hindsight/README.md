# Hindsight LXC Setup

Hindsight is the memory backend used by Hermes.

Current Hermes config uses:

```yaml
memory:
  provider: hindsight
```

## LXC requirements

Use the standard homelab LXC defaults from `inventory/lxc-map.md`:

- privileged container / `Unprivileged container=No`
- nesting enabled if Docker or nested services are used
- persistent data directory for Hindsight memory/database

## Rebuild placeholders to fill from live system

| Item | Value |
|---|---|
| CT ID | TBD |
| IP | TBD |
| Port | TBD |
| Data directory | TBD |
| Service manager | TBD |
| Health endpoint | TBD |

## Integration with Hermes

After Hindsight is installed and running, verify Hermes has memory enabled and provider set to Hindsight:

```bash
hermes config get memory
hermes config set memory.provider hindsight
```

Restart Hermes/gateway if needed:

```bash
hermes gateway restart
```

## Verification

1. Retain a test memory from Hermes.
2. Recall/search the same memory.
3. Restart Hindsight.
4. Confirm the memory still exists.
5. Back up and restore the data directory, then repeat recall.

## Secrets

Document any Hindsight API key or auth token here after confirming the live setup. Do not commit real values; add placeholders to `.env.example` or a config example instead.
