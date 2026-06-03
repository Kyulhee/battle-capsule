# Next Chat Handoff

> Last updated: 2026-06-03. Short context only; read `CLAUDE.md`, `DOCS_INDEX.md`, `MASTERPLAN.md`, and `IMPACT_MAP.md` before code changes.

## Current State

- Branch: `master`.
- Latest completed slice: `v2.0.28 — combat location / route pressure telemetry`.
- Next structural slice: `v2.0.29 — fresh 60-vs-99 route-pressure comparison`.
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
- Current v2.0.28 slice adds combat-location / route-pressure telemetry; no gameplay tuning or default/global 99 promotion was made.

Earlier v1.12 work added Emergency Shell/Escape Capsule, Ghost Grass, player artifact runtime state, artifact visuals, compact artifact selection UI, raw PNG icon loading, bush GLB visuals, restored bush interaction semantics, and bush visual feedback. Full recent detail is in `DEVLOG.md` and `devlog/v1.12.md`.

## Recommended Next Slice

`v2.0.29 — fresh 60-vs-99 route-pressure comparison`

- Keep `Main.gd` as match-global orchestrator.
- Keep the default map unchanged; use `map_spec_path=res://data/mapSpec_large_candidate.json` for candidate-only testing.
- v2.0.27 corrected the design target: do not tune bots to hit a CHASE combat percentage. Battle royale scale should verify strategic movement, contested routes, and power-position pressure first.
- Candidate `mapSpec_large_candidate.json` now has 6 route descriptors:
  - primary chokes: `west_ridge_choke`, `east_pine_choke`.
  - flanks: `north_slope_flank`, `south_creek_flank`.
  - loot/recovery flow: `central_meadow_cross`, `inner_brush_recovery_exit`.
- `MapDefinition.get_route_descriptors()` exposes route points as `points_2d`, and route validation now checks id, role, width, point count, point validity, and bounds.
- `MapDefinition.describe_strategic_position()` now classifies a world position into current POI role/name and route role/id.
- `Entity.gd` logs strategic context for combat damage and combat kills.
- `Telemetry.gd` aggregates hits/damage/kills by POI role, route role, and route id.
- `analyze_results.py` prints combat-location and route-pressure mixes.
- `compare_scale_profiles.py` prints route-pressure rows and a `Route pressure decision`.
- `tools/verify_strategic_flow_map.gd` guards candidate POI role coverage, route role coverage, primary-choke alternate routes, and connected POI references.
- v2.0.28 1-run candidate `xlarge_60` smoke at `C:\tmp\game_dev_route_pressure_smoke` confirmed telemetry output:
  - combat damage on route 72.8%.
  - damage route mix: loot_flow 37.0%, recovery_exit 34.5%, off_route 27.2%, flank 1.0%, primary_choke 0.2%.
  - This is a schema smoke only. The normal 1-run scale gate failed because first upgrade happened at 1.7s, so do not use it as a balance pass.
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
- v2.0.24 tuning: added runtime loot `rare_bias_mult`; final `target_99_probe` v3 uses `loot_count=240`, `stage_wave_count_mult=9`, `hotspot_density_mult=1.16`, `rare_bias_mult=1.45`.
- v2.0.24 adjusted 99 output at `C:\tmp\game_dev_candidate_99_loot_v3`: gate passed, avg duration 149.0s, first upgrade 16.6s, legacy disengage 125.6/run, entries 437.6/run.
- v3 vs previous 99: first upgrade -10.8s, non-pistol pickups/entity/min +0.03, rare pickups/entity/min +0.03, DISENGAGE state -0.68pp.
- v3 vs 60 still has combat throughput gap: damage/entity/min -12.67, shots/entity/min -1.51, plans/entity/min -1.06, duration +42.7s.
- v2.0.25 engagement-density comparison: 99 has 64% more entities than 60, but only +7% damage/match min, +8% shots/match min, and +1% plans/match min.
- v2.0.25 also shows ATTACK efficiency is intact: damage/ATTACK min 770.5 -> 819.3, shots/ATTACK min 94.1 -> 101.1.
- Active coverage is thinner at 99: `ATTACK+CHASE` 41.32% -> 37.67%, `RETREAT+ESCAPE` 44.13% -> 48.79%.
- v2.0.26 telemetry: `doctrine.chase_context_time_by_archetype` splits CHASE time into `combat`, `loot`, `recover_loot`, and `unknown`.
- v2.0.26 fresh sets:
  - `C:\tmp\game_dev_chase_candidate_60`: gate passed, avg duration 101.7s, first upgrade 11.8s.
  - `C:\tmp\game_dev_chase_candidate_99`: gate passed, avg duration 141.5s, first upgrade 25.4s, legacy disengage 122.4/run.
- v2.0.26 CHASE context: 60 combat 50.0%, loot 29.2%, recover_loot 20.9%; 99 combat 45.2%, loot 30.9%, recover_loot 24.0%.
- 99 CHASE is majority loot/recovery movement, but this is not automatically a failure. Next telemetry should show whether movement crosses intended strategic routes and whether combat clusters around route/POI pressure.
- `target_99` envelope is pinned at minimum 160m world / 72m spawn radius and preferred 180m world / 78m spawn radius.
- `data/mapSpec_large_candidate.json` now satisfies the preferred target envelope as data: 180m world, 78m spawn radius, 8.5m boundary margin, target_99 saturation=0.20.
- Next work should run fresh 5-run candidate `xlarge_60` and `target_99_probe` sets, compare route pressure, and only then decide whether route layout, pickup spacing, AI aggression, damage, or zone pacing needs tuning.
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
