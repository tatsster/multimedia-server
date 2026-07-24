---
name: software-development-maintenance
description: "Debug, review, simplify, and maintain code: systematic root-cause debugging plus parallel cleanup/review workflows."
version: 1.0.0
author: Hermes Agent
license: MIT
platforms: [linux, macos, windows]
metadata:
  hermes:
    tags: [software-development, debugging, code-review, refactor, cleanup, root-cause, simplify, delegation, testing]
    related_skills: [test-driven-development, plan]
---

# Software Development Maintenance

## Umbrella scope

Use this class-level skill for maintaining existing code: debugging failures, tracing root causes, reviewing recent changes, simplifying diffs, refactoring safely, and verifying fixes with tests. It absorbs the former narrow `systematic-debugging` and `simplify-code` skills.

Load this when the user asks to fix a bug, investigate a failing test/build, review recent changes, simplify code, clean up a diff, or run a pre-commit quality pass.

## Core rule: understand before changing

Never guess at fixes. For bugs and failures, complete the investigation loop first:

1. Read the full error, stack trace, logs, and relevant source.
2. Reproduce the issue with the smallest reliable command.
3. Check recent changes and trace data flow to the source of the bad state.
4. Compare against working patterns in the same codebase.
5. Form and test a minimal hypothesis.
6. Only then patch the root cause and verify with a regression test or targeted check.

Red flags: "quick fix", "probably X", multiple unrelated edits at once, proposing fixes before reproducing, or attempting a fourth fix after three failed attempts. Stop and return to evidence gathering; after three failed fixes, question the architecture with the user.

## Debugging workflow

Use for test failures, production bugs, unexpected behavior, performance regressions, build failures, and integration issues.

Phase 1: root-cause investigation
- Read errors carefully; search for exact strings in the codebase.
- Reproduce consistently with the exact failing command.
- Inspect `git diff`, recent commits, and changed dependencies/config.
- In multi-component systems, add temporary diagnostics at boundaries to show where data changes.
- Trace upstream until you find where the bad value or behavior originates.

Phase 2: pattern analysis
- Find similar working examples in the repo.
- Read reference implementations completely before adapting them.
- Identify the specific difference between broken and working paths.

Phase 3: hypothesis testing
- State the hypothesis and the evidence that would prove/disprove it.
- Change one variable at a time.
- Prefer small repro scripts, focused tests, or instrumentation over broad edits.

Phase 4: implementation
- Add or identify a regression test first when practical.
- Patch the root cause, not the symptom.
- Run targeted tests for touched files, then relevant lint/type/build checks.
- If the fix fails, revert or isolate it before trying the next hypothesis.

## Parallel simplify/review workflow

Use when the user explicitly asks to "simplify", "review my code", "clean up my changes", or `/simplify`.

1. Identify the diff scope:
   - default: `git diff`
   - if empty: `git diff HEAD`
   - staged: `git diff --staged`
   - last commit: `git diff HEAD~1`
   - branch/PR: `git diff main...HEAD`
   - path-scoped: `git diff -- <path>`
2. If the diff is huge, ask to scope it down before sending it to multiple reviewers.
3. Launch up to three focused reviewers with the complete diff plus repo path:
   - Reuse: find duplicated functionality and existing helpers/constants/patterns.
   - Quality: find redundant state, parameter sprawl, copy-paste variation, leaky abstractions, stringly typed code.
   - Efficiency: find redundant work, missed concurrency, hot-path bloat, TOCTOU, leaks, broad reads.
4. Require evidence: `file:line -> problem -> suggested fix`, confidence ranked high/medium/low.
5. Aggregate results, dedupe overlaps, discard weak findings, resolve conflicts as correctness > user focus > readability/reuse > micro-performance.
6. Apply only worthwhile scoped fixes unless the user requested a dry run.
7. Verify with targeted tests and summarize applied vs skipped findings.

## Delegation prompts

For debugging subagents, ask them to investigate and report root cause only before fixing:

```python
delegate_task(
    goal="Investigate why [specific test/behavior] fails",
    context="Follow software-development-maintenance: read the full error, reproduce, trace data flow, compare working patterns, and report root cause. Do not fix yet. Error: ... Test command: ...",
    toolsets=["terminal", "file", "search"]
)
```

For simplify reviewers, give each reviewer the complete diff and repo path, but a single lens: reuse, quality, or efficiency.

## Pitfalls

- Do not split a diff across reviewers; cross-file issues disappear.
- Do not accept reviewer guesses without repo evidence.
- Do not refactor the whole module under the banner of cleanup; keep edits close to touched code.
- Respect AGENTS.md, CLAUDE.md, HERMES.md, linters, and existing style.
- Do not run expensive multi-agent review automatically after every edit; only when asked.
- If debugging attempts keep revealing new shared-state/coupling problems, pause and discuss the architecture instead of piling on patches.
