# Battle Capsule Master Plan

> Last updated: 2026-05-23 (v1.11.15 Player slot HUD renderer)

This is the active roadmap. Historical long-form planning was moved to [archive/MASTERPLAN_full_2026-05-13.md](archive/MASTERPLAN_full_2026-05-13.md).

## Current Status

**Current line**: v1.11-dev — subsystem directory + data boundaries.

**Current stabilization add-on**: v1.10.x — Item/Asset Readability Polish.

**Next structural slice**: v1.11.16 — Player weapon icon resolver boundary review.

**Latest completed slice**: v1.11.15 — Player slot HUD renderer.

**v1.10 completion status**: structurally closed for Main-owned data/catalog/presentation cleanup. Remaining visual polish may continue as narrow v1.10.x patches, but it is not a blocker for v1.11.

**Release status**: paused. Continue version-to-version development without GitHub releases unless explicitly requested.

**External assets**: `asset_generator/expected_output/` contains generated icon source files. Runtime-ready files are selected into `assets/` and registered through `data/asset_catalog.json`.

## Active Principles

- Keep `Main.gd` as the orchestrator while reducing the amount of code that must be read for simple config/UI/asset edits.
- Preserve single-source game state ownership in `Main.gd`: `zone`, `mission_tracker`, `player_ref`, `alive_count`, and Telemetry hooks stay there for now.
- Prefer catalog/helper/controller boundaries over broad gameplay rewrites.
- Treat already connected item/icon assets as readability polish, not new content expansion.
- User-facing descriptions that contain gameplay numbers should be generated from the same data used by gameplay logic whenever practical.
- New gameplay tuning values should enter through data/config/catalog/controller specs first, not as local constants inside `Main.gd`.
- Do not start 99-player scale, new maps, mission map theming, or v1.12 complex artifact logic until v1.10 and v1.11 stabilization are complete.

## Active Docs

| Document | Purpose |
|---|---|
| [../CLAUDE.md](../CLAUDE.md) | Session onboarding and default reading path |
| [DOCS_INDEX.md](DOCS_INDEX.md) | Documentation routing |
| [DEVLOG.md](DEVLOG.md) | Short active work log |
| [IMPACT_MAP.md](IMPACT_MAP.md) | Ownership and change-impact checks |
| [ARCHITECTURE.md](ARCHITECTURE.md) | Module boundaries |
| [TESTING.md](TESTING.md) | Verification criteria |
| [ASSET_BRIEF.md](ASSET_BRIEF.md) | Stable external asset style and format brief |

## v1.10 — Main Slimdown + UI Controllers `M`

**Summary**: Keep `Main.gd` as the orchestration root, but move isolated screen/config/spawn/asset responsibilities behind small boundaries.

**Status**: in progress. `Main.gd` still owns substantial UI orchestration, match bootstrapping, event flow, and state wiring. The goal is not line-count reduction by itself; the goal is that routine config, catalog, asset, and display edits no longer require reading unrelated `Main.gd` systems.

**Already split**

- `GameConfig`: match, zone, difficulty, Hell timing JSON loader.
- `DebugFlags` / `DebugOverlay`: runtime debug flags and simple overlay.
- `AssetCatalog`: audio/icon/prop/cosmetic ID lookup with fallback and missing-path summary.
- `LootSpawner`: POI/density-based loot hotspot and position calculations.
- `SupplyDropController`: supply drop timing, position roll, and cluster calculations.
- `ArtifactCatalog`: starting artifact choices and stat modifiers.
- `DifficultyCatalog`: difficulty label/description/color UI data.
- `HelpCatalog`: How to Play section/row data.
- `MenuIconFactory`: procedural menu/records/help icon generation.
- `HelpPanelBuilder`: How to Play panel rendering from HelpCatalog rows.
- `RecordsPanelBuilder`: Records tabs, clear button, and history row rendering.
- `MenuVisualBuilder`: main/secondary menu gradients, noise overlay, logo placement, and shared button styling.
- `WorldPresentationBuilder`: world presentation defaults for the zone ring and supply pillar drop animation.
- `DifficultySelectorBuilder`: difficulty button/tooltip/pressure opt-in menu UI.
- `SettingsPanelBuilder`: Settings modal layout and controls.
- `ResultPanelBuilder`: result panel card/buttons/label population.
- `PausePanelBuilder`: pause overlay and pause action buttons.
- `ArtifactSelectionPanelBuilder`: artifact selection overlay/cards/buttons.
- `HellAnnouncementBuilder`: Hell mode announcement overlay/card/rows/button.
- `EventTextBuilder`: transient top-center event text labels and fade-out tween setup.
- `MenuController`: panel visibility routing and main/secondary menu button wiring.
- `MatchBootstrap`: match-start zone creation, bonus mission selection, pressure flag initialization, Hell modifier roll.
- `MatchTuning`: `GameConfig` match/zone tuning interpretation and CLI match/difficulty override parsing.
- `MatchRuntimeTuning`: Main-owned spawn safety, navigation bake, stage loot wave, and supply fallback tuning interpretation.
- `BotSpawnPlanner`: weighted bot archetype plans that scale beyond the 11-bot baseline.
- `LootSpawnDirector`: item template categorization, pickup creation, supply pillar creation, and supply cluster creation.
- `PressureEffectCatalog`: pressure reward/penalty ids and HUD labels.
- `PressureEffectApplier`: pressure mission reward/penalty effect execution against explicit player/zone/actor context.
- `ItemResourceCatalog`: default loot item templates, extra consumables, pickup scene, and supply railgun resource references.
- `HellEventController`: Hell blackout/bombardment timers, overlay flashes, warning markers, damage application, and Hell event Telemetry logging.

**Good next candidates**

1. v1.11 subsystem directory/data-boundary pass: reorganize non-Main code and split tuning values from algorithms by domain.
2. Remaining v1.10.x item/asset readability polish: only narrow visual/readability patches that do not change expansion architecture.
3. v1.12 Complex Artifacts: begin new artifact content only after the subsystem structural pass is stable.

**Recommended split order**

1. Finish low-risk UI/menu extraction first.
   - Good targets: difficulty tooltip panel, settings/menu panel visibility, records/help entry wiring.
   - Reason: large line-count reduction with low gameplay risk.
2. Extract match bootstrapping only after the UI surface is calmer.
   - Good targets: `start_game()` config/difficulty/artifact/spawn sequencing.
   - Reason: this touches player, bots, zone, mission, Telemetry, and asset wiring, so it needs a clearer call graph.
3. Continue data/value binding as vertical slices.
   - Good targets: mission/pressure text, difficulty descriptions with numeric values, remaining ammo/heal/help strings.
   - Reason: this directly prevents hardcoded-number drift without forcing a large config rewrite.
4. Defer state-owning systems until there is a dedicated migration plan.
   - Pressure mission effects, zone state, player reference, alive count, and result/Telemetry finalization should stay in `Main.gd` for now.

**Boundary rules**

- Controllers/helpers should not discover each other through the scene tree. `Main.gd` wires them.
- Do not move zone, mission, player, alive count, or Telemetry ownership out of `Main.gd` yet.
- Preserve Telemetry event names and JSON schema unless a dedicated migration is planned.
- Runtime controllers may receive `Main.gd`-owned references through explicit wiring, but they should not own match-global state.

**v1.10 closure result**

- Complete: Main-owned item/resource pool, spawn/navigation/loot/supply fallback runtime tuning, UI/panel builders, match bootstrap/tuning helpers, pressure effect execution, bot spawn planning, loot/supply pickup creation, and world/menu presentation defaults have first-pass boundaries.
- Complete: simple item display, item resources, menu/help/records/result/pause/artifact/Hell announcement UI, and Main runtime tuning can be edited through data/catalog/helper files without reading unrelated Main systems.
- Intentionally retained in `Main.gd`: `zone`, `mission_tracker`, `player_ref`, `alive_count`, `game_over`, `difficulty`, pressure flags, scene callbacks, exported scene/count defaults, and Telemetry hook calls.
- Deferred: remaining visual-only item/asset polish can continue as v1.10.x patches, but does not block v1.11.
- Deferred: non-Main domain files still need their own data/algorithm separation in v1.11.

### v1.10.17-v1.10.20 — Main Data/Catalog Closure Plan `M`

**Summary**: Finish the Main-owned data/catalog cleanup before touching subsystem-wide directory moves. `Main.gd` should remain the orchestrator and state owner, but routine item pool, spawn, navigation, supply fallback, and presentation tuning edits should not require reading unrelated Main sections.

**Current Main candidates**

- Item/resource pool: first pass complete through `ItemResourceCatalog`; Main keeps only runtime references loaded from the catalog.
- Match runtime tuning: first pass complete through `data/game_config.json` `runtime` + `MatchRuntimeTuning`; Main applies sanitized values.
- Navigation/runtime world setup: navigation mesh bake parameters are config-backed; zone ring visual defaults are in `WorldPresentationBuilder`.
- Presentation-only values: first pass complete for zone ring, supply pillar drop Y range, menu logo size, and Hell announcement dismiss fade.
- Keep in Main: `zone`, `mission_tracker`, `player_ref`, `alive_count`, `game_over`, `difficulty`, pressure flags, scene callbacks, and Telemetry hook calls.

**v1.10.17 — Item/Resource Catalog Boundary**

- Move default drop item references out of `Main.gd` into an item/resource catalog boundary.
- Adding, removing, or swapping default item pools should not require editing `Main.gd`.
- Preserve current item list, pickup scene, advanced heal, railgun supply behavior, and Telemetry schema.
- First pass complete: `ItemResourceCatalog.gd` owns the pickup scene, default item templates, extra consumables, and supply railgun item. `Main.gd` loads runtime references from the catalog and still owns loot/supply state wiring.

**v1.10.18 — Match Runtime Tuning Boundary**

- Move Main-owned spawn safety, obstacle-clearance, navigation bake, stage loot-wave, and supply fallback tuning into `GameConfig`/`MatchTuning` or a small `MatchRuntimeTuning` helper.
- Keep the algorithms in their current owners unless the move clearly reduces coupling.
- Preserve existing defaults exactly unless a separate balance change is requested.
- First pass complete: `data/game_config.json` `runtime` owns spawn, navigation, stage loot wave, and supply fallback values; `MatchRuntimeTuning.gd` clamps/normalizes them; `Main.gd` keeps spawn/navigation/supply algorithms and state wiring.

**v1.10.19 — Main Presentation Boundary**

- Move remaining Main-local visual defaults that are still edited as data, such as zone ring color/mesh sizing and small menu/announcement constants, into UI/world-view helpers or catalogs.
- Do not move broad UI state or panel routing back into Main.
- Defer low-value visual constants if moving them would create more indirection than benefit.
- First pass complete: `WorldPresentationBuilder.gd` owns zone ring mesh/material defaults and supply pillar drop Y range; `MenuVisualBuilder.gd` owns the main logo size; `HellAnnouncementBuilder.gd` owns the dismiss fade duration. `Main.gd` now calls these helpers while keeping world/UI state wiring.

**v1.10.20 — Closure Review**

- Re-scan `Main.gd` for remaining non-state constants and classify each as: moved, intentionally owned by Main, or deferred to v1.11.
- Update `ARCHITECTURE.md` and `IMPACT_MAP.md` with the final boundaries.
- Verification gate: `git diff --check`, Godot headless quit, `python tools\simulate_matches.py 1`, and one Hell or high-bot simulation when gameplay wiring changed.
- Closure complete: `Main.gd` is 1097 lines. Remaining numeric/default values are classified below rather than moved blindly.

**Moved or already data-backed**

- Default item resources and pickup scene: `ItemResourceCatalog`.
- Match/count/zone base config and CLI overrides: `GameConfig` + `MatchTuning`.
- Spawn safety, navigation bake, stage loot wave, supply fallback: `data/game_config.json` `runtime` + `MatchRuntimeTuning`.
- Zone stage 2+ wait/shrink/damage values: `data/game_config.json` `zone.stages` + `ZoneController`.
- Menu/panel presentation and world presentation defaults: UI builders and `WorldPresentationBuilder`.

**Intentionally retained in Main**

- Scene references and match entry defaults: `player_scene`, `bot_scene`, `bot_count`, `loot_count`, `spawn_radius`, base zone exports. These are inspector/CLI/config merge points, not final hardcoded balance ownership.
- Match-global state: `current_state`, `difficulty`, `zone`, `mission_tracker`, `player_ref`, `alive_count`, `game_over`, `match_timer`, pressure state flags, supply minimap state.
- Wiring-only node paths, callbacks, Telemetry hook calls, and autoload lookups.
- Debug/simulation conveniences: screenshot trigger, bot snapshot print, simulation time scale.

**Deferred to v1.11**

- Hell start-state policy currently applied in `spawn_entities()` should move toward Hell modifier/config data when Hell systems are directory-separated.
- Mission/artifact feasibility glue such as `_is_bonus_mission_feasible()` should move toward mission/artifact compatibility data.
- Mission context thresholds such as supply proximity and perception completion should move into mission/pressure specs when `MissionTracker` is split.
- Result text formatting and debug snapshot aggregation can move to UI/debug helpers when those domains are reorganized.
- Remaining non-Main tuning in `Player.gd`, `Bot.gd`, `MissionTracker.gd`, `HellEventController.gd`, `LootSpawnDirector.gd`, and UI builders belongs to v1.11 vertical slices.

**Explicit v1.10 deferrals**

- Do not refactor `Player.gd`, `Bot.gd`, `MissionTracker.gd`, `HellEventController.gd`, `LootSpawnDirector.gd`, or UI builders just because they still contain tuning values.
- Do not reorganize directory structure in v1.10 unless required by a Main boundary.
- Do not start new artifacts, new maps, 99-player scale, or strategic prop gameplay in v1.10.

### v1.10.3+ — Data/Description Value Binding `M`

**Summary**: Keep gameplay numbers, UI descriptions, labels, and algorithms connected through shared structured sources so a balance change does not require separate text edits.

This is a v1.10 structural cleanup, not a balance pass. The first implementation should be a narrow vertical slice that proves the pattern before broad migration.

**Problem**

- Some catalog descriptions include numeric values directly in prose, for example artifact lines such as shotgun damage multipliers.
- If gameplay modifiers and text are edited separately, future balance changes can silently make UI descriptions wrong.
- The same risk exists outside artifacts: ammo amounts, heal amounts, weapon stats, difficulty descriptions, mission text, and help text can drift if they duplicate values owned elsewhere.
- The rule applies broadly: Main should wire loaded values, controllers should own algorithms, and reusable numeric tuning should move into config/resource/catalog files by vertical slice.

**Source-of-truth direction**

- `StatsData` / weapon `.tres`: weapon damage, range, ammo, fire-rate, pellet, and spread-related values.
- `ItemData` / item `.tres`: pickup type, amount, rarity, ammo target, display name, and pickup color.
- `GameConfig` / config JSON: match, zone, difficulty, and system tuning values that already load from config.
- `BotDoctrine` profiles: bot behavior tuning already expressed as structured dictionaries.
- `ArtifactCatalog` or a follow-up artifact spec helper: artifact modifier values and generated description lines should come from the same structured entry.

**First vertical slice**

1. Audit user-facing numeric descriptions.
   - Start with `ArtifactCatalog.gd`.
   - Then inspect pickup/HUD ammo strings, heal amounts, difficulty text, mission/pressure text, and help rows.
   - Record ownership before editing behavior.
2. Define a small formatter/helper boundary.
   - Prefer a focused helper such as `DescriptionFormatter` or artifact-local builder functions.
   - Avoid adding a large localization/config framework before the needed data shape is proven.
3. Convert starting artifact descriptions first.
   - First pass complete for current starting artifacts.
   - Artifact modifier numbers now live in structured fields used by gameplay.
   - `line1`/`line2` are generated from those values.
   - The player-visible text stays readable Korean, not raw debug data.
4. Extend only where duplication is confirmed.
   - First pickup/HUD pass complete: `ItemDisplayFormatter` reads pickup details from `ItemData`/`StatsData` and HUD ammo from slot state.
   - First zone timing pass complete: stage 2+ wait/shrink/damage values are loaded from `data/game_config.json` `zone.stages`, while `ZoneController.gd` owns only lifecycle/damage algorithms.
   - Do not migrate labels that are already simple names and have no duplicated gameplay number.
5. Keep behavior stable.
   - No balance changes unless explicitly requested.
   - No Telemetry event/schema changes.
   - No `Main.gd` ownership changes unless a later slice explicitly targets them.

**Explicit exclusions**

- Do not replace all `.tres` resources with JSON just for uniformity.
- Do not introduce a localization system yet.
- Do not rewrite combat, pickup, artifact, or mission algorithms as part of the audit.
- Do not start new artifacts while this slice is still defining the description/value contract.

**Verification**

- `git diff --check`
- Godot headless quit
- `python tools\simulate_matches.py 1` for any gameplay-code touch
- Manual audit that converted descriptions use the same fields as the gameplay path
- Confirm no Telemetry hook names or JSON schema changed

### v1.10.x — Item/Asset Readability Polish `S`

**Summary**: Improve readability and consistency of already connected item/icon assets without adding new items, weapons, artifacts, or gameplay content.

This is a stabilization step before v1.12 Complex Artifacts. It covers pickup display, item label noise, focus clarity, glow intensity, and asset fallback/export checks.

**Patch numbering guidance**

- Use `v1.10.1`-style slices for localized presentation tuning that does not change asset pipeline rules. Example: weakening an over-visible pickup focus marker after screenshot review.
- Use `v1.10.2`-style slices for small asset-pipeline rule changes that can affect multiple runtime files. Example: changing generated icon post-processing scale rules and re-syncing runtime weapon icons.
- Keep all `v1.10.x` slices inside the existing v1.10 stabilization scope. These are not v1.12 content features.

**Scope**

- Existing weapon, ammo, heal, armor, and artifact pickup display only.
- Existing runtime core icons under `assets/icons/` only unless a specific generated icon is selected.
- No new item, weapon, artifact, mission, or map content.
- No `Main.gd` game-state ownership changes.
- No Telemetry JSON schema changes.
- `asset_generator/expected_output/` remains an external source pool; do not commit or integrate the whole folder.

**Priorities**

1. Item label LOD — first pass complete
   - Hide labels for distant pickups.
   - At pickup range, show name only.
   - For the current focus/pickup candidate, show name plus quantity/ammo details.
   - When same-kind pickups are clustered, avoid showing every label at once.
2. Focus marker tone-down — v1.10.1 first pass complete
   - Current filled floor highlight read too heavy in real screenshots.
   - Reduced alpha, emission, and radius while preserving current focus logic.
   - Focus should be secondary to pickup shape/icon and detailed label.
   - No collection logic, Telemetry, or asset file changes.
3. Drop display naming consistency — v1.10.1 first pass complete
   - Initial map loot and supply drops use `ItemData` templates from `src/items/*.tres`, so their labels are already Korean and data-driven.
   - Player/bot death drops create `ItemData` at runtime and now share `DropDisplayCatalog` for Korean weapon/ammo/heal names and death-drop weapon colors.
   - This was fixed as a generation-path consistency issue, not as label text patching in `Pickup.gd`.
   - Preserve drop quantities, item types, Telemetry schema, and collection behavior.
4. Glow intensity
   - Reduce common/blue weapon and ammo glow.
   - Preserve rare/purple, legendary/orange, and armor/cyan readability.
   - Keep glow values in catalog/helper-style visual parameters rather than adding scattered item hardcoding.
5. Pickup focus
   - The current interactable target must be visually clear.
   - Focus should feel like game UI, not debug text.
6. Weapon icon optical sizing — v1.10.2 first pass complete
   - Generated weapon masters are square canvases, so short/thick weapons such as pistol can appear optically larger than long weapons such as shotgun/rifle in HUD slots.
   - Prefer post-processing rules over manual PNG edits so future sync runs stay consistent.
   - `tools/sync_generated_icons.ps1` now supports per-icon `VisualScale` overrides and `-OnlyCategory weapons`.
   - Runtime `assets/icons/weapons/*.png` were re-synced with pistol/knife reduced and long weapons slightly expanded.
   - Keep HUD slot rendering unchanged unless post-processing cannot solve the mismatch.
   - Do not bulk-sync held action/status/map/ui icons as part of this work.
7. AssetCatalog/fallback
   - Missing assets must keep using primitive/icon fallback without runtime errors.
   - New runtime assets must be registered through `data/asset_catalog.json`.
   - Export should include selected runtime assets and exclude generated source/master files.
8. Verification
   - `git diff --check`
   - `.\Godot_v4.6.2-stable_win64_console.exe --path . --headless --quit`
   - `python tools\simulate_matches.py 1`
   - Confirm Telemetry hook names and JSON schema are unchanged.

**Explicit exclusions**

- Screenshot saving is not mandatory verification.
- Do not touch v2.0 MapDefinition, v2.1 Forest 2.0, or v2.2 AI LOD work.
- Do not start 99-player expansion, new maps, mission map theming, or new artifact implementation.

## v1.11 — Subsystem Directory + Data Boundaries `M`

**Summary**: After `Main.gd` data/catalog closure, reorganize subsystem code by domain and separate reusable tuning values from algorithms outside Main. This is a structural version, not a content expansion.

**Directory direction**

- Keep orchestration and scene wiring in `src/Main.gd`.
- Keep stable low-level data/config/catalog classes under `src/core/` only when they are genuinely shared.
- Group domain systems more explicitly, for example `src/systems/match/`, `src/systems/loot/`, `src/systems/mission/`, `src/systems/zone/`, and `src/systems/hell/` when files are ready to move.
- Keep entity execution under `src/entities/player/`, `src/entities/bot/`, and pickup/environment folders.
- Keep UI construction under `src/ui/`, with panels/overlays/HUD helpers separated by usage.

**Data/algorithm separation targets**

- `MissionTracker.gd`: move mission and pressure descriptors toward catalog/data while keeping condition evaluation logic testable.
- `MissionCatalog.gd`: first mission/pressure descriptor catalog boundary; `MissionTracker` still owns progress/evaluation/HUD state.
- `MissionHudFormatter.gd`: mission/pressure HUD formatting boundary; `MissionTracker` still owns counters, evaluation, and badge state.
- `MissionEvaluator.gd`: bonus mission completion/early-fail evaluation boundary; `MissionTracker` still owns hooks, counters, context gathering, and badge state.
- `PressureConditionEvaluator.gd`: pressure descriptor feasibility and condition completion boundary; `MissionTracker` still owns pressure counters, timing, hooks, and active state.
- `MissionBadgeStore.gd`: achievement badge persistence boundary; `MissionTracker` still exposes badge wrapper APIs.
- `Player.gd`: split heal, ammo, HUD numeric display, combat visual constants, and artifact stat reads by vertical slice.
- `Bot.gd`: split perception, loot search, combat movement, and debug/visual constants into doctrine/profile/config boundaries without changing AI behavior.
- `HellEventController.gd`: move remaining bombardment/blackout tuning and visual constants into config/catalog entries.
- `HellTuning.gd`: first Hell tuning data boundary; reads `data/game_config.json` `hell` sections and normalizes timers, blackout, bombardment, barrage, standard bombardment, and marker visual values.
- `LootSpawnDirector.gd` and supply helpers: move supply/pillar visual and cluster tuning values into config/catalog entries.
- UI builders: keep presentation constants close to their builder unless reused across multiple screens.

**Recommended v1.11 slice order**

1. Hell subsystem boundary.
   - Move runtime controller into `src/systems/hell/`.
   - Then move bombardment/blackout tuning and visual constants into data/config/helper boundaries.
   - Keep Hell modifier selection and announcement wiring in `Main.gd`.
2. Zone subsystem boundary.
   - Move `ZoneController.gd` toward `src/systems/zone/` only after confirming all `Main`/`Bot`/`Player`/`Minimap` references.
   - Keep zone ownership in `Main.gd`.
   - First pass complete: path ownership moved to `src/systems/zone/ZoneController.gd`; public API and runtime `main.zone` reads are unchanged.
3. Loot/supply subsystem boundary.
   - Group loot hotspot calculation, supply timing, and pickup creation under `src/systems/loot/` by small path-preserving slices.
   - Keep `Main.gd` supply minimap state and Telemetry hook calls.
   - First pass complete: `LootSpawner`, `SupplyDropController`, and `LootSpawnDirector` now live under `src/systems/loot/`; public APIs and Main state ownership are unchanged.
4. Mission/pressure data boundary.
   - Move mission and pressure descriptors out of `MissionTracker.gd` into catalog/data structures before adding new mission types.
   - Keep mission progress/evaluation APIs stable.
   - First pass complete: `MissionCatalog.gd` owns bonus mission list construction and hard/Hell pressure descriptor pools; `MissionTracker.gd` keeps public static wrappers plus feasibility/progress/evaluation logic.
   - Mission HUD first pass complete: `MissionHudFormatter.gd` owns pressure and bonus mission HUD string formatting while `MissionTracker.gd` passes state snapshots.
   - Mission evaluation first pass complete: `MissionEvaluator.gd` owns bonus mission completion/early-fail rules while `MissionTracker.gd` passes explicit state context and keeps public APIs.
   - Path ownership first pass complete: `MissionTracker.gd` moved to `src/systems/mission/`; class name, public APIs, and Main-owned instance are unchanged.
   - Pressure condition first pass complete: `PressureConditionEvaluator.gd` owns pressure descriptor feasibility and pressure condition completion checks while `MissionTracker.gd` passes condition ids and counter snapshots.
   - Badge store first pass complete: `MissionBadgeStore.gd` owns `user://achievements.json` read/write while `MissionTracker.gd` keeps public badge wrapper APIs.
   - Closure review complete: `MissionTracker.gd` is now 257 lines and intentionally owns active mission/pressure state, counters, hooks, public wrappers, and context assembly. New mission data, HUD strings, bonus evaluation, pressure condition checks, and badge file I/O have separate owners.
5. Entity vertical slices.
   - Split `Player.gd`/`Bot.gd` tuning by behavior domain only when a concrete data owner is clear.
   - Do not move combat or perception behavior just to reduce line count.
   - Player HUD first pass complete: `src/ui/player/PlayerHudBuilder.gd` owns top HUD node construction/styling for zone, mission, pressure, flash, and kill feed nodes.
   - Player HUD/status continuation complete: `PlayerHudBuilder.gd` also owns health/shield/stat HUD, slot HUD node construction, and zone warning overlay construction. `Player.gd` still owns runtime HUD values, slot state styling updates, weapon icon loading, combat state, and player behavior.
   - Player slot HUD renderer complete: `PlayerSlotHudRenderer.gd` owns active/empty/normal slot panel styling, slot ammo text, and slot ammo warning colors. `Player.gd` still owns `WeaponSlotManager`, weapon icon loading/fallbacks, and reload-progress overlay text.

### v1.11.1 — Hell Subsystem Directory First Pass `S`

**Summary**: Start v1.11 with a path-only domain move for the smallest runtime controller boundary.

- Move `HellEventController.gd` from `src/core/` to `src/systems/hell/`.
- Update `Main.gd` preload path and architecture/impact docs.
- Keep `class_name HellEventController`, public API, signal names, Telemetry event names, modifier ids, and runtime behavior unchanged.
- Do not move tuning constants in this slice; they are the next data-boundary slice.
- First pass complete: `src/systems/hell/HellEventController.gd` is the new owner path. `Main.gd` still owns Hell modifier selection, announcement UI, and controller wiring.

### v1.11.2 — Hell Tuning Data Boundary `S`

**Summary**: Separate Hell event tuning values from Hell runtime algorithms without changing balance.

- Move bombardment/blackout numeric defaults and marker/flash visual constants into config/helper data.
- Preserve current fallback values exactly.
- Keep algorithms in `HellEventController.gd` unless a helper removes real coupling.
- Verify normal and Hell simulations because this touches runtime event behavior.
- First pass complete: `HellTuning.gd` owns the fallback defaults and sanitization; `data/game_config.json` owns override-ready Hell timer/blackout/bombardment/barrage/standard/disc sections; `HellEventController.gd` owns runtime algorithms only.

### v1.11.3 — Zone Subsystem Directory First Pass `S`

**Summary**: Move the existing zone lifecycle controller into a domain system path without changing state ownership or behavior.

- Move `ZoneController.gd` from `src/core/` to `src/systems/zone/`.
- Move the Godot script uid file with it.
- Update `Main.gd` preload path and architecture/impact docs.
- Keep `class_name ZoneController`, public API, signals, stage config behavior, damage behavior, and Telemetry-facing flow unchanged.
- Keep `Main.gd` as the owner of `zone`; `Bot.gd`, `Player.gd`, `Minimap.gd`, `DebugOverlay.gd`, and `WorldPresentationBuilder.gd` continue to read `main.zone`.

### v1.11.4 — Loot/Supply Subsystem Directory First Pass `S`

**Summary**: Group existing loot/supply calculation and pickup creation helpers into one loot system path without changing behavior.

- Move `LootSpawner.gd` from `src/core/` to `src/systems/loot/`.
- Move `SupplyDropController.gd` from `src/core/` to `src/systems/loot/`.
- Move `LootSpawnDirector.gd` from `src/systems/match/` to `src/systems/loot/`.
- Update `Main.gd` preload paths and architecture/impact docs.
- Keep `class_name`, public APIs, pickup quantities, supply timing, supply pillar creation, Telemetry hook calls, and Main-owned supply minimap state unchanged.

### v1.11.5 — Mission/Pressure Descriptor Catalog First Pass `S`

**Summary**: Move mission and pressure descriptor construction behind a mission catalog boundary without changing mission runtime behavior.

- Add `src/systems/mission/MissionCatalog.gd` for bonus mission list construction and hard/Hell pressure descriptor pools.
- Keep `MissionTracker.gd` as the owner of mission state, pressure condition enum, feasibility filtering, progress counters, evaluation, HUD text, badge persistence, and public static accessors.
- Keep `Main.gd`, `MatchBootstrap.gd`, pressure effect ids, mission ids, condition ids, reward/penalty descriptors, and Telemetry-facing flow unchanged.
- First pass complete: callers can keep using `MissionTracker.get_all_missions()`, `get_hard_pool()`, and `get_hell_pool()` while descriptor edits now route to `MissionCatalog.gd`.

### v1.11.6 — Pressure HUD Formatter First Pass `S`

**Summary**: Move pressure HUD string assembly out of `MissionTracker.gd` without changing pressure condition evaluation.

- Add `src/systems/mission/MissionHudFormatter.gd` for pressure HUD title/deadline/progress/reward/penalty text.
- Keep `MissionTracker.gd` as the owner of pressure state, counters, condition enum, condition evaluation, and public `get_pressure_hud_text()` API.
- Keep `Player.gd` HUD label flow, pressure descriptor values, effect labels, and Telemetry-facing behavior unchanged.
- Do not move bonus mission HUD/evaluation in this slice; that remains a separate review because it touches Telemetry reads and player HP lookup.

### v1.11.7 — Bonus Mission HUD Formatter First Pass `S`

**Summary**: Move bonus mission HUD string assembly out of `MissionTracker.gd` without changing mission completion evaluation.

- Extend `src/systems/mission/MissionHudFormatter.gd` to format bonus mission HUD text from explicit context data.
- Keep `MissionTracker.gd` as the owner of bonus mission hooks, counters, Telemetry/player HP context gathering, mission evaluation, early-fail checks, badge persistence, and public `get_hud_text()` API.
- Preserve all current mission HUD strings, including the no-Telemetry fallback for all-weapon mission text.
- Do not move `evaluate()` or `get_early_fail_status()` in this slice; evaluation/data-spec work remains a separate review.

### v1.11.8 — Mission Evaluator First Pass `S`

**Summary**: Move bonus mission completion and early-fail rules out of `MissionTracker.gd` without changing public mission APIs.

- Add `src/systems/mission/MissionEvaluator.gd` for bonus mission `evaluate()` and `early_fail_status()` condition checks.
- Keep `MissionTracker.gd` as the owner of mission hooks, counters, Telemetry/player HP context gathering, badge persistence, and public `evaluate()` / `get_early_fail_status()` wrappers.
- Preserve all current mission completion rules and no-Telemetry fallback behavior.
- Do not move pressure condition evaluation in this slice; pressure runtime counters and success/fail flow remain in `MissionTracker.gd`.

### v1.11.9 — MissionTracker System Path Move `S`

**Summary**: Finish mission subsystem path ownership by moving `MissionTracker.gd` under `src/systems/mission/`.

- Move `src/core/MissionTracker.gd` and its `.uid` file to `src/systems/mission/`.
- Update `Main.gd` preload path.
- Keep `class_name MissionTracker`, public APIs, mission/pressure state ownership, hooks, descriptors, evaluation, HUD behavior, badge persistence, and Telemetry-facing flow unchanged.
- Do not move pressure condition evaluation in this slice; it remains the next explicit boundary review.

### v1.11.10 — Pressure Condition Evaluator First Pass `S`

**Summary**: Move pressure descriptor feasibility and pressure condition completion rules out of `MissionTracker.gd`.

- Add `src/systems/mission/PressureConditionEvaluator.gd`.
- Keep `MissionTracker.gd` as the owner of `PressureCondition` ids, active pressure state, counters, hooks, deadline timing, instant-fail flag, and public pressure APIs.
- Preserve `filter_feasible()`, `tick_pressure()`, pressure success/fail behavior, pressure descriptor ids, and Telemetry-facing flow.
- Do not move pressure runtime state or Main pressure trigger/effect application in this slice.

### v1.11.11 — Mission Badge Store First Pass `S`

**Summary**: Move mission achievement badge file I/O out of `MissionTracker.gd`.

- Add `src/systems/mission/MissionBadgeStore.gd` for `user://achievements.json` read/write.
- Keep `MissionTracker.gd` public `save_badge()`, `has_badge()`, and `load_achievements()` wrappers.
- Preserve achievement JSON path, `badges` array shape, duplicate-prevention behavior, result flow, and Telemetry schema.
- Do not move active mission state or badge award timing in this slice.

### v1.11.12 — Mission Subsystem Closure Review `S`

**Summary**: Close the mission subsystem structural pass before starting entity vertical slices.

- Re-audit `src/systems/mission/MissionTracker.gd` after descriptor, HUD, evaluator, pressure condition, badge store, and path ownership slices.
- Mark as intentionally retained in `MissionTracker.gd`: active mission/pressure state, counters, hooks, pressure deadline/instant-fail state, public wrappers, and context assembly for helper calls.
- Mark as split owners: `MissionCatalog.gd`, `MissionHudFormatter.gd`, `MissionEvaluator.gd`, `PressureConditionEvaluator.gd`, and `MissionBadgeStore.gd`.
- No runtime code, mission behavior, pressure behavior, or Telemetry schema changes in this closure slice.
- Next v1.11 work should move to entity vertical slices, starting with Player-owned values and UI/combat display boundaries.

### v1.11.13 — Player HUD Builder First Pass `S`

**Summary**: Start entity vertical slices by moving low-risk top HUD construction out of `Player.gd`.

- Add `src/ui/player/PlayerHudBuilder.gd` for zone timer, mission HUD label, pressure HUD label, mission/pressure flash panel, and kill feed node construction/styling.
- Keep `Player.gd` as the owner of player state, HUD value updates, health/shield UI, weapon slot UI, pickup focus, combat, movement, artifact application, and Sfx/Telemetry hooks.
- Preserve the existing CanvasLayer child order for the extracted nodes so top HUD z-order and runtime label behavior remain unchanged.
- Do not move shot heat, melee, occluder fade, heal regen, slot HUD, or combat tuning in this slice.
- Next Player slice should continue with another concrete UI/data boundary before touching combat constants.

### v1.11.14 — Player HUD/Status Builder Continuation `S`

**Summary**: Extend the Player HUD construction boundary without moving gameplay or slot behavior.

- Extend `src/ui/player/PlayerHudBuilder.gd` to build health/shield rows, status counters, artifact label, bottom slot HUD nodes, and zone warning overlay.
- Keep `Player.gd` as the owner of health/shield/stat value updates, slot selection/ammo state, slot active/empty styling, weapon icon loading/fallbacks, pickup focus, combat, movement, artifact behavior, and Sfx/Telemetry hooks.
- Preserve existing CanvasLayer child order for top HUD, status HUD, slot HUD, and zone warning overlay.
- Do not move `_refresh_slot_hud()`, `_make_weapon_icon()`, shot heat, melee, occluder fade, heal regen, or artifact modifier logic in this slice.
- Next Player slice should review slot display state styling/icon ownership separately because it touches asset catalog lookups and inventory state.

### v1.11.15 — Player Slot HUD Renderer `S`

**Summary**: Move slot display state rendering out of `Player.gd` while keeping inventory and icon ownership stable.

- Add `src/ui/player/PlayerSlotHudRenderer.gd` for active/normal/empty slot panel styles, slot ammo text, and ammo warning colors.
- Keep `Player.gd` as the owner of `WeaponSlotManager`, slot signal wiring, slot state changes, reload-progress HUD override, weapon icon loading/fallback generation, combat, movement, artifact behavior, and Sfx/Telemetry hooks.
- Pass icon lookup through an explicit `Callable` so the renderer does not read `AssetCatalog` or the scene tree.
- Preserve existing slot labels, active-slot highlight, out-of-ammo coloring, empty-slot behavior, and `ItemDisplayFormatter` ammo text.
- Next Player slice should review `_make_weapon_icon()` / `_load_catalog_icon()` as a separate icon resolver boundary.

**v1.11 completion gate**

- Directory moves must preserve class names, preload paths, scene references, and runtime behavior.
- Each move should be small enough to validate with `git diff --check`, Godot headless quit, and at least one simulation.
- No new artifact behavior, new map content, 99-player scale, or strategic prop gameplay should be implemented in v1.11 unless the structural pass is explicitly closed.

## v1.12 — Complex Artifacts `M`

**Summary**: After v1.10 Main stabilization and v1.11 subsystem boundaries, add second-pass artifacts that create replay variation through bounded gameplay logic.

Candidate artifacts:

- Emergency Shell: once per match, shield at low HP.
- Ghost Grass: stealth grace after leaving bushes.
- Pulse Scanner: periodic nearby bot direction HUD cue.
- Marked King: kill reward plus temporary exposure.
- Glass Capsule: low max HP, high outgoing damage.
- Overheat Barrel: sustained-fire damage/spread tradeoff.

Do not begin until v1.10 Main boundaries, v1.11 subsystem boundaries, and pickup/asset readability are stable.

## Phase 2 Guardrails

Phase 2 remains blocked until v1.10, v1.11, and v1.12 foundations are stable.

| Future Area | Guardrail |
|---|---|
| v2.0 MapDefinition + Full Map UI | Requires config/debug foundation, v1.10 Main slimdown, and v1.11 subsystem boundaries |
| Forest 2.0 / City Map | Requires MapDefinition and large navigation stability checks |
| 99-player or large-map scale | Requires AI LOD, spawn/loot density rescale, zone/pathing rescale, and performance validation |

## Compact History

| Version | Summary |
|---|---|
| v1.11-dev | Subsystem directory and non-Main data/algorithm boundaries |
| v1.10-dev | Main slimdown, UI catalogs, supply/loot calculation boundaries |
| v1.9-dev | AssetCatalog hooks, audio/cosmetic IDs, debug logging hooks, scale-test CLI overrides |
| v1.8-dev | GameConfig, DebugFlags, DebugOverlay, AssetCatalog, runtime core icon pass |
| v1.7.3.1 | Main menu and How to Play hotfix |
| v1.7.x | AI doctrine, archetype readability, minimap/world footprint alignment |
| v1.6.x and earlier | Core battle royale prototype, missions, artifacts, telemetry, release foundation |

Detailed historical notes are indexed in [devlog/INDEX.md](devlog/INDEX.md); full pre-reset documents are in `docs/archive/` and `docs/devlog/`.

## Next Agent Checklist

- Read [HANDOFF.md](HANDOFF.md), [DOCS_INDEX.md](DOCS_INDEX.md), and this file before work.
- Before code changes, check [IMPACT_MAP.md](IMPACT_MAP.md) for ownership and cascade effects.
- Keep `asset_generator/` untracked unless explicitly asked to integrate selected files.
- For asset generation instructions, use local `docs/ASSET_GENERATION_PROMPTS.md` if present, and keep stable style/format rules in [ASSET_BRIEF.md](ASSET_BRIEF.md).
- For narrow v1.10 work, verify with `git diff --check`, Godot headless quit, and one simulation.
