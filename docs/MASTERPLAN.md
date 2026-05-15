# Battle Capsule Master Plan

> Last updated: 2026-05-15 (v1.10.20 Main closure review)

This is the active roadmap. Historical long-form planning was moved to [archive/MASTERPLAN_full_2026-05-13.md](archive/MASTERPLAN_full_2026-05-13.md).

## Current Status

**Current line**: v1.10-dev closure complete; next development line is v1.11-dev — subsystem directory + data boundaries.

**Current stabilization add-on**: v1.10.x — Item/Asset Readability Polish.

**Next structural slice**: v1.11.1 — subsystem directory/data-boundary planning.

**Latest completed slice**: v1.10.20 — Main data/catalog closure review and explicit deferrals.

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
- `Player.gd`: split heal, ammo, HUD numeric display, combat visual constants, and artifact stat reads by vertical slice.
- `Bot.gd`: split perception, loot search, combat movement, and debug/visual constants into doctrine/profile/config boundaries without changing AI behavior.
- `HellEventController.gd`: move remaining bombardment/blackout tuning and visual constants into config/catalog entries.
- `LootSpawnDirector.gd` and supply helpers: move supply/pillar visual and cluster tuning values into config/catalog entries.
- UI builders: keep presentation constants close to their builder unless reused across multiple screens.

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
