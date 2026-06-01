# Battle Capsule Active Devlog

> Last updated: 2026-06-02. Compressed recent work log. Full historical detail is preserved in `docs/devlog/` and `docs/archive/`.

Do not load full snapshots by default. Use `docs/devlog/INDEX.md` and per-version summaries unless exact history is needed.

---

## v2.0.17 — Guarded 99-Target Candidate Probe

**Scope**

- Added `target_99_probe` only to `data/mapSpec_large_candidate.json`; the default map still has no 99-player runtime preset.
- Kept `target_99` as a `scale_envelope`, not a runtime `scale_preset`.
- The probe uses 99 bots, 240 loot, 78m spawn radius, 180 safe spawn attempts, and slower early zone pacing on the 180m candidate map.
- Added `tools/verify_candidate_99_probe.gd` to assert the probe is candidate-only, validates against the preferred `target_99` envelope, and is absent from the default map.

**Verification**

- `verify_candidate_99_probe.gd`, `verify_large_map_candidate.gd`, `verify_map_definition.gd`, and `verify_map_runtime_path.gd` passed.
- 5-run candidate-map `target_99_probe` simulation passed: avg duration 129.4s, no runs under 60s, no zero damage/shot/plan sentinels.
- Existing scale gate passed: fallback=0.0/run, min nearest=3.5m, avg nearest=7.7m, saturation=0.20, AI avg=439.9us.

**Decision**

- 99 bots are now technically smokeable on the non-default candidate path.
- Do not promote this to the default map or global 99-player tuning yet; the next slice should analyze 99-probe pacing, zone escape volume, and engagement density before broader promotion.

---

## v2.0.16 — Candidate Map Runtime Loading Smoke

**Scope**

- Added `map_spec_path` as a safe CLI/test override in `Main.gd`; the exported default remains `res://data/mapSpec_example.json`.
- Added `map_spec_path`, `map_spec`, `map_definition_path`, and `map_definition` command-line aliases through `MatchTuning.gd`.
- Preserved raw command-line value casing for resource paths so mixed-case filenames like `mapSpec_large_candidate.json` load reliably.
- Added `tools/verify_map_runtime_path.gd` to pin CLI path parsing, candidate definition loading, and `xlarge_60` preset resolution.

**Verification**

- `verify_map_runtime_path.gd` passed.
- Godot headless load with `map_spec_path=res://data/mapSpec_large_candidate.json scale_preset=xlarge_60` loaded `Mountain Forest Alpha Large Candidate`.
- 5-run candidate-map `xlarge_60` simulation passed: avg duration 99.7s, no runs under 60s, no zero damage/shot/plan sentinels.
- Candidate-map scale gate passed: fallback=0.0/run, min nearest=3.5m, avg nearest=9.6m, saturation=0.12, AI avg=311.8us.

**Decision**

- The larger candidate is now runtime-smokable without becoming the default map.
- The next slice can consider a guarded 99-target probe on the candidate path only; do not switch the default map or promote 99-player tuning globally.

---

## v2.0.15 — Non-Default Large Map Candidate

**Scope**

- Added `data/mapSpec_large_candidate.json` as a separate 180m forest candidate map; `Main.gd` still loads the current default map.
- Kept `target_99` as a `scale_envelope`, not a runtime `scale_preset`; the candidate exposes only `baseline` and `xlarge_60` presets.
- Set the candidate `xlarge_60` test surface to 60 bots, 150 loot, 78m spawn radius, 120 safe spawn attempts, and a slower early zone curve.
- Expanded candidate authored data to 11 POIs and 35 obstacles so target-envelope validation is tied to a concrete map spec instead of only abstract math.
- Added `tools/verify_large_map_candidate.gd` to validate the candidate, verify it satisfies the `target_99` preferred world/spawn envelope, and keep `target_99` out of runtime presets.

**Verification**

- `verify_large_map_candidate.gd` passed: `xlarge_60` world=180m, spawn=78m, boundary margin=8.5m, target_99 preferred saturation=0.20.
- `verify_map_definition.gd` and `verify_scale_envelope.gd` passed.
- Godot headless project load passed with the expected AssetCatalog fallback warning only.
- `git diff --check` passed.

**Decision**

- This is still scale-backbone work, not a playable 99-player expansion.
- The next slice should add a safe candidate-map runtime loading/smoke path before any 99-player preset.

---

## v2.0.14 — Larger-Map Spawn Envelope Prerequisite

**Scope**

- Added definition-owned `scale_envelopes.target_99` as a planning target, not a runtime `scale_preset`.
- Captured 99-bot prerequisites from the 60-bot spawn telemetry: minimum 160m world / 72m spawn radius, preferred 180m world / 78m spawn radius, 8m inner radius, 3.5m entity clearance, and saturation guardrails.
- Added `tools/verify_scale_envelope.gd` to keep `target_99` out of runtime presets and verify the envelope math against current `xlarge_60`.
- Extended `MapDefinition` to load, expose, summarize, and sanity-check `scale_envelopes`.

**Verification**

- `verify_map_definition.gd` passed with `target_99` exposed as an envelope only.
- `verify_scale_envelope.gd` passed: current `xlarge_60` saturation=0.24 / boundary margin=0.5m; `target_99` min=160m world + 72m spawn, preferred=180m world + 78m spawn.

**Decision**

- 99-player tuning remains blocked until a new or rescaled map spec satisfies the `target_99` envelope.
- The next implementation slice should build a non-default larger map candidate or map-rescale prototype before adding a 99-player runtime preset.

---

## v2.0.13 — 60-Bot Spawn Distribution Telemetry

**Scope**

- Added `spawn` telemetry for requested/placed entity count, fallback usage, nearest-spawn distance, average spawn attempts, max attempts, and spawn-annulus saturation.
- `Main.gd` now records fallback spawn positions into `_spawn_positions` so later spawn checks and telemetry include the actual fallback placement.
- Extended `analyze_results.py` and `check_scale_telemetry.py` to report spawn distribution and fail repeated scale runs if fallback spawns appear or nearest spacing drops below the clearance floor.
- Kept this as measurement and gate work; no 99-player preset or larger map was added.

**Verification**

- `python -m py_compile tools\analyze_results.py tools\check_scale_telemetry.py` passed.
- Godot headless project load passed with expected AssetCatalog warning only.
- `python tools\simulate_matches.py 5 normal scale_preset=xlarge_60` passed.
- `python tools\analyze_results.py tools\sim_runs_current` reported avg duration 120.0s, avg zone stage 2.40, no zero damage/shot/plan sentinels, and spawn distribution placed=61/61, fallback=0.0/run, min nearest=3.5m, avg nearest=7.1m, avg attempts=1.5, max attempts=7, saturation=0.24.
- `python tools\check_scale_telemetry.py tools\sim_runs_current` passed with spawn distribution included.

**Decision**

- Current 120m map / 56m spawn radius is technically viable for 60 bots, but minimum spacing is already at the clearance floor.
- Do not add a 99-player preset on the same map envelope; larger scale needs a larger map/spawn envelope plan first.

---

## v2.0.12 — 60-Bot Progressive Zone Pacing

**Scope**

- Made the `xlarge_60` zone curve explicit instead of relying on the baseline stage timings after the first shrink.
- Retuned the 60-bot zone profile so early compression is slower, then stage timings accelerate: first shrink now ends later, stage 2 uses 30s wait / 24s shrink, then later stages step down to 22/18, 14/12, and 10/10.
- Kept this as preset data tuning; no new map size, 99-player preset, or AI LOD behavior was added.

**Verification**

- `verify_map_definition.gd` passed with pinned `xlarge_60` stage overrides.
- `python tools\simulate_matches.py 5 normal scale_preset=xlarge_60` passed.
- `python tools\analyze_results.py tools\sim_runs_current` reported avg duration 103.9s, avg zone stage 2.00, 0 runs under 60s, avg first upgrade 11.8s, no zero damage/shot/plan sentinels, and AI update budget avg=369.8us.
- `python tools\check_scale_telemetry.py tools\sim_runs_current` passed.

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
