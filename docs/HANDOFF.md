# Next Chat Handoff

> Last updated: 2026-06-01. Short context only; read `CLAUDE.md`, `DOCS_INDEX.md`, `MASTERPLAN.md`, and `IMPACT_MAP.md` before code changes.

## Current State

- Branch: `master`.
- Latest completed slice: `v2.0.8 — conservative 60-bot scale feasibility`.
- Next structural slice: `v2.0.9 — 60-bot telemetry repeat and AI LOD decision`.
- Release remains paused. Continue version-to-version development unless the user explicitly asks for a release.
- Expected Godot startup warning remains: `AssetCatalog: 7 configured asset paths are missing; fallbacks remain active.`
- `asset_generator/` is an external source pool and must stay untracked unless selected files are promoted into runtime assets.
- `docs/ASSET_GENERATION_PROMPTS.md` is local prompt scratch and should stay untracked unless the user asks to publish it.
- `docs/ASSET_STATUS.md` is now the concise asset-state handoff document.

## Recent Completed Commits

- `a7c23bf feat: promote remaining artifact icons` — Escape Capsule and Ghost Grass PNGs were normalized, cataloged, and verified as real artifact icon paths.
- `d445692 docs: sync asset and v2 handoff` — compacted handoff/devlog docs and added `ASSET_STATUS.md`.
- `14a1a33 feat: add map definition compatibility layer` — added `MapDefinition.gd` and validation tooling.
- `2e69bb7 feat: merge map definition scale presets` — added baseline/medium scale preset data and runtime merge support.
- `ada6ad4 feat: add read-only full map overlay` — added the read-only Full Map overlay and smoke verification.
- `7790567 test: expand map definition validation` — expanded MapDefinition validation for POI, obstacle, spawn/loot, and zone sanity checks.
- `8a24fbf refactor: extract settings manager` — moved settings persistence/audio/display mutation into `SettingsManager.gd`.
- `2cf1365 test: add large scale preset smoke` — added and smoked the conservative `large_40` scale preset.
- `5c0d21a feat: add map definition position queries` — added MapDefinition world-position query helpers and connected Minimap/FullMapOverlay to them.
- Current v2.0.8 slice adds and smokes the conservative `xlarge_60` scale preset.

Earlier v1.12 work added Emergency Shell/Escape Capsule, Ghost Grass, player artifact runtime state, artifact visuals, compact artifact selection UI, raw PNG icon loading, bush GLB visuals, restored bush interaction semantics, and bush visual feedback. Full recent detail is in `DEVLOG.md` and `devlog/v1.12.md`.

## Recommended Next Slice

`v2.0.9 — 60-bot telemetry repeat and AI LOD decision`

- Keep `Main.gd` as match-global orchestrator.
- Run repeated `scale_preset=xlarge_60` simulations and inspect duration, combat plans, zero-damage/zero-shot sentinels, recover/disengage volume, and early upgrade timing.
- Decide whether to add AI LOD, spawn distribution, or loot distribution work before any 99-player preset.
- Keep 99-player tuning blocked until 60-bot telemetry is stable across repeated runs.

## Asset Notes

- All six starting artifact icons are integrated.
- Bush GLBs are integrated and visual-only; `Bush.tscn` Area3D remains gameplay authority.
- Generated tree/rock/log/landmark GLBs remain deferred. Promote them only as selected runtime assets and preserve explicit collision/cover authority.
- Deferred asset decisions are tracked in `ASSET_STATUS.md`.

## Tooling Note

The Windows shell sandbox may fail with `CreateProcessAsUserW failed: 1312`. If so, retry simple commands with `sandbox_permissions: "require_escalated"`.

## User Preferences

- Use Korean.
- Work in small verified slices: plan -> edit -> verify -> commit/push.
- Keep active docs compact; archive raw/full history.
- Prefer data/tuning/catalog boundaries over broad gameplay rewrites.
