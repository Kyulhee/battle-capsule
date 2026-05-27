# Next Chat Handoff

> Last updated: 2026-05-27. This note is intentionally short and only covers context that is easy to miss from `CLAUDE.md`, `DOCS_INDEX.md`, `MASTERPLAN.md`, and `DEVLOG.md`.

## Current State

- Branch: `master`.
- Current roadmap line: `v1.12-dev` Complex Artifacts, starting with bounded player-runtime effects.
- Latest completed slice: `v1.12.2 — Emergency Shell first implementation`.
- Next structural slice: `v1.12.3 — Emergency Shell playtest/readability check or next artifact shortlist`.
- Release remains paused. Continue version-to-version development without GitHub releases unless the user explicitly asks for a release.
- `asset_generator/` is an external-agent workspace and must remain untracked unless the user explicitly asks to integrate selected files.
- `docs/ASSET_GENERATION_PROMPTS.md` is local-only prompt scratch material and must remain untracked unless the user explicitly asks otherwise.
- Expected warning during Godot startup: `AssetCatalog: 7 configured asset paths are missing; fallbacks remain active.`

## Exact Git State At Handoff

After the v1.12.2 push, expected local status is only the external-generation scratch area:

```text
?? asset_generator/
?? docs/ASSET_GENERATION_PROMPTS.md
```

Do not stage `asset_generator/` or `docs/ASSET_GENERATION_PROMPTS.md` unless the user explicitly asks to integrate selected files.

## Recent Completed Commits

- `5365ebf refactor: close pressure snapshot boundary` — closed v1.11 structurally.
- `6f71fc5 docs: plan complex artifact runtime boundary` — opened v1.12 and selected Emergency Shell as the first implementation candidate.
- `1579ff3 feat: add emergency shell artifact` — implemented Emergency Shell, artifact runtime helper, artifact telemetry, and smoke verification.

Older v1.11 slice detail is in `docs/devlog/v1.11.md` and the full snapshots under `docs/devlog/`.

## Current Discussion

The user agreed to continue after v1.11 closure. v1.12.1 selected Emergency Shell as the first Complex Artifact. v1.12.2 implemented it with `PlayerArtifactRuntime.gd`, catalog-owned threshold/shield values, Player-owned damage-flow wiring, and artifact Telemetry metrics.

Recommended next slice:

- `v1.12.3 — Emergency Shell playtest/readability check or next artifact shortlist`
  - Confirm the selection card layout remains readable with five artifacts.
  - Review Emergency Shell feedback and balance values after manual play/screenshot if possible.
  - Decide whether to tune Emergency Shell or shortlist the next artifact.

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

- `v1.12.3 — Emergency Shell playtest/readability check or next artifact shortlist`
  - Prefer visual/manual-readability review before adding another runtime artifact.
- Narrow v1.10.x item/asset readability polish
  - Only visual/readability patches; do not change expansion architecture.
- Later v1.11 candidates:
  - Reopen only for concrete boundary bugs or stale doc routes.
  - Avoid large JSON/resource migration until new mission/content expansion requires it.
