# OmniRoute LXC Setup

OmniRoute is the OpenAI-compatible AI gateway used by Hermes.

Current homelab pattern:

```text
Hermes -> http://<omniroute-lxc-ip>:20128/v1 -> AI providers/models
```

Current model used by Hermes:

```text
codex/gpt-5.5-medium
```

## LXC requirements

Create the LXC using the same defaults as the rest of this homelab:

- nesting enabled
- privileged container / `Unprivileged container=No`
- CPU advanced settings same as current guide
- persistent storage for OmniRoute data

OmniRoute uses SQLite and stores data under `DATA_DIR` if configured, otherwise usually under:

```text
~/.omniroute/storage.sqlite
```

For Docker deployment, the project documents this volume:

```text
/app/data
```

Recommended: set an explicit data directory/volume and back it up.

## Install options

The upstream README documents two common install methods.

### npm

```bash
npm install -g omniroute
omniroute
```

### Docker

```bash
docker run -d \
  --name omniroute \
  --restart unless-stopped \
  --stop-timeout 40 \
  -p 20128:20128 \
  -v omniroute-data:/app/data \
  diegosouzapw/omniroute:latest
```

Default endpoints:

```text
Dashboard: http://<omniroute-lxc-ip>:20128
API:       http://<omniroute-lxc-ip>:20128/v1
```

## Recommended first setup

1. Start OmniRoute.
2. Open Dashboard:

```text
http://<omniroute-lxc-ip>:20128
```

3. Complete onboarding / set admin password.
4. Add at least one provider/account.
5. Go to Dashboard → Endpoints/API Keys.
6. Create an API key for Hermes.
7. Put that key into Hermes config as `${OMNIROUTE_API_KEY}`.

## Headless/onboarding workaround

If onboarding cannot start from the web dashboard, current upstream code supports a bootstrap path using `INITIAL_PASSWORD`.

Relevant upstream behavior found in OmniRoute source:

- `src/lib/db/settings.ts`
  - `getSettings()` auto-completes onboarding when `process.env.INITIAL_PASSWORD` is set:
    - `setupComplete = true`
    - `requireLogin = true`
- `src/lib/auth/managementPassword.ts`
  - startup hashes `INITIAL_PASSWORD` with bcrypt
  - stores the hash in the `key_value` table under namespace `settings`, key `password`

So the safest workaround is usually:

```bash
export INITIAL_PASSWORD='<new-admin-password>'
omniroute
```

or for Docker:

```bash
docker run -d \
  --name omniroute \
  --restart unless-stopped \
  -p 20128:20128 \
  -e INITIAL_PASSWORD='<new-admin-password>' \
  -v omniroute-data:/app/data \
  diegosouzapw/omniroute:latest
```

Then restart normally after the password hash has been written.

## SQLite password/onboarding DB notes

OmniRoute SQLite DB path depends on deployment:

| Deployment | Likely DB path |
|---|---|
| npm/root user | `/root/.omniroute/storage.sqlite` |
| npm/non-root user | `~/.omniroute/storage.sqlite` |
| explicit env | `$DATA_DIR/storage.sqlite` |
| Docker volume | `/app/data/storage.sqlite` inside container/volume |

The management password and onboarding flags live in the `key_value` table:

```sql
SELECT namespace, key, value
FROM key_value
WHERE namespace = 'settings'
  AND key IN ('password', 'setupComplete', 'requireLogin');
```

The values are JSON strings. `setupComplete` and `requireLogin` are stored as JSON booleans, usually text `true`. `password` should be a JSON string containing a bcrypt hash.

### Manual DB update method

Use this only if `INITIAL_PASSWORD` does not work. Stop OmniRoute first and back up the DB.

1. Stop OmniRoute.
2. Back up DB:

```bash
cp /path/to/storage.sqlite /path/to/storage.sqlite.bak.$(date +%Y%m%d-%H%M%S)
```

3. Generate bcrypt hash. From the OmniRoute source, salt rounds are `12`.

Example using Node in an OmniRoute install with `bcryptjs` available:

```bash
node -e 'const bcrypt=require("bcryptjs"); bcrypt.hash(process.argv[1],12).then(h=>console.log(JSON.stringify(h)))' '<new-admin-password>'
```

The output includes quotes because OmniRoute stores JSON values in `key_value.value`.

4. Update SQLite:

```bash
sqlite3 /path/to/storage.sqlite <<'SQL'
INSERT OR REPLACE INTO key_value(namespace, key, value)
VALUES ('settings', 'setupComplete', 'true');
INSERT OR REPLACE INTO key_value(namespace, key, value)
VALUES ('settings', 'requireLogin', 'true');
INSERT OR REPLACE INTO key_value(namespace, key, value)
VALUES ('settings', 'password', '"<bcrypt-hash-here>"');
SQL
```

Important: if your generated hash command already printed a quoted JSON string, paste it as the value. Example:

```sql
VALUES ('settings', 'password', '"$2a$12$..."');
```

5. Start OmniRoute and log in with the new password.

## Verify

```bash
curl http://<omniroute-lxc-ip>:20128
curl http://<omniroute-lxc-ip>:20128/v1/models \
  -H 'Authorization: Bearer <omniroute-api-key>'
```

Then verify Hermes points to OmniRoute:

```bash
hermes config get model
```

Expected:

```text
base_url: http://<omniroute-lxc-ip>:20128/v1
model: codex/gpt-5.5-medium
```

## Secrets and where to get them

Do not commit these values.

| Secret | Where to create/get it |
|---|---|
| OmniRoute admin password | Choose during onboarding or set via `INITIAL_PASSWORD` |
| Hermes API key for OmniRoute | OmniRoute Dashboard → Endpoints/API Keys |
| Provider OAuth/API keys | OmniRoute Dashboard → Providers |
