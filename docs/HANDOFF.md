# Next Chat Handoff

> Last updated: 2026-06-03. Short context only; read `CLAUDE.md`, `DOCS_INDEX.md`, `MASTERPLAN.md`, and `IMPACT_MAP.md` before code changes.

## Current State

- Branch: `master`.
- Latest completed slice: `v2.0.23 — 99-probe economy/combat tempo diagnosis`.
- Next structural slice: `v2.0.24 — candidate-only 99-probe loot/economy adjustment`.
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
- `2b0a07b feat: add candidate map runtime loading` — added `map_spec_path` CLI/test loading for non-default candidate smokes.
- `31a7bcc feat: add candidate 99 probe` — added candidate-only `target_99_probe` and verified 5-run telemetry.
- `051cb3a feat: add normalized scale analysis` — added per spawned entity/minute analyzer output and aggregate doctrine state mix.
- `d5ffb1a feat: add scale profile comparison` — added `out_dir=` support plus normalized 60-vs-99 comparison tooling.
- `6583693 feat: add scale pressure decision` — added pressure-decision output; no gameplay tuning or default/global 99 promotion was made.
- `ee8519b feat: add disengage reason telemetry` — persists DISENGAGE entries and reasons while preserving `disengage_triggered` as the existing outnumbered/legacy scale-gate metric.
- `bd2a805 docs: record reason-aware scale comparison` — recorded the fresh reason-aware 60-vs-99 candidate comparison.
- Current v2.0.23 slice adds economy tempo rows and tempo decision output; no gameplay tuning or default/global 99 promotion was made.

Earlier v1.12 work added Emergency Shell/Escape Capsule, Ghost Grass, player artifact runtime state, artifact visuals, compact artifact selection UI, raw PNG icon loading, bush GLB visuals, restored bush interaction semantics, and bush visual feedback. Full recent detail is in `DEVLOG.md` and `devlog/v1.12.md`.

## Recommended Next Slice

`v2.0.24 — candidate-only 99-probe loot/economy adjustment`

- Keep `Main.gd` as match-global orchestrator.
- Keep the default map unchanged; use `map_spec_path=res://data/mapSpec_large_candidate.json` for candidate-only testing.
- Current default-map 5-run `xlarge_60` telemetry passed with spawn distribution: placed=61/61, fallback=0.0/run, min nearest=3.5m, avg nearest=7.1m, avg attempts=1.5, saturation=0.24.
- Candidate-map 5-run `xlarge_60` telemetry passed: avg duration 99.7s, fallback=0.0/run, min nearest=3.5m, avg nearest=9.6m, saturation=0.12, no zero sentinels.
- Candidate-map 5-run `target_99_probe` telemetry passed: avg duration 129.4s, fallback=0.0/run, min nearest=3.5m, avg nearest=7.7m, saturation=0.20, AI avg=439.9us, no zero sentinels.
- Current 99-probe normalized output: damage=27.7, shots=3.35, plans=1.83, disengage=0.56, stuck=0.11, zone_fire=1.02, survival=1.24 per spawned entity/min.
- Current 99-probe state mix: ZONE_ESCAPE 26.0%, DISENGAGE 22.0%, CHASE 19.2%, ATTACK 18.9%, IDLE 14.0%.
- Fresh normalized comparison from `C:\tmp`: 99 vs 60 has duration +7.1s, spawn saturation +0.08, AI avg +123.9us, ZONE_ESCAPE +2.14pp, DISENGAGE +5.32pp.
- v2.0.20 pressure decision: spawn/pathing is not the current blocker; AI budget is not the current blocker; DISENGAGE pressure looks duration/exit-related rather than trigger-frequency-related; ZONE_ESCAPE should be reviewed after DISENGAGE exit behavior.
- v2.0.21 reason telemetry: `tactics.disengage_entries` is full DISENGAGE entry volume; `tactics.disengage_reasons` and `tactics.disengage_reasons_by_archetype` are persisted; `disengage_triggered` remains the existing outnumbered/legacy gate metric.
- v2.0.21 1-run smoke at `C:\tmp\game_dev_disengage_reason_smoke` confirmed persisted reason data and `check_scale_telemetry.py --min-runs 1` passed.
- v2.0.22 fresh reason-aware candidate sets:
  - `C:\tmp\game_dev_reason_candidate_60`: 5-run `xlarge_60`, avg duration 106.3s, first upgrade 12.8s, legacy disengage 79.2/run, entries 332.0/run, gate passed.
  - `C:\tmp\game_dev_reason_candidate_99`: 5-run `target_99_probe`, avg duration 148.0s, first upgrade 27.4s, legacy disengage 129.0/run, entries 461.4/run, gate passed.
- v2.0.22 comparison: 99 has DISENGAGE state +4.25pp but lower normalized entry/reason rates (entries/entity/min -1.20, survival_break -0.97, outnumbered -0.21), so outnumbered thresholds are not the first tuning target.
- Stronger 99 signal: duration +41.8s, first upgrade +14.5s, damage/entity/min -11.63, shots/entity/min -1.42, plans/entity/min -0.99.
- v2.0.23 tempo tooling: `compare_scale_profiles.py` now prints weapon/non-pistol/rare/heal/shield rates plus `Tempo decision`; `analyze_results.py` prints economy-normalized rows.
- v2.0.23 tempo result: weapon pickups/entity/min -0.15, non-pistol pickups/entity/min -0.07, rare pickups/entity/min -0.12 for 99 vs 60.
- Raw `target_99_probe` loot count is close to 60 density, so tune actual non-pistol/rare access and combat throughput rather than only raw loot count.
- `target_99` envelope is pinned at minimum 160m world / 72m spawn radius and preferred 180m world / 78m spawn radius.
- `data/mapSpec_large_candidate.json` now satisfies the preferred target envelope as data: 180m world, 78m spawn radius, 8.5m boundary margin, target_99 saturation=0.20.
- Next work should make a candidate-only `target_99_probe` loot/economy adjustment, then rerun the 5-run gates and reason/tempo-aware comparison.
- Keep using `verify_candidate_99_probe.gd`, `verify_large_map_candidate.gd`, `verify_map_runtime_path.gd`, candidate-path simulation, `analyze_results.py`, and `check_scale_telemetry.py` as scale gates.

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
