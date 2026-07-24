---
name: homepage-service-widget-management
description: Add or remove Homepage service widgets in T4tsster's homelab, update the live liftlab.dev Homepage config, and sync the GitHub repository too.
usage_hint: "Trigger on: homepage widget, homepage service, liftlab.dev dashboard, add widget, remove widget, service card, update homepage repo. Always update both live config and GitHub."
metadata:
  trigger_text:
    - homepage widget
    - homepage service
    - liftlab.dev dashboard
    - add widget
    - remove widget
    - service card
    - update homepage repo
---

# Homepage service widget management

Use this when T4tsster asks to add, remove, or change a service/widget in Homepage for the homelab / `liftlab.dev`.

## Goal

Keep **both** sources in sync:

1. The live Homepage config used by `https://liftlab.dev`.
2. The GitHub repository config/docs, currently `tatsster/multimedia-server` under the `dashboards/homepage/` directory.

Do not stop after changing only the repository; the live Homepage LXC/CT config may still show stale widgets until it is edited and Homepage is restarted.

## Procedure

1. **Clarify the requested service change if needed**
   - Service name.
   - Whether to add, remove, or modify.
   - Widget type/API details if adding.
   - Whether it should be an iframe widget where possible, because the user prefers fewer exposed ports and iframe embeds when suitable.

2. **Update the GitHub repository**
   - Work in the repo containing Homepage config, usually `tatsster/multimedia-server`.
   - Edit relevant files under `dashboards/homepage/`, commonly:
     - `dashboards/homepage/services.yaml`
     - `dashboards/homepage/widgets.yaml` if applicable
     - `dashboards/homepage/.env.example` for new/removed API tokens, URLs, usernames, or passwords
     - `dashboards/homepage/Readme.md` for docs/service lists/env tables
   - For removals, delete stale service blocks and unused env vars/docs.
   - For additions, add the service block, widget block/config, required env placeholders, and README documentation.

3. **Validate repository config**
   - Run YAML validation for Homepage YAML files, for example:
     ```bash
     python3 - <<'PY'
     import glob, yaml
     for f in glob.glob('dashboards/homepage/*.yaml'):
         with open(f) as fh:
             yaml.safe_load(fh)
         print('OK', f)
     PY
     ```
   - Search for stale references after removals:
     ```bash
     rg -i 'SERVICE_NAME|service_slug' homepage
     ```
     Use the repo search tool instead of shell search when operating through Hermes tools.

4. **Commit and push the repository change**
   - Review diff:
     ```bash
     git diff -- homepage
     git status --short
     ```
   - Commit with a clear message, e.g.:
     ```bash
     git add homepage
     git commit -m "Update Homepage service widgets"
     git push origin main
     ```
   - Report the commit hash to the user.

5. **Update the live Homepage CT/LXC config safely**
   - The live config path previously used for `liftlab.dev` was:
     ```text
     /opt/dashboards/homepage/config/services.yaml
     ```
   - Connect to the homelab/PVE/CT using the established environment/session access available at the time.
   - **Do not blindly copy the repo file over the live file.** The live config may contain newer env-var names, local-only secrets/placeholders, or ordering/grouping that is not yet reflected in Git. Prefer a minimal targeted edit to the live file.
   - Before editing, back up the live file and inspect the live `.env` variable names used by existing widgets:
     ```bash
     cp /opt/dashboards/homepage/config/services.yaml /opt/dashboards/homepage/config/services.yaml.bak.$(date +%Y%m%d-%H%M%S)
     grep -o 'HOMEPAGE_VAR_[A-Z0-9_]*' /opt/dashboards/homepage/config/services.yaml | sort -u
     grep -o 'HOMEPAGE_VAR_[A-Z0-9_]*' /opt/dashboards/homepage/config/.env | sort -u
     ```
   - Preserve existing working widget credential variable names exactly. In this homelab, known live names include:
     ```text
     HOMEPAGE_VAR_PROXMOXVE_TOKEN
     HOMEPAGE_VAR_PROXMOXBACKUP_TOKEN
     HOMEPAGE_VAR_QBIT_URL
     HOMEPAGE_VAR_QBIT_USERNAME
     HOMEPAGE_VAR_QBIT_PASSWORD
     ```
     Do not replace them with stale repo/example names such as `*_PASSWORD` or qBittorrent dashboard-token names unless the live `.env` actually uses those names.
   - Edit the live Homepage config to match only the requested service change. If moving a service between groups, remove the now-empty group; for this dashboard, Beszel belongs under `Services`, not a separate `Monitoring` group.
   - If other live config files are involved, update them too, e.g.:
     ```text
     /opt/dashboards/homepage/config/widgets.yaml
     /opt/dashboards/homepage/config/settings.yaml
     /opt/dashboards/homepage/config/bookmarks.yaml
     /opt/dashboards/homepage/config/.env
     ```
   - Do not expose extra ports unless the user explicitly asks; prefer reverse proxy or iframe embedding where applicable.

6. **Restart Homepage on the live host**
   - Restart the Homepage service/container. Previously this worked:
     ```bash
     systemctl restart homepage
     ```
   - If systemd is not used in the current deployment, inspect the deployment and restart the relevant Docker/PM2/service process.

7. **Verify live site**
   - Check Homepage API output:
     ```bash
     curl -s https://liftlab.dev/api/services
     ```
   - Confirm removed services no longer appear, or added services do appear.
   - Optionally use the browser tool to load `https://liftlab.dev` and inspect the page/DOM.
   - If the user still sees an old widget after verification passes, suggest hard refresh / clearing site data for `liftlab.dev`.

## Pitfalls

- Updating GitHub alone is not enough; the live CT may use a separate config copy.
- Always remove/update matching docs and `.env.example` entries so the repo does not advertise stale services.
- Verify against `https://liftlab.dev/api/services`; visual Homepage cards can be affected by browser cache.
- For removals, search case-insensitively for both display name and slug, e.g. `Mealie` and `mealie`.
- For additions, do not commit real secrets. Use placeholders in `.env.example` and configure real values only in the live `.env`/secret store.

## Reporting format

Tell the user:

- What service/widget changed.
- Which repo files changed.
- Whether the live config was updated and Homepage restarted.
- Verification results from `https://liftlab.dev/api/services` or browser check.
- Commit hash pushed to GitHub.
