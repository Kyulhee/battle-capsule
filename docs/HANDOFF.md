# Next Chat Handoff

> Last updated: 2026-05-26. This note is intentionally short and only covers context that is easy to miss from `CLAUDE.md`, `DOCS_INDEX.md`, `MASTERPLAN.md`, and `DEVLOG.md`.

## Current State

- Branch: `master`.
- Current roadmap line: `v1.11-dev` subsystem directory + non-Main data/algorithm boundaries.
- Release remains paused. Continue version-to-version development without GitHub releases unless the user explicitly asks for a release.
- `asset_generator/` is an external-agent workspace and must remain untracked unless the user explicitly asks to integrate selected files.
- `docs/ASSET_GENERATION_PROMPTS.md` is local-only prompt scratch material and must remain untracked unless the user explicitly asks otherwise.
- Expected warning during Godot startup: `AssetCatalog: 7 configured asset paths are missing; fallbacks remain active.`

## Exact Git State At Handoff

After the v1.11.33 push, expected local status is only the external-generation scratch area:

```text
?? asset_generator/
?? docs/ASSET_GENERATION_PROMPTS.md
```

Do not stage `asset_generator/` or `docs/ASSET_GENERATION_PROMPTS.md` unless the user explicitly asks to integrate selected files.

## Recent Completed Commits

- `1e328f1 refactor: bind bonus mission descriptions`
  - Added `MissionTuning.gd` and `MissionDescriptionFormatter.gd`.
  - Bonus mission descriptions/HUD/evaluation now read from `MissionData.target_value` and shared tuning values.
  - Pushed to `origin/master`.
- `3cd4966 refactor: generate pressure mission descriptions`
  - Added `PressureMissionDescriptionFormatter.gd`.
  - Pressure descriptor `description` text now generates from `conditions[]`.
  - Pushed to `origin/master`.
- `b0df82f refactor: extract pressure feasibility tuning`
  - Added pressure feasibility cutoff ownership to `MissionTuning.gd`.
  - `PressureConditionEvaluator.gd` now reads detected-survival and late-zone outside-zone feasibility cutoffs from shared tuning.
  - Pushed to `origin/master`.

## Current Discussion

The user wants to pause before continuing new gameplay work and review two cross-cutting issues:

1. Whether the v1.10-v1.11 data/algorithm boundary work is coherently progressing or becoming scattered.
2. Whether recurring session docs (`MASTERPLAN.md`, `DEVLOG.md`, per-version devlogs) have grown too long and need a raw-log + compressed-active-doc workflow.

Recommended next slice:

- `v1.11.34 — Boundary and Documentation Governance Review`
  - Audit v1.10-v1.11 extracted helpers by role: config/tuning, catalog/data, formatter/presentation, evaluator/algorithm, controller/director orchestration.
  - Identify duplicated authority, Main-owned state that should stay vs move, and any modules whose names/responsibilities drifted.
  - Define active-doc length budgets and archive/raw-log routing before more slices add documentation weight.

## Tooling Note

The current Windows shell sandbox has repeatedly failed direct shell execution with:

```text
CreateProcessAsUserW failed: 1312
```

Because of that, even simple reads/status checks have needed `sandbox_permissions: "require_escalated"`. Automatic approval review sometimes times out, especially for parallel escalated calls. Use sequential shell commands, not parallel shell batches, until the session/runner is restarted or the sandbox issue clears.

Good command pattern:

- Run one shell command at a time.
- Prefer simple prefixes: `git status`, `git diff`, `git add`, `git commit`, `git push`, `rg`, `python tools\simulate_matches.py`, Godot headless.
- If an approval review times out, retry the same simple command once before changing approach.

## User Preferences To Preserve

- Use Korean for progress updates and summaries.
- Continue small, verified slices: plan -> edit -> verify -> commit/push -> devlog.
- Prioritize expansion readiness and data/algorithm boundaries before large new gameplay features.
- Keep `Main.gd` as orchestrator and state owner unless there is a dedicated migration plan.
- Avoid duplicated gameplay numbers in UI/descriptions; prefer shared tuning/catalog/formatter boundaries.
- Do not commit local external-generation scratch files unless explicitly requested.

## Good Next Candidates

- `v1.11.34 — Boundary and Documentation Governance Review`
  - Likely docs-first unless a small authority conflict is found.
  - Should produce a short governance plan before more extraction work.
- Later v1.11 candidates:
  - Continue non-Main tuning/data boundary slices by domain.
  - Avoid large JSON/resource migration until new mission/content expansion requires it.
