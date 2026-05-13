# Next Chat Handoff

> Last updated: 2026-05-13. This note is intentionally short and only covers context that is easy to miss from `CLAUDE.md`, `DOCS_INDEX.md`, `MASTERPLAN.md`, and `DEVLOG.md`.

## Current State

- Current branch is `master`.
- `asset_generator/` is intentionally a separate external-agent workspace. Leave it untracked unless the user explicitly asks to integrate it.
- A local commit from the previous session may still need pushing if `git status` shows the branch ahead of `origin/master`: `refactor: split menu icon factory`.
- Release should remain paused. The user asked to continue version-to-version work without GitHub releases unless they explicitly request a release.
- Documentation routing was reset on 2026-05-13:
  - Read `CLAUDE.md` → `docs/HANDOFF.md` → `docs/DOCS_INDEX.md` → `docs/MASTERPLAN.md` by default.
  - Historical long docs are preserved under `docs/archive/` and `docs/devlog/`, but should not be loaded by default.
  - `docs/ASSET_GENERATION_PROMPTS.md` may exist as a local-only copy-ready prompt scratch file; it is intentionally untracked unless requested.

## Recent Work Rhythm

- Work has been proceeding as small v1.10 Main slimdown boundaries.
- Each completed slice should normally run:
  - `git diff --check`
  - `.\Godot_v4.6.2-stable_win64_console.exe --path . --headless --quit`
  - `python tools\simulate_matches.py 1`
- Repeated simulation runs are not required for these narrow refactors unless a gameplay path changes.
- `AssetCatalog: 7 configured asset paths are missing; fallbacks remain active.` is expected while audio assets are still missing.

## User Preferences To Preserve

- Keep changes incremental and commit/push after each verified step.
- Do not commit `asset_generator/`.
- Prefer improving expansion infrastructure over adding big gameplay features immediately.
- For UI/help/config text, avoid duplicating static data in `Main.gd`; catalog/helper boundaries are acceptable if they reduce the amount of Main code needed for simple edits.
- Use Korean for user-facing progress updates and summaries.

## Good Next Candidates

- Continue v1.10 Main slimdown only if the work remains low-risk:
  - `MenuController` extraction for menu/records/help/settings orchestration.
  - `MatchBootstrap` extraction for config load, difficulty setup, seed/map bootstrapping.
  - Small UI helper/catalog extractions if they remove isolated static data from `Main.gd`.
- v1.10.x Item/Asset Readability Polish is now explicitly tracked in `docs/MASTERPLAN.md`:
  - pickup label LOD,
  - lower common pickup glow,
  - focused pickup clarity,
  - AssetCatalog fallback/export checks.
- Avoid moving gameplay state ownership out of Main yet. `zone`, `mission_tracker`, `player_ref`, `alive_count`, and Telemetry hooks should stay single-source until a broader controller boundary is explicitly planned.

## Push Note

If push is blocked by safety review, confirm with the user that pushing to `origin` at `https://github.com/Kyulhee/battle-capsule.git` is approved, then retry `git push`.
