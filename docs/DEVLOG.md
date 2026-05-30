# Battle Capsule Active Devlog

> Last updated: 2026-05-30. Compressed recent work log. Full historical detail is preserved in `docs/devlog/` and `docs/archive/`.

Do not load full snapshots by default. Use `docs/devlog/INDEX.md` and per-version summaries unless exact history is needed.

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

- `v2.0.3`: build a read-only Full Map UI foundation from the same map feature data.
- Defer generated tree/rock/log/landmark GLB promotion until map visual upgrade is prioritized.
