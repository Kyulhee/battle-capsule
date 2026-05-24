# Battle Capsule Active Devlog

> Last updated: 2026-05-23. Keep this file short. Add only recent verified work and link older details through [devlog/INDEX.md](devlog/INDEX.md).

The previous full devlog was preserved at [devlog/DEVLOG_full_2026-05-13.md](devlog/DEVLOG_full_2026-05-13.md). Do not load it by default.

---

## v1.11.19-dev — 2026-05-24

**Player pass closure review**

**docs/MASTERPLAN.md / docs/ARCHITECTURE.md / docs/IMPACT_MAP.md / docs/devlog/v1.11.md**

- Re-audited `src/entities/player/Player.gd` after the HUD builder, slot renderer, weapon icon resolver, tuning constants, and occluder fader slices.
- Marked `Player.gd` at 832 lines and intentionally retained movement/input/crouch/footstep execution, health/shield runtime updates, heal consumption/regeneration, combat firing/melee execution, artifact modifier application, pickup focus/interaction, kill feed population, zone warning update, and Sfx/Telemetry hooks.
- Documented split Player-side owners: `PlayerHudBuilder.gd`, `PlayerSlotHudRenderer.gd`, `PlayerWeaponIconResolver.gd`, `PlayerTuning.gd`, and `PlayerOccluderFader.gd`.
- Scoped the next entity work toward Bot data-boundary slices.
- No runtime code or Telemetry schema was changed.

**검증 결과**

- `git diff --check` 통과.
- `.\Godot_v4.6.2-stable_win64_console.exe --path . --headless --quit` 통과.
- Runtime simulation은 생략: docs-only closure review이며 runtime code 변경 없음.

---

## v1.11.18-dev — 2026-05-24

**Player occluder fader helper**

**src/entities/player/PlayerOccluderFader.gd / src/entities/player/Player.gd**

- Added `PlayerOccluderFader.gd` for camera-to-player occluder ray sampling, occluder mesh discovery, fade material state, and restore behavior.
- `Player.gd` now delegates wall transparency updates with `self` and the camera node while keeping camera lookup, movement/combat/heal state, artifact modifiers, HUD updates, and zone warning logic.
- Kept occluder tuning values in `PlayerTuning.gd` and preserved ray sample points, collision mask, fade material behavior, linger timing, and exit-tree restore behavior.

**검증 결과**

- `git diff --check` 통과.
- `.\Godot_v4.6.2-stable_win64_console.exe --path . --headless --quit` 통과.
- `python tools\simulate_matches.py 1 normal` 통과: duration=70.4s, stage=3, recover=36, disengage=22.
- `python tools\simulate_matches.py 1 hell` 통과: duration=64.0s, stage=2, recover=110, disengage=23.

---

## v1.11.17-dev — 2026-05-23

**Player tuning constants boundary**

**src/entities/player/PlayerTuning.gd / src/entities/player/Player.gd**

- Added `PlayerTuning.gd` for footstep interval, heal regen rate, shot heat/spread tuning, melee tuning, and occluder fade tuning constants.
- `Player.gd` now references the tuning owner while keeping movement/combat/heal/occluder algorithms, runtime state, artifact modifiers, slot state, and HUD value updates.
- Preserved all current numeric values exactly and did not introduce JSON loading in this slice.

**검증 결과**

- `git diff --check` 통과.
- `.\Godot_v4.6.2-stable_win64_console.exe --path . --headless --quit` 통과.
- `python tools\simulate_matches.py 1 normal` 통과: duration=97.7s, stage=4, recover=30, disengage=20.
- `python tools\simulate_matches.py 1 hell` 통과: duration=88.0s, stage=3, recover=57, disengage=20.

---

## v1.11.16-dev — 2026-05-23

**Player weapon icon resolver**

**src/ui/player/PlayerWeaponIconResolver.gd / src/entities/player/Player.gd**

- Added `PlayerWeaponIconResolver.gd` for weapon HUD icon cache, AssetCatalog path loading, image-file fallback loading, and procedural pixel fallback generation.
- `Player.gd` now passes `main.asset_catalog` explicitly through the slot HUD renderer icon callback while keeping scene-tree lookup, `WeaponSlotManager` ownership, slot behavior, reload-progress override text, player state, combat, movement, and artifact behavior.
- Preserved weapon icon ids, fallback shapes/colors, slot HUD icon behavior, and missing-asset fallback behavior.

**검증 결과**

- `git diff --check` 통과.
- `.\Godot_v4.6.2-stable_win64_console.exe --path . --headless --quit` 통과.
- `python tools\simulate_matches.py 1 normal` 통과: duration=73.1s, stage=3, recover=15, disengage=15.
- `python tools\simulate_matches.py 1 hell` 통과: duration=70.3s, stage=3, recover=102, disengage=26.

---

## v1.11.15-dev — 2026-05-23

**Player slot HUD renderer**

**src/ui/player/PlayerSlotHudRenderer.gd / src/entities/player/Player.gd**

- Added `PlayerSlotHudRenderer.gd` for active/normal/out-of-ammo slot panel styling, slot ammo text, and ammo warning colors.
- `Player.gd` now delegates `_refresh_slot_hud()` while keeping `WeaponSlotManager` ownership, slot signal wiring, reload-progress override text, weapon icon loading/fallbacks, player state, combat, movement, artifact behavior, and Sfx/Telemetry hooks.
- The renderer receives weapon icons through an explicit `Callable` and does not read `AssetCatalog` or the scene tree.
- Preserved slot labels, active-slot highlight, empty-slot behavior, out-of-ammo coloring, and `ItemDisplayFormatter` ammo text.

**검증 결과**

- `git diff --check` 통과.
- `.\Godot_v4.6.2-stable_win64_console.exe --path . --headless --quit` 통과.
- `python tools\simulate_matches.py 1 normal` 통과: duration=60.9s, stage=2, recover=28, disengage=21.
- `python tools\simulate_matches.py 1 hell` 통과: duration=67.1s, stage=2, recover=167, disengage=20.

---

## v1.11.14-dev — 2026-05-23

**Player HUD/status builder continuation**

**src/ui/player/PlayerHudBuilder.gd / src/entities/player/Player.gd**

- Extended `PlayerHudBuilder.gd` beyond the top HUD to build health/shield rows, status counters, artifact label, bottom slot HUD nodes, and zone warning overlay.
- `Player.gd` now receives node/style references from the builder while keeping runtime value updates, slot selection/ammo styling, weapon icon loading/fallbacks, player state, combat, movement, artifact behavior, and Sfx/Telemetry hooks.
- Moved Player-local status icon helper functions into the HUD builder.
- Preserved existing CanvasLayer child order and did not change slot behavior, mission/pressure text, Telemetry schema, or combat constants.

**검증 결과**

- `git diff --check` 통과.
- `.\Godot_v4.6.2-stable_win64_console.exe --path . --headless --quit` 통과.
- `python tools\simulate_matches.py 1 normal` 통과: duration=67.3s, stage=2, recover=35, disengage=18.
- `python tools\simulate_matches.py 1 hell` 통과: duration=43.4s, stage=2, recover=127, disengage=18.

---

## v1.11.13-dev — 2026-05-23

**Player HUD builder first pass**

**src/ui/player/PlayerHudBuilder.gd / src/entities/player/Player.gd**

- Added `PlayerHudBuilder.gd` for Player top HUD node construction/styling.
- Moved zone timer, mission HUD, pressure HUD, mission/pressure flash panel, and kill feed container creation out of `Player.gd`.
- Kept `Player.gd` as the owner of HUD value updates, flash/kill feed population, health/shield/stat/slot HUD, player state, combat, movement, artifact behavior, and Sfx/Telemetry hooks.
- Preserved existing top HUD node order and did not change mission/pressure text, Telemetry schema, combat constants, or slot behavior.

**검증 결과**

- `git diff --check` 통과.
- `.\Godot_v4.6.2-stable_win64_console.exe --path . --headless --quit` 통과.
- `python tools\simulate_matches.py 1 normal` 통과: duration=79.2s, stage=3, recover=44, disengage=14.
- `python tools\simulate_matches.py 1 hell` 통과: duration=70.4s, stage=3, recover=134, disengage=19.

---

## v1.11.12-dev — 2026-05-23

**Mission subsystem closure review**

**docs/MASTERPLAN.md / docs/ARCHITECTURE.md / docs/IMPACT_MAP.md**

- Re-audited `src/systems/mission/MissionTracker.gd` after the mission catalog, HUD formatter, evaluator, pressure condition evaluator, badge store, and path ownership slices.
- Marked `MissionTracker.gd` at 257 lines and intentionally retained active mission/pressure state, counters, hooks, public wrappers, pressure timing/instant-fail state, and context assembly.
- Documented split mission subsystem owners: `MissionCatalog.gd`, `MissionHudFormatter.gd`, `MissionEvaluator.gd`, `PressureConditionEvaluator.gd`, and `MissionBadgeStore.gd`.
- Scoped the next v1.11 work toward Player entity data-boundary slices.
- No runtime code, mission behavior, pressure behavior, or Telemetry schema was changed.

**검증 결과**

- `git diff --check` 통과.
- `.\Godot_v4.6.2-stable_win64_console.exe --path . --headless --quit` 통과.
- Runtime simulation은 생략: docs-only closure review이며 runtime code 변경 없음.

---

## v1.11.11-dev — 2026-05-23

**Mission badge store first pass**

**src/systems/mission/MissionBadgeStore.gd / src/systems/mission/MissionTracker.gd**

- Added `MissionBadgeStore.gd` for `user://achievements.json` badge persistence.
- `MissionTracker.gd` now delegates `save_badge()`, `has_badge()`, and `load_achievements()` while keeping those public wrapper APIs.
- Preserved achievement JSON path, `badges` array shape, duplicate-prevention behavior, result flow, and Telemetry schema.

**검증 결과**

- `git diff --check` 통과.
- `.\Godot_v4.6.2-stable_win64_console.exe --path . --headless --quit` 통과.
- `python tools\simulate_matches.py 1 normal` 통과: duration=65.2s, stage=2, recover=27, disengage=16.
- `python tools\simulate_matches.py 1 hell` 통과: duration=72.4s, stage=3, recover=102, disengage=18.

---

## v1.11.10-dev — 2026-05-23

**Pressure condition evaluator first pass**

**src/systems/mission/PressureConditionEvaluator.gd / src/systems/mission/MissionTracker.gd**

- Added `PressureConditionEvaluator.gd` for pressure descriptor feasibility and active pressure condition completion checks.
- `MissionTracker.gd` now delegates `filter_feasible()` and pressure completion checks while keeping `PressureCondition` ids, counters, active pressure state, deadline timing, instant-fail flag, hooks, and public APIs.
- Kept pressure success/fail behavior, pressure descriptor ids, Main pressure trigger/effect flow, and Telemetry schema unchanged.

**검증 결과**

- `git diff --check` 통과.
- `.\Godot_v4.6.2-stable_win64_console.exe --path . --headless --quit` 통과.
- `python tools\simulate_matches.py 1 normal` 통과: duration=76.4s, stage=3, recover=30, disengage=21.
- `python tools\simulate_matches.py 1 hell` 통과: duration=46.5s, stage=2, recover=93, disengage=19.

---

## v1.11.9-dev — 2026-05-22

**MissionTracker system path move**

**src/systems/mission/MissionTracker.gd / src/Main.gd**

- Moved `MissionTracker.gd` and its `.uid` from `src/core/` to `src/systems/mission/`.
- Updated `Main.gd` preload path to the mission system location.
- Kept `class_name MissionTracker`, public APIs, mission/pressure state ownership, hooks, descriptors, evaluation, HUD behavior, badge persistence, and Telemetry-facing flow unchanged.

**검증 결과**

- `git diff --check` 통과.
- `.\Godot_v4.6.2-stable_win64_console.exe --path . --headless --quit` 통과.
- `python tools\simulate_matches.py 1 normal` 통과: duration=83.7s, stage=3, recover=27, disengage=21.
- `python tools\simulate_matches.py 1 hell` 통과: duration=75.5s, stage=3, recover=133, disengage=28.

---

## v1.11.8-dev — 2026-05-22

**Mission evaluator first pass**

**src/systems/mission/MissionEvaluator.gd / src/systems/mission/MissionTracker.gd**

- Added `MissionEvaluator.gd` for bonus mission completion and early-fail condition checks.
- `MissionTracker.gd` now keeps mission hooks/counters and builds explicit final-rank/player-HP/Telemetry context for evaluator calls.
- Kept public `evaluate()` and `get_early_fail_status()` APIs, mission completion rules, badge persistence, result flow, pressure evaluation, and Telemetry schema unchanged.

**검증 결과**

- `git diff --check` 통과.
- `.\Godot_v4.6.2-stable_win64_console.exe --path . --headless --quit` 통과.
- `python tools\simulate_matches.py 1 normal` 통과: duration=63.3s, stage=2, recover=20, disengage=21.
- `python tools\simulate_matches.py 1 hell` 통과: duration=73.8s, stage=3, recover=64, disengage=26.

---

## v1.11.7-dev — 2026-05-22

**Bonus mission HUD formatter first pass**

**src/systems/mission/MissionHudFormatter.gd / src/systems/mission/MissionTracker.gd**

- Extended `MissionHudFormatter.gd` to format bonus mission HUD text from explicit context data.
- `MissionTracker.gd` now keeps Telemetry/player HP context gathering and delegates `get_hud_text()` string assembly to the formatter.
- Preserved current mission HUD strings, including the no-Telemetry fallback for all-weapon mission text.
- Kept mission completion evaluation, early-fail checks, badge persistence, Player HUD label flow, and Telemetry schema unchanged.

**검증 결과**

- `git diff --check` 통과.
- `.\Godot_v4.6.2-stable_win64_console.exe --path . --headless --quit` 통과.
- `python tools\simulate_matches.py 1 normal` 통과: duration=58.9s, stage=2, recover=30, disengage=18.
- `python tools\simulate_matches.py 1 hell` 통과: duration=51.5s, stage=2, recover=132, disengage=24.

---

## v1.11.6-dev — 2026-05-22

**Pressure HUD formatter first pass**

**src/systems/mission/MissionHudFormatter.gd / src/systems/mission/MissionTracker.gd**

- Added `MissionHudFormatter.gd` for pressure HUD title/deadline/progress/reward/penalty string assembly.
- `MissionTracker.gd` now passes an explicit pressure counter snapshot and condition id mapping to the formatter.
- Kept pressure condition evaluation, success/fail timing, public `get_pressure_hud_text()` API, Player HUD label flow, effect ids/labels, and Telemetry schema unchanged.
- Bonus mission HUD/evaluation remains in `MissionTracker.gd` for a separate slice because it still reads Telemetry and player HP context.

**검증 결과**

- `git diff --check` 통과.
- `.\Godot_v4.6.2-stable_win64_console.exe --path . --headless --quit` 통과.
- `python tools\simulate_matches.py 1 normal` 통과: duration=57.7s, stage=2, recover=29, disengage=20.
- `python tools\simulate_matches.py 1 hell` 통과: duration=83.1s, stage=3, recover=113, disengage=23.

---

## v1.11.5-dev — 2026-05-22

**Mission/pressure descriptor catalog first pass**

**src/systems/mission/MissionCatalog.gd / src/systems/mission/MissionTracker.gd**

- Added `MissionCatalog.gd` as the descriptor/list construction owner for bonus missions and hard/Hell pressure mission pools.
- `MissionTracker.gd` now delegates `get_all_missions()`, `get_hard_pool()`, and `get_hell_pool()` to the catalog while keeping its public API stable.
- Kept mission/pressure ids, condition enum values, reward/penalty descriptors, feasibility filtering, progress/evaluation logic, HUD formatting, badge persistence, Main pressure flow, and Telemetry schema unchanged.

**검증 결과**

- `git diff --check` 통과.
- `.\Godot_v4.6.2-stable_win64_console.exe --path . --headless --quit` 통과.
- `python tools\simulate_matches.py 1 normal` 통과: duration=63.8s, stage=2, recover=34, disengage=22.
- `python tools\simulate_matches.py 1 hell` 통과: duration=45.1s, stage=2, recover=83, disengage=18.

---

## v1.11.4-dev — 2026-05-21

**Loot/supply subsystem directory first pass**

**src/systems/loot/LootSpawner.gd / SupplyDropController.gd / LootSpawnDirector.gd / src/Main.gd**

- Moved `LootSpawner.gd` and `SupplyDropController.gd` from `src/core/` to `src/systems/loot/`.
- Moved `LootSpawnDirector.gd` from `src/systems/match/` to `src/systems/loot/`.
- Updated `Main.gd` preload paths and architecture/impact docs.
- Kept `class_name`, public APIs, loot/supply quantities, supply timing, supply pillar creation, Telemetry hook calls, and Main-owned supply minimap state unchanged.

**검증 결과**

- `git diff --check` 통과.
- `.\Godot_v4.6.2-stable_win64_console.exe --path . --headless --quit` 통과.
- `python tools\simulate_matches.py 1 normal` 통과: duration=58.7s, stage=2, recover=51, disengage=19.
- `python tools\simulate_matches.py 1 hell` 통과: duration=70.5s, stage=3, recover=86, disengage=16.

---

## v1.11.3-dev — 2026-05-21

**Zone subsystem directory first pass**

**src/systems/zone/ZoneController.gd / src/Main.gd / docs/MASTERPLAN.md / docs/ARCHITECTURE.md / docs/IMPACT_MAP.md**

- Moved `ZoneController.gd` from `src/core/` to `src/systems/zone/` with its Godot script uid file.
- Updated `Main.gd` preload path to the new zone system location.
- Kept `class_name`, public API, signals, stage config behavior, outside damage behavior, and `main.zone` read pattern unchanged.
- `Main.gd` still owns the zone instance and Telemetry-facing zone flow.

**검증 결과**

- `git diff --check` 통과.
- `.\Godot_v4.6.2-stable_win64_console.exe --path . --headless --quit` 통과.
- `python tools\simulate_matches.py 1 normal` 통과: duration=76.5s, stage=3, recover=36, disengage=12.
- `python tools\simulate_matches.py 1 hell` 통과: duration=78.4s, stage=3, recover=147, disengage=24.

---

## v1.11.2-dev — 2026-05-21

**Hell tuning data boundary**

**data/game_config.json / src/core/GameConfig.gd / src/systems/hell/HellTuning.gd / src/systems/hell/HellEventController.gd**

- Added `HellTuning` for sanitized Hell timer, blackout, bombardment, barrage, standard bombardment, and marker visual values.
- Expanded `data/game_config.json` `hell` into structured `timers`, `blackout`, `bombardment`, `barrage`, `standard`, and `disc` sections with the existing values.
- Added `GameConfig.hell_tuning()` while keeping `hell_value()` for compatibility.
- Updated `HellEventController` to read tuning through `HellTuning` instead of owning local bombardment/blackout constants.
- Preserved Hell modifier ids, event names, damage/timing/color values, gameplay behavior, and Telemetry schema.

**검증 결과**

- `git diff --check` 통과.
- `.\Godot_v4.6.2-stable_win64_console.exe --path . --headless --quit` 통과.
- `python tools\simulate_matches.py 1 normal` 통과: duration=79.5s, stage=3, recover=30, disengage=21.
- `python tools\simulate_matches.py 1 hell` 통과: duration=40.4s, stage=2, recover=110, disengage=17.

---

## v1.11.1-dev — 2026-05-15

**Hell subsystem directory first pass**

**src/systems/hell/HellEventController.gd / src/Main.gd / docs/MASTERPLAN.md / docs/ARCHITECTURE.md / docs/IMPACT_MAP.md**

- Started v1.11 as a subsystem directory/data-boundary version.
- Moved `HellEventController.gd` from `src/core/` to `src/systems/hell/` and updated the `Main.gd` preload path.
- Kept `class_name`, public API, signal names, modifier ids, Telemetry event names, and runtime behavior unchanged.
- Documented the v1.11 slice order and scoped v1.11.2 as Hell tuning data separation.
- No Hell tuning values, gameplay behavior, or Telemetry schema changed.

**검증 결과**

- `git diff --check` 통과.
- `.\Godot_v4.6.2-stable_win64_console.exe --path . --headless --quit` 통과.
- `python tools\simulate_matches.py 1 normal` 통과: duration=61.4s, stage=2, recover=36, disengage=21.
- `python tools\simulate_matches.py 1 hell` 통과: duration=55.9s, stage=2, recover=117, disengage=17.

---

## v1.10.20-dev — 2026-05-15

**Main data/catalog closure review**

**docs/MASTERPLAN.md / docs/ARCHITECTURE.md / docs/IMPACT_MAP.md**

- Re-audited `Main.gd` after the v1.10.17-v1.10.19 data/resource/runtime/presentation splits; current line count is 1097.
- Marked v1.10 Main-owned data/catalog/presentation cleanup structurally closed.
- Classified remaining `Main.gd` values as intentionally Main-owned merge points/state/wiring or deferred v1.11 domain-slice work.
- Explicitly deferred Hell start-state policy, mission/artifact feasibility glue, mission context thresholds, result text formatting, debug snapshot aggregation, and non-Main tuning/data boundaries to v1.11.
- No runtime code, gameplay behavior, or Telemetry schema was changed.

**검증 결과**

- `git diff --check` 통과.
- `.\Godot_v4.6.2-stable_win64_console.exe --path . --headless --quit` 통과.
- `python tools\simulate_matches.py 1 normal` 통과: duration=66.3s, stage=2, recover=36, disengage=25.

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

**src/core/PressureEffectCatalog.gd / src/systems/mission/MissionTracker.gd / src/systems/match/PressureEffectApplier.gd / src/systems/match/BotSpawnPlanner.gd / src/entities/bot/BotDoctrine.gd / src/systems/zone/ZoneController.gd / data/game_config.json / src/Main.gd**

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
