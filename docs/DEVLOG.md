# Battle Capsule Active Devlog

> Last updated: 2026-06-08. Compressed recent work log. Full raw detail is preserved in [devlog/DEVLOG_full_2026-06-08.md](devlog/DEVLOG_full_2026-06-08.md).

Do not load full snapshots by default. Use this file for the current state and open archived logs only when exact slice detail is needed.

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

1. Convert the Night Artificial Forest concept into a first 99-player candidate `mapSpec`.
2. Keep existing 60/99 scale tools as structural safety gates only.
3. Add POI-level minimap/probe tests for `Sluice Crossing`, `Wire Maze`, `Black Ridge`, `Supply Flats`, and `False Clinic`.
4. Prototype player-facing flashlight before full bot night systems.
5. Add separate 10-15 minute pacing telemetry after the map and night assumptions are represented.

## Archive Pointers

| Path | Contents |
|---|---|
| [devlog/DEVLOG_full_2026-06-08.md](devlog/DEVLOG_full_2026-06-08.md) | Full active devlog before Night Artificial Forest compression |
| [archive/MASTERPLAN_full_2026-06-08.md](archive/MASTERPLAN_full_2026-06-08.md) | Full roadmap before Night Artificial Forest compression |
| [devlog/DEVLOG_full_2026-05-26.md](devlog/DEVLOG_full_2026-05-26.md) | Full active devlog before v1.11.35 compression |
| [devlog/v1.11_full_2026-05-26.md](devlog/v1.11_full_2026-05-26.md) | Full v1.11 slice summary before compression |
