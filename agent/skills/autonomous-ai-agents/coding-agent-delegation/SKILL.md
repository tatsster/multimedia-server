---
name: coding-agent-delegation
description: "Class-level delegation to coding CLIs and autonomous agents: Claude Code, Codex, OpenCode, and Kanban Codex lanes."
version: 1.0.0
author: Hermes Agent
license: MIT
platforms: [linux, macos, windows]
metadata:
  hermes:
    tags: [Autonomous-Agents, Claude-Code, Codex, OpenCode, Kanban, Delegation]
---

# Coding Agent Delegation

Use this umbrella when a coding task should be delegated to an external coding CLI or isolated implementation lane while Hermes retains responsibility for requirements, safety, testing, and final verification.

## General delegation rules

1. Start with a precise task statement, repo path, acceptance criteria, constraints, and files likely in scope.
2. Keep Hermes as owner of task lifecycle: review plans, inspect diffs, run tests, and verify side effects yourself.
3. Prefer isolated branches/worktrees for risky work.
4. Require the agent to return verifiable artifacts: changed paths, commands run, test output, commit hash, PR URL, or failure log.
5. Never trust a child agent's self-report without checking files, git status, and tests.

## Claude Code

Use Claude Code CLI for feature implementation, refactors, and PR work when it is installed and authenticated. Give it a bounded scope and make it report a patch/summary rather than letting it own merges or deployments. Avoid using it for tasks requiring user interaction unless you can supervise via PTY.

## OpenAI Codex CLI

Use Codex CLI for isolated coding lanes, feature spikes, or implementation attempts. Provide explicit context and test commands. Reconcile its output with normal file tools and git inspection.

## OpenCode

Use OpenCode as another implementation/review lane for code changes or PR review. The same verification rules apply: inspect diffs, run tests, and do not accept unverifiable completion claims.

## Kanban Codex lane

When operating as a Hermes Kanban worker, a Codex lane can implement a card while Hermes manages card lifecycle, reconciliation, and handoff. Keep prompts self-contained and include the card goal, current branch/workdir, acceptance criteria, and expected handoff format.

If the original `kanban-codex-lane` package's prompt template is needed, restore or re-home its archived `templates/pmb-codex-lane-prompt.md` into this umbrella before referencing it.
