# Next Chat Handoff

> Last updated: 2026-06-03. Short context only; read `CLAUDE.md`, `DOCS_INDEX.md`, `MASTERPLAN.md`, and `IMPACT_MAP.md` before code changes.

## Current State

- Branch: `master`.
- Latest completed slice: `v2.0.32 — pickup location / recovery-exit source diagnostics`.
- Next structural slice: `v2.0.33 — POI target acquisition and route-overlap follow-up`.
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
- `9e11a5d feat: add scale tempo diagnostics` — adds economy tempo rows and tempo decision output.
- Current v2.0.24 slice adds candidate-only `target_99_probe` economy tuning; no default/global 99 promotion was made.
- `b44d9dd feat: add engagement density diagnostics` — adds engagement-density diagnostics; no gameplay tuning or default/global 99 promotion was made.
- `5fa689c feat: add route pressure telemetry` — adds combat-location / route-pressure telemetry; no gameplay tuning or default/global 99 promotion was made.
- Current v2.0.32 slice adds pickup location diagnostics; default map/global 99 promotion was not made.

Earlier v1.12 work added Emergency Shell/Escape Capsule, Ghost Grass, player artifact runtime state, artifact visuals, compact artifact selection UI, raw PNG icon loading, bush GLB visuals, restored bush interaction semantics, and bush visual feedback. Full recent detail is in `DEVLOG.md` and `devlog/v1.12.md`.

## Recommended Next Slice

`v2.0.33 — POI target acquisition and route-overlap follow-up`

- Keep `Main.gd` as match-global orchestrator.
- Keep the default map unchanged; use `map_spec_path=res://data/mapSpec_large_candidate.json` for candidate-only testing.
- v2.0.27 corrected the design target: do not tune bots to hit a CHASE combat percentage. Battle royale scale should verify strategic movement, contested routes, and power-position pressure first.
- v2.0.30 changed the candidate map to strategic gates:
  - Central Meadow radius/density reduced.
  - `West Ridge Overlook` and `East Pine Gate` added as transit-choke POIs.
  - West/East primary-choke route points now pass through those gates.
  - Only one offset high rock cover per gate remains; the first heavier-cover smoke failed on stuck triggers, so do not add more hard clutter without rerunning scale gates.
- v2.0.31 added CHASE location diagnostics only: CHASE self/target POI context, target route context, and target kind by `combat`, `loot`, and `recover_loot`.
- v2.0.31 fresh 5-run sets passed scale gates:
  - `C:\tmp\game_dev_chase_location_60_v2031`: avg duration 113.3s, first upgrade 13.3s, stuck 29.8/run, fallback 0.0/run.
  - `C:\tmp\game_dev_chase_location_99_v2031`: avg duration 140.9s, first upgrade 11.0s, stuck 48.6/run, fallback 0.0/run.
- v2.0.31 result: route pressure remains analyzable, but 99 active coverage is thinner while per-ATTACK efficiency is intact. `ATTACK+CHASE` is 40.5% -> 35.9%, damage/ATTACK min is 790.6 -> 904.2.
- CHASE recover-loot at 99 is anchored on recovery exits and mostly weapon/ammo access: recovery_exit 32.1%, weapon target 34.4%, ammo target 51.4%, heal target 7.1%, armor target 3.5%.
- Combat CHASE target POI pressure drops while target route pressure stays high: combat target POI 61.4% -> 55.3%, combat target route 73.5% -> 77.9%.
- v2.0.32 added pickup spawn/collection location diagnostics only: pickup spawn/collect POI role and route role by `weapon`, `ammo`, `heal`, and `armor`.
- v2.0.32 fresh 5-run sets passed scale gates:
  - `C:\tmp\game_dev_pickup_location_60_v2032`: avg duration 102.3s, first upgrade 14.3s, stuck 33.4/run, fallback 0.0/run.
  - `C:\tmp\game_dev_pickup_location_99_v2032`: avg duration 153.3s, first upgrade 25.7s, stuck 45.6/run, fallback 0.0/run.
- v2.0.32 result: recovery-exit weapon/ammo placement is not a 99-specific overstock signal. Weapon spawn recovery_exit is 24.8% -> 21.2%; ammo spawn recovery_exit is 26.3% -> 24.5%.
- Weapon/ammo collection at recovery_exit also drops at 99: weapon 30.9% -> 27.4%, ammo 32.8% -> 28.9%.
- Stronger signal is POI leakage: weapon collect POI 65.3% -> 54.6%, ammo collect POI 69.0% -> 55.5%, combat target POI 62.8% -> 53.0%, recover target POI 77.6% -> 59.1%.
- Next work should inspect POI target acquisition, route/POI overlap width, and open-area pickup collection before AI aggression, raw damage, generic zone-speed tuning, or recovery-exit loot relocation.
- Candidate `mapSpec_large_candidate.json` now has 6 route descriptors:
  - primary chokes: `west_ridge_choke`, `east_pine_choke`.
  - flanks: `north_slope_flank`, `south_creek_flank`.
  - loot/recovery flow: `central_meadow_cross`, `inner_brush_recovery_exit`.
- `MapDefinition.get_route_descriptors()` exposes route points as `points_2d`, and route validation now checks id, role, width, point count, point validity, and bounds.
- `MapDefinition.describe_strategic_position()` now classifies a world position into current POI role/name and route role/id.
- `Entity.gd` logs strategic context for combat damage and combat kills.
- `Telemetry.gd` aggregates hits/damage/kills by POI role, route role, and route id.
- `analyze_results.py` prints combat-location, route-pressure, CHASE location, and pickup location mixes.
- `compare_scale_profiles.py` prints route-pressure, CHASE location, and pickup location decisions.
- `tools/verify_strategic_flow_map.gd` guards candidate POI role coverage, route role coverage, primary-choke alternate routes, and connected POI references.
- Current 99-probe normalized output from v2.0.32: damage=19.78, shots=2.44, plans=1.38, disengage=0.46, entries=1.84, stuck=0.18 per spawned entity/min.
- Current 99-probe state mix from v2.0.32: ZONE_ESCAPE 28.1%, DISENGAGE 22.3%, CHASE 19.0%, ATTACK 17.6%, IDLE 13.0%.
- `target_99` envelope is pinned at minimum 160m world / 72m spawn radius and preferred 180m world / 78m spawn radius.
- `data/mapSpec_large_candidate.json` now satisfies the preferred target envelope as data: 180m world, 78m spawn radius, 8.5m boundary margin, target_99 saturation=0.20.
- Keep using `verify_strategic_flow_map.gd`, `verify_candidate_99_probe.gd`, `verify_large_map_candidate.gd`, candidate-path simulation, `analyze_results.py`, `compare_scale_profiles.py`, and `check_scale_telemetry.py` as scale gates.

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
