# Battle Capsule Active Devlog

> Last updated: 2026-06-02. Compressed recent work log. Full historical detail is preserved in `docs/devlog/` and `docs/archive/`.

Do not load full snapshots by default. Use `docs/devlog/INDEX.md` and per-version summaries unless exact history is needed.

---

## v2.0.11 — AI Update Budget Telemetry Probe

**Scope**

- Added sampled bot AI update-budget telemetry: every fourth bot physics update records total elapsed update time by state and archetype.
- Extended saved simulation results with an `ai` group and taught `analyze_results.py` to report aggregate average/max update cost plus the highest-cost states.
- Extended the 60-bot repeated telemetry gate to print AI update budget and fail only on loose guardrail thresholds when AI samples are present.
- Kept this as instrumentation/backbone work; no AI LOD behavior or 99-player preset was added.

**Verification**

- `python -m py_compile tools\analyze_results.py tools\check_scale_telemetry.py` passed.
- Godot headless project load passed with expected AssetCatalog warning only.
- `verify_map_definition.gd` passed.
- `python tools\simulate_matches.py 5 normal scale_preset=xlarge_60` passed.
- `python tools\analyze_results.py tools\sim_runs_current` reported avg duration 97.3s, 0 runs under 60s, avg first upgrade 12.6s, and AI update budget samples=25210, avg=363.3us, max=28459us.
- `python tools\check_scale_telemetry.py tools\sim_runs_current` passed with AI update budget included.

---

## v2.0.10 — 60-Bot Distribution Tuning And Telemetry Gate

**Scope**

- Retuned `xlarge_60` as the active 60-bot test surface: 120 loot, 1.05 hotspot density multiplier, 0.08/0.08 stage loot wave probabilities, 6x stage wave count multiplier, and 30s initial zone timer.
- Added `tools/check_scale_telemetry.py` to fail repeated scale runs on zero combat sentinels, short duration, too-fast/too-slow first upgrade, excessive recover deaths, stuck volume, or disengage volume.
- Kept 99-player tuning blocked; this slice tightens the 60-bot gate instead of adding a larger preset.

**Verification**

- `verify_map_definition.gd` passed.
- `python tools\simulate_matches.py 5 normal scale_preset=xlarge_60` passed.
- `python tools\analyze_results.py tools\sim_runs_current` reported avg duration 100.2s, 0 runs under 60s, avg first upgrade 11.1s, and no zero-damage/shot/plan sentinels.
- `python tools\check_scale_telemetry.py tools\sim_runs_current` passed.
- Godot headless project load passed with expected AssetCatalog warning only.
- `python tools\simulate_matches.py 1 normal` passed.

---

## v2.0.9 — 60-Bot Telemetry Repeat And Scale Decision

**Scope**

- Ran 5 repeated `scale_preset=xlarge_60` normal simulations and analyzed the current telemetry summary.
- Recorded the scale decision: 60 bots has no combat/perception regression sentinel, but 99-player tuning remains blocked until spawn/loot distribution and scale telemetry gates are tightened.

**Telemetry**

- Runs: 5; avg duration 93.2s, min/max 75.2s / 131.6s, avg zone stage 2.60, runs under 60s: 0.
- Regression sentinels: zero damage, zero weapon damage, zero shot, and zero combat plan all `none`.
- Recover success: 230/527 (43.6%); died in RECOVER: 1 total.
- Avg disengage triggers: 100.4; avg stuck triggers: 44.2; avg combat plans cover/reposition/kite: 147.2 / 128.0 / 4.2.
- Avg first upgrade: 9.5s, which is too fast for the current scale target and points to loot/spawn distribution work before 99-player tuning.

**Decision**

- Do not add a 99-player preset yet.
- Next slice should keep `xlarge_60` as the test surface and add distribution/telemetry gates before any larger scale preset.

---

## v2.0.8 — Conservative 60-Bot Scale Feasibility

**Scope**

- Added `xlarge_60` to `data/mapSpec_example.json` as a bounded 60-bot scale preset.
- The preset keeps spawn radius at 56m inside the current 120m world bounds, raises safe spawn attempts to 80, and uses 144 loot with a 1.15 hotspot density multiplier.
- `tools/verify_map_definition.gd` now pins the `xlarge_60` match, runtime spawn/loot, and zone overrides.

**Verification**

- `verify_map_definition.gd` passed.
- Godot headless project load passed with expected AssetCatalog warning only.
- `python tools\simulate_matches.py 1 normal scale_preset=xlarge_60` passed with 60-bot distribution.
- `python tools\simulate_matches.py 1 normal` passed.

---

## v2.0.7 — MapDefinition Position Query Compatibility

**Scope**

- Added `MapDefinition` query helpers for world size/bounds, world-position bounds checks, clamping, bounds UV conversion, and world-distance scaling.
- Added defensive POI and obstacle descriptor accessors so map UI can consume validated definition data without hand-parsing raw `MapSpec` dictionaries.
- `FullMapOverlay` and `Minimap` now accept the active `MapDefinition` and prefer its query/descriptor APIs while preserving `MapSpec` fallback behavior.

**Verification**

- `verify_map_definition.gd` passed with position query and descriptor copy checks.
- `verify_full_map_overlay.gd` passed.
- Godot headless project load passed with expected AssetCatalog warning only.

---

## v2.0.6 — Conservative 40-Bot Scale Preset Smoke

**Scope**

- Added `large_40` to `data/mapSpec_example.json` as the next validated scale preset after `medium_24`.
- The preset keeps spawn radius inside the current world bounds and nudges loot density / zone timing conservatively instead of jumping toward 99-player tuning.
- `tools/verify_map_definition.gd` now pins the `large_40` match, runtime loot, and zone overrides.

**Verification**

- `verify_map_definition.gd` passed.
- Godot headless project load passed with expected AssetCatalog warning only.
- `python tools\simulate_matches.py 1 normal scale_preset=large_40` passed with 40-bot distribution.

---

## v2.0.5 — SettingsManager Boundary Extraction

**Scope**

- Added `src/core/SettingsManager.gd` to own `user://settings.cfg` load/save, master volume application, fullscreen state, clamping, and runtime sync.
- `Main.gd` now keeps only settings panel callbacks and delegates persistence/audio/display mutation to `SettingsManager`.
- Added `tools/verify_settings_manager.gd` for save/load, clamp, fullscreen state, and missing-file fallback smoke coverage.

**Verification**

- `verify_settings_manager.gd` passed.
- Godot headless project load passed with expected AssetCatalog warning only.
- `python tools\simulate_matches.py 1 normal` passed.

---

## v2.0.4 — MapDefinition Validation Expansion

**Scope**

- Expanded `MapDefinition.validate()` for POI item density / rare-bias sanity, oversized POI radii, rotated obstacle footprint bounds, spawn radius versus runtime spawn clearance, loot density coverage, and implicit zone radius sanity.
- `MapDefinition.summary()` now reports loot hotspot count and the resolved zone initial radius.
- Scale presets now accept legacy flat match keys as a compatibility fallback while still preferring nested `match` sections.
- `tools/verify_map_definition.gd` now includes a negative validation probe for POI, obstacle, spawn, and zone profile failures.

**Verification**

- `verify_map_definition.gd` passed.

---

## v2.0.3 — Read-Only Full Map UI Foundation

**Scope**

- Added `src/ui/FullMapOverlay.gd`, a presentation-only full-screen map overlay for world bounds, POIs, generated obstacle footprints, current/next zone, player facing, and supply marker state.
- `Main.gd` now syncs map UI data through `_sync_map_views()` and toggles the Full Map overlay with `M`; `ESC` closes the overlay before pause.
- The overlay reuses `MapDefinition`, wrapped `MapSpec`, and `WorldBuilder.get_minimap_features()` data without owning match decisions.
- Added `tools/verify_full_map_overlay.gd` to pin layout bounds, world-to-map projection, generated feature ingestion, and runtime marker state.

**Verification**

- `verify_full_map_overlay.gd` passed.
- `verify_map_definition.gd` passed.
- Godot headless project load passed with expected AssetCatalog warning only.

---

## v2.0.2 — Definition-Driven Scale Preset Merge

**Scope**

- Added baseline match/runtime/zone values and `baseline` / `medium_24` scale presets to `data/mapSpec_example.json`.
- `Main.gd` now loads `MapDefinition` before world generation and applies the selected scale preset into bot count, loot count, spawn radius, zone timing, zone stages, and runtime tuning.
- `MatchRuntimeTuning.gd` and `LootSpawner.gd` now support `hotspot_density_mult` for preset-driven POI loot density scaling.
- `MatchTuning.gd` accepts `scale_preset` / `map_scale_preset` command-line args for smoke scale runs.
- `tools/verify_map_definition.gd` now verifies preset match overrides and runtime loot density overrides.

**Verification**

- `verify_map_definition.gd` passed.
- Godot headless project load passed with expected AssetCatalog warning only.
- `python tools\simulate_matches.py 1 normal` passed with baseline 11-bot distribution.
- `python tools\simulate_matches.py 1 normal scale_preset=medium_24` passed with 24-bot distribution.

---

## v2.0.1 — MapDefinition Compatibility Loader

**Scope**

- Added `src/core/MapDefinition.gd` as a compatibility wrapper over current MapSpec JSON.
- The wrapper owns map id/name, source path, MapSpec reference, match/runtime/zone overrides, scale presets, summary data, and validation.
- Added `tools/verify_map_definition.gd` to validate legacy MapSpec wrapping and wrapper-format match overrides.
- Updated architecture/impact docs so future map/full-map work checks `MapDefinition` first while runtime call sites still consume `MapSpec`.

**Verification**

- `verify_map_definition.gd` passed: `mountain_forest_alpha`, 7 POIs, 35 obstacles, wrapper bot override 24.
- Godot headless project load passed with expected AssetCatalog warning only.
- `python tools\simulate_matches.py 1 normal` passed.

---

## v1.12.11 — Artifact Icon Completion

**Scope**

- Promoted generated Escape Capsule and Ghost Grass PNGs into normalized runtime artifact icons.
- Added catalog paths for all six starting artifact icons.
- Extended `tools/sync_generated_icons.ps1` with exact-destination filtering for targeted icon promotion.
- Strengthened `tools/verify_artifact_selection_layout.gd` so each starting artifact must have a real catalog icon path, not only a procedural fallback texture.
- GLB bush visuals now animate nearest mesh clumps on enter/exit/movement instead of swaying the entire `CatalogPropVisual` root.
- Added `docs/ASSET_STATUS.md` as the concise asset-state handoff for integrated, generated, and deferred assets.
- Updated roadmap toward `v2.0 MapDefinition + player scale`.

**Verification**

- `git diff --check` passed.
- `verify_artifact_selection_layout.gd` passed: 6 options, 936px row width.
- `verify_bush_interaction.gd` passed.
- `verify_bush_prop_assets.gd` passed.
- Godot headless project load passed with expected AssetCatalog warning only.
- `python tools\simulate_matches.py 1 normal` passed.

---

## v1.12.10 — Bush Asset Integration And Feedback

**Scope**

- Promoted selected generated bush GLBs into runtime assets: `bush_dense.glb` and `bush_low.glb`.
- Added `forest.bush`, `forest.bush.low`, and `forest.bush.dense` prop catalog paths.
- `WorldBuilder` attaches catalog GLB visuals while `Bush.tscn` Area3D remains gameplay/collision authority.
- Raw GLB loading uses `GLTFDocument` when Godot import metadata is absent.
- Restored same-bush visibility semantics and outside-bush concealment behavior.
- Restored player-entry visual feedback through a low-alpha interior tint and per-clump rustle.

**Verification**

- `verify_bush_prop_assets.gd` passed.
- `verify_bush_interaction.gd` passed.
- Godot headless project load passed with expected AssetCatalog warning only.
- Normal match simulation passed.

---

## v1.12.1-v1.12.9 — Complex Artifact Line

- Added Escape Capsule and Ghost Grass as bounded player-runtime artifacts.
- Added `PlayerArtifactRuntime.gd` for one-match trigger/timer state.
- Added artifact Telemetry metrics without changing existing score schema.
- Added `PlayerArtifactVisuals.gd` for player-attached artifact presentation nodes.
- Tuned first-pass visuals for Red Trigger, Armor Sponge, Silent Core, Zone Battery, Escape Capsule, and Ghost Grass.
- Added artifact icon resolution through normalized `artifact.<id>` ids and raw PNG loading.
- Reworked artifact selection into circular options plus one stable detail card.
- Completed balance penalties: Escape Capsule ammo purge, Red Trigger reveal increase, Armor Sponge dynamic speed/heal conversion cap, Silent Core first unrevealed non-knife miss, Ghost Grass cooldown/risk.

Details are in `docs/devlog/v1.12.md`.

---

## v1.11 Closure

- v1.11 is structurally closed as of `v1.11.36`.
- `Main.gd` remains match-global orchestrator and state owner.
- Mission, pressure, loot, supply, Hell, player HUD, bot visual/debug, pickup presentation, and asset/icon lookup now have bounded helper/catalog/tuning owners.
- Future v1.11 reopen should require a concrete boundary bug or stale doc route.

Details are in `docs/devlog/v1.11.md` and `docs/devlog/v1.11_full_2026-05-26.md`.

---

## Next

- `v2.0.11`: add AI update-budget / LOD telemetry at 60-bot scale before any 99-player preset.
- Defer generated tree/rock/log/landmark GLB promotion until map visual upgrade is prioritized.
