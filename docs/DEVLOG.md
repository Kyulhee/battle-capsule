# Battle Capsule Active Devlog

> Last updated: 2026-05-15. Keep this file short. Add only recent verified work and link older details through [devlog/INDEX.md](devlog/INDEX.md).

The previous full devlog was preserved at [devlog/DEVLOG_full_2026-05-13.md](devlog/DEVLOG_full_2026-05-13.md). Do not load it by default.

---

## v1.10.19-dev — 2026-05-15

**Main presentation defaults boundary**

**src/ui/WorldPresentationBuilder.gd / src/ui/MenuVisualBuilder.gd / src/ui/panels/HellAnnouncementBuilder.gd / src/Main.gd**

- Added `WorldPresentationBuilder` for zone ring mesh/material defaults, zone ring sync, and supply pillar drop visual interpolation.
- Moved main logo size into `MenuVisualBuilder` and Hell announcement dismiss fade duration into `HellAnnouncementBuilder`.
- `Main.gd` now delegates these presentation defaults while keeping zone, supply, UI lifetime, and match state wiring.
- Updated architecture/impact/masterplan docs for the new presentation boundary.
- No zone lifecycle, supply logic, gameplay behavior, or Telemetry schema was changed.

**검증 결과**

- `git diff --check` 통과.
- `.\Godot_v4.6.2-stable_win64_console.exe --path . --headless --quit` 통과.
- `python tools\simulate_matches.py 1 normal` 통과: duration=77.5s, stage=3, recover=34, disengage=23.
- `python tools\simulate_matches.py 1 hell` 통과: duration=73.5s, stage=3, recover=111, disengage=20.

---

## v1.10.18-dev — 2026-05-15

**Main runtime tuning boundary**

**data/game_config.json / src/core/GameConfig.gd / src/systems/match/MatchRuntimeTuning.gd / src/Main.gd**

- Added `data/game_config.json` `runtime` section for Main-owned spawn safety, navigation bake, stage loot wave, and supply fallback tuning.
- Added `MatchRuntimeTuning` to clamp/normalize runtime tuning before Main applies it.
- `Main.gd` now reads spawn attempts, spawn inner radius, fallback spawn range/height, entity/obstacle clearance, navigation bake values, stage loot wave scale, and supply fallback position/timer from runtime tuning.
- Spawn, navigation, loot, supply, and Telemetry behavior are intended to stay unchanged.

**검증 결과**

- `git diff --check` 통과.
- `.\Godot_v4.6.2-stable_win64_console.exe --path . --headless --quit` 통과.
- `python tools\simulate_matches.py 1 normal` 통과: duration=70.3s, stage=3, recover=34, disengage=23.
- `python tools\simulate_matches.py 1 hell` 통과: duration=97.5s, stage=4, recover=120, disengage=26.

---

## v1.10.17-dev — 2026-05-15

**Expansion readiness planning + item/resource catalog boundary**

**docs/MASTERPLAN.md / src/core/ItemResourceCatalog.gd / src/Main.gd**

- Defined the v1.10.17-v1.10.20 Main data/catalog closure plan.
- Scoped v1.10 to Main-owned item/resource, runtime tuning, and presentation data boundaries.
- Re-scoped v1.11 as a subsystem directory/data-boundary pass before content expansion.
- Moved Complex Artifacts planning to v1.12 so artifact content does not start before the structural pass is stable.
- Added `ItemResourceCatalog` for the pickup scene, default loot item templates, extra consumables, and supply railgun item.
- `Main.gd` now loads item runtime references from the catalog instead of owning item resource preloads directly.
- Current item list, advanced heal inclusion, supply railgun behavior, loot spawn behavior, and Telemetry schema remain unchanged.

**검증 결과**

- `git diff --check` 통과.
- `.\Godot_v4.6.2-stable_win64_console.exe --path . --headless --quit` 통과.
- `python tools\simulate_matches.py 1 normal` 통과: duration=81.5s, stage=3, recover=48, disengage=21.
- `python tools\simulate_matches.py 1 hell` 통과: duration=86.8s, stage=3, recover=130, disengage=27.

---

## v1.10.16-dev — 2026-05-15

**Risk review fixes + first zone data binding slice**

**src/core/PressureEffectCatalog.gd / src/core/MissionTracker.gd / src/systems/match/PressureEffectApplier.gd / src/systems/match/BotSpawnPlanner.gd / src/entities/bot/BotDoctrine.gd / src/core/ZoneController.gd / data/game_config.json / src/Main.gd**

- Added `PressureEffectCatalog` as the shared pressure effect id/label source used by mission HUD text and effect execution.
- Changed `BotSpawnPlanner` to emit archetype names instead of relying on hardcoded enum integer order; `BotDoctrine` now owns name/id conversion.
- Moved zone stage 2+ wait/shrink/damage values into `data/game_config.json` `zone.stages`; `ZoneController.gd` now applies injected stage configs and keeps lifecycle/damage algorithms.
- Updated architecture/impact docs so Main remains the wiring/state owner while reusable numeric tuning moves through data/catalog/helper boundaries.

**검증 결과**

- `git diff --check` 통과.
- `.\Godot_v4.6.2-stable_win64_console.exe --path . --headless --quit` 통과.
- `python tools\simulate_matches.py 1 normal bot_count=20` 통과: duration=85.1s, stage=3, recover=44, disengage=35.
- `python tools\simulate_matches.py 1 hell` 통과: duration=51.4s, stage=2, recover=163, disengage=22.

---

## v1.10.15-dev — 2026-05-15

**Main Slimdown — expansion risk reducer split**

**src/systems/match/PressureEffectApplier.gd / BotSpawnPlanner.gd / LootSpawnDirector.gd / src/Main.gd**

- Added `PressureEffectApplier` for pressure mission reward/penalty execution.
- Added `BotSpawnPlanner` for weighted bot archetype plans, preserving the 3:3:2:3 base mix while scaling beyond 11 bots.
- Added `LootSpawnDirector` for item template categorization, initial/wave loot pickup creation, supply pillar creation, and supply cluster pickup creation.
- `Main.gd` keeps state ownership (`player_ref`, `zone`, pressure flags, supply flags, Telemetry hooks) and explicit scene wiring; helpers receive references/callbacks instead of discovering scene nodes.
- This reduces pre-expansion risk around new pressure effects, larger bot counts, and loot/supply rule changes without changing gameplay values or Telemetry schema.
- `Main.gd` is now 1084 lines after this split.

**검증 결과**

- `git diff --check` 통과.
- `.\Godot_v4.6.2-stable_win64_console.exe --path . --headless --quit` 통과.
- `python tools\simulate_matches.py 1` 통과: duration=82.9s, stage=3, recover=35, disengage=16.
- `python tools\simulate_matches.py 1 hell` 통과: duration=70.3s, stage=3, recover=118, disengage=19.

---

## v1.10.14-dev — 2026-05-15

**Main Slimdown — pause/event overlay builder split**

**src/ui/panels/PausePanelBuilder.gd / src/ui/overlays/EventTextBuilder.gd / src/Main.gd**

- Added `PausePanelBuilder` for the pause overlay, title, and Resume/Restart/Main Menu buttons.
- Added `EventTextBuilder` for transient top-center event text labels and fade-out tween setup.
- `Main.gd` now keeps pause state, callbacks, and event signal handling; overlay node construction moved to UI helpers.
- No pause state rules, button callbacks, menu routing, Hell event behavior, gameplay behavior, Telemetry hook names, or JSON schema were changed.
- `Main.gd` is now 1156 lines after this split.

**검증 결과**

- `git diff --check` 통과.
- `.\Godot_v4.6.2-stable_win64_console.exe --path . --headless --quit` 통과.
- `python tools\simulate_matches.py 1` 통과: duration=92.3s, stage=3, recover=28, disengage=20.

---

## v1.10.13-dev — 2026-05-15

**Main Slimdown — menu visual builder split**

**src/ui/MenuVisualBuilder.gd / src/Main.gd**

- Added `MenuVisualBuilder` under `src/ui/` for main/secondary menu visual styling.
- Moved menu panel gradient setup, main menu noise overlay, capsule logo placement, and shared button StyleBox/color definitions out of `Main.gd`.
- `Main.gd` now only wires target panels/buttons and keeps a thin `_apply_btn_style()` wrapper for existing builder callbacks.
- `HelpPanelBuilder` still owns How to Play content; `MenuVisualBuilder` owns only panel/background/button presentation.
- No scene node names, menu routing rules, settings behavior, gameplay behavior, Telemetry hook names, or JSON schema were changed.
- `Main.gd` is now 1200 lines after this split.

**검증 결과**

- `git diff --check` 통과.
- `.\Godot_v4.6.2-stable_win64_console.exe --path . --headless --quit` 통과.
- `python tools\simulate_matches.py 1` 통과: duration=67.7s, stage=2, recover=28, disengage=20.

---

## v1.10.12-dev — 2026-05-14

**Main Slimdown — MatchTuning config/CLI split**

**src/systems/match/MatchTuning.gd / src/Main.gd**

- Added `MatchTuning` under `src/systems/match/` for match/zone tuning interpretation.
- Moved `game_config` match/zone value reads, clamp defaults, CLI match override parsing, and CLI difficulty parsing out of `Main.gd`.
- `Main.gd` still owns exported match fields and applies returned values to its own state; `loot_spawner.configure_count()` remains in `Main.gd` because the spawner is Main-owned.
- This slice is a responsibility-boundary cleanup, not a line-count reduction; `Main.gd` was 1277 lines after the helper wrapper offset the removed parser code.
- No config keys, CLI aliases, difficulty indices, gameplay values, Telemetry hook names, or JSON schema were changed.

**검증 결과**

- `git diff --check` 통과.
- `.\Godot_v4.6.2-stable_win64_console.exe --path . --headless --quit` 통과.
- `python tools\simulate_matches.py 1 normal bot_count=11 loot_count=40 zone_wait=30 zone_shrink=20` 통과: duration=97.6s, stage=4, recover=30, disengage=21.

---

## v1.10.11-dev — 2026-05-14

**Main Slimdown — MatchBootstrap first pass**

**src/systems/match/MatchBootstrap.gd / src/Main.gd**

- Added `MatchBootstrap` under the new `src/systems/match/` placement for match lifecycle helpers.
- Moved zone controller creation/configuration, bonus mission tracker creation/selection, pressure flag initialization, and Hell modifier roll out of `Main.gd`.
- `Main.gd` still owns `zone`, `mission_tracker`, pressure state fields, Hell event runtime wiring, spawn calls, Telemetry start calls, and artifact application.
- This slice prioritizes consistent ownership boundaries over line-count reduction; `Main.gd` was 1277 lines after this split because the explicit helper calls offset most of the removed inline code.
- No zone values, mission pool rules, pressure behavior, Hell modifier range, Telemetry hook names, or JSON schema were changed.

**검증 결과**

- `git diff --check` 통과.
- `.\Godot_v4.6.2-stable_win64_console.exe --path . --headless --quit` 통과.
- `python tools\simulate_matches.py 1` 통과: duration=53.2s, stage=2, recover=18, disengage=20.

---

## v1.10.10-dev — 2026-05-14

**Main Slimdown — MenuController routing split**

**src/ui/menu/MenuController.gd / src/Main.gd**

- Added `MenuController` under `src/ui/menu/`.
- Moved panel visibility routing, main menu button wiring, dynamic Settings button insertion, and Records/Help close button wiring out of `Main.gd`.
- `Main.gd` keeps menu callbacks, settings behavior, result/records/help content ownership, and a thin `_show_panel()` wrapper.
- No scene node names, panel visibility rules, gameplay behavior, Telemetry hook names, or JSON schema were changed.
- `Main.gd` was 1273 lines after this split.

**검증 결과**

- `git diff --check` 통과.
- `.\Godot_v4.6.2-stable_win64_console.exe --path . --headless --quit` 통과.
- `python tools\simulate_matches.py 1` 통과: duration=59.0s, stage=2, recover=46, disengage=24.

---

## v1.10.9-dev — 2026-05-14

**Main Slimdown — Hell announcement panel builder split**

**src/ui/panels/HellAnnouncementBuilder.gd / src/Main.gd**

- Added `HellAnnouncementBuilder` under `src/ui/panels/`.
- Moved Hell mode announcement overlay, card layout, penalty rows, event rows, and start button construction out of `Main.gd`.
- `Main.gd` keeps Hell modifier selection, pause/unpause state, active panel lifetime, and dismiss fade ownership.
- No Hell modifier descriptions, Hell runtime behavior, pause/dismiss behavior, Telemetry hook names, or JSON schema were changed.
- `Main.gd` was 1280 lines after this split.

**검증 결과**

- `git diff --check` 통과.
- `.\Godot_v4.6.2-stable_win64_console.exe --path . --headless --quit` 통과.
- `python tools\simulate_matches.py 1` 통과: duration=85.1s, stage=3, recover=37, disengage=22.

---

## v1.10.8-dev — 2026-05-14

**Main Slimdown — artifact selection panel builder split**

**src/ui/panels/ArtifactSelectionPanelBuilder.gd / src/Main.gd**

- Added `ArtifactSelectionPanelBuilder` under `src/ui/panels/`.
- Moved artifact selection overlay, card layout, skip button, and card button construction out of `Main.gd`.
- `Main.gd` keeps artifact catalog selection, `_pending_artifact`, panel lifetime, and `start_game()` transition ownership.
- No artifact data, modifier values, description generation, apply behavior, Telemetry hook names, or JSON schema were changed.
- `Main.gd` was 1386 lines after this split.

**검증 결과**

- `git diff --check` 통과.
- `.\Godot_v4.6.2-stable_win64_console.exe --path . --headless --quit` 통과.
- `python tools\simulate_matches.py 1` 통과: duration=74.5s, stage=3, recover=21, disengage=19.

---

## v1.10.7-dev — 2026-05-14

**Main Slimdown — result panel builder split**

**src/ui/panels/ResultPanelBuilder.gd / src/Main.gd**

- Added `ResultPanelBuilder` under the new `src/ui/panels/` placement for panel-specific UI builders.
- Moved Result panel card layout, labels, result buttons, and result label population out of `Main.gd`.
- `Main.gd` keeps match finalization, mission evaluation, score calculation, Telemetry calls, and result panel routing.
- No score formula, mission evaluation, Telemetry hook names, JSON schema, or scene panel names were changed.
- `Main.gd` was 1472 lines after this split.

**검증 결과**

- `git diff --check` 통과.
- `.\Godot_v4.6.2-stable_win64_console.exe --path . --headless --quit` 통과.
- `python tools\simulate_matches.py 1` 통과: duration=60.0s, stage=2, recover=34, disengage=21.

---

## v1.10.6-dev — 2026-05-14

**Main Slimdown — menu UI builder split**

**src/ui/DifficultySelectorBuilder.gd / src/ui/SettingsPanelBuilder.gd / src/Main.gd**

- Moved difficulty selector button creation, pressure opt-in checkbox UI, and difficulty tooltip rendering out of `Main.gd`.
- Moved Settings modal layout, volume slider row, fullscreen button text, and close button construction out of `Main.gd`.
- `Main.gd` now keeps only selected difficulty, pressure opt-in state, AudioServer/DisplayServer actions, and settings persistence.
- No difficulty values, settings file keys, menu scene nodes, gameplay behavior, Telemetry hook names, or JSON schema were changed.
- `Main.gd` is now 1576 lines after this split.

**검증 결과**

- `git diff --check` 통과.
- `.\Godot_v4.6.2-stable_win64_console.exe --path . --headless --quit` 통과.
- `python tools\simulate_matches.py 1` 통과: duration=76.5s, stage=3, recover=21, disengage=18.

---

## v1.10.5-dev — 2026-05-14

**Main Slimdown — HellEventController runtime split**

**src/core/HellEventController.gd / src/Main.gd**

- Moved Hell blackout timers, bombardment timers, warning discs, overlay flashes, bomb damage application, and Hell event Telemetry logging out of `Main.gd`.
- `Main.gd` now selects the Hell modifier, wires the controller, and keeps the announcement panel only.
- The former in-function bombardment tuning constants now live in one controller boundary instead of inside `Main.gd`.
- No Hell balance values, collection/combat behavior, Telemetry hook names, or JSON schema were changed.
- `Main.gd` is now 1693 lines after this split.

**검증 결과**

- `git diff --check` 통과.
- `.\Godot_v4.6.2-stable_win64_console.exe --path . --headless --quit` 통과.
- `python tools\simulate_matches.py 1` 통과: duration=86.1s, stage=3, recover=33, disengage=20.

---

## v1.10.4-dev — 2026-05-14

**Data/Description Value Binding — item display formatter**

**src/core/ItemDisplayFormatter.gd / src/entities/pickup/Pickup.gd / src/entities/player/Player.gd**

- Added a small item display formatter for pickup names/details and weapon/slot ammo strings.
- Focused pickup details now read weapon ammo, ammo amount, heal count, and armor amount from `ItemData` / `StatsData` instead of local string fragments in `Pickup.gd`.
- Player HUD slot ammo and reload-progress ammo text now share the same formatter fed by `WeaponSlotManager` slot state.
- No pickup collection, inventory, balance values, Telemetry hook names, or JSON schema were changed.

**검증 결과**

- `git diff --check` 통과.
- `.\Godot_v4.6.2-stable_win64_console.exe --path . --headless --quit` 통과.
- `python tools\simulate_matches.py 1` 통과: duration=72.6s, stage=3, recover=23, disengage=12.

---

## v1.10.3-dev — 2026-05-14

**Data/Description Value Binding — artifact descriptions**

**src/core/ArtifactCatalog.gd / src/Main.gd / src/entities/player/Player.gd**

- Starting artifact `line1`/`line2` text is now generated from structured `mods` values instead of storing gameplay numbers directly in prose.
- Red Trigger damage/spread values and Armor Sponge heal-to-shield amounts now live in artifact modifier fields that Player combat/healing code also reads.
- Zone Battery difficulty-specific shield regeneration moved from `Main.gd` ad hoc mutation into `ArtifactCatalog.prepare_for_difficulty()`, so selection card text and applied value share the same path.
- No balance values, Telemetry hook names, or JSON schema were changed.

**검증 결과**

- `git diff --check` 통과.
- `.\Godot_v4.6.2-stable_win64_console.exe --path . --headless --quit` 통과.
- `python tools\simulate_matches.py 1` 통과: duration=85.1s, stage=3, recover=26, disengage=16.

---

## v1.10-dev — 2026-05-14

**Bot Objective Awareness — loot movement scan**

**src/entities/bot/Bot.gd**

- Loot/objective chase now keeps navigation toward the pickup while rotating view through an objective-relative scan pattern.
- Footstep and ambient awareness can now set scan alerts during loot chase, so bots can turn their view toward nearby movement without abandoning the pickup route.
- Non-recovery opportunistic loot can still be interrupted by a fully revealed enemy; recovery/combat-loot runs keep their objective unless existing higher-priority damage or loud-gunshot overrides take over.
- Telemetry hook names and JSON schema were not changed.

**검증 결과**

- `git diff --check` 통과.
- `.\Godot_v4.6.2-stable_win64_console.exe --path . --headless --quit` 통과.
- `python tools\simulate_matches.py 1` 통과: duration=104.4s, stage=4, recover=41, disengage=17.

---

## v1.10-dev — 2026-05-13

**RecordsPanelBuilder Boundary — Records rendering split**

**src/ui/RecordsPanelBuilder.gd / src/Main.gd**

- Moved Records difficulty tabs, clear button, history row rendering, and record icon value rows out of `Main.gd`.
- `Main.gd` keeps selected difficulty state and callbacks; `RecordsPanelBuilder` owns UI construction from Telemetry history.
- This continues the low-risk `MenuController`-direction split without moving game state, match flow, or Telemetry schema.
- `Main.gd` is now about 1847 lines after the Help/Records builder splits.

**검증 결과**

- `git diff --check` 통과.
- `.\Godot_v4.6.2-stable_win64_console.exe --path . --headless --quit` 통과.
- `python tools\simulate_matches.py 1` 통과: duration=74.1s, stage=3, recover=30, disengage=17.

---

## v1.10-dev — 2026-05-13

**HelpPanelBuilder Boundary — How to Play rendering split**

**src/ui/HelpPanelBuilder.gd / src/Main.gd**

- Moved How to Play scroll content rendering from `Main.gd` into `HelpPanelBuilder`.
- `Main.gd` now wires the Help panel root and close button styling, while `HelpPanelBuilder` reads `HelpCatalog` rows and uses `MenuIconFactory` for icon rows.
- This is a low-risk `MenuController`-direction slice; gameplay state ownership, Telemetry hooks, and match flow were not changed.
- `Main.gd` dropped the HelpPanel row-builder functions and no longer preloads `HelpCatalog` directly.

**검증 결과**

- `git diff --check` 통과.
- `.\Godot_v4.6.2-stable_win64_console.exe --path . --headless --quit` 통과.
- `python tools\simulate_matches.py 1` 통과: duration=62.3s, stage=2, recover=14, disengage=17.

---

## v1.10.2-dev — 2026-05-13

**Item/Asset Readability Polish — weapon icon optical sizing**

**tools/sync_generated_icons.ps1**

- Added per-icon `VisualScale` overrides so generated square-canvas weapon masters can be optically balanced during sync instead of manually edited after export.
- Added `-OnlyCategory` filtering and used `-OnlyCategory weapons` so this pass only re-synced runtime weapon icons.

**assets/icons/weapons/**

- Re-synced knife, pistol, AR, shotgun, and railgun runtime icons.
- Pistol was reduced from roughly 54x43 alpha bounds to 42x34.
- AR, shotgun, and railgun were expanded horizontally to roughly 57-60px bounds so long weapons do not read as undersized beside pistol.
- HUD rendering and pickup decal code were not changed.

**검증 결과**

- `git diff --check` 통과.
- `.\Godot_v4.6.2-stable_win64_console.exe --path . --headless --quit` 통과.
- `python tools\simulate_matches.py 1` 통과: duration=77.0s, stage=3, recover=14, disengage=20.

---

## v1.10.1-dev — 2026-05-13

**Item/Asset Readability Polish — focus marker and death-drop labels**

**src/entities/pickup/Pickup.gd**

- Reduced focused pickup floor marker radius, alpha, and emission so it reads as a secondary focus cue instead of a heavy ground highlight.
- Pickup focus logic, collection behavior, and Telemetry schema were not changed.

**src/core/DropDisplayCatalog.gd / src/entities/player/Player.gd / src/entities/bot/Bot.gd**

- Added a shared death-drop display catalog for runtime-generated weapon, ammo, and heal pickup names.
- Player death drops now use Korean names consistently with bot death drops and `src/items/*.tres` templates.
- Bot death drops were moved to the same catalog so future death-drop naming changes have one source.

**Docs**

- Clarified that v1.10 is still in progress, not a completed Main slimdown release.
- Updated v1.10 completion gate and impact notes for `DropDisplayCatalog`.

**검증 결과**

- `git diff --check` 통과.
- `.\Godot_v4.6.2-stable_win64_console.exe --path . --headless --quit` 통과.
- `python tools\simulate_matches.py 1` 통과: duration=77.1s, stage=3, recover=20, disengage=21.

---

## v1.10.x-dev — 2026-05-13

**Item/Asset Readability Polish — pickup label LOD and focus**

**src/entities/pickup/Pickup.gd / src/entities/player/Player.gd**

- Pickup labels now use a small LOD policy: distant pickups hide labels, nearby non-focused pickups show name only, and the current interaction focus shows name plus ammo/quantity detail.
- Same-kind pickup clusters suppress duplicate labels so dense loot piles do not flood the screen with repeated text.
- Common/blue weapon and ammo glow intensity was reduced while purple/orange/cyan high-value cues remain stronger.
- The player now tracks the nearest interactable pickup each frame and marks it with a subtle in-world focus disc plus detailed label.
- Collection behavior, item data, and Telemetry JSON schema were not changed.

**docs/IMPACT_MAP.md**

- Updated pickup display ownership notes to reflect label LOD/focus behavior.

**검증 결과**

- `git diff --check` 통과.
- `.\Godot_v4.6.2-stable_win64_console.exe --path . --headless --quit` 통과.
- `python tools\simulate_matches.py 1` 통과: duration=61.7s, stage=2, recover=17, disengage=21.

---

## v1.10-docs — 2026-05-13

**Document Operations Reset + External Asset Prompt Plan**

**Docs**

- Replaced the default documentation flow with a short routing structure:
  - [../CLAUDE.md](../CLAUDE.md)
  - [DOCS_INDEX.md](DOCS_INDEX.md)
  - [MASTERPLAN.md](MASTERPLAN.md)
  - [DEVLOG.md](DEVLOG.md)
- Moved historical long documents out of the default reading path:
  - `docs/archive/MASTERPLAN_full_2026-05-13.md`
  - `docs/archive/IDEA_PLAN_legacy.md`
  - `docs/devlog/DEVLOG_full_2026-05-13.md`
- Added compact per-version devlog summaries under [devlog/INDEX.md](devlog/INDEX.md).
- Added local-only `docs/ASSET_GENERATION_PROMPTS.md` for copy-ready external generator prompts; it remains intentionally untracked.
- Replaced the old ASCII/mockup UI process with screenshot-driven review guidance in [UI_DESIGN.md](UI_DESIGN.md).

**Scope Note**

- No gameplay or runtime code changes.
- `asset_generator/` remains untracked and external.

---

## v1.10-dev — 2026-05-11

**MenuIconFactory Boundary — procedural menu icon split**

- Moved capsule logo and Records/Help pixel icon generation from `Main.gd` into `src/ui/MenuIconFactory.gd`.
- `Main.gd` now asks for icon IDs instead of owning pixel-generation details.
- Verified previously with Godot headless quit, one simulation, and `git diff --check`.

---

## v1.10-dev — 2026-05-11

**HelpCatalog Boundary — How to Play data split**

- Moved How to Play key/icon/text/description data into `src/core/HelpCatalog.gd`.
- `Main.gd` still owns the HelpPanel builder and rendering style.
- Verified previously with Godot headless quit, one simulation, and `git diff --check`.

---

## v1.10-dev — 2026-05-11

**DifficultyCatalog Boundary — difficulty UI data split**

- Moved difficulty labels, descriptions, and colors into `src/core/DifficultyCatalog.gd`.
- Main menu, tooltip, and Records tabs now share the same source.
- Verified previously with Godot headless quit, one simulation, and `git diff --check`.

---

## v1.10-dev — 2026-05-11

**ArtifactCatalog Boundary — starting artifact data split**

- Moved starting artifact ID/label/color/description/modifier data into `src/core/ArtifactCatalog.gd`.
- `Main.gd` keeps selection UI and modifier application flow.
- Verified previously with Godot headless quit, one simulation, and `git diff --check`.

---

## v1.10-dev — 2026-05-11

**SupplyDropController Boundary — supply calculation split**

- Added `src/core/SupplyDropController.gd` for supply telegraph timing, position roll, pillar progress, and cluster calculations.
- `Main.gd` still owns minimap state and actual node creation.
- Verified previously with Godot headless quit, one simulation, and `git diff --check`.
