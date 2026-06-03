# Battle Capsule Master Plan

> Last updated: 2026-06-03 (v2.0.30 candidate strategic-route pressure pass)

This is the active roadmap. Full pre-compression details are preserved in [archive/MASTERPLAN_full_2026-05-26.md](archive/MASTERPLAN_full_2026-05-26.md). Older historical plans live under `docs/archive/`.

## Current Status

| Item | Status |
|---|---|
| Current line | v2.0-dev: MapDefinition + player scale foundation |
| Latest completed slice | v2.0.30: candidate strategic-route pressure pass |
| Next structural slice | v2.0.31: CHASE recovery / POI-pressure follow-up |
| v1.10 status | Structurally closed for Main-owned data/catalog/presentation cleanup |
| Release status | Paused; continue version-to-version development unless a release is explicitly requested |
| External assets | `asset_generator/` and local prompt scratch files stay untracked unless explicitly integrated |

Expected Godot startup warning while missing generated assets remain unresolved:

```text
AssetCatalog: 7 configured asset paths are missing; fallbacks remain active.
```

## Active Principles

- Keep `Main.gd` as the orchestrator and match-global state owner.
- Preserve single-source state ownership in `Main.gd` for `zone`, `mission_tracker`, `player_ref`, `alive_count`, game-over flow, pressure trigger flags, and Telemetry hook calls until a dedicated migration plan exists.
- Prefer small catalog, tuning, formatter, evaluator, controller, director, planner, and store boundaries over broad gameplay rewrites.
- Gameplay numbers shown in UI/descriptions should come from the same data/tuning used by logic whenever practical.
- Do not start 99-player runtime scale, default/playable map promotion, mission map theming, bot artifacts, or artifact upgrade trees without an explicit migration plan.
- Active docs should stay compact. Raw/full details belong in `docs/archive/` or `docs/devlog/` snapshots.

## Active Docs

| Document | Purpose |
|---|---|
| [../CLAUDE.md](../CLAUDE.md) | Session onboarding and default reading path |
| [HANDOFF.md](HANDOFF.md) | Short next-session context |
| [DOCS_INDEX.md](DOCS_INDEX.md) | Documentation routing and active-doc budgets |
| [DEVLOG.md](DEVLOG.md) | Compressed recent verified work |
| [IMPACT_MAP.md](IMPACT_MAP.md) | Ownership and change-impact checks |
| [ARCHITECTURE.md](ARCHITECTURE.md) | Module boundaries; open for structural changes |
| [TESTING.md](TESTING.md) | Verification criteria |
| [ASSET_BRIEF.md](ASSET_BRIEF.md) | Stable external asset style and format brief |
| [ASSET_STATUS.md](ASSET_STATUS.md) | Current asset integration state and deferred asset decisions |

## Boundary Role Rules

| Role | Owns | Must not own |
|---|---|---|
| `Main.gd` | Match-global state, scene wiring, lifecycle orchestration, Telemetry hooks | Static catalogs, formatting tables, reusable tuning defaults |
| `*Tuning.gd` | Numeric thresholds, fallback values, label helpers for those values | Runtime counters, scene lookups, mutation, policy orchestration |
| `*Catalog.gd` / `*Data.gd` | Static ids, descriptor construction, resource/data lookup | Runtime progress, evaluation side effects, scene state |
| `*Formatter.gd` / `*Builder.gd` / `*Resolver.gd` | Text, display specs, node construction, icon/visual lookup | Gameplay decisions, hidden duplicated thresholds |
| `*Evaluator.gd` | Pure condition checks from explicit context and descriptor data | Counters, timers, file I/O, reward/penalty execution |
| `*Controller.gd` / `*Director.gd` / `*Planner.gd` | Bounded runtime process, placement, or planning inside one domain | Match-global ownership that should remain in `Main.gd` |
| `*Store.gd` | File persistence and schema compatibility for one concern | Gameplay timing, UI formatting, evaluation rules |

## Structural State

### v1.10 Main Slimdown

Complete enough for v1.11:

- Main-owned item/resource pools, runtime match tuning, UI panel builders, match bootstrap helpers, pressure effect execution, bot spawn planning, loot/supply creation, and world/menu presentation defaults have first-pass boundaries.
- Routine edits to item display, resources, menu/help/records/result/pause/artifact/Hell announcement UI, and Main runtime tuning no longer require reading unrelated `Main.gd` systems.
- Intentionally retained in `Main.gd`: scene callbacks, exported scene/count defaults, current match state, zone, mission tracker, player reference, alive count, game-over flow, pressure trigger/effect flow, and Telemetry hook calls.
- Remaining v1.10.x item/asset readability polish can continue as narrow visual patches, but it does not block v1.11.

### v1.11 Subsystem Boundaries

Current audit result: direction is coherent enough to continue. The main risk was documentation and repeated slice drift, not a specific broken runtime authority.

| Domain | Current state |
|---|---|
| Hell | `HellEventController.gd` under `src/systems/hell/`; `HellTuning.gd` owns config-backed event tuning. Main still selects modifiers and wires announcements. |
| Zone | `ZoneController.gd` under `src/systems/zone/`; Main still owns `zone`, while Bot/Player/Minimap read through Main-owned references. |
| Loot/Supply | `LootSpawner`, `SupplyDropController`, and `LootSpawnDirector` live under `src/systems/loot/`; Main keeps supply minimap state and Telemetry hooks. |
| Mission | Catalog, HUD formatting, bonus evaluation, pressure condition evaluation, badge storage, description formatting, and tuning now have separate owners. `MissionTracker.gd` keeps active state, counters, hooks, public wrappers, pressure descriptor snapshots, and context assembly. |
| Player | HUD builders/renderers, weapon icon resolver, tuning constants, occluder fader, artifact runtime state, and artifact visuals are split. `Player.gd` keeps movement, combat, heal, artifact application, pickup, HUD update, zone warning, Sfx, and Telemetry runtime behavior. |
| Bot | Tuning, debug label construction, marker formatting, visual kit, and skin controller are split. `Bot.gd` intentionally keeps AI state machine, perception, navigation, loot/supply decisions, combat, death/drop behavior, and Main-owned state reads. |
| Entity/Pickup | Weapon slot tuning, pickup presentation, and pickup icon resolution are split. `Pickup.gd` keeps runtime nodes, focus/LOS, item collection side effects, Telemetry, and lifecycle. |
| Mission numeric text | Bonus and pressure mission descriptions now generate from mission/condition data plus shared tuning where practical. Pressure feasibility cutoffs live in `MissionTuning.gd`. |
| Docs | v1.11.35 snapshots full active docs and compresses default-session docs. |

## Recent Slices

| Slice | Result |
|---|---|
| v1.11.31 | Bonus mission descriptions/HUD/evaluation thresholds now read from `MissionData` and `MissionTuning`. |
| v1.11.32 | Pressure mission descriptions generate from `conditions[]`. |
| v1.11.33 | Pressure feasibility cutoffs moved to `MissionTuning.gd`. |
| v1.11.34 | Boundary role rules and active-document budgets defined. |
| v1.11.35 | Full docs snapshotted; active roadmap/devlog/version summary compressed. |
| v1.11.36 | `Main.gd` no longer reads MissionTracker private pressure descriptor state; v1.11 marked structurally closed. |

Full slice history is preserved in [devlog/v1.11_full_2026-05-26.md](devlog/v1.11_full_2026-05-26.md) and [devlog/DEVLOG_full_2026-05-26.md](devlog/DEVLOG_full_2026-05-26.md).

## v1.12 Complex Artifacts

**Goal**: Add replay-changing artifacts without undoing v1.10-v1.11 boundaries. First-pass complex artifacts should be player-owned runtime effects with explicit catalog data and small hooks.

**v1.12.1 decision**

- First candidate: **Emergency Shell**.
- Reason: one-shot low-HP shield is a bounded player-runtime effect with clear state (`unused/triggered`), visible shield-bar feedback, and limited balance impact.
- Rejected as first candidates:
  - Glass Capsule: too close to existing passive stat modifiers; it would not prove the complex-artifact runtime boundary.
  - Ghost Grass / Pulse Scanner / Marked King / Overheat Barrel: more interesting, but each touches perception, enemy reveal, minimap/HUD, kill rewards, or sustained-fire tuning before the runtime boundary is proven.

**Emergency Shell boundary contract**

| Owner | Responsibility |
|---|---|
| `ArtifactCatalog.gd` | Selection descriptor, id, label, color, description text, numeric effect data. |
| `PlayerArtifactRuntime.gd` | One-match trigger state and pure trigger decision from explicit player health/shield context. |
| `Player.gd` | Own helper instance, call it from damage flow, apply returned shield update, update HUD/Sfx/Telemetry hooks. |
| `Telemetry.gd` | Record selected artifact id and trigger count without changing existing score schema. |
| `Main.gd` | Keep selection/apply orchestration only; no artifact effect logic. |

**First implementation guardrails**

- Trigger only once per match.
- Trigger after a non-lethal hit or tick leaves player HP at or below the configured threshold. Do not intercept lethal damage in the first pass.
- Use catalog-owned numbers for threshold and shield amount; visible description must be generated from those values.
- Preserve existing artifacts and simulations.
- Do not add bot artifacts, map-themed artifacts, or artifact upgrade trees in v1.12.2.

**v1.12.2 result**

- Added Emergency Shell as a starting artifact.
- Added `PlayerArtifactRuntime.gd` for one-match player artifact trigger state.
- Emergency Shell triggers once after non-lethal damage leaves HP at or below the configured threshold, then grants the configured shield amount up to current max shield.
- Added artifact Telemetry metrics and `tools/verify_artifact_runtime.gd` smoke coverage.

**v1.12.3 result**

- Added `tools/verify_artifact_selection_layout.gd` to check artifact card count, required text, Emergency Shell presence, and default 1280px row fit.
- Verified the five-card selection row is 796px wide, so no immediate card layout change is needed.
- Kept Emergency Shell values unchanged for now.
- Shortlisted **Ghost Grass** as the next candidate because bush-exit stealth grace is bounded player runtime state and does not require minimap/HUD direction UI.

**v1.12.4 result**

- Added **Ghost Grass** as a starting artifact.
- Catalog-owned values: 2.0s bush-exit grace, 0.45 visual stealth multiplier, 0.6 footstep radius multiplier.
- `PlayerArtifactRuntime.gd` now owns both Emergency Shell one-shot state and Ghost Grass timer state.
- `Player.gd` only reports bush transitions, applies returned runtime effects, and keeps reveal/fire behavior authoritative through `reveal_timer`.
- Telemetry records `ghost_grass_started`; selection layout smoke now verifies six cards at 958px row width.

**v1.12.5 result**

- Added `PlayerArtifactVisuals.gd` as the owner for player-attached artifact visual nodes.
- `ArtifactCatalog.gd` now gives every starting artifact a `visual_id`.
- First-pass primitive visuals:
  - Red Trigger: shotgun-only red glow.
  - Armor Sponge: shield-ratio armor plates.
  - Silent Core: running afterimages.
  - Zone Battery: blue plasma near the zone edge.
  - Emergency Shell: back pack that ruptures on trigger.
  - Ghost Grass: short green wake while active.
- Gameplay state stays in `PlayerArtifactRuntime.gd`; visual nodes only read `Player.gd` context snapshots and artifact events.

**v1.12.6 result**

- Added `tools/capture_artifact_visual_gallery.gd` to render all current artifact visual states into `C:/tmp/artifact_visual_gallery.png`.
- Reviewed the generated gallery and tuned the first-pass visuals for readability.
- Silent Core now trails opposite movement direction instead of stacking directly over the body.
- Ghost Grass now uses a brighter lime/yellow-green wake with stronger blades so it does not blend into the default player tint.

**v1.12.7 result**

- Added `ArtifactIconResolver.gd` and normalized artifact icon ids as `artifact.<id>`.
- Artifact selection UI gained artifact icon images.
- The in-game artifact HUD indicator now uses an icon instead of text.
- Existing runtime artifact PNGs cover Red Trigger, Armor Sponge, Silent Core, and Zone Battery; Ghost Grass and Escape Capsule use catalog fallback icons until generated PNGs are selected.
- `tools/verify_artifact_selection_layout.gd` gained icon coverage.

**v1.12.8 result**

- Renamed Emergency Shell presentation to **Escape Capsule** while keeping the stable internal id `emergency_shell`.
- Escape Capsule now purges all ammo after its one-shot shield trigger.
- Red Trigger now increases ranged firing reveal duration to 3.0s.
- Armor Sponge now scales movement speed from normal at 0 shield to the previous 0.75 floor at max shield; heal conversion is capped at 50 shield and uses 50% of heal value.
- Silent Core no longer halves max HP/shield; instead, the first unrevealed non-knife shot is forced to miss.
- Ghost Grass is now a short-risk stealth: 1.25s after bush exit, 5.0s cooldown, and 1.5x gun damage plus immediate break if shot while active.
- Zone Battery remains unchanged.

**v1.12.9 result**

- Artifact selection now uses fixed circular icon options with one-line summaries instead of six long cards.
- Selecting an option updates one stable detail card with the full generated `line1`/`line2` description and choose button.
- `ArtifactCatalog.gd` now provides catalog-owned `summary` text per artifact, keeping short option text near the detailed artifact data.
- Added `tools/capture_artifact_selection_ui.gd`, which renders `C:/tmp/artifact_selection_ui.png` for screenshot review.
- `tools/verify_artifact_selection_layout.gd` now checks option count, button icons, default detail state, detail update on option press, and 1280px row fit.
- Follow-up patch centers option icons with embedded `TextureRect`s instead of `Button.icon`; generated source icons currently exist only for Red Trigger, Armor Sponge, Silent Core, and Zone Battery.
- `ArtifactIconResolver.gd` now falls back to raw PNG `Image.load()` when Godot import metadata is absent, so the four existing runtime artifact PNGs load before procedural fallback icons.

**v1.12.10 result**

- Promoted selected generated bush GLBs into runtime assets: `assets/props/forest/bush_dense.glb` and `assets/props/forest/bush_low.glb`.
- Added `forest.bush`, `forest.bush.low`, and `forest.bush.dense` paths under `data/asset_catalog.json`.
- `Main.gd` now passes `asset_catalog` into `WorldBuilder.generate_world()`.
- `WorldBuilder` keeps `Bush.tscn` Area3D gameplay/collision as the authority, attaches catalog GLB visuals when available, disables imported visual collision nodes, and hides the old cylinder mesh only after a catalog visual loads.
- Raw `.glb` files load through `GLTFDocument` when Godot import metadata is absent.
- Added `tools/verify_bush_prop_assets.gd` to verify catalog paths, raw GLB mesh counts, and default-map bush replacement.
- Follow-up patch tracks bush occupancy by Area instance, restores same-bush visibility semantics, keeps outside bush concealment strict by default, reuses the old cylinder mesh as player-entry dark tint, and adds rustle feedback on enter/exit/movement.
- Added `tools/verify_bush_interaction.gd` to pin same-bush visibility, outside concealment, reveal override, entry/exit state, tint visibility, and rustle feedback.
- Follow-up patch animates only the nearest GLB bush clumps instead of swaying the whole catalog visual.

**v1.12.11 result**

- Promoted generated Escape Capsule and Ghost Grass artifact PNGs into normalized runtime icons.
- Added catalog paths for all six starting artifact icons.
- `tools/verify_artifact_selection_layout.gd` now checks that each starting artifact has a real catalog icon file path, not just a procedural fallback texture.

## Next Work

1. **v2.0 MapDefinition + player scale** — primary priority.
   - Design MapDefinition resource and Full Map UI foundation.
   - Expand map size and player count toward real playable scale.
   - Requires AI LOD, spawn/loot density rescale, zone/pathing rescale before 99-player target.
2. **v1.10.x Item/Asset Readability Polish**
   - Only narrow visual/readability patches.
   - Keep generated source assets untracked unless selected files are integrated into runtime assets.
3. **Optional v1.11 reopen**
   - Only for a concrete boundary bug or stale doc route.
   - Avoid new helper extraction based on line count alone.

## v2.0 MapDefinition Plan

**Goal**: make map scale, match scale, spawn/loot density, zone profile, minimap/full-map metadata, and selected visual props an explicit definition layer before increasing player count.

**Boundary contract**

| Owner | Responsibility |
|---|---|
| `MapDefinition` | Static map id/name, world size, POIs, obstacles, routes, scale presets, spawn/loot/zone profile ids or overrides. |
| `WorldBuilder.gd` | Build world geometry and visual prop overlays from a definition; keep collision/gameplay authority explicit. |
| `Main.gd` | Continue owning match-global state and orchestration; consume sanitized definition data instead of scattering map-scale defaults. |
| `Minimap.gd` / future Full Map UI | Render definition features, current/next zone, player/supply markers, and selected POI metadata; no match logic. |
| Runtime tuning helpers | Clamp and merge scale preset values; do not discover scenes or mutate match state. |

**First slices**

1. Add a compatibility loader so current `MapSpec` JSON can be wrapped as the first `MapDefinition`. Done in v2.0.1.
2. Move map-specific spawn radius, loot count/density, and zone radius profile into definition-owned or preset-owned data while preserving `game_config.json` fallback behavior. Done in v2.0.2.
3. Add validation tooling for world bounds, POI radii, obstacle bounds, spawn radius, loot hotspot coverage, and zone radius sanity. Done in v2.0.4.
4. Build a Full Map UI foundation from the same minimap feature data; keep it read-only at first. Done in v2.0.3.
5. Scale bots by presets before 99-player work: 11 -> 24 -> 40 -> 60 -> 99, with AI LOD and telemetry checks at each step. 60-bot scale is the current active runtime surface; target_99 is still envelope/candidate data only.

**Non-goals for the first v2.0 pass**

- Do not promote new default/playable maps, mission map theming, bot artifacts, artifact upgrade trees, fire spread, or interior/landmark gameplay.
- Do not redesign landmark collision until a feature needs precise interiors or climbable structures.
- Do not bulk-promote generated GLBs; keep prop upgrades tied to visual or gameplay needs.

**v2.0.1 result**

- Added `MapDefinition.gd` as a compatibility wrapper around current `MapSpec` JSON.
- The wrapper exposes map id/name, map spec, match/runtime/zone overrides, scale presets, validation, and summary data without changing runtime call sites.
- Added `tools/verify_map_definition.gd` to validate legacy MapSpec wrapping and wrapper-format overrides.

**v2.0.2 result**

- `data/mapSpec_example.json` now carries definition-owned baseline match/runtime/zone values plus `baseline` and `medium_24` scale presets.
- `Main.gd` loads MapDefinition before world generation and applies the selected scale preset while preserving command-line tuning overrides.
- `MatchRuntimeTuning.gd` and `LootSpawner.gd` now support `hotspot_density_mult` so loot density can scale independently from loot count.
- `scale_preset=medium_24` is available for smoke scale runs without changing the default baseline behavior.

**v2.0.3 result**

- Added a read-only Full Map overlay toggled from `Main.gd` during active matches.
- The overlay renders world bounds, POIs, generated obstacle footprints, current/next zone, player facing, and supply marker state from `MapDefinition` / `MapSpec` / `WorldBuilder.get_minimap_features()`.
- Added `tools/verify_full_map_overlay.gd` for projection, layout bounds, generated feature ingestion, and runtime marker smoke coverage.

**v2.0.4 result**

- Expanded `MapDefinition.validate()` to catch POI density/bias issues, oversized POI radii, rotated obstacle footprint bounds, spawn/runtime clearance conflicts, loot density gaps, and implicit zone radius sanity.
- `tools/verify_map_definition.gd` now includes negative validation probes so the new checks are pinned.
- Preset compatibility now supports flat match keys as a fallback while nested `match` sections remain preferred.

**v2.0.5 result**

- Added `SettingsManager.gd` so settings file persistence, master volume application, fullscreen state, and clamping are no longer implemented directly in `Main.gd`.
- `Main.gd` keeps settings panel callbacks as scene wiring only.
- Added `tools/verify_settings_manager.gd` to pin load/save/clamp/missing-file behavior.

**v2.0.6 result**

- Added the `large_40` scale preset with 40 bots, 104 loot, 56m spawn radius, 1.12 hotspot density multiplier, and slightly longer zone timings.
- Extended `verify_map_definition.gd` so the new preset's match/runtime/zone overrides are pinned.
- Smoked `scale_preset=large_40` through one normal simulation before any 60/99-player work.

**v2.0.7 result**

- Added `MapDefinition` helpers for world bounds, bounds UV conversion, position clamping, and world-distance scaling.
- Added defensive POI/obstacle descriptor accessors so map UI can ask the definition for presentation-safe placement data.
- `FullMapOverlay` and `Minimap` now prefer `MapDefinition` query APIs while retaining `MapSpec` fallback compatibility.

**v2.0.8 result**

- Added the `xlarge_60` scale preset with 60 bots, 144 loot, 56m spawn radius, 80 safe spawn attempts, 1.15 hotspot density multiplier, and 22/36/26 zone timings.
- Extended `verify_map_definition.gd` so the new preset's match/runtime/zone overrides are pinned.
- Smoked `scale_preset=xlarge_60` through one normal simulation; do not move to 99-player tuning until repeated 60-bot telemetry is reviewed.

**v2.0.9 result**

- Repeated `scale_preset=xlarge_60` for 5 normal simulations and analyzed `tools/sim_runs_current`.
- Result was stable at the regression-sentinel level: no zero damage, zero weapon damage, zero shot, or zero combat plan runs; average duration 93.2s.
- 99-player tuning remains blocked because first upgrade averaged 9.5s and disengage/stuck/survival volumes are high enough to require 60-bot spawn/loot distribution and telemetry gates first.

**v2.0.10 result**

- Retuned current `xlarge_60` to 120 loot, 1.05 hotspot density multiplier, 0.08/0.08 stage wave probabilities, 6x stage wave count multiplier, and 30s initial zone timer.
- Added `tools/check_scale_telemetry.py` as a repeated-run scale gate over zero sentinels, duration floor, first-upgrade pacing, recover deaths, stuck volume, and disengage volume.
- Repeated 5-run `xlarge_60` telemetry passed the new gate: avg duration 100.2s, avg first upgrade 11.1s, no zero damage/shot/plan sentinels.

**v2.0.11 result**

- Added sampled AI update-budget telemetry by bot state and archetype without adding LOD behavior.
- `tools/analyze_results.py` and `tools/check_scale_telemetry.py` now report AI update budget from the saved `ai` telemetry group.
- Repeated 5-run `xlarge_60` telemetry passed: avg duration 97.3s, avg first upgrade 12.6s, no zero damage/shot/plan sentinels, AI update budget samples=25210, avg=363.3us, max=28459us.
- Current evidence does not force immediate AI LOD; v2.0.12 should decide whether to plan bounded LOD now or continue with map-size/spawn distribution prerequisites before 99-player tuning.

**v2.0.12 result**

- Added explicit `xlarge_60` zone stage overrides because the prior preset slowed the first shrink but still inherited fast baseline stage 2+ timings.
- New 60-bot pacing keeps early compression slower and accelerates later: stage 2 is 30s wait / 24s shrink, then later stages move to 22/18, 14/12, and 10/10.
- Repeated 5-run `xlarge_60` telemetry passed: avg duration 103.9s, avg zone stage 2.00, avg first upgrade 11.8s, no zero damage/shot/plan sentinels, AI update budget avg=369.8us.
- Next scale work should review whether the current 120m map and 56m spawn radius are still adequate for 60 bots before any 99-player preset.

**v2.0.13 result**

- Added spawn distribution telemetry and scale-gate output for requested/placed count, fallback usage, nearest spacing, attempt count, and spawn-annulus saturation.
- Repeated 5-run `xlarge_60` telemetry passed: placed=61/61, fallback=0.0/run, min nearest=3.5m, avg nearest=7.1m, avg attempts=1.5, max attempts=7, saturation=0.24.
- Current 120m map / 56m spawn radius is technically viable for 60 bots, but the minimum spacing already sits at the clearance floor.
- 99-player tuning remains blocked until a larger map/spawn envelope is explicitly planned.

**v2.0.14 result**

- Added `scale_envelopes.target_99` to the definition as a planning envelope, not a runtime preset.
- The 99-bot prerequisite is now explicit: minimum 160m world / 72m spawn radius and preferred 180m world / 78m spawn radius, with 8m inner radius, 3.5m clearance, and saturation guardrails.
- Added `tools/verify_scale_envelope.gd` so `target_99` cannot be confused with a playable `scale_preset` and the envelope math stays pinned.
- Next work should create a non-default larger map candidate or map-rescale prototype that satisfies this envelope before any 99-player runtime preset.

**v2.0.15 result**

- Added `data/mapSpec_large_candidate.json` as a non-default 180m candidate map with 11 POIs and 35 obstacles.
- The candidate `xlarge_60` surface uses 60 bots, 150 loot, 78m spawn radius, 120 safe spawn attempts, and a slower early zone curve.
- `target_99` remains an envelope only; no 99-player runtime preset or default map switch was added.
- Added `tools/verify_large_map_candidate.gd`; it passed with 8.5m boundary margin and target_99 preferred saturation=0.20.
- Next work should add a safe candidate-map runtime loading/smoke path before any 99-player preset.

**v2.0.16 result**

- Added a `map_spec_path` CLI/test override while keeping `res://data/mapSpec_example.json` as the exported default.
- `MatchTuning.gd` now preserves raw resource path casing and accepts `map_spec_path`, `map_spec`, `map_definition_path`, and `map_definition` aliases.
- Added `tools/verify_map_runtime_path.gd` for CLI path parsing and candidate `xlarge_60` resolution.
- Candidate-map `xlarge_60` passed 5-run telemetry: avg duration 99.7s, fallback=0.0/run, min nearest=3.5m, saturation=0.12, no zero sentinels.
- Next work may add a guarded 99-target probe only on the non-default candidate path; no default map switch or global 99-player preset yet.

**v2.0.17 result**

- Added `target_99_probe` only on the non-default 180m candidate map.
- The default map still has no 99-player runtime preset, and `target_99` remains a planning envelope.
- Added `tools/verify_candidate_99_probe.gd` to keep the probe candidate-only and verify envelope fit.
- Candidate-map `target_99_probe` passed 5-run telemetry: avg duration 129.4s, fallback=0.0/run, min nearest=3.5m, saturation=0.20, AI avg=439.9us, no zero sentinels.
- Next work should analyze 99-probe pacing, zone escape volume, and engagement density before default/global promotion.

**v2.0.18 result**

- `tools/analyze_results.py` now reports scale-normalized per spawned entity/minute rates and aggregate doctrine state mix.
- Current 99-probe normalized output: damage=27.7, shots=3.35, plans=1.83, disengage=0.56, stuck=0.11, zone_fire=1.02, survival=1.24.
- Current 99-probe state mix: ZONE_ESCAPE 26.0%, DISENGAGE 22.0%, CHASE 19.2%, ATTACK 18.9%, IDLE 14.0%.
- No gameplay tuning was made; next work should compare candidate `xlarge_60` and `target_99_probe` through the same analyzer before changing numbers.

**v2.0.19 result**

- `tools/simulate_matches.py` now accepts `out_dir=` / `sim_out_dir=` so repeated comparison runs can stay outside the repo.
- Added `tools/compare_scale_profiles.py` for normalized 60-vs-99 comparison.
- Fresh candidate-map 5-run gates passed for both `xlarge_60` and `target_99_probe`.
- 99 vs 60 deltas: duration +7.1s, spawn saturation +0.08, AI avg +123.9us, ZONE_ESCAPE +2.14pp, DISENGAGE +5.32pp.
- Next work should decide whether the higher 99 DISENGAGE/ZONE_ESCAPE share is a zone profile issue, spawn/POI density issue, or bot outnumbered-behavior issue.

**v2.0.20 result**

- `tools/compare_scale_profiles.py` now prints `DISENGAGE sec/trigger` and a pressure-decision summary.
- Current 99 pressure is not spawn/pathing or AI budget.
- DISENGAGE pressure looks duration/exit-related rather than trigger-frequency-related.
- ZONE_ESCAPE rose mildly without higher normalized zone-fire, so review it after DISENGAGE exit behavior.
- Do not tune zone profile, spawn/POI density, or outnumbered thresholds until persisted DISENGAGE reason telemetry is available.

**v2.0.21 result**

- Persisted full DISENGAGE entry volume as `tactics.disengage_entries` while preserving `disengage_triggered` as the existing outnumbered/legacy gate metric.
- Persisted reason counts in `tactics.disengage_reasons` and `tactics.disengage_reasons_by_archetype`.
- Reason-aware analyzer/compare output now reports entry rates, seconds per entry, and per-reason entity/min deltas.
- 1-run candidate-map smoke confirmed the new telemetry is saved and existing scale gate semantics still pass with `--min-runs 1`.
- Next work should rerun fresh candidate 60-vs-99 5-run sets and compare reason deltas before any behavior tuning.

**v2.0.22 result**

- Fresh 5-run candidate-map sets with reason telemetry passed scale gates for both `xlarge_60` and `target_99_probe`.
- 99 vs 60: duration +41.8s, first upgrade +14.5s, damage/entity/min -11.63, shots/entity/min -1.42, plans/entity/min -0.99, DISENGAGE state +4.25pp.
- Reason deltas do not support tuning outnumbered thresholds first: entries/entity/min -1.20, survival_break -0.97, outnumbered -0.21, `DISENGAGE sec/entry` +0.25.
- The first 99-specific tuning target is economy/combat tempo dilution, not DISENGAGE trigger frequency.
- Do not change zone pacing, spawn/POI density, or bot behavior thresholds until the tempo diagnosis is complete.

**v2.0.23 result**

- `compare_scale_profiles.py` now reports economy tempo rows and a `Tempo decision` summary.
- `analyze_results.py` now reports economy-normalized rows for single run directories.
- Fresh 99 vs 60 economy deltas: weapon pickups/entity/min -0.15, non-pistol pickups/entity/min -0.07, rare pickups/entity/min -0.12.
- Raw 99 loot count is close to 60 density, so the issue is actual non-pistol/rare access and combat throughput, not just total loot count.
- Next tuning should be candidate-only and target loot/economy access before zone pacing or bot-threshold changes.

**v2.0.24 result**

- Added runtime loot `rare_bias_mult` and applied it only to candidate `target_99_probe`.
- Final v3 candidate adjustment keeps raw `loot_count` at 240 and `stage_wave_count_mult` at 9, with `hotspot_density_mult=1.16` and `rare_bias_mult=1.45`.
- Adjusted 99 v3 gate passed; first upgrade improved from 27.4s to 16.6s and DISENGAGE state fell slightly.
- Combat throughput remains the major gap versus 60: damage/entity/min -12.67, shots/entity/min -1.51, plans/entity/min -1.06, duration +42.7s.
- Next work should diagnose engagement density/combat throughput before zone pacing or bot-threshold tuning.

**v2.0.25 result**

- `compare_scale_profiles.py` now reports match-minute throughput, ATTACK-minute efficiency, engage sample density, active combat share, and an engagement-density decision.
- `analyze_results.py` now reports matching single-directory engagement-density rows.
- 99 v3 has 64% more spawned entities than 60, but only +7% damage/match min, +8% shots/match min, and +1% plans/match min.
- Damage/ATTACK min and shots/ATTACK min are not worse, so per-attack lethality is not the blocker.
- Next work should inspect target acquisition, chase routing, and encounter spacing before zone, damage, or retreat-threshold tuning.

**v2.0.26 result**

- Persisted `doctrine.chase_context_time_by_archetype` and tagged CHASE as `combat`, `loot`, `recover_loot`, or `unknown`.
- Fresh 5-run 60 and adjusted 99 candidate sets both passed scale gates.
- CHASE context mix shows 99 has less combat CHASE and more loot/recovery CHASE: 60 combat 50.0% vs 99 combat 45.2%; 99 loot+recover_loot 54.8%.
- Fresh 99 still fails to scale match-minute combat throughput with population, while per-ATTACK efficiency remains intact.
- Design correction: CHASE-to-combat share is not the target by itself. Battle royale flow needs loot movement, rotations, and contested power positions before tuning combat frequency.

**v2.0.27 result**

- Reframed the next scale question from objective-interrupt tuning to strategic flow: why entities move, which routes they cross, and where combat pressure should appear.
- Added candidate-map strategic `routes` data for primary chokes, flanks, loot flow, and recovery re-entry without changing runtime movement or bot behavior.
- `MapDefinition` now exposes route descriptors and validates route id, role, width, point count, and world bounds when routes are present.
- Added `verify_strategic_flow_map.gd` to guard candidate POI role coverage, route role coverage, primary-choke alternate routes, and route-to-POI references.

**v2.0.28 result**

- `MapDefinition.describe_strategic_position()` classifies combat positions into POI role/name and route role/id.
- `Entity.gd` logs strategic context for combat damage and combat kills through `Telemetry.gd`.
- Telemetry now aggregates hits, damage, and kills by POI role, route role, and route id.
- `analyze_results.py` and `compare_scale_profiles.py` report route-pressure mixes and decisions.
- 1-run candidate `xlarge_60` smoke confirmed route-pressure telemetry is written and readable; the normal 1-run scale gate failed only due to an early 1.7s upgrade sample, so use fresh 5-run sets for balance decisions.
- Next work should run fresh 60-vs-99 candidate route-pressure comparison before changing route layout, pickup spacing, AI aggression, damage, or zone pacing.

**v2.0.29 result**

- Fresh candidate-map 5-run `xlarge_60` and `target_99_probe` sets both passed scale gates.
- 99 preserves broad route pressure but does not create intended contested terrain pressure: combat damage on route is 63.2% -> 60.7%, while primary-choke damage is only 0.4% -> 1.0%, flank damage is 3.0% -> 2.7%, and transit-choke POI damage stays below 0.4%.
- 99 still has thinner active engagement coverage despite healthy per-ATTACK efficiency: `ATTACK+CHASE` 41.6% -> 38.3%, `RETREAT+ESCAPE` 43.7% -> 47.7%, damage/ATTACK min 758.8 -> 872.3.
- Next work should be candidate-only strategic-route pressure design before AI aggression, damage, or generic zone-speed tuning.

**v2.0.30 result**

- Candidate map `3.3-candidate` adds strategic gate POIs at West Ridge Overlook and East Pine Gate, retunes primary-choke paths through them, reduces Central Meadow dominance, and keeps only light offset high-rock cover after heavy-cover smoke raised stuck triggers too far.
- `verify_strategic_flow_map.gd` now guards 4 transit-choke POIs, multi-point primary-choke paths, central-route width, and exact gate classification.
- Fresh 5-run 60 and 99 candidate sets both passed scale gates after the obstacle reduction.
- 99 now has material contested-terrain pressure: combat damage on route 70.1%, primary-choke damage 24.7%, transit-choke POI damage 20.9%.
- The next blocker is no longer route existence. 99 still has thinner active coverage and more recovery movement: `ATTACK+CHASE` 39.9% -> 37.8%, CHASE combat 49.5% -> 40.0%, CHASE recover-loot 18.6% -> 27.7%.
- Next work should inspect CHASE recovery/loot interruptions and POI pressure distribution before AI aggression, damage, or generic zone-speed tuning.

## Deferred Asset Upgrades

Recorded for future reference. Do not pursue until the relevant gameplay feature is being implemented.

| Upgrade | Trigger condition |
|---|---|
| Bush B direction — cell-based Area3D per leaf clump, `bush_cell.glb` single-clump asset, map spec as cell coordinate arrays | When fire spread or per-cell vision events (flare, illumination) are implemented |
| GLB visual replacement pass — rocks, trees, fallen tree, log pile, landmarks as `CatalogPropVisual` over existing procedural collision | When map visual upgrade is prioritized; purely cosmetic, no gameplay impact |
| Tier 1 dynamic props — barrel_cluster, fire_pit, log_pile as event-capable objects | When fire/explosion events are implemented alongside Bush B |
| Landmark collision redesign — cabin, watchtower with hand-crafted CollisionShape3D matching GLB geometry | When interior entry or precise landmark interaction is planned |

Current bush GLB integration (v1.12.10) is kept as-is. `asset_generator/` remains untracked.

## Completion Gates

### v1.11 Gate

- Status: structurally closed as of v1.11.36.
- Directory moves must preserve class names, preload paths, scene references, runtime behavior, and Telemetry schema.
- New boundaries must match the role rules in this file.
- Formatters/builders must not hide gameplay thresholds unless those values are passed from data/tuning owners.
- Evaluators should receive explicit context and avoid side effects.
- Controllers/directors may be stateful only inside one bounded domain.
- Docs-only slices verify with `git diff --check`; code slices verify with `git diff --check`, Godot headless quit, and at least one relevant simulation.

### Phase 2 Guardrails

| Future Area | Guardrail |
|---|---|
| v2.0 MapDefinition + Full Map UI | Requires config/debug foundation, v1.10 Main slimdown, and v1.11 subsystem closure |
| Forest 2.0 / City Map | Requires MapDefinition and large navigation stability checks |
| 99-player or large-map scale | Requires AI LOD, spawn/loot density rescale, zone/pathing rescale, and performance validation |

## Compact History

| Version | Summary |
|---|---|
| v1.11-dev | Subsystem directory and non-Main data/algorithm boundaries |
| v1.10-dev | Main slimdown, UI catalogs, supply/loot calculation boundaries |
| v1.9-dev | AssetCatalog hooks, audio/cosmetic IDs, debug logging hooks, scale-test CLI overrides |
| v1.8-dev | GameConfig, DebugFlags, DebugOverlay, AssetCatalog, runtime core icon pass |
| v1.7.x | AI doctrine, archetype readability, minimap/world footprint alignment |
| v1.6.x and earlier | Core battle royale prototype, missions, artifacts, telemetry, release foundation |

## Next Agent Checklist

- Read [HANDOFF.md](HANDOFF.md), [DOCS_INDEX.md](DOCS_INDEX.md), and this file before work.
- Before code changes, check [IMPACT_MAP.md](IMPACT_MAP.md) for ownership and cascade effects.
- Keep `asset_generator/` and `docs/ASSET_GENERATION_PROMPTS.md` untracked unless explicitly asked to integrate them.
- For asset generation, keep stable style/format rules in [ASSET_BRIEF.md](ASSET_BRIEF.md) and local prompt scratch out of commits.
- For docs-only work, verify with `git diff --check`; for code work, add Godot/simulation checks based on risk.
