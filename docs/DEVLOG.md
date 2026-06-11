# Battle Capsule Active Devlog

> Last updated: 2026-06-11. Compressed recent work log. Full raw detail is preserved in [devlog/DEVLOG_full_2026-06-08.md](devlog/DEVLOG_full_2026-06-08.md).

Do not load full snapshots by default. Use this file for the current state and open archived logs only when exact slice detail is needed.

---

## v2 Pacing Baseline Report

**Scope**

- Added `tools/summarize_pacing_baseline.py` to interpret pacing telemetry against the 10-15 minute Night BR target.
- The report is intentionally not a hard gate. It separates structural smoke results from candidate gameplay pacing values.
- The tool prints duration scale-up, milestone phase placement, CHASE route/context dwell, and stuck route/cell watch points.

**Verification**

- `python -m py_compile tools\summarize_pacing_baseline.py tools\analyze_results.py tools\check_scale_telemetry.py tools\simulate_matches.py` passed.
- `python tools\summarize_pacing_baseline.py C:\tmp\game_dev_pacing_map_clearance_v2_3run` passed.
- The verified sample is classified as compressed structural smoke:
  - avg duration 143.6s versus 600-900s target
  - 4.18x scale-up to the 10m floor
  - 5.22x scale-up to the 12.5m midpoint
  - first non-pistol upgrade 27.3s and stage 2 26.4s still land in the 0-2m opening phase relative to the 10-15m target.
- `git diff --check` passed.

**Decision**

- Use this report before changing zone, loot, combat, or AI pacing numbers.
- Keep `check_scale_telemetry.py` as the structural gate and `summarize_pacing_baseline.py` as a gap report.

---

## v2 Pacing Telemetry - First Pass

**Scope**

- Added a `pacing` telemetry group without changing gameplay tuning.
- Captures first shot, first contact, first damage, first kill, first non-pistol upgrade, and zone stage timings.
- Extended `analyze_results.py` to print pacing milestones and reuse existing doctrine CHASE context/route dwell summaries when the group is present.
- Added stuck state/route/cell context to make repeated 99-probe failures diagnosable instead of adjusting thresholds.
- Moved the Night candidate Black Ridge and south/clinic fixed obstacles out of high-traffic path cells after the diagnostic runs showed structural stuck concentration there.
- Added `verify_pacing_telemetry.gd` as a schema/hook smoke test.

**Verification**

- `verify_pacing_telemetry.gd` passed.
- `python -m py_compile tools\analyze_results.py tools\check_scale_telemetry.py tools\simulate_matches.py` passed.
- `git diff --check` passed.
- Final `target_99_probe` 3-run structural gate passed:
  - output: `C:\tmp\game_dev_pacing_map_clearance_v2_3run`
  - avg duration 143.6s, min/max 120.0s / 161.2s, no runs under 60s
  - avg first upgrade 27.3s, fallback 0.0/run, zone deaths 0.3/run, stuck 20.3/run
  - AI update budget avg 661.2us, max 28729us
  - regression sentinels clear
  - `check_scale_telemetry.py --min-runs 3` passed.

**Decision**

- Treat these values as measurement only. Do not tune zone, loot, AI aggression, damage, or map density from this first telemetry row until a small repeated sample exists.
- The map movement in this slice is a pathing clearance fix from stuck diagnostics, not a 10-15 minute pacing balance change.

---

## v2 Night Awareness - Abstract Bot First Pass

**Scope**

- Added a first-pass abstract night awareness modifier for bot viewers only.
- Night maps are detected from map metadata (`theme`, `id`, or `layout` containing the Night Artificial Forest signal).
- The system does not simulate bot flashlights, batteries, fear, cone-vs-cone checks, or blackout logic.
- Instead, night awareness adjusts existing perception:
  - quiet dark targets reduce bot effective vision range and increase dwell;
  - moving targets generate a small signature;
  - player night readability generates a light signature;
  - revealed/firing targets overcome the night penalty.
- Combat, movement, damage response, zone escape, and AI state handlers remain unchanged.

**Verification**

- `verify_bot_night_awareness.gd` passed.
- `verify_ai_lod_perception.gd` passed.
- `verify_bush_interaction.gd` passed.
- Earlier in the slice, `verify_player_night_readability.gd`, `verify_pickup_light_lod.gd`, and Night candidate runtime loads passed before the final constant softening.
- Initial stronger tuning smoke results:
  - `visual_review`: `C:\tmp\game_dev_bot_night_awareness_visual_review_v1`, duration 233.5s, fallback 0.0/run, zone deaths 0, sentinel clear, AI update avg 166.6us.
  - `xlarge_60`: `C:\tmp\game_dev_bot_night_awareness_xlarge60_v1`, duration 85.4s, fallback 0.0/run, zone deaths 2, sentinel clear, AI update avg 421.1us.
  - `target_99_probe`: `C:\tmp\game_dev_bot_night_awareness_target99_v1`, duration 170.0s, fallback 0.0/run, zone deaths 4, sentinel clear, AI update avg 540.2us.
- The initial `target_99_probe` scale checker failed because stuck rose to 96.0/run, above the 60.0 gate.
- After that failure, the night awareness constants were softened.
- Softened tuning unit verifiers passed:
  - `verify_bot_night_awareness.gd`
  - `verify_ai_lod_perception.gd`
  - `verify_bush_interaction.gd`
- Softened `target_99_probe` 1-run reference:
  - output: `C:\tmp\game_dev_bot_night_awareness_target99_v2`
  - duration 107.8s, fallback 0.0/run, zone deaths 1, stuck 45.0/run
  - regression sentinels clear
  - AI update budget avg 539.5us
  - `check_scale_telemetry.py --min-runs 1` failed because no first upgrade was recorded in that single economy sample.
- Softened `target_99_probe` 3-run structural smoke passed:
  - output: `C:\tmp\game_dev_bot_night_awareness_target99_v2_3run`
  - avg duration 149.7s, min/max 125.1s / 175.3s
  - avg first upgrade 23.0s, first weapons: ar=1, shotgun=2
  - fallback 0.0/run, zone deaths 1.3/run, stuck 55.7/run, disengage 111.7/run
  - regression sentinels clear
  - AI update budget avg 511.6us, max 19301us
  - `check_scale_telemetry.py --min-runs 3` passed.

**Decision**

- Treat N2-AI-01 as complete for the current structural gate: the 3-run sample stayed inside stuck, disengage, spawn fallback, sentinel, and AI budget thresholds.
- Keep the single-run no-upgrade result as a variance note, not a reason to lower scale thresholds.
- Next work should start N2-PACE-01: add explicit 10-15 minute pacing telemetry instead of interpreting the current 100-175s structural smoke as final match pacing.

---

## v2 Performance LOD - AI Perception Tick

**Scope**

- Added accumulated-delta perception ticks in `Entity.gd` instead of running full perception every physics frame.
- Kept player perception responsive at 0.05s.
- Added bot state-based perception LOD:
  - ATTACK: 0.05s
  - CHASE / ZONE_ESCAPE / RECOVER / DISENGAGE: 0.08s
  - IDLE: 0.12s
- Throttled bot all-actor sensory loops:
  - close range: 0.05s
  - gunshot: 0.10s
  - footstep: 0.15s
- Did not skip movement, combat state handlers, shooting, damage reactions, zone escape, or stuck handling.

**Verification**

- `verify_ai_lod_perception.gd` passed.
- `verify_pickup_light_lod.gd` passed.
- `verify_player_night_readability.gd` passed.
- Night candidate runtime load passed with both `visual_review` and `xlarge_60`; only expected AssetCatalog fallback warnings remained.
- `visual_review` 1-run smoke passed:
  - output: `C:\tmp\game_dev_ai_lod_visual_review_v1`
  - duration 391.9s, fallback 0.0/run, zone deaths 0, stuck 4.0/run
  - regression sentinels clear
  - AI update budget avg 173.6us
- `xlarge_60` 1-run smoke passed:
  - output: `C:\tmp\game_dev_ai_lod_xlarge60_v1`
  - duration 106.6s, fallback 0.0/run, zone deaths 0, stuck 31.0/run
  - regression sentinels clear
  - AI update budget avg 412.3us
  - `check_scale_telemetry.py --min-runs 1` passed.
- `target_99_probe` 1-run smoke passed:
  - output: `C:\tmp\game_dev_ai_lod_target99_v1`
  - duration 178.2s, fallback 0.0/run, zone deaths 1, stuck 51.0/run
  - regression sentinels clear
  - AI update budget avg 463.0us
  - `check_scale_telemetry.py --min-runs 1` passed.

**Decision**

- This keeps the 99-player AI target alive while reducing the cost of repeated all-actor scans.
- It is still a structural safety pass, not final 10-15 minute pacing or final night AI behavior.
- Next AI work should be behavior-facing: abstract night awareness/reveal response, with repeated 99 probes only after the behavior shape is stable.

---

## v2 Performance LOD - Pickup Lights

**Scope**

- Added distance-based LOD for pickup `OmniLight3D` nodes.
- Sensed pickups still keep their body/icon visibility, but their light is now:
  - full strength near the player;
  - dimmed at mid distance;
  - culled at far distance;
  - restored when the pickup is focused for readability.
- Kept bot AI update cadence untouched in this slice. Bot AI LOD affects the state machine and should be handled as a separate unit.

**Verification**

- `verify_pickup_light_lod.gd` passed.
- `verify_player_night_readability.gd` still passed.
- Night candidate `visual_review` runtime load passed:
  - command: `map_spec_path=res://data/mapSpec_night_forest_candidate.json scale_preset=visual_review`
  - only the expected AssetCatalog fallback warning remained.

**Decision**

- 99-player AI remains a target, but manual visual inspection and structural load probes must stay separated.
- `visual_review` should be the default renderer check. If it still lags, use `bot_count=0 loot_count=24`.
- Next performance work should inspect bot AI update cadence/LOD separately, with behavior regression checks.

---

## v2 Night Readability - Player Flashlight First Pass

**Scope**

- Added `PlayerNightReadability.gd` as a small player-only controller for existing `VisionSpot` and `ProximityLight`.
- Added `capture_player_night_readability.gd` to produce a direct review PNG at `C:\tmp\player_night_readability.png`.
- Added a `visual_review` scale preset to the Night candidate because `xlarge_60` is too heavy for manual visual inspection.
- Night profile activates from map metadata for the Night Artificial Forest candidate.
- Default/non-night maps restore the scene's existing light values.
- Did not add bot flashlight inventory, battery, fear, blackout, or cone-vs-cone perception.

**Verification**

- `verify_player_night_readability.gd` passed.
- `capture_player_night_readability.gd` saved `C:\tmp\player_night_readability.png`.
- Night candidate runtime load passed with `scale_preset=xlarge_60`; only the expected AssetCatalog fallback warning remained.
- One Night candidate `xlarge_60` match smoke passed:
  - output: `C:\tmp\game_dev_night_readability_smoke_v1`
  - duration 122.2s, stage 2, spawn fallback 0.0/run
  - regression sentinels clear: zero damage, zero weapon damage, zero shots, zero combat-plan runs all absent
  - observation: stuck 59.0/run and zone deaths 4.0/run remain structural/readability follow-up signals, not flashlight balance targets.
- `visual_review` is the intended manual renderer preset: 8 bots, 45 loot, no stage loot waves, slow zone.
- `visual_review` 1-run smoke passed:
  - output: `C:\tmp\game_dev_night_visual_review_smoke_v1`
  - duration 287.2s, stage 2, spawn fallback 0.0/run, zone deaths 0
  - regression sentinels clear
  - AI update budget avg 184.4us, much lower than the 60/99 structural probes

**Decision**

- This is a player-facing readability prototype only.
- Before expanding to bot night awareness, do a visual/manual pass on flashlight framing, item readability, bush readability, and combat readability.
- Do not use `xlarge_60` or `target_99_probe` for manual visual checks unless specifically testing performance.
- The earlier manual visual command used `xlarge_60`; that was a load-test preset and can lag heavily because it runs 60 bots, 150 pickups, many pickup lights, and full AI/navigation in the normal renderer.

---

## v2 Night Candidate Map Iteration

**Scope**

- Folded the 8 POI probe lessons back into `data/mapSpec_night_forest_candidate.json`.
- Updated candidate metadata to `0.2-poi-probe-integrated`.
- Kept route topology and verifier key classification points unchanged.
- Reduced obstruction pressure around the two highest-stuck observation POIs:
  - Cabin Row: moved/shrank nearby canyon wall, tree cluster, and bush patch away from the readable lane.
  - Broadcast Fence/Wire Maze side: shrank and offset log piles to keep the gate structural but less cluttered.

**Verification**

- `python -m json.tool data\mapSpec_night_forest_candidate.json` passed.
- `verify_night_forest_candidate.gd` passed: 14 POIs, 6 routes, `target_99_probe` bots=99, loot=240.
- Runtime path load passed for both:
  - `scale_preset=xlarge_60`
  - `scale_preset=target_99_probe`
- Both runtime loads only showed the expected AssetCatalog fallback warning.
- One 99-player candidate reference simulation passed:
  - output: `C:\tmp\game_dev_night_candidate_99_probe_v1`
  - duration 165.4s, stage 2, spawn placed 100/100, fallback 0.0/run, saturation 0.20
  - regression sentinels clear: zero damage, zero weapon damage, zero shots, zero combat-plan runs all absent
  - combat route damage: primary_choke 48.9%, off_route 32.6%, loot_flow 12.0%, recovery_exit 3.5%, flank 3.0%
  - POI damage: open 56.5%, transit_choke 24.4%, concealment_field 18.7%, recovery_pocket 0.4%
  - observation: stuck 101.0/run and zone deaths 4.0/run remain visible structural risks before densifying or adding night visibility.

**Decision**

- Treat this as a structural candidate baseline, not a 10-15 minute pacing pass.
- The 99-player spawn/route/telemetry path is alive on the Night candidate, but stuck and zone pressure need continued observation.
- Next autonomous unit should start `N2-VIS-01`: player-facing flashlight/readability prototype, with bots limited to abstract night awareness in later work.

---

## v2 POI Probe Reference Simulation Batch

**Scope**

- Ran 3-run reference simulations for the six POI probes that did not yet have simulation baselines:
  - Black Ridge: `C:\tmp\game_dev_black_ridge_probe_v1`
  - False Clinic: `C:\tmp\game_dev_false_clinic_probe_v1`
  - Supply Flats: `C:\tmp\game_dev_supply_flats_probe_v1`
  - Ammunition Pockets: `C:\tmp\game_dev_ammunition_pockets_probe_v1`
  - Cabin Row: `C:\tmp\game_dev_cabin_row_probe_v1`
  - Broadcast Fence: `C:\tmp\game_dev_broadcast_fence_probe_v1`
- Interpreted these as structure/readability/collision references only. They are not 10-15 minute pacing gates.

**Verification**

| Probe | Avg duration | Fallback | Zone deaths | Stuck/run | Sentinel | Main route damage |
|---|---:|---:|---:|---:|---|---|
| Black Ridge | 74.0s | 0.0/run | 0 | 6.7 | clear | flank 47.7%, primary 30.1%, off-route 13.8% |
| False Clinic | 71.5s | 0.0/run | 0 | 6.0 | clear | flank 34.4%, recovery 24.3%, primary 16.0% |
| Supply Flats | 74.5s | 0.0/run | 0 | 2.0 | clear | flank 42.8%, off-route 24.4%, recovery 14.0% |
| Ammunition Pockets | 84.2s | 0.0/run | 0 | 6.7 | clear | flank 46.4%, recovery 18.9%, off-route 16.0% |
| Cabin Row | 85.1s | 0.0/run | 0 | 13.3 | clear | flank 43.5%, off-route 34.1%, primary 15.0% |
| Broadcast Fence | 73.5s | 0.0/run | 1 | 11.3 | clear | flank 48.1%, off-route 23.3%, primary 20.2% |

Sentinel means zero total damage, zero shots, and zero combat-plan runs were all absent.

**Decision**

- All eight core POI probes now have smoke/runtime validation and 3-run reference simulation baselines.
- Cabin Row and Broadcast Fence should be visually/manual reviewed before densifying because they show higher stuck/run.
- Broadcast Fence has one zone death in this small sample; keep it as an observation, not an immediate tuning target.
- Next autonomous unit should fold the POI lessons back into `data/mapSpec_night_forest_candidate.json` rather than continuing to tune isolated POI duration or first-upgrade timing.

---

## v2 POI Probe Batch - Supply, Ammo, Cabin, Broadcast

**Scope**

- Added the remaining core Night Artificial Forest POI structural probes:
  - `data/mapSpec_poi_supply_flats_probe.json`
  - `data/mapSpec_poi_ammunition_pockets_probe.json`
  - `data/mapSpec_poi_cabin_row_probe.json`
  - `data/mapSpec_poi_broadcast_fence_probe.json`
- Added `tools/PoiProbeVerifier.gd` as a shared verifier helper for the new probes only.
- Added per-probe smoke entry scripts:
  - `tools/verify_poi_supply_flats_probe.gd`
  - `tools/verify_poi_ammunition_pockets_probe.gd`
  - `tools/verify_poi_cabin_row_probe.gd`
  - `tools/verify_poi_broadcast_fence_probe.gd`
- Updated [TESTING.md](TESTING.md), [MAP_TILE_GROUPS.md](MAP_TILE_GROUPS.md), [MASTERPLAN.md](MASTERPLAN.md), and [HANDOFF.md](HANDOFF.md).

**Verification**

- JSON parse passed for all four new `mapSpec` files.
- Godot smoke passed for all four new verifiers:
  - Supply Flats: 6 POIs, 5 routes, 10 obstacles.
  - Ammunition Pockets: 6 POIs, 5 routes, 10 obstacles.
  - Cabin Row: 6 POIs, 5 routes, 12 obstacles.
  - Broadcast Fence: 6 POIs, 5 routes, 13 obstacles.
- Runtime path load passed for all four probes with `scale_preset=poi_probe`; only the expected AssetCatalog fallback warning remained.

**Decision**

- The core 8 POI structural probe set is now present: Sluice Crossing, Wire Maze, Black Ridge, False Clinic, Supply Flats, Ammunition Pockets, Cabin Row, Broadcast Fence.
- Do not infer 10-15 minute balance from these smoke checks.
- Next autonomous unit should either run short reference simulations for the four new probes or fold probe lessons back into `data/mapSpec_night_forest_candidate.json`.

---

## v2 POI Probe - False Clinic

**Scope**

- Added `data/mapSpec_poi_false_clinic_probe.json` as the fourth POI-level structural probe.
- The probe is a compact 76m recovery-pocket map with front-lane pressure, north/south flanks, limited recovery loot, and forced re-entry from `False Clinic` back to `Clinic Doorway`.
- Added `tools/verify_poi_false_clinic_probe.gd` to validate role counts, recovery-pocket loot limits, front-lane/re-entry route contracts, facade/soft-cover limits, connected POIs, key position classification, and compact probe scale.
- Updated [TESTING.md](TESTING.md) and [MAP_TILE_GROUPS.md](MAP_TILE_GROUPS.md) with the new probe.

**Verification**

- `python -m json.tool data/mapSpec_poi_false_clinic_probe.json` passed.
- `verify_poi_false_clinic_probe.gd` passed: 6 POIs, 5 routes, 14 obstacles, front lane as `primary_choke`, 2 flanks, 1 recovery exit, 1 loot flow.
- Runtime path load passed with `map_spec_path=res://data/mapSpec_poi_false_clinic_probe.json scale_preset=poi_probe`; only the expected AssetCatalog fallback warning remained.

**Decision**

- Keep this as a recovery re-entry structure probe.
- Do not raise the clinic recovery pocket's loot density or rare bias before a short reference simulation, because the current purpose is to prevent a safe heal-and-arm loop.
- Next autonomous unit should move to `Supply Flats` early-loot probing.

---

## v2 POI Probe - Black Ridge

**Scope**

- Added `data/mapSpec_poi_black_ridge_probe.json` as the third POI-level structural probe.
- The probe is a compact 78m contestable ridge with a fast exposed direct ascent, slower covered north flank, low-ground south/recovery flank, hollow re-entry, and loot-to-recovery flow.
- Added `tools/verify_poi_black_ridge_probe.gd` to validate role counts, direct ascent width/alternate route, ridge wall/rock-cover limits, connected POIs, key position classification, and compact probe scale.
- Updated [TESTING.md](TESTING.md) and [MAP_TILE_GROUPS.md](MAP_TILE_GROUPS.md) with the new probe.

**Verification**

- `python -m json.tool data/mapSpec_poi_black_ridge_probe.json` passed.
- `verify_poi_black_ridge_probe.gd` passed: 6 POIs, 5 routes, 15 obstacles, direct ascent as `primary_choke`, 2 flanks, 1 recovery exit, 1 loot flow.
- Runtime path load passed with `map_spec_path=res://data/mapSpec_poi_black_ridge_probe.json scale_preset=poi_probe`; only the expected AssetCatalog fallback warning remained.

**Decision**

- Keep this as a structure/readability/collision probe for a power position, not as a climb/interior/elevation-system implementation.
- Do not add more hard cover to the ridge before a manual review or short reference simulation.
- Next autonomous unit should move to `False Clinic` recovery re-entry probing.

---

## v2 POI Probe - Wire Maze Reference Simulation

**Scope**

- Ran the `Wire Maze` POI probe as a short 3-run reference simulation.
- Interpreted the result as a structure/readability/collision check only, not as a 10-15 minute pacing gate.

**Verification**

- Command: `python tools\simulate_matches.py 3 normal out_dir=C:\tmp\game_dev_wire_maze_probe_v1 map_spec_path=res://data/mapSpec_poi_wire_maze_probe.json scale_preset=poi_probe`
- 3-run result at `C:\tmp\game_dev_wire_maze_probe_v1`: avg duration 66.6s, min/max 58.8s / 73.8s, avg zone stage 2.00.
- Spawn fallback stayed 0.0/run, zone deaths stayed 0, and zero damage / zero weapon damage / zero shot / zero combat-plan sentinels were all clear.
- Combat route pressure was readable: damage primary_choke 46.0%, flank 27.1%, recovery_exit 17.0%, off_route 9.6%.
- `verify_poi_wire_maze_probe.gd` passed again.
- `check_scale_telemetry.py --min-runs 1` failed as a reference-only non-POI gate: avg duration 66.6s < 70.0s, one run under 60s, avg first upgrade 6.9s < 10.0s.

**Decision**

- Keep `Wire Maze` as a valid lightweight POI probe.
- Track stuck triggers at 8.7/run during later visual/manual review, but do not densify or retune the maze from this short probe.
- Next autonomous unit should move to `Black Ridge` structural probing.

---

## v2 POI Probe - Wire Maze

**Scope**

- Added `data/mapSpec_poi_wire_maze_probe.json` as the second POI-level structural probe.
- The probe is a compact 76m sparse maze with a direct lane, north concealed flank, south recovery flank, shed re-entry, and loot-to-recovery flow.
- Added `tools/verify_poi_wire_maze_probe.gd` to validate role counts, direct lane width/alternate route, sparse wall count, connected POIs, key position classification, and compact probe scale.
- Updated [TESTING.md](TESTING.md) with the new smoke commands.

**Verification**

- `python -m json.tool data/mapSpec_poi_wire_maze_probe.json` passed.
- `git diff --check` passed.
- `verify_poi_wire_maze_probe.gd` passed: 6 POIs, 5 routes, 15 obstacles, direct lane as `primary_choke`, 2 flanks, 1 recovery exit, 1 loot flow.
- Runtime path load passed with `map_spec_path=res://data/mapSpec_poi_wire_maze_probe.json scale_preset=poi_probe`; only the expected AssetCatalog fallback warning remained.

**Decision**

- Keep this as a structure/readability/collision probe.
- Do not densify the maze before a short simulation or manual visual review. Next autonomous unit should be either Wire Maze 1-3 run reference simulation or Black Ridge structural probe.

---

## v2 POI Probe - Sluice Crossing

**Scope**

- Added `data/mapSpec_poi_sluice_crossing_probe.json` as the first POI-level structural probe.
- The probe is a compact 72m map with direct crossing, north flank, south/recovery flank, pump re-entry, and early loot-to-recovery flow.
- Added `tools/verify_poi_sluice_crossing_probe.gd` to validate role counts, direct crossing width/alternate route, connected POIs, key position classification, and compact probe scale.
- Updated [TESTING.md](TESTING.md) with the new smoke commands.

**Verification**

- `python -m json.tool data/mapSpec_poi_sluice_crossing_probe.json` passed.
- `git diff --check` passed.
- `verify_poi_sluice_crossing_probe.gd` passed: 6 POIs, 5 routes, direct crossing as `primary_choke`, 2 flanks, 1 recovery exit, 1 loot flow.
- Runtime path load passed with `map_spec_path=res://data/mapSpec_poi_sluice_crossing_probe.json scale_preset=poi_probe`; only the expected AssetCatalog fallback warning remained.
- 3-run simulation at `C:\tmp\game_dev_sluice_probe_v1` completed: avg duration 69.1s, fallback 0.0/run, zone deaths 0, no zero-damage/shot/combat-plan sentinels.
- `check_scale_telemetry.py --min-runs 1` was run as a reference only and failed the non-POI thresholds: avg duration 69.1s < 70.0s, first upgrade 8.2s < 10.0s.

**Decision**

- Keep this as a local POI probe for structure/readability/collision checks.
- Do not tune duration or first-upgrade timing from this probe. Existing scale gates are not POI-probe hard gates.
- Next work should add the `Wire Maze` or `Black Ridge` POI probe.

---

## v2 Night Forest Candidate MapSpec

**Scope**

- Added `data/mapSpec_night_forest_candidate.json` as a non-default 180m structural candidate.
- The candidate uses `Sluice Crossing` as the diagonal crossing pressure point, `Black Ridge` as a contestable power position, `Wire Maze` as a sparse first-pass transit choke, and `False Clinic` as recovery with re-entry pressure.
- Added `tools/verify_night_forest_candidate.gd` to validate POI role counts, route role counts, primary choke alternates, key position classification, default-map absence, and `target_99_probe` envelope floors.
- Updated [TESTING.md](TESTING.md) with the new smoke commands.

**Verification**

- `python -m json.tool data/mapSpec_night_forest_candidate.json` passed.
- `git diff --check` passed.
- `verify_night_forest_candidate.gd` passed: 14 POIs, 6 routes, 3 loot hubs, 5 transit chokes, 2 recovery pockets, 4 concealment fields.
- Runtime path load passed with `map_spec_path=res://data/mapSpec_night_forest_candidate.json scale_preset=xlarge_60`; only the expected AssetCatalog fallback warning remained.

**Decision**

- Keep this as a candidate-only structural map, not a default map promotion.
- Next work should add POI-level probes before judging full 99-player pacing.

---

## v2 Planning Reset - Night Artificial Forest 99 Candidate

**Scope**

- Archived the previous long `MASTERPLAN.md` to [archive/MASTERPLAN_full_2026-06-08.md](archive/MASTERPLAN_full_2026-06-08.md).
- Archived the previous long `DEVLOG.md` to [devlog/DEVLOG_full_2026-06-08.md](devlog/DEVLOG_full_2026-06-08.md).
- Rewrote active `MASTERPLAN.md` as a Korean-first compressed roadmap.
- Added [NIGHT_BR_PACING_PLAN.md](NIGHT_BR_PACING_PLAN.md) for 10-15 minute night BR pacing, test layers, and staged bot night-awareness decisions.
- Updated [MAP_TILE_GROUPS.md](MAP_TILE_GROUPS.md) with the Night Artificial Forest candidate, 8 POI role mapping, route-shape guidance, and first-pass constraints.
- Compressed [HANDOFF.md](HANDOFF.md) and updated [DOCS_INDEX.md](DOCS_INDEX.md).

**Decision**

- Treat v2.0.40 scale telemetry as a structural safety gate, not final 99-player balance.
- Build one Night Artificial Forest 99-player candidate before more behavior tuning.
- Do not apply full flashlight/battery/fear behavior to every bot in the first night pass.

---

## v2.0.40 - Opportunistic Loot Scoring And Pistol Upgrade Tuning

**Scope**

- Applied a narrow Bot loot-selection behavior pass.
- Healthy idle bots now use the scored pickup selector, so mismatched ammo filtering and weapon-upgrade preferences are not bypassed.
- Post-kill opportunistic loot now starts only when no enemy is visibly tracked.
- Pistol holders prefer non-pistol weapon pickups more strongly, while same-pistol weapon pickups are less favored as low-ammo substitutes.
- `compare_scale_profiles.py` separates real pistol new-weapon objectives from older inflated pistol-to-non-pistol target metrics.
- No map data, loot counts, AI aggression, damage, zone pacing, or default/global 99 promotion changed.

**Verification**

- `git diff --check` passed.
- Python compile passed for the analysis toolchain.
- `verify_candidate_99_probe.gd` passed.
- Fresh 5-run sets passed `check_scale_telemetry.py --min-runs 5`:
  - `C:\tmp\game_dev_pistol_upgrade_xlarge60_v2040`: avg duration 99.9s, first upgrade 11.8s, stuck 24.4/run, fallback 0.0/run.
  - `C:\tmp\game_dev_pistol_upgrade_99_v2040`: avg duration 152.6s, first upgrade 19.7s, stuck 47.0/run, fallback 0.0/run.

**Decision**

- Keep the tuning. At 99 vs v2.0.39, ammo mismatch fell 8.1% -> 0.0%, and pistol ammo mismatch fell 6.6% -> 0.0%.
- Weapon-new objectives improved 2.0% -> 5.2%; pistol new-weapon objectives improved 0.5% -> 3.4%.
- Objective reliability stayed stable: collect 31.9% -> 31.7%, interrupt 59.7% -> 58.7%.
- Remaining issue is not ammo mismatch or raw pistol upgrade scoring. Under the new plan, inspect it only after Night Artificial Forest structure and night-visibility assumptions exist.

---

## v2.0.38-v2.0.39 Loot Objective Rollup

- v2.0.38 narrowed combat low-ammo looting, skipped unusable mismatched ammo, and gave pistol users bounded non-pistol weapon preference.
- v2.0.38 improved 99 same-weapon ammo objectives 33.5% -> 53.1% and reduced ammo mismatch 13.1% -> 10.2%.
- v2.0.39 added diagnostic-only loot objective context so collection/interruption is grouped by the original objective target.
- v2.0.39 showed residual mismatch was mostly idle pistol holders targeting non-pistol ammo; new-weapon objective collection was healthy at 99.

---

## v2.0.30-v2.0.37 Scale Diagnostics Rollup

- v2.0.30 changed the candidate map toward strategic gates and reduced overly heavy gate cover after stuck risk.
- Primary choke pressure became readable: 99 combat damage on route reached 70.1%, primary-choke damage 24.7%, transit-choke POI damage 20.9%.
- v2.0.31-v2.0.35 added CHASE location, pickup location, POI band, acquisition source, and route/POI overlap diagnostics.
- Main finding: target acquisition remained mostly route-bound, but 99 had thinner active coverage and more loot/recover movement.
- v2.0.36-v2.0.37 added loot objective start/outcome and selection context diagnostics.
- Main finding: weapon/ammo objectives dominated at 99, while heal/armor objectives fell; ammo mismatch and objective interruption were the narrowest actionable issues.

---

## v2.0.1-v2.0.29 Foundation Rollup

- Added `MapDefinition.gd` compatibility over legacy `mapSpec`.
- Moved map-scale spawn/loot/zone data toward definition/preset-owned data.
- Added read-only Full Map overlay using the same map feature data as the minimap path.
- Added validation tooling for world bounds, POI radii, obstacles, spawn clearance, loot coverage, route roles, and scale envelopes.
- Opened scale path through `medium_24`, `large_40`, `xlarge_60`, and candidate-only `target_99_probe`.
- Added normalized scale analysis, route-pressure telemetry, POI proximity diagnostics, and scale comparison tooling.
- Default map/global 99 promotion was never made.

---

## v1.12 Artifact/Asset Rollup

- Added Escape Capsule and Ghost Grass, then normalized all six starting artifact icons.
- Added `PlayerArtifactRuntime.gd`, `PlayerArtifactVisuals.gd`, and `ArtifactIconResolver.gd`.
- Artifact selection UI and in-game HUD now use catalog-backed artifact icons.
- Bush GLB visuals are integrated as cosmetic replacement while `Bush.tscn` remains gameplay authority.
- Generated tree/rock/log/landmark GLBs remain deferred.

---

## Current Next

1. Draft the first 10-15 minute pacing adjustment plan from the baseline report without applying gameplay tuning yet.
2. Keep the Night Artificial Forest 99 candidate and `target_99_probe` as non-default structural safety gates.
3. Do not expand bots into full flashlight, battery, fear, blackout, or cone-vs-cone night systems before the pacing adjustment plan has a clear verification path.

## Archive Pointers

| Path | Contents |
|---|---|
| [devlog/DEVLOG_full_2026-06-08.md](devlog/DEVLOG_full_2026-06-08.md) | Full active devlog before Night Artificial Forest compression |
| [archive/MASTERPLAN_full_2026-06-08.md](archive/MASTERPLAN_full_2026-06-08.md) | Full roadmap before Night Artificial Forest compression |
| [devlog/DEVLOG_full_2026-05-26.md](devlog/DEVLOG_full_2026-05-26.md) | Full active devlog before v1.11.35 compression |
| [devlog/v1.11_full_2026-05-26.md](devlog/v1.11_full_2026-05-26.md) | Full v1.11 slice summary before compression |
