# Next Chat Handoff

> Last updated: 2026-06-02. Short context only; read `CLAUDE.md`, `DOCS_INDEX.md`, `MASTERPLAN.md`, and `IMPACT_MAP.md` before code changes.

## Current State

- Branch: `master`.
- Latest completed slice: `v2.0.16 — candidate map runtime loading/smoke`.
- Next structural slice: `v2.0.17 — guarded 99-target candidate probe`.
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
- `1862a45 test: add 60 bot scale preset smoke` — added and smoked the conservative `xlarge_60` scale preset.
- `7fe0db9 docs: record 60 bot telemetry decision` — repeated 5 `xlarge_60` simulations and kept 99-player tuning blocked until distribution/telemetry gates are tightened.
- `cfb56ba test: add 60 bot telemetry gate` — retuned `xlarge_60` distribution and added the repeated scale telemetry gate.
- `6a45c8b feat: add ai update budget telemetry` — added sampled AI update-budget telemetry and analyzer/gate reporting without adding AI LOD behavior.
- `78667a5 tune 60 bot zone pacing` — added explicit progressive `xlarge_60` zone stage timings.
- `21e988a feat: add spawn distribution telemetry` — added spawn distribution telemetry and scale-gate reporting.
- `21e9eea feat: add target scale envelope` — added `scale_envelopes.target_99` as planning data, not a runtime preset.
- `27d9969 feat: add large map candidate` — added the non-default 180m candidate map and envelope validation.
- Current v2.0.16 slice adds `map_spec_path` CLI/test loading and `tools/verify_map_runtime_path.gd`; the candidate is runtime-smokable without becoming the default map.

Earlier v1.12 work added Emergency Shell/Escape Capsule, Ghost Grass, player artifact runtime state, artifact visuals, compact artifact selection UI, raw PNG icon loading, bush GLB visuals, restored bush interaction semantics, and bush visual feedback. Full recent detail is in `DEVLOG.md` and `devlog/v1.12.md`.

## Recommended Next Slice

`v2.0.17 — guarded 99-target candidate probe`

- Keep `Main.gd` as match-global orchestrator.
- Keep the default map unchanged; use `map_spec_path=res://data/mapSpec_large_candidate.json` for candidate-only testing.
- Current default-map 5-run `xlarge_60` telemetry passed with spawn distribution: placed=61/61, fallback=0.0/run, min nearest=3.5m, avg nearest=7.1m, avg attempts=1.5, saturation=0.24.
- Candidate-map 5-run `xlarge_60` telemetry passed: avg duration 99.7s, fallback=0.0/run, min nearest=3.5m, avg nearest=9.6m, saturation=0.12, no zero sentinels.
- `target_99` envelope is pinned at minimum 160m world / 72m spawn radius and preferred 180m world / 78m spawn radius.
- `data/mapSpec_large_candidate.json` now satisfies the preferred target envelope as data: 180m world, 78m spawn radius, 8.5m boundary margin, target_99 saturation=0.20.
- Next work may add a clearly named candidate-only 99-target probe preset, then run telemetry before any default/global promotion.
- Keep using `verify_large_map_candidate.gd`, `verify_map_runtime_path.gd`, candidate-path simulation, `analyze_results.py`, and `check_scale_telemetry.py` as scale gates.

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
