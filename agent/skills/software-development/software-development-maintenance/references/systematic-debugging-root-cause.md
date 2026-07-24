# Systematic debugging: root-cause reference

Source: former `systematic-debugging` skill, condensed as a support reference under `software-development-maintenance`.

## Iron law

No fixes before root cause investigation. Symptom fixes are failures.

## Phase 1: investigate

Checklist:
- Read every error, warning, and stack-frame path.
- Reproduce consistently with the smallest command.
- Check `git diff`, recent commits, dependency/config changes.
- Add diagnostics at component boundaries in multi-component systems.
- Trace bad values upstream until their origin is known.

Useful commands:

```bash
pytest tests/test_module.py::test_name -v --tb=long
git log --oneline -10
git diff
git log -p --follow src/problematic_file.py
```

Use `search_files` for error strings, function callers, and variable assignments. Use `read_file` for exact source context.

## Phase 2: patterns

Find similar working code in the same repo. Read reference implementations completely. Identify the exact difference between working and broken cases.

## Phase 3: hypothesis

State a testable hypothesis. Change one variable at a time. Prefer temporary instrumentation or a minimal repro over speculative patches.

## Phase 4: fix and verify

Write or identify a regression test, patch the root cause, and run targeted tests plus relevant lint/type/build checks.

## Rule of three

If three fixes fail, stop. Repeated failures that reveal new shared state or coupling usually mean an architectural issue. Discuss the architecture before attempting another patch.

## Red flags

- "Quick fix for now."
- "Just try X."
- Multiple changes before running tests.
- Proposing fixes before tracing data flow.
- Skipping a regression test when one is practical.
- Adapting a reference pattern without reading it completely.
