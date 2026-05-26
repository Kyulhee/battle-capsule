# Next Chat Handoff

> Last updated: 2026-05-26. This note is intentionally short and only covers context that is easy to miss from `CLAUDE.md`, `DOCS_INDEX.md`, `MASTERPLAN.md`, and `DEVLOG.md`.

## Current State

- Branch: `master`.
- Current roadmap line: `v1.11-dev` structurally closed; reopen only for concrete boundary bugs.
- Latest completed slice: `v1.11.36 — v1.11 closure decision and pressure snapshot boundary`.
- Next structural slice: `v1.12 planning — Complex Artifacts scope and first implementation candidate`.
- Release remains paused. Continue version-to-version development without GitHub releases unless the user explicitly asks for a release.
- `asset_generator/` is an external-agent workspace and must remain untracked unless the user explicitly asks to integrate selected files.
- `docs/ASSET_GENERATION_PROMPTS.md` is local-only prompt scratch material and must remain untracked unless the user explicitly asks otherwise.
- Expected warning during Godot startup: `AssetCatalog: 7 configured asset paths are missing; fallbacks remain active.`

## Exact Git State At Handoff

After the v1.11.36 push, expected local status is only the external-generation scratch area:

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
- `ef977a3 docs: audit boundary and documentation governance`
  - Added v1.11.34 role rules and active document budgets.
  - Scoped active docs compression as the immediate next structural slice.
  - Pushed to `origin/master`.
- `d0de216 docs: compress active planning logs`
  - Snapshotted full active docs before compression.
  - Compressed `MASTERPLAN.md`, `DEVLOG.md`, and `docs/devlog/v1.11.md` for default-session loading.
  - Pushed to `origin/master`.

## Current Discussion

The user agreed to the governance-first plan. v1.11.34 found no urgent runtime authority bug. v1.11.35 snapshotted and compressed the default-session roadmap/devlog files. v1.11.36 then closed the only concrete ownership leak found during the closure audit: Main now reads pressure descriptor reward/penalty/title through `MissionTracker.get_active_pressure_snapshot()`.

Recommended next slice:

- `v1.12 planning — Complex Artifacts scope and first implementation candidate`
  - Choose one artifact with bounded state, UI, Telemetry, and balance impact.
  - Define the data/config boundary before implementation.
  - Keep the first v1.12 slice design-first unless a tiny prerequisite is obvious.

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

- `v1.12 planning — Complex Artifacts scope and first implementation candidate`
  - Likely docs/design first.
- Narrow v1.10.x item/asset readability polish
  - Only visual/readability patches; do not change expansion architecture.
- Later v1.11 candidates:
  - Reopen only for concrete boundary bugs or stale doc routes.
  - Avoid large JSON/resource migration until new mission/content expansion requires it.
