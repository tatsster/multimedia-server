---
name: github-workflows
description: "Class-level GitHub operations: auth, repositories, issues, PR lifecycle, CI, and reviews using gh or REST fallbacks."
version: 1.0.0
author: Hermes Agent
license: MIT
platforms: [linux, macos, windows]
metadata:
  hermes:
    tags: [GitHub, Git, Pull-Requests, Issues, Code-Review, CI, Repository-Management]
---

# GitHub Workflows

Use this umbrella when the user asks to work with GitHub: authenticate, clone/create/fork repositories, manage issues, open or merge PRs, inspect CI, or perform code review. Prefer `gh` when authenticated; otherwise use `git` plus `curl` with `GITHUB_TOKEN`.

## 1. Auth and environment setup

Start every GitHub task by detecting the available path:

```bash
if command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1; then
  AUTH=gh
else
  AUTH=curl
  if [ -z "$GITHUB_TOKEN" ]; then
    if [ -f ~/.agent/hermes/.env ] && grep -q '^GITHUB_TOKEN=' ~/.agent/hermes/.env; then
      export GITHUB_TOKEN=$(grep '^GITHUB_TOKEN=' ~/.agent/hermes/.env | head -1 | cut -d= -f2- | tr -d '\r\n')
    elif [ -f ~/.git-credentials ] && grep -q github.com ~/.git-credentials; then
      export GITHUB_TOKEN=$(grep github.com ~/.git-credentials | head -1 | sed 's|https://[^:]*:\([^@]*\)@.*|\1|')
    fi
  fi
fi
```

If auth is missing, guide the user through either `gh auth login`, token login (`echo TOKEN | gh auth login --with-token`), HTTPS PAT credential storage, or SSH key setup. Configure `git config --global user.name` and `user.email` before committing.

## 2. Repository management

Use for cloning, creating, forking, remotes, repo settings, releases, secrets, Actions workflows, and gists.

- Clone with `gh repo clone owner/repo` or `git clone https://github.com/owner/repo.git`.
- Create with `gh repo create ...` or `POST /user/repos` / `POST /orgs/{org}/repos`.
- Fork with `gh repo fork ... --clone` or `POST /repos/{owner}/{repo}/forks`, then add `upstream`.
- Manage Actions with `gh workflow`, `gh run`, or REST endpoints under `/actions`.
- Create releases with `gh release create` or `POST /repos/{owner}/{repo}/releases`.

## 3. Issues and triage

Use for creating, viewing, labeling, assigning, commenting, closing, and bulk-triaging issues. Remember that the GitHub `/issues` API returns PRs too; filter entries with a `pull_request` field when you need issues only.

Bug report skeleton:

```md
## Bug Description
## Steps to Reproduce
## Expected Behavior
## Actual Behavior
## Environment
```

Feature request skeleton:

```md
## Feature Description
## Motivation
## Proposed Solution
## Alternatives Considered
```

For triage: list `needs-triage`, read context, categorize, label priority/type, assign if clear, and comment with rationale.

## 4. PR lifecycle

Typical flow:

1. `git fetch origin && git checkout main && git pull origin main`
2. Create a branch (`feat/...`, `fix/...`, `refactor/...`, `docs/...`, `ci/...`).
3. Make changes with file tools; commit using Conventional Commits.
4. `git push -u origin HEAD`.
5. Open PR with `gh pr create` or `POST /pulls`.
6. Monitor CI with `gh pr checks --watch`, `gh run view --log-failed`, or REST status/check-runs endpoints.
7. Fix CI in a bounded loop: inspect logs, patch, commit, push, re-check; stop after repeated failures and report.
8. Merge with `gh pr merge --squash --delete-branch` or `PUT /pulls/{number}/merge`.

## 5. Code review

For local review, first inspect `git diff --stat`, `git log main..HEAD --oneline`, then changed files and full context. Check correctness, security, tests, performance, maintainability, docs, secrets, conflict markers, and large accidental files.

For PR review:

1. Fetch PR metadata, changed files, checks, and diff.
2. Check out the PR locally (`gh pr checkout N` or `git fetch origin pull/N/head:pr-N`).
3. Run relevant automated checks if safe.
4. Submit structured findings grouped as Critical, Warnings, Suggestions, Looks Good.
5. Choose verdict: approve only when no blocking issues; request changes for critical/warning issues; comment for non-blocking observations.

## 6. Owner/repo extraction helper

```bash
REMOTE_URL=$(git remote get-url origin)
OWNER_REPO=$(echo "$REMOTE_URL" | sed -E 's|.*github\.com[:/]||; s|\.git$||')
OWNER=$(echo "$OWNER_REPO" | cut -d/ -f1)
REPO=$(echo "$OWNER_REPO" | cut -d/ -f2)
```

## 7. Support-file preservation notes from absorbed skills

The absorbed narrow skills had useful support files (PR templates, issue templates, review output template, API cheatsheet, CI troubleshooting notes, auth helper script). If more detailed recipes are needed, restore those archived packages or re-home the files into this umbrella's `references/`, `templates/`, and `scripts/` directories before relying on relative links.
