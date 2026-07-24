# Simplify Code: parallel review recipe

Source: former `simplify-code` skill, condensed as a support reference under `software-development-maintenance`.

## Trigger

Use when the user explicitly says "simplify", "review my recent changes", "clean up my changes", or `/simplify`.

Optional modifiers:
- Focus: `reuse`, `quality`, or `efficiency`.
- Dry run: report findings without applying changes.
- Scope: staged changes, last commit, branch/PR diff, or named files.

## Diff selection

```bash
git diff                 # default working-tree changes
git diff HEAD            # include staged if working-tree diff is empty
git diff --staged        # staged only
git diff HEAD~1          # last commit
git diff main...HEAD     # branch / PR
git diff -- src/foo.py   # named paths
```

If no git diff exists, fall back to explicitly named or recently edited files. If there is no changed code, stop.

## Three reviewer lenses

Give every reviewer the complete diff and absolute repo path. Require repo searches and concrete evidence.

### Reuse

Find code that duplicates existing helpers, utilities, constants, registries, or patterns. Flag hand-rolled parsing/string/path/env/type logic when a repo primitive exists.

### Quality

Find redundant state, parameter sprawl, copy-paste-with-variation, leaky abstractions, raw strings where constants/enums/registries exist, and refactors that reduce complexity without broad churn.

### Efficiency

Find redundant computation, repeated file reads/API calls, N+1 access patterns, missed concurrency, startup/hot-path bloat, TOCTOU existence checks, memory/listener leaks, and broad reads where slices would do.

## Aggregation rules

- Dedupe overlapping findings.
- Drop weak findings without debate.
- Resolve conflicts by: correctness > stated user focus > readability/reuse > micro-performance.
- Apply scoped fixes only; this is not permission to rewrite whole modules.
- Verify with targeted tests/lint/type checks.
