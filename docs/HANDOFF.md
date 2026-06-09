# Next Chat Handoff

> Last updated: 2026-06-09. Short context only; read `CLAUDE.md`, `DOCS_INDEX.md`, `MASTERPLAN.md`, and `IMPACT_MAP.md` before code changes.

## Current State

- Branch: `master`.
- Latest pushed code slice: Night Artificial Forest candidate `0.2-poi-probe-integrated` structure iteration (`167dd29 tune night forest candidate structure`).
- Latest local slice: player-facing Night readability first pass.
- Current planning pivot: v2 scale telemetry is now treated as a **structural safety gate**, not final 99-player balance.
- Current map direction: validate player-facing flashlight/readability before adding bot night-awareness complexity.
- Target match length for the intended main game: 10-15 minutes.
- Default map and default scale preset are still not promoted to 99 players.
- `target_99_probe` remains candidate-only.
- New candidate path: `res://data/mapSpec_night_forest_candidate.json`.
- First POI probe path: `res://data/mapSpec_poi_sluice_crossing_probe.json`.
- Second POI probe path: `res://data/mapSpec_poi_wire_maze_probe.json`.
- Third POI probe path: `res://data/mapSpec_poi_black_ridge_probe.json`.
- Fourth POI probe path: `res://data/mapSpec_poi_false_clinic_probe.json`.
- Fifth POI probe path: `res://data/mapSpec_poi_supply_flats_probe.json`.
- Sixth POI probe path: `res://data/mapSpec_poi_ammunition_pockets_probe.json`.
- Seventh POI probe path: `res://data/mapSpec_poi_cabin_row_probe.json`.
- Eighth POI probe path: `res://data/mapSpec_poi_broadcast_fence_probe.json`.
- Release remains paused unless the user explicitly asks for a release.
- Expected Godot startup warning remains: `AssetCatalog: 7 configured asset paths are missing; fallbacks remain active.`

## Local/Untracked Notes

- `plan_report/` is local reference material for the Night Artificial Forest concept. Do not commit it unless explicitly requested.
- `asset_generator/` is an external source pool. Keep it untracked unless selected files are promoted into runtime assets.
- `docs/ASSET_GENERATION_PROMPTS.md` is local prompt scratch. Keep it untracked unless the user asks to publish it.
- `.gitignore` may have pre-existing local edits; do not revert or stage them unless the user asks.

## Read First

- [MASTERPLAN.md](MASTERPLAN.md): active Korean-first roadmap and current decisions.
- [NIGHT_BR_PACING_PLAN.md](NIGHT_BR_PACING_PLAN.md): 10-15 minute night BR pacing and test layers.
- [MAP_TILE_GROUPS.md](MAP_TILE_GROUPS.md): placement group brief plus Night Artificial Forest POI mapping.
- [ASSET_STATUS.md](ASSET_STATUS.md): current artifact/bush/generated-asset state.
- [IMPACT_MAP.md](IMPACT_MAP.md): ownership and change-impact checks before code edits.

## Recent Relevant Commits

- `167dd29 tune night forest candidate structure` — pushed candidate `0.2-poi-probe-integrated` and structural reference notes.
- `60f7012 feat: add night poi probe set` — pushed core 8 POI probe set, shared verifier, docs, and 3-run reference notes.
- `5c2d7b3 docs: add 99 map tile group brief` — added `MAP_TILE_GROUPS.md` and linked it from active docs.
- `c029db8 feat: add wire maze poi probe` — earlier Wire Maze POI probe slice.
- `4e3ad65 feat: add sluice crossing poi probe` — first POI-level structural probe.
- `127c8c4 feat: add night forest map candidate` — non-default 180m night forest candidate.
- `8333bd3 tune bot opportunistic loot selection` — latest pushed gameplay tuning slice, v2.0.40.

Older v2.0 telemetry detail is in [DEVLOG.md](DEVLOG.md), [archive/MASTERPLAN_full_2026-06-08.md](archive/MASTERPLAN_full_2026-06-08.md), and `docs/devlog/`.

## Next Work

1. Review or continue `N2-VIS-01`.
   - `PlayerNightReadability.gd` now switches the existing player `VisionSpot`/`ProximityLight` into a night profile for Night Artificial Forest metadata.
   - `verify_player_night_readability.gd` passed.
   - `capture_player_night_readability.gd` writes `C:\tmp\player_night_readability.png` for direct review.
   - Manual visual inspection should use `scale_preset=visual_review`, not `xlarge_60`.
   - `visual_review` is 8 bots / 45 loot / no stage loot waves / slow zone. If it still lags, add `bot_count=0 loot_count=24`.
   - `visual_review` 1-run smoke at `C:\tmp\game_dev_night_visual_review_smoke_v1`: duration 287.2s, fallback 0.0/run, zone deaths 0, regression sentinels clear, AI update avg 184.4us.
   - Night candidate `xlarge_60` runtime load passed.
   - Night candidate `xlarge_60` 1-run smoke at `C:\tmp\game_dev_night_readability_smoke_v1`: duration 122.2s, fallback 0.0/run, regression sentinels clear, stuck 59.0/run, zone deaths 4.0/run.
   - Next preferred check is a visual/manual pass on flashlight framing, item readability, bush readability, and combat readability.
   - Do not give every bot full flashlight/battery/fear behavior yet.
   - Later bot work should start with abstract night awareness, not cone-vs-cone inventory simulation.
2. Night candidate map baseline now exists.
   - `data/mapSpec_night_forest_candidate.json` is at `0.2-poi-probe-integrated`.
   - Cabin Row and Broadcast Fence/Wire side were de-cluttered based on high stuck observations.
   - JSON parse, `verify_night_forest_candidate.gd`, `xlarge_60` runtime load, and `target_99_probe` runtime load passed.
   - 99-player 1-run reference at `C:\tmp\game_dev_night_candidate_99_probe_v1`: duration 165.4s, stage 2, spawn placed 100/100, fallback 0.0/run, saturation 0.20, zero damage/shot/combat-plan sentinels clear.
   - Observation, not hard fail: stuck 101.0/run and zone deaths 4.0/run remain visible before adding more density or treating pace as final.
3. Existing POI probe references remain useful context.
   - Sluice 3-run reference at `C:\tmp\game_dev_sluice_probe_v1`: avg duration 69.1s, fallback 0.0/run, zone deaths 0, no zero-damage/shot/combat-plan sentinels.
   - Wire Maze 3-run reference at `C:\tmp\game_dev_wire_maze_probe_v1`: avg duration 66.6s, fallback 0.0/run, zone deaths 0, no zero-damage/shot/combat-plan sentinels. Route damage pressure: primary_choke 46.0%, flank 27.1%, recovery_exit 17.0%, off_route 9.6%.
   - Black Ridge 3-run reference at `C:\tmp\game_dev_black_ridge_probe_v1`: avg duration 74.0s, fallback 0.0/run, zone deaths 0, stuck 6.7/run, sentinels clear.
   - False Clinic 3-run reference at `C:\tmp\game_dev_false_clinic_probe_v1`: avg duration 71.5s, fallback 0.0/run, zone deaths 0, stuck 6.0/run, sentinels clear.
   - Supply Flats 3-run reference at `C:\tmp\game_dev_supply_flats_probe_v1`: avg duration 74.5s, fallback 0.0/run, zone deaths 0, stuck 2.0/run, sentinels clear.
   - Ammunition Pockets 3-run reference at `C:\tmp\game_dev_ammunition_pockets_probe_v1`: avg duration 84.2s, fallback 0.0/run, zone deaths 0, stuck 6.7/run, sentinels clear.
   - Cabin Row 3-run reference at `C:\tmp\game_dev_cabin_row_probe_v1`: avg duration 85.1s, fallback 0.0/run, zone deaths 0, stuck 13.3/run, sentinels clear.
   - Broadcast Fence 3-run reference at `C:\tmp\game_dev_broadcast_fence_probe_v1`: avg duration 73.5s, fallback 0.0/run, zone deaths 1, stuck 11.3/run, sentinels clear.
   - Cabin Row and Broadcast Fence are the main observation points before adding more cover or future visibility systems.
   - Existing scale gates are reference-only for POI probes; do not tune duration or first-upgrade timing from these minimaps.
4. Run current scale tooling as structural checks only on the night candidate.
   - Do not tune combat/CHASE percentages as final design targets yet.
   - Keep fallback 0, clearance, route/POI coverage, stuck, disengage, zone escape, and AI cost visible.
5. Prototype night vision carefully.
   - Start with player-facing flashlight and reveal/readability.
   - Bots should first use abstract night awareness, not full flashlight/battery/fear state.
6. Build a separate 10-15 minute pacing gate after the map and first night-vision pass exist.

## Verification Reminders

Docs-only work:

- `git diff --check`

Candidate map work:

- `tools/verify_player_night_readability.gd`
- `.\Godot_v4.6.2-stable_win64_console.exe --path . --script res://tools/capture_player_night_readability.gd`
- `.\Godot_v4.6.2-stable_win64_console.exe --path . -- map_spec_path=res://data/mapSpec_night_forest_candidate.json scale_preset=visual_review`
- `.\Godot_v4.6.2-stable_win64_console.exe --path . -- map_spec_path=res://data/mapSpec_night_forest_candidate.json scale_preset=visual_review bot_count=0 loot_count=24`
- `tools/verify_strategic_flow_map.gd`
- `tools/verify_candidate_99_probe.gd`
- `tools/verify_night_forest_candidate.gd`
- `tools/verify_poi_sluice_crossing_probe.gd`
- `tools/verify_poi_wire_maze_probe.gd`
- `tools/verify_poi_black_ridge_probe.gd`
- `tools/verify_poi_false_clinic_probe.gd`
- `tools/verify_poi_supply_flats_probe.gd`
- `tools/verify_poi_ammunition_pockets_probe.gd`
- `tools/verify_poi_cabin_row_probe.gd`
- `tools/verify_poi_broadcast_fence_probe.gd`
- `.\Godot_v4.6.2-stable_win64_console.exe --headless --path . --quit -- map_spec_path=res://data/mapSpec_night_forest_candidate.json scale_preset=xlarge_60`
- `.\Godot_v4.6.2-stable_win64_console.exe --headless --path . --quit -- map_spec_path=res://data/mapSpec_night_forest_candidate.json scale_preset=target_99_probe`
- `python tools\simulate_matches.py 1 map_spec_path=res://data/mapSpec_night_forest_candidate.json scale_preset=target_99_probe out_dir=C:\tmp\game_dev_night_candidate_99_probe_v1`
- `python tools\analyze_results.py C:\tmp\game_dev_night_candidate_99_probe_v1`
- `.\Godot_v4.6.2-stable_win64_console.exe --headless --path . --quit -- map_spec_path=res://data/mapSpec_poi_sluice_crossing_probe.json scale_preset=poi_probe`
- `.\Godot_v4.6.2-stable_win64_console.exe --headless --path . --quit -- map_spec_path=res://data/mapSpec_poi_wire_maze_probe.json scale_preset=poi_probe`
- `.\Godot_v4.6.2-stable_win64_console.exe --headless --path . --quit -- map_spec_path=res://data/mapSpec_poi_black_ridge_probe.json scale_preset=poi_probe`
- `.\Godot_v4.6.2-stable_win64_console.exe --headless --path . --quit -- map_spec_path=res://data/mapSpec_poi_false_clinic_probe.json scale_preset=poi_probe`
- `.\Godot_v4.6.2-stable_win64_console.exe --headless --path . --quit -- map_spec_path=res://data/mapSpec_poi_supply_flats_probe.json scale_preset=poi_probe`
- `.\Godot_v4.6.2-stable_win64_console.exe --headless --path . --quit -- map_spec_path=res://data/mapSpec_poi_ammunition_pockets_probe.json scale_preset=poi_probe`
- `.\Godot_v4.6.2-stable_win64_console.exe --headless --path . --quit -- map_spec_path=res://data/mapSpec_poi_cabin_row_probe.json scale_preset=poi_probe`
- `.\Godot_v4.6.2-stable_win64_console.exe --headless --path . --quit -- map_spec_path=res://data/mapSpec_poi_broadcast_fence_probe.json scale_preset=poi_probe`
- fresh 5-run `xlarge_60`
- fresh 5-run `target_99_probe`
- `tools/compare_scale_profiles.py`
- `tools/check_scale_telemetry.py`

## Guardrails

- Do not promote the 99-player candidate to default/global runtime without an explicit decision.
- Do not add full bot flashlight, battery, fear, blackout, fire spread, interior cabin, or watchtower climb systems in the first map candidate.
- Keep `Main.gd` as match-global orchestrator.
- Keep bush gameplay authority in `Bush.tscn`; visual GLB bush replacement is cosmetic.
- For asset generation, keep stable style/format rules in [ASSET_BRIEF.md](ASSET_BRIEF.md) and local prompt scratch out of commits.
