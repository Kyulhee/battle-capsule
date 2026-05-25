# Impact Map — 배틀캡슐

> **정확성 규칙**: 이 파일이 실제 코드와 다를 경우 즉시 사용자에게 보고하고 수정하라.  
> 기준 버전: v1.11-dev / 마지막 검증: 2026-05-24

---

## 모듈 소유 관계

| 모듈 | 소유 변수 | 소유자 파일 | 타입 |
|---|---|---|---|
| ZoneController | `var zone` | `Main.gd` | RefCounted zone system controller |
| WeaponSlotManager | `var slots` | `Player.gd` | RefCounted |
| MissionTracker | `var mission_tracker` | `Main.gd` | RefCounted |
| MissionBadgeStore | achievement badge persistence | `MissionTracker.gd` | static mission store |
| MissionCatalog | bonus/pressure descriptor pools | `MissionTracker.gd` | static mission catalog |
| MissionEvaluator | bonus mission completion and early-fail rules | `MissionTracker.gd` | static mission evaluator |
| MissionHudFormatter | mission/pressure HUD strings | `MissionTracker.gd` | static mission formatter |
| PressureConditionEvaluator | pressure feasibility and completion rules | `MissionTracker.gd` | static pressure evaluator |
| WeaponSlotTuning | reload times and reserve-ammo caps | `WeaponSlotManager.gd` | static tuning helper |
| ArtifactCatalog | starting artifact specs/descriptions | `Main.gd`, `Player.gd` | static catalog |
| ItemResourceCatalog | default loot resources and pickup scene | `Main.gd` | static catalog |
| ItemDisplayFormatter | pickup/HUD item text | `Pickup.gd`, `Player.gd` | static formatter |
| PickupPresentation | pickup color/glow/label/icon plane presentation values | `Pickup.gd` | static presentation helper |
| PickupIconResolver | pickup icon ids/cache/catalog texture loading | `Pickup.gd` | RefCounted icon helper |
| DropDisplayCatalog | death-drop display names/colors | `Player.gd`, `Bot.gd` | static catalog |
| PlayerHudBuilder | Player HUD node/style construction | `Player.gd` | static UI builder |
| PlayerSlotHudRenderer | Player slot panel/ammo display refresh | `Player.gd` | static UI renderer |
| PlayerWeaponIconResolver | Player weapon HUD icon cache/loading/fallbacks | `Player.gd` | RefCounted UI resolver |
| PlayerTuning | Player movement/combat/heal/occluder tuning constants | `Player.gd` | static tuning constants |
| PlayerOccluderFader | Player occluder ray tracing/fade material state | `Player.gd` | RefCounted helper |
| BotTuning | Bot melee/retreat/perception/debug tuning constants | `Bot.gd` | static tuning constants |
| BotDebugLabelBuilder | Bot state/archetype Label3D construction | `Bot.gd` | static visual helper |
| BotMarkerFormatter | Bot state/archetype marker text/color/catalog id mapping | `Bot.gd` | static formatter |
| BotVisualSkinController | Bot archetype skin root apply/sync/hide lifecycle | `Bot.gd` | RefCounted visual helper |
| HellEventController | Hell blackout/bombardment runtime | `Main.gd` | RefCounted hell system controller |
| HellTuning | Hell event tuning and visual defaults | `HellEventController.gd`, `GameConfig.gd` | static tuning helper |
| MenuVisualBuilder | menu background/button presentation | `Main.gd` | static UI builder |
| WorldPresentationBuilder | zone ring and supply pillar world presentation | `Main.gd` | static UI/world builder |
| DifficultySelectorBuilder | difficulty selector/tooltip UI | `Main.gd` | static UI builder |
| SettingsPanelBuilder | settings modal UI | `Main.gd` | static UI builder |
| ResultPanelBuilder | result panel layout/population | `Main.gd` | static UI builder |
| PausePanelBuilder | pause overlay/buttons | `Main.gd` | static UI builder |
| ArtifactSelectionPanelBuilder | artifact selection modal UI | `Main.gd` | static UI builder |
| HellAnnouncementBuilder | Hell announcement modal UI | `Main.gd` | static UI builder |
| EventTextBuilder | transient event text overlay | `Main.gd` | static UI builder |
| MenuController | panel routing and menu button wiring | `Main.gd` | RefCounted UI controller |
| MatchBootstrap | match-start initialization helpers | `Main.gd` | static system helper |
| MatchTuning | match/zone tuning interpretation | `Main.gd` | static system helper |
| MatchRuntimeTuning | Main runtime spawn/navigation/loot fallback tuning | `Main.gd` | static system helper |
| BotSpawnPlanner | bot archetype plan generation | `Main.gd` | static system helper |
| LootSpawner | loot hotspot and position calculation | `Main.gd` | RefCounted loot system helper |
| SupplyDropController | supply drop timing and cluster calculation | `Main.gd` | RefCounted loot system helper |
| LootSpawnDirector | loot/supply pickup creation | `Main.gd` | static loot system helper |
| PressureEffectCatalog | pressure effect ids and HUD labels | `MissionTracker.gd`, `PressureEffectApplier.gd` | static catalog |
| PressureEffectApplier | pressure reward/penalty execution | `Main.gd` | static system helper |

---

## 파일별 양방향 참조

### `src/Main.gd`
- **현재 역할**: match-global orchestrator. v1.10.20 기준 1097줄.
- **의도적으로 소유**: `zone`, `mission_tracker`, `player_ref`, `alive_count`, `game_over`, `difficulty`, pressure flags, supply minimap state, scene callbacks, exported scene/count defaults, Telemetry hook calls.
- **data/config-backed merge points**: `bot_count`, `loot_count`, `spawn_radius`, base zone exports are loaded/overridden through `GameConfig`/`MatchTuning` and CLI parsing before match start.
- **분리 완료**: item/resource references, runtime spawn/navigation/loot/supply fallback tuning, menu/panel builders, match bootstrap/tuning helpers, pressure effect execution, bot spawn planning, loot/supply pickup creation, zone/supply world presentation.
- **v1.11 이월**: Hell start-state policy, mission/artifact feasibility glue, mission context thresholds, result text formatting, debug snapshot aggregation, and non-Main tuning/data boundaries in Player/Bot/Mission/Hell/Loot/UI helpers.

### `src/systems/zone/ZoneController.gd`
- **읽는 파일**: `Bot.gd` (`main.zone.current_center/radius/stage`), `Minimap.gd` (`main.zone.current/next_center/radius`), `Player.gd` (`main.zone.shrinking`, `main.zone.timer`, `main.zone.is_outside()`)
- **쓰는 파일**: `Main.gd` 만 (`zone.timer +=`, `zone.wait_time`, `zone.shrink_time`). Stage별 수치는 `data/game_config.json` `zone.stages`가 소유하고, `Main.gd`/`MatchBootstrap.gd`가 controller에 주입.
- **시그널 수신처**: `Main.gd` — `stage_advanced` → `_on_zone_stage_changed()`, `zone_warning` → `_on_zone_warning()`
- **내부에서 호출하는 외부 API**: `entity.take_damage()` (duck-typed), `mission_tracker.on_player_zone_tick()` / `on_pressure_zone_tick()` (duck-typed)
- **v1.11 상태**: path ownership first pass complete. `Main.gd` still owns the instance; other systems continue to read `main.zone`.

### `src/core/WeaponSlotManager.gd`
- **읽는 파일**: `Player.gd` (소유, 모든 접근), `Main.gd` (`player_ref.slots.fill_all_ammo()` / `clear_all_ammo()` / `clear_active_ammo()`)
- **tuning 경계**: reload times and reserve-ammo caps live in `WeaponSlotTuning.gd`; `WeaponSlotManager.gd` keeps slot arrays, active slot, reload timers, reload transfer state, signals, public APIs, and inventory/reload algorithms.
- **쓰는 파일**: `Player.gd` 만
- **시그널 수신처**: `Player.gd` — `slot_switched` → `_on_slot_switched()`, `reload_started` → `Sfx.play("reload")`, `reload_done` → `_on_reload_done()`, `inventory_changed` → `_refresh_slot_hud()`, `gun_count_changed` → `_on_gun_count_changed()`
- **외부 진입점**: `Pickup.gd` → `Player.receive_weapon()` / `receive_ammo()` 래퍼 → `slots.*()` (Pickup은 WeaponSlotManager를 직접 참조하지 않음)

### `src/core/WeaponSlotTuning.gd`
- **읽는 파일**: 직접 scene lookup 없음.
- **호출자**: `WeaponSlotManager.gd` `get_reload_time()` / `get_reserve_max()`.
- **역할**: no-weapon reload fallback, unknown-weapon reload fallback, weapon-specific reload times, weapon-specific reserve-ammo caps, and reserve fallback.
- **소유하지 않는 것**: slot inventory state, reload transfer algorithm, signals, Player HUD rendering, pickup collection, pressure effect execution.
- **수정 영향**: reload time이나 reserve cap을 바꾸면 `WeaponSlotManager.gd`, Player slot HUD ammo text, pressure ammo effects, and normal/Hell simulations를 함께 확인.

### `src/systems/mission/MissionTracker.gd`
- **읽는 파일**: `MissionBadgeStore.gd` (badge persistence), `MissionCatalog.gd` (bonus/pressure descriptor construction), `MissionEvaluator.gd` (bonus mission evaluation), `MissionHudFormatter.gd` (bonus/pressure HUD formatting), `PressureConditionEvaluator.gd` (pressure condition checks)
- **호출자**: `Main.gd` (소유), `MatchBootstrap.gd` (`get_all_missions()`), `ZoneController.gd` (`tick_damage` 내 duck-typed)
- **쓰는 파일**: `Main.gd` 만
- **시그널**: 없음 — `tick_pressure(delta, num_detecting)` 반환값 `"success"` / `"fail"` / `""` 을 Main이 폴링
- **훅 호출자**: `Main.gd` (`on_pressure_kill`, `on_pressure_damage`, `on_weapon_slot_used` 등), `ZoneController.gd` (`on_player_zone_tick`, `on_pressure_zone_tick`)
- **소유 범위**: mission/pressure runtime state, `PressureCondition` enum ids, progress counters, pressure timing, pressure instant-fail flag, mission/pressure context gathering, badge wrapper APIs.
- **소유하지 않는 것**: badge JSON file I/O, bonus mission list construction, hard/Hell pressure descriptor pool construction, bonus mission completion/early-fail rules, pressure feasibility/completion condition checks, bonus/pressure HUD string/effect/progress assembly.
- **v1.11.12 closure**: 257 lines. Further splitting should require a concrete behavior/state migration plan, not line-count cleanup.

### `src/systems/mission/MissionBadgeStore.gd`
- **읽는 파일**: `user://achievements.json`.
- **호출자**: `MissionTracker.gd` public `save_badge()`, `has_badge()`, `load_achievements()` wrappers.
- **역할**: achievement JSON load/save, `badges` array creation, duplicate badge prevention.
- **소유하지 않는 것**: active mission state, badge award timing, result panel text, Telemetry.
- **수정 영향**: achievement schema/path 변경 시 `MissionTracker.gd` wrappers, `Main.gd` result flow, user save compatibility를 함께 확인.

### `src/systems/mission/MissionCatalog.gd`
- **읽는 파일**: `MissionData.gd`, `PressureEffectCatalog.gd`.
- **호출자**: `MissionTracker.gd` public static wrappers.
- **역할**: bonus mission list construction, hard/Hell pressure descriptor pools, mission/pressure ids, reward/penalty descriptor composition.
- **소유하지 않는 것**: active mission state, pressure runtime counters, feasibility filtering, pressure condition evaluation, HUD progress text, badge persistence, Main pressure trigger flow.
- **수정 영향**: 새 bonus mission이나 pressure descriptor 추가 시 `MissionTracker.gd` condition/evaluation support, `PressureEffectCatalog.gd`, `PressureEffectApplier.gd`, `Main.gd` pressure state updates, simulations를 함께 확인.

### `src/systems/mission/MissionEvaluator.gd`
- **읽는 파일**: `MissionData.gd`.
- **호출자**: `MissionTracker.gd` `evaluate()` / `get_early_fail_status()`.
- **역할**: bonus mission completion and early-fail condition checks from explicit final-rank/player-HP/Telemetry/counter context.
- **소유하지 않는 것**: active mission selection, mission hooks/counters, badge persistence, result panel flow, pressure mission success/fail evaluation.
- **수정 영향**: bonus mission condition 변경 시 `MissionCatalog.gd` descriptor data, `MissionTracker.gd` context keys, `MissionHudFormatter.gd` HUD text, `Main.gd` result mission save flow, simulations를 함께 확인.

### `src/systems/mission/MissionHudFormatter.gd`
- **읽는 파일**: `MissionData.gd`, `PressureEffectCatalog.gd`.
- **호출자**: `MissionTracker.gd` `get_hud_text()` / `get_pressure_hud_text()`.
- **역할**: bonus mission HUD strings and pressure HUD title/deadline/progress/reward/penalty string assembly from explicit context dictionaries.
- **소유하지 않는 것**: bonus/pressure counters, mission completion evaluation, pressure success/fail result, early-fail checks, Player HUD label node placement, Telemetry.
- **수정 영향**: mission/pressure HUD 문구/진행도 포맷 변경 시 `MissionTracker.gd` context snapshot keys, `MissionData.gd` condition ids, `PressureEffectCatalog.gd` effect labels, `Player.gd` HUD label behavior를 함께 확인.

### `src/systems/mission/PressureConditionEvaluator.gd`
- **읽는 파일**: 직접 scene lookup 없음. `MissionTracker.gd`가 descriptor, counter snapshot, condition id mapping을 넘김.
- **호출자**: `MissionTracker.gd` `filter_feasible()` / `_evaluate_pressure_conditions()`.
- **역할**: pressure descriptor feasibility and active pressure condition completion checks.
- **소유하지 않는 것**: active pressure state, pressure counters, deadline ticking, instant-fail mutation, reward/penalty application, Telemetry.
- **수정 영향**: 새 pressure condition이나 feasibility rule 변경 시 `MissionTracker.gd` counter hooks/snapshot, `MissionCatalog.gd` descriptors, `MissionHudFormatter.gd` progress text, pressure simulations를 함께 확인.

### `src/core/ItemResourceCatalog.gd`
- **읽는 파일**: `src/items/*.tres`, `src/entities/pickup/Pickup.tscn`.
- **호출자**: `Main.gd` `_configure_item_resources()`.
- **역할**: 기본 loot item templates, extra consumables, supply railgun item, pickup scene 리소스 참조를 한 곳에서 제공.
- **소유하지 않는 것**: loot/supply state, spawn count, hotspot selection, pickup node creation, Telemetry logging.
- **수정 영향**: 기본 드랍 pool이나 supply railgun 리소스를 바꾸면 `Main.gd` runtime references, `LootSpawnDirector.gd`, `Pickup.gd`, `ItemData.gd`, simulation loot flow를 확인.

### `src/systems/hell/HellEventController.gd`
- **읽는 파일**: 직접 scene lookup 없음. `Main.gd`가 `game_config`, host, overlay parent, Telemetry를 주입.
- **호출자**: `Main.gd` `start_game()` / `_process()`에서 `configure()`, `start_match()`, `tick()` 호출.
- **역할**: Hell blackout/bombardment timer, warning disc creation, overlay flash, bomb damage application, and `Telemetry.log_hell_event()` delegation.
- **소유하지 않는 것**: 난이도 선택, Hell modifier enum compatibility, announcement panel, match-global state, Telemetry schema.
- **수정 영향**: Hell tuning constants or event names 변경 시 `Main.gd` Hell wiring, `Player.gd` SCARCITY read, `Telemetry.gd` event aggregation, `data/game_config.json` Hell timer keys를 함께 확인.
- **v1.11 상태**: path ownership first pass complete. Tuning values are read through `HellTuning.gd`; runtime algorithms remain here.

### `src/systems/hell/HellTuning.gd`
- **읽는 파일**: 직접 scene lookup 없음. `GameConfig.hell_tuning()` 결과 또는 fallback defaults만 처리.
- **호출자**: `HellEventController.gd` `configure()` 및 runtime section access.
- **역할**: Hell timers, blackout fade/hold, bombardment center/event text, barrage/standard bomb values, disc visual defaults sanitize/normalize.
- **소유하지 않는 것**: Hell runtime timers, overlay nodes, actor damage application, Telemetry logging, Hell modifier selection.
- **수정 영향**: Hell tuning key를 바꾸면 `data/game_config.json`, `GameConfig.gd` default data, `HellEventController.gd` section reads, Hell simulation을 함께 확인.

### `src/entities/Entity.gd` (base)
- **시그널 수신처**:
  - `died` → `Main.gd` (`_on_player_died`, `_on_bot_died`)
  - `health_changed` / `shield_changed` → `Player.gd` 자기 연결 (`_on_health_changed`, `_on_shield_changed`)
  - `health_changed` / `shield_changed` → `Main.gd` 에서도 직접 `.emit()` 호출 (압박 미션 효과 적용 시)
- **인식 API**: `_can_i_see(target)`는 actor perception, `can_sense_item(world_pos)`는 아이템 표시/플레이어 상호작용/봇 루팅 후보 필터에 공통 사용.

### `src/entities/player/Player.gd`
- **현재 역할**: Player entity runtime owner. v1.11.19 기준 832줄.
- **의도적으로 소유**: movement/input/crouch/footstep execution, health/shield runtime updates, heal consumption/regeneration, combat firing/melee execution, artifact modifier application, pickup focus/interaction, kill feed population, zone warning update, Sfx/Telemetry hooks.
- **분리 완료**: HUD construction (`PlayerHudBuilder.gd`), slot display state (`PlayerSlotHudRenderer.gd`), weapon HUD icon loading/fallbacks (`PlayerWeaponIconResolver.gd`), player tuning constants (`PlayerTuning.gd`), occluder fade state/material restore (`PlayerOccluderFader.gd`).
- **수정 영향**: movement/combat/heal/artifact/pickup behavior 변경 시 `PlayerTuning.gd`, `ArtifactCatalog.gd`, `WeaponSlotManager.gd`, `ItemDisplayFormatter.gd`, and simulations를 함께 확인.

### `src/entities/bot/Bot.gd`
- **현재 역할**: Bot entity runtime owner. v1.11.24 기준 1908줄.
- **Main 참조 방법**: `get_tree().get_root().get_node("Main")` 런타임 조회 — 읽기 전용
- **읽는 Main 필드**: `main.zone.current_center`, `main.zone.current_radius`, `main.zone.stage`, `main.alive_count`
- **전술 계층**: State/movement/firing 실행은 `Bot.gd`, 전술 선택과 profile merge는 `BotDoctrine.gd`.
- **tuning 경계**: `BotTuning.gd` owns melee/retreat counterfire/attack-bout/hard gunshot/debug constants. `Bot.gd` still owns the state machine and runtime behavior.
- **marker/skin 경계**: `BotDebugLabelBuilder.gd` owns Label3D node construction; `BotMarkerFormatter.gd` owns marker text/color/catalog id mapping; `BotVisualSkinController.gd` owns archetype skin root apply/sync/hide lifecycle. `Bot.gd` still owns visibility, reveal checks, crouch body mesh updates, AssetCatalog lookup, and AI state.
- **의도적으로 소유**: AI state machine and timers, navigation/stuck handling, objective/loot/supply decisions, recovery/disengage/zone escape behavior, perception/noise/ambient awareness checks, combat movement and firing/melee execution, damage/death/drop handling, Sfx/Telemetry hooks.
- **Death drop 표시**: `DropDisplayCatalog`에서 무기/탄약/회복 아이템 표시 이름과 death-drop 색상을 가져옴.
- **closure note**: Further Bot extraction should require explicit behavior coverage because perception, movement, loot, and combat execution share mutable runtime state.

### `src/entities/bot/BotTuning.gd`
- **읽는 파일**: 직접 scene lookup 없음.
- **호출자**: `Bot.gd`.
- **역할**: bot melee, attack-bout reposition, retreat counterfire, Hard gunshot awareness, and debug marker constants.
- **소유하지 않는 것**: AI state machine, doctrine profile application, movement/combat/recovery algorithms, perception checks, archetype/difficulty runtime state.
- **수정 영향**: Bot tuning value를 바꾸면 `Bot.gd` melee/retreat/perception/debug paths, `BotDoctrine.gd`, and normal/Hell simulations를 함께 확인.

### `src/entities/bot/BotDebugLabelBuilder.gd`
- **읽는 파일**: 직접 scene lookup 없음.
- **호출자**: `Bot.gd` `_ready()`.
- **역할**: state label and archetype marker `Label3D` node construction/styling.
- **소유하지 않는 것**: state/archetype marker text, color updates, catalog ids, visibility, reveal checks, AI behavior, visual skin application.
- **수정 영향**: Bot debug marker position/style을 바꾸면 `Bot.gd` marker visibility, `BotMarkerFormatter.gd` content specs, and visual checks를 함께 확인.

### `src/entities/bot/BotMarkerFormatter.gd`
- **읽는 파일**: `BotDoctrine.gd` combat plan constants. 직접 scene lookup 없음.
- **호출자**: `Bot.gd` `_update_state_label()` / `_update_archetype_marker()`, `BotVisualKit.gd` catalog tint lookup.
- **역할**: state label specs, archetype marker prefixes, combat-plan marker abbreviations, archetype fallback colors, and cosmetic catalog ids.
- **소유하지 않는 것**: `Label3D` node construction, marker visibility/reveal checks, AssetCatalog lookup, visual skin construction, AI behavior, Telemetry.
- **수정 영향**: Bot marker text/color/catalog id를 바꾸면 `Bot.gd` marker update paths, `BotVisualKit.gd` cosmetic ids, `data/asset_catalog.json`, and visual/headless checks를 함께 확인.

### `src/entities/bot/BotVisualSkinController.gd`
- **읽는 파일**: `BotVisualKit.gd`. 직접 scene lookup 없음.
- **호출자**: `Bot.gd` `_apply_visual_skin()`, crouch sync path, and `die()`.
- **역할**: `ArchetypeSkin` root application, visibility sync with the body mesh/death state, crouch position/scale sync, and death hide behavior.
- **소유하지 않는 것**: primitive skin part construction, material defaults, AssetCatalog lookup, AI state, crouch decision, body mesh scale/position changes, Telemetry.
- **수정 영향**: Bot skin visibility/position/scale를 바꾸면 `Bot.gd` crouch/death paths, `BotVisualKit.gd` generated parts, and visual/headless checks를 함께 확인.

### `src/core/DropDisplayCatalog.gd`
- **읽는 파일**: 직접 scene 참조 없음.
- **호출자**: `Player.gd`, `Bot.gd` death drop 생성 경로.
- **역할**: 런타임으로 생성되는 death drop의 weapon/ammo/heal 표시 이름과 weapon color를 한 곳에서 제공. 초기 맵 loot/supply drop 템플릿 이름은 `src/items/*.tres`가 계속 소유.

### `src/core/ArtifactCatalog.gd`
- **읽는 파일**: 직접 scene 참조 없음.
- **호출자**: `Main.gd` artifact selection/apply flow, `Player.gd` artifact modifier execution.
- **역할**: 시작 아티팩트 ID/label/color/modifier와 `line1`/`line2` 설명 생성. 설명 안의 gameplay 수치는 `mods`에서 읽어 생성하고, `Player.gd`도 같은 modifier 키를 읽어 실제 효과를 적용.
- **난이도 보정**: `prepare_for_difficulty()`가 Zone Battery regen처럼 난이도별로 달라지는 표시/적용 값을 준비한다. `Main.gd`에서 별도 ad hoc mutation을 추가하지 않는다.

### `src/core/ItemDisplayFormatter.gd`
- **읽는 파일**: 직접 scene 참조 없음.
- **호출자**: `Pickup.gd` label name/detail, `Player.gd` slot ammo and reload-progress HUD text.
- **역할**: pickup detail과 HUD ammo 문자열을 `ItemData`, `StatsData`, `WeaponSlotManager` slot state에서 받은 값으로 생성한다. 포맷 변경은 이 helper에서 시작하고, collection/inventory 동작은 건드리지 않는다.

### `src/ui/player/PlayerHudBuilder.gd`
- **읽는 파일**: 직접 scene lookup 없음. `Player.gd`가 `$CanvasLayer/Control` root를 넘김.
- **호출자**: `Player.gd` `_ready()`.
- **역할**: zone timer, mission HUD, pressure HUD, mission/pressure flash panel, kill feed container, health/shield/stat HUD, slot HUD nodes, and zone warning overlay construction/styling.
- **소유하지 않는 것**: HUD text/value updates, mission/pressure state reads, kill feed message population, slot selection/ammo styling updates, weapon icon loading/fallbacks, player combat/movement/state.
- **수정 영향**: Player HUD position/style/z-order를 바꾸면 `Player.gd` `_process()` label updates, `_update_status_hud()`, `_refresh_slot_hud()`, `show_pressure_flash()`, kill feed path, and zone warning alpha update를 함께 확인.

### `src/ui/player/PlayerSlotHudRenderer.gd`
- **읽는 파일**: `ItemDisplayFormatter.gd`. 직접 scene lookup 없음.
- **호출자**: `Player.gd` `_refresh_slot_hud()`.
- **역할**: slot active/normal/out-of-ammo panel styling, slot ammo text formatting, ammo warning color application, and slot icon texture assignment via caller-provided icon `Callable`.
- **소유하지 않는 것**: `WeaponSlotManager` state, slot switching/reload behavior, reload-progress override text, AssetCatalog icon lookup, procedural weapon icon fallback, combat state.
- **수정 영향**: slot highlight, ammo color, or ammo text behavior를 바꾸면 `Player.gd` `_refresh_slot_hud()` call path, reload-progress HUD override, `WeaponSlotManager` arrays, `PlayerWeaponIconResolver.gd`, and `ItemDisplayFormatter.gd`를 함께 확인.

### `src/ui/player/PlayerWeaponIconResolver.gd`
- **읽는 파일**: caller가 넘긴 `AssetCatalog`-compatible object only. 직접 scene lookup 없음.
- **호출자**: `Player.gd` `_refresh_slot_hud()`가 `PlayerSlotHudRenderer.gd`에 넘기는 icon `Callable`.
- **역할**: weapon HUD icon cache, AssetCatalog path loading, image-file fallback loading, and procedural pixel fallback icon generation.
- **소유하지 않는 것**: scene-tree lookup, slot state/style, ammo text, weapon inventory behavior, asset catalog data ownership.
- **수정 영향**: weapon HUD icon id, fallback color/shape, or icon loading behavior를 바꾸면 `data/asset_catalog.json`, selected assets under `assets/`, `PlayerSlotHudRenderer.gd`, and slot HUD visual verification을 함께 확인.

### `src/entities/player/PlayerTuning.gd`
- **읽는 파일**: 직접 scene lookup 없음.
- **호출자**: `Player.gd`.
- **역할**: footstep interval, heal regen rate, shot heat/spread constants, melee constants, and occluder fade constants.
- **소유하지 않는 것**: movement/combat/heal/occluder algorithms, artifact modifier application, runtime state, data-file loading.
- **수정 영향**: Player tuning value를 바꾸면 movement/fire/melee/heal/occluder behavior, normal/Hell simulations, and relevant player visual checks를 함께 확인.

### `src/entities/player/PlayerOccluderFader.gd`
- **읽는 파일**: `PlayerTuning.gd`. Direct scene lookup 없음.
- **호출자**: `Player.gd` `_handle_wall_transparency()` and `_exit_tree()`.
- **역할**: camera-to-player occluder ray samples, occluder group mesh discovery, fade material creation/update, linger state, and restore-on-exit behavior.
- **소유하지 않는 것**: camera node lookup, player movement/combat state, occluder group assignment in world assets, tuning constants.
- **수정 영향**: wall transparency/occluder behavior를 바꾸면 `Player.gd` camera path, occluder group tagging, `PlayerTuning.gd` fade constants, and visual/headless checks를 함께 확인.

### `src/ui/DifficultySelectorBuilder.gd`
- **읽는 파일**: `DifficultyCatalog.gd`.
- **호출자**: `Main.gd` main menu setup and difficulty state refresh.
- **역할**: 난이도 버튼, hover tooltip, pressure opt-in checkbox UI, difficulty highlight 갱신.
- **소유하지 않는 것**: 실제 `difficulty`, `pressure_opt_in_hard`, match start behavior.

### `src/ui/MenuVisualBuilder.gd`
- **읽는 파일**: 직접 scene lookup 없음. `Main.gd`가 대상 panel/button node와 logo texture를 넘김.
- **호출자**: `Main.gd` `_setup_menu_visuals()` / `_setup_secondary_panels()` / `_apply_btn_style()`.
- **역할**: main/secondary menu gradient backgrounds, main menu noise overlay, capsule logo placement, shared button StyleBox/color overrides.
- **소유하지 않는 것**: panel visibility routing, menu callbacks, Help/Records content, settings behavior, scene node lookup.
- **수정 영향**: 메뉴/보조 패널 배경이나 버튼 스타일을 바꾸면 `Main.gd` target node wiring, `MenuController.gd` panel routing, `HelpPanelBuilder.gd`/`RecordsPanelBuilder.gd` content layout을 함께 확인.

### `src/ui/WorldPresentationBuilder.gd`
- **읽는 파일**: 직접 scene lookup 없음. `Main.gd`가 zone controller와 supply pillar node를 넘김.
- **호출자**: `Main.gd` `_ready()` / `_process()` / `telegraph_supply_zone()`.
- **역할**: zone ring mesh/material defaults, zone ring position/scale sync, supply pillar drop Y-range interpolation.
- **소유하지 않는 것**: zone lifecycle/state, supply telegraph/spawn state, minimap state, loot/supply algorithms, Telemetry schema.
- **수정 영향**: zone ring color/mesh/radius styling이나 supply pillar drop visual을 바꾸면 `Main.gd` zone/supply wiring, `ZoneController.gd`, `SupplyDropController.gd`, `LootSpawnDirector.gd` supply pillar creation을 함께 확인.

### `src/ui/SettingsPanelBuilder.gd`
- **읽는 파일**: 직접 scene 참조 없음.
- **호출자**: `Main.gd` `_on_settings_pressed()`.
- **역할**: Settings modal UI, volume slider text, fullscreen button text, close button construction.
- **소유하지 않는 것**: `AudioServer`, `DisplayServer`, settings save/load keys. Main이 callback으로 유지.

### `src/ui/panels/ResultPanelBuilder.gd`
- **읽는 파일**: 직접 scene 참조 없음.
- **호출자**: `Main.gd` `_setup_result_panel()` / `_end_match()`.
- **역할**: Result panel card/buttons/labels 생성과 최종 결과 label population.
- **소유하지 않는 것**: match finalization, mission evaluation, score formula, Telemetry end/log calls.

### `src/ui/panels/PausePanelBuilder.gd`
- **읽는 파일**: 직접 scene lookup 없음. `Main.gd`가 resume/restart/menu callbacks와 button style callback을 넘김.
- **호출자**: `Main.gd` `_create_pause_panel()`.
- **역할**: pause overlay ColorRect, centered button stack, title, pause action buttons 생성.
- **소유하지 않는 것**: paused state, Escape input handling, restart/menu behavior, scene reload, panel lifetime.
- **수정 영향**: pause UI layout이나 버튼 구성을 바꾸면 `Main.gd` `_toggle_pause()`/`_input()`, `MenuVisualBuilder.gd` shared button style, scene pause mode behavior를 함께 확인.

### `src/ui/panels/ArtifactSelectionPanelBuilder.gd`
- **읽는 파일**: 직접 scene 참조 없음. 표시할 artifact catalog array를 `Main.gd`에서 받음.
- **호출자**: `Main.gd` `_show_artifact_select()`.
- **역할**: artifact selection overlay, artifact cards, skip/select buttons 생성.
- **소유하지 않는 것**: `ArtifactCatalog` lookup, `_pending_artifact`, artifact apply path, `start_game()` transition.

### `src/ui/panels/HellAnnouncementBuilder.gd`
- **읽는 파일**: 직접 scene 참조 없음. 표시할 Hell modifier description array를 `Main.gd`에서 받음.
- **호출자**: `Main.gd` `_show_hell_announcement()`.
- **역할**: Hell announcement overlay, card, penalty/event rows, start button 생성, dismiss fade duration default 제공.
- **소유하지 않는 것**: Hell modifier selection, pause/unpause, active panel lifetime, Hell runtime controller.

### `src/ui/overlays/EventTextBuilder.gd`
- **읽는 파일**: 직접 scene lookup 없음. `Main.gd`가 parent node, message, color를 넘김.
- **호출자**: `Main.gd` `_show_event_text()` through Hell/event signal paths.
- **역할**: top-center event label construction, text/shadow style, z-index, fade-out tween, queue_free callback.
- **소유하지 않는 것**: event timing, event source, Hell event runtime, gameplay state, Telemetry schema.
- **수정 영향**: event text 위치/수명/스타일을 바꾸면 `Main.gd` event signal wiring과 `HellEventController.gd` `event_text_requested` 호출 흐름을 함께 확인.

### `src/ui/menu/MenuController.gd`
- **읽는 파일**: `Main.gd`가 넘긴 `CanvasLayer/Control` subtree.
- **호출자**: `Main.gd` `_ready()` / `_show_panel()`.
- **역할**: panel visibility routing, main menu button wiring, dynamic Settings button insertion, Records/Help close button wiring.
- **소유하지 않는 것**: menu callbacks, settings behavior, Records/Help/Result content, gameplay state.

### `src/systems/match/MatchBootstrap.gd`
- **읽는 파일**: 직접 scene 참조 없음. `Main.gd`가 script refs, values, and callbacks를 넘김.
- **호출자**: `Main.gd` `start_game()`.
- **역할**: zone controller creation/configuration, bonus mission tracker creation/selection, initial pressure state dictionary, Hell modifier roll.
- **소유하지 않는 것**: `zone`, `mission_tracker`, pressure fields, spawn calls, Telemetry start calls, artifact application, Hell runtime controller.

### `src/systems/match/MatchTuning.gd`
- **읽는 파일**: 직접 scene 참조 없음. `Main.gd`가 `GameConfig`, 현재 exported tuning 값, 또는 CLI arg 문자열을 넘김.
- **호출자**: `Main.gd` `_apply_game_config()` / `_apply_cmdline_arg()`.
- **역할**: match/zone config 값 clamp, CLI match override alias parsing, CLI difficulty parsing.
- **소유하지 않는 것**: `bot_count`, `loot_count`, `spawn_radius`, zone timing fields, `difficulty`, `loot_spawner.configure_count()`, match-global state, Telemetry schema.
- **수정 영향**: 새 CLI alias나 config key를 추가하면 `Main.gd` 적용 경로, `data/game_config.json`, `tools/simulate_matches.py` 호출 관례, TESTING/문서 예시를 함께 확인.

### `src/systems/match/BotSpawnPlanner.gd`
- **읽는 파일**: 직접 scene 참조 없음.
- **호출자**: `Main.gd` `spawn_entities()`.
- **역할**: weighted bot archetype name plan 생성, Hell all-aggressive modifier용 forced archetype plan 생성. 정수 id 변환은 `BotDoctrine.gd`가 담당.
- **소유하지 않는 것**: bot scene instancing, spawn position, AI configuration call, `alive_count`, Telemetry spawn logging.
- **수정 영향**: bot_count 확장, archetype 비율, 새 archetype 추가 시 `BotDoctrine.gd` name/id mapping, `Bot.gd`, Telemetry archetype aggregation, `Main.gd` spawn wiring을 함께 확인.

### `src/systems/match/MatchRuntimeTuning.gd`
- **읽는 파일**: 직접 scene 참조 없음. `Main.gd`가 `GameConfig.runtime_tuning()` 결과를 넘김.
- **호출자**: `Main.gd` `_setup_navigation()`, `_get_safe_spawn_pos()`, `_is_clear_of_entities()`, `_is_clear_of_obstacles()`, `_on_zone_stage_changed()`, `telegraph_supply_zone()`.
- **역할**: spawn safety, navigation bake, stage loot wave, supply fallback tuning 값 clamp/normalize.
- **소유하지 않는 것**: actual spawn algorithm, NavigationRegion node ownership, loot/supply state, Telemetry logging, CLI overrides.
- **수정 영향**: runtime tuning key를 바꾸면 `data/game_config.json`, `GameConfig.gd`, `Main.gd` call sites, simulation spawn/loot/supply flow를 함께 확인.

### `src/systems/loot/LootSpawner.gd`
- **읽는 파일**: direct scene lookup 없음. `Main.gd`가 `MapSpec`을 넘김.
- **호출자**: `Main.gd` loot hotspot registration, position choice, spawn count calculation.
- **역할**: POI 기반 loot hotspot 등록, density-weighted hotspot choice, random loot position sampling, initial weapon/consumable count calculation.
- **소유하지 않는 것**: pickup node creation, item templates, supply state, Telemetry logging.
- **수정 영향**: loot density/position/count rule 변경 시 `Main.gd`, `MapSpec`, `LootSpawnDirector.gd`, pickup/simulation flow를 함께 확인.

### `src/systems/loot/SupplyDropController.gd`
- **읽는 파일**: direct scene lookup 없음.
- **호출자**: `Main.gd` supply telegraph, pillar progress, supply cluster count/offset.
- **역할**: supply drop timing, random position roll, pillar progress, cluster consumable count, cluster offset.
- **소유하지 않는 것**: minimap state, supply pillar node creation, pickup creation, Telemetry logging.
- **수정 영향**: supply timing/position/cluster rule 변경 시 `Main.gd`, `LootSpawnDirector.gd`, `Minimap.gd`, simulation supply flow를 함께 확인.

### `src/systems/loot/LootSpawnDirector.gd`
- **읽는 파일**: `ItemData.gd` type enum. 직접 scene lookup 없음.
- **호출자**: `Main.gd` `_categorize_templates()` / `_spawn_initial_loot()` / `spawn_loot()` / `telegraph_supply_zone()` / `activate_supply_zone()`.
- **역할**: item template category split, initial loot pickup creation, dynamic loot wave pickup creation, supply pillar creation, supply cluster pickup creation.
- **소유하지 않는 것**: `loot_count`, `loot_hotspots`, `supply_telegraphed`, `supply_spawned`, `supply_pos`, `supply_timer`, Telemetry supply event logging, minimap state.
- **수정 영향**: pickup spawn quantities or supply cluster composition 변경 시 `LootSpawner.gd`, `SupplyDropController.gd`, item templates, `Pickup.gd`, `Main.gd` supply state, Minimap supply display를 함께 확인.

### `src/systems/match/PressureEffectApplier.gd`
- **읽는 파일**: `PressureEffectCatalog.gd` effect ids. 직접 scene lookup 없음.
- **호출자**: `Main.gd` `_apply_pressure_effects()`.
- **역할**: pressure reward/penalty effects execution against explicit `player`, `zone`, and `actors` context; returns Main-owned pressure state updates.
- **소유하지 않는 것**: pressure mission selection/timing, `heal_pickup_banned`, `heal_ban_until_stage`, `railgun_unlimited_until_stage`, player/zone/actor ownership, Telemetry logging.
- **수정 영향**: 새 pressure effect 추가 시 `PressureEffectCatalog.gd` id/format, `MissionCatalog.gd` descriptor pools, `PressureEffectApplier.gd`, `Main.gd` returned state handling, `Player.gd`/`ZoneController.gd`/`Bot.gd` touched state를 함께 확인.

### `src/entities/bot/Bot.gd`
- **목표 이동**: `is_targeting_loot` CHASE는 `_nav_move_toward(..., false)`로 pickup 방향 이동을 유지하고 `_update_objective_scan()`으로 시야 회전을 따로 갱신.
- **감지 연결**: footstep/ambient awareness는 loot chase 중에도 `_scan_alert`를 걸 수 있음. 비회복성 opportunistic loot만 완전 감지된 적에게 중단될 수 있고, recovery/combat-loot는 기존 damage/gunshot override가 우선.
- **수정 영향**: loot 추적, RECOVER, perception, gunshot/footstep awareness를 함께 확인. Telemetry hook 이름과 JSON schema를 임의로 추가하지 않음.

### `src/entities/bot/BotDoctrine.gd`
- **읽는 파일**: 직접 scene 참조 없음 — `Bot.gd`가 넘긴 context/profile만 사용.
- **공개 API**: `build_profile()`, `choose_combat_plan()`, `choose_supply_decision()`, `explain_profile()`.
- **수정 영향**: plan 문자열을 변경하면 `Bot.gd` 실행부, `Telemetry.gd`, `tools/analyze_results.py`를 함께 확인.

### `src/entities/bot/BotVisualKit.gd`
- **읽는 파일**: `BotMarkerFormatter.gd` cosmetic catalog id mapping. 직접 scene 참조 없음 — `BotVisualSkinController.gd`가 `apply_skin(bot, archetype_id, seed, asset_catalog)` 호출.
- **소유 노드**: 각 Bot 하위 `ArchetypeSkin` Node3D와 primitive MeshInstance3D 파츠.
- **catalog id**: `BotMarkerFormatter.gd`의 bot cosmetic id mapping을 재사용해 marker tint와 skin tint id drift를 피한다.
- **수정 영향**: material override를 몸통 MeshInstance3D에 직접 적용하면 headless 종료 오류가 날 수 있으므로 얼굴/머리 파츠 중심으로 유지.

### `src/entities/pickup/Pickup.gd`
- **현재 역할**: Pickup entity runtime owner. v1.11.29 기준 307줄.
- **호출 대상**: `collector.receive_weapon(wstats)` / `collector.receive_ammo(type, amount)` — `has_method()` duck-typed, Player·Bot 동시 지원
- **표시 조건**: 플레이어의 `Entity.can_sense_item()`을 통과한 경우에만 pickup node가 표시됨. Label LOD/focus 값은 `PickupPresentation.gd`가 제공하고, 현재 상호작용 후보 focus는 `Player.gd`가 `set_focused()`로 전달.
- **presentation 경계**: `PickupPresentation.gd` owns base colors, glow/light tuning, label LOD distances/scales/colors, visibility refresh interval, and icon plane size/height values.
- **icon 경계**: `PickupIconResolver.gd` owns icon ids, texture cache, AssetCatalog path lookup, ResourceLoader texture loading, and image-file fallback loading.
- **의도적으로 소유**: runtime node creation, focus/LOS updates, cluster-label comparison, AssetCatalog scene lookup, icon decal placement/material setup, item collection side effects, Telemetry pickup logging, and debug logging.
- **closure note**: Further Pickup extraction should require an item-effect boundary because collection touches Player/Bot inventory, pressure penalties, Telemetry, and debug logging.

### `src/entities/pickup/PickupPresentation.gd`
- **읽는 파일**: `ItemData.gd` enum/type/rarity fields. 직접 scene lookup 없음.
- **호출자**: `Pickup.gd` visual update, label refresh, cluster label check, and icon decal placement paths.
- **역할**: pickup base colors, glow/light parameters, label LOD range, cluster radius, label focused/normal scale, label colors, visibility refresh interval, and icon plane size/height values.
- **소유하지 않는 것**: runtime nodes, focus state, LOS sensing, AssetCatalog icon loading, item collection effects, Telemetry, debug logging.
- **수정 영향**: pickup readability values를 바꾸면 `Pickup.gd` label/focus/icon paths, `ItemDisplayFormatter.gd`, selected assets, and visual/headless checks를 함께 확인.

### `src/entities/pickup/PickupIconResolver.gd`
- **읽는 파일**: `ItemData.gd` enum/type/rarity fields and caller-provided AssetCatalog-compatible object. 직접 scene lookup 없음.
- **호출자**: `Pickup.gd` `_update_icon_decal()`.
- **역할**: pickup icon id mapping, per-pickup texture cache, AssetCatalog icon path lookup, ResourceLoader texture loading, and image-file fallback loading.
- **소유하지 않는 것**: icon decal node creation, material setup, scene-tree AssetCatalog lookup, pickup collection effects, Telemetry, debug logging.
- **수정 영향**: pickup icon id나 loading behavior를 바꾸면 `Pickup.gd` icon decal path, `data/asset_catalog.json`, selected icon assets, and visual/headless checks를 함께 확인.

### `src/ui/HelpPanelBuilder.gd`
- **읽는 파일**: `HelpCatalog.gd` section/row data, `MenuIconFactory.gd` procedural icons.
- **호출자**: `Main.gd` `_setup_secondary_panels()`.
- **소유 범위**: How to Play scroll content 생성. Help panel 표시 전환과 close button 연결은 `Main.gd`/`MenuController`, 버튼 스타일은 `MenuVisualBuilder`가 유지.

### `src/ui/RecordsPanelBuilder.gd`
- **읽는 파일**: `DifficultyCatalog.gd`, `MenuIconFactory.gd`, `Telemetry.get_history_for_difficulty()`.
- **호출자**: `Main.gd` `_on_records_pressed()` / `_populate_records_list()`.
- **소유 범위**: Records 난이도 탭, CLEAR ALL 버튼, 기록 행 렌더링. 선택된 난이도 상태와 clear/diff 콜백은 `Main.gd`가 유지.

### `src/maps/WorldBuilder.gd`
- **읽는 파일**: `MapSpec.gd`가 파싱한 POI/obstacles/routes.
- **공개 API**: `generate_world(spec)`, `get_minimap_features()`.
- **수정 영향**: 실제 생성 위치/회전/jitter/스케일을 바꾸면 미니맵 footprint 기록도 같은 기준으로 수정해야 함.

### `src/ui/Minimap.gd`
- **읽는 파일**: `MapSpec`의 POI, `WorldBuilder.get_minimap_features()`의 실제 생성 footprint, `Main.zone`/supply/player 상태.
- **렌더 순서**: 낮은 layer(부쉬) → 높은 layer(장애물) 순서로 그려 하늘에서 본 최종 덮임 형태를 표현.
- **수정 영향**: 새 장애물 타입을 추가하면 `WorldBuilder` footprint 기록과 `Minimap._feature_colors()`를 함께 확인.

---

## 변경 → 연쇄 영향

| 변경 대상 | 직접 파일 | 반드시 확인할 파일 |
|---|---|---|
| `ZoneController` 공개 API | `ZoneController.gd` | `Main.gd`, `Bot.gd`, `Player.gd`, `Minimap.gd` |
| `WeaponSlotManager` 공개 API | `WeaponSlotManager.gd` | `Player.gd` (시그널 연결), `Main.gd` (`player_ref.slots.*`) |
| Weapon slot tuning values | `src/core/WeaponSlotTuning.gd` | `WeaponSlotManager.gd`, Player HUD ammo text, pressure ammo effects, simulations |
| `MissionTracker` 훅 추가/변경 | `MissionTracker.gd` | `Main.gd` (훅 호출 추가), 존 관련이면 `ZoneController.gd` |
| `Entity.take_damage()` 시그니처 | `Entity.gd` | `Bot.gd`, `Player.gd`, `ZoneController.tick_damage()` |
| `StatsData` 필드 추가 | `StatsData.gd` | `WeaponSlotManager.gd`, `Bot.gd`, `Player.gd` |
| 난이도 파라미터 | `data/game_config.json`, `GameConfig.gd` | `Main.gd` `_get_difficulty_params()`, `Bot.gd` configure path |
| Artifact modifier 값/설명 | `ArtifactCatalog.gd` | `Main.gd` artifact card/apply flow, `Player.gd` combat/heal modifier reads |
| Pickup/HUD item text | `ItemDisplayFormatter.gd` | `Pickup.gd`, `Player.gd`, `ItemData.gd`, `WeaponSlotManager.gd` |
| Pickup presentation values | `src/entities/pickup/PickupPresentation.gd` | `Pickup.gd` label/focus/icon paths, selected assets, visual checks |
| Pickup icon catalog loading | `src/entities/pickup/PickupIconResolver.gd` | `Pickup.gd` icon decal path, `data/asset_catalog.json`, selected icon assets |
| Player HUD layout/style | `src/ui/player/PlayerHudBuilder.gd` | `Player.gd` HUD references, mission/pressure label updates, status updates, slot refresh, flash tween, kill feed population, zone warning alpha update |
| Player slot display state | `src/ui/player/PlayerSlotHudRenderer.gd` | `Player.gd` slot arrays, `PlayerWeaponIconResolver.gd`, reload-progress HUD override, `WeaponSlotManager.gd`, `ItemDisplayFormatter.gd` |
| Player weapon HUD icons | `src/ui/player/PlayerWeaponIconResolver.gd` | `Player.gd` asset catalog pass-through, `data/asset_catalog.json`, selected icon assets, `PlayerSlotHudRenderer.gd` |
| Player tuning constants | `src/entities/player/PlayerTuning.gd` | `Player.gd` movement/combat/heal/occluder algorithms, simulations |
| Player occluder fade behavior | `src/entities/player/PlayerOccluderFader.gd` | `Player.gd` camera lookup, `PlayerTuning.gd`, occluder group tagging/materials |
| Bot tuning constants | `src/entities/bot/BotTuning.gd` | `Bot.gd` state machine/combat/perception paths, `BotDoctrine.gd`, simulations |
| Bot debug marker layout | `src/entities/bot/BotDebugLabelBuilder.gd` | `Bot.gd` marker visibility paths and visual checks |
| Bot marker content mapping | `src/entities/bot/BotMarkerFormatter.gd` | `Bot.gd` state/archetype marker updates, `BotDoctrine.gd`, cosmetic catalog tint ids |
| Bot visual skin lifecycle | `src/entities/bot/BotVisualSkinController.gd` | `Bot.gd` crouch/death visual sync, `BotVisualKit.gd`, visual checks |
| Hell 정전/포격 이벤트 | `data/game_config.json` `hell` + `HellTuning.gd` + `src/systems/hell/HellEventController.gd` | `Main.gd` start/tick wiring, `Player.gd` SCARCITY reads, `Telemetry.gd`, Hell simulations |
| Difficulty selector UI | `DifficultySelectorBuilder.gd` | `Main.gd` difficulty callbacks, `DifficultyCatalog.gd` labels/descriptions |
| Zone/supply world presentation | `WorldPresentationBuilder.gd` | `Main.gd` zone/supply wiring, `ZoneController.gd`, `SupplyDropController.gd`, `LootSpawnDirector.gd` |
| Settings modal UI | `SettingsPanelBuilder.gd` | `Main.gd` settings callbacks, `user://settings.cfg` key compatibility |
| Result panel UI | `ResultPanelBuilder.gd` | `Main.gd` finalization/score data, Telemetry score fields |
| Pause overlay UI | `PausePanelBuilder.gd` | `Main.gd` pause state/input callbacks, `MenuVisualBuilder.gd` shared button style |
| Artifact selection UI | `ArtifactSelectionPanelBuilder.gd` | `ArtifactCatalog.gd`, `Main.gd` pending/apply flow, `Player.gd` `apply_artifact()` |
| Hell announcement UI | `HellAnnouncementBuilder.gd` | `Main.gd` Hell modifier/dismiss wiring, `HellEventController.gd` modifier description |
| Event text overlay | `EventTextBuilder.gd` | `Main.gd` event signal wiring, `HellEventController.gd` event text requests |
| Menu panel routing | `MenuController.gd` | `Main.gd` callbacks, scene panel names, Records/Help close buttons |
| Menu visual style | `MenuVisualBuilder.gd` | `Main.gd` target node wiring, `MenuController.gd`, `HelpPanelBuilder.gd`, `RecordsPanelBuilder.gd` |
| Match start initialization | `MatchBootstrap.gd` | `Main.gd` state ownership, `ZoneController.gd`, `MissionTracker.gd`, Hell modifier enum compatibility |
| Match/zone tuning config 또는 CLI alias | `MatchTuning.gd` | `Main.gd` apply path, `data/game_config.json`, `tools/simulate_matches.py`, TESTING/문서 예시 |
| Main runtime tuning | `MatchRuntimeTuning.gd`, `data/game_config.json` `runtime` | `Main.gd` spawn/navigation/supply/zone-stage loot paths, `GameConfig.gd`, simulations |
| Bot count/archetype ratio | `BotSpawnPlanner.gd` | `Main.gd` spawn wiring, `Bot.gd` archetype enum, `BotDoctrine.gd`, Telemetry archetype reports |
| Loot/supply pickup creation | `src/systems/loot/LootSpawnDirector.gd` | `Main.gd` supply/loot state, `LootSpawner.gd`, `SupplyDropController.gd`, `Pickup.gd`, `ItemData.gd`, Minimap supply display |
| Mission/pressure descriptor | `src/systems/mission/MissionCatalog.gd` | `MissionTracker.gd` condition/evaluation support, `PressureEffectCatalog.gd`, `PressureEffectApplier.gd`, `Main.gd` pressure trigger flow |
| Mission badge persistence | `src/systems/mission/MissionBadgeStore.gd` | `MissionTracker.gd` wrappers, `Main.gd` result badge award flow, user save compatibility |
| Bonus mission evaluation | `src/systems/mission/MissionEvaluator.gd` | `MissionTracker.gd` evaluation context, `MissionCatalog.gd`, `MissionHudFormatter.gd`, `Main.gd` result mission flow |
| Pressure condition evaluation | `src/systems/mission/PressureConditionEvaluator.gd` | `MissionTracker.gd` pressure counter snapshot/hooks, `MissionCatalog.gd`, `MissionHudFormatter.gd`, pressure simulations |
| Pressure HUD text | `src/systems/mission/MissionHudFormatter.gd` | `MissionTracker.gd` pressure counter snapshot, `PressureEffectCatalog.gd`, `Player.gd` HUD label behavior |
| Bonus mission HUD text | `src/systems/mission/MissionHudFormatter.gd` | `MissionTracker.gd` bonus HUD context, `MissionData.gd`, `Player.gd` mission HUD label behavior |
| Pressure reward/penalty effect | `PressureEffectCatalog.gd` + `PressureEffectApplier.gd` | `MissionCatalog.gd` descriptor pools, `MissionTracker.gd` HUD text, `Main.gd` returned state updates, `Player.gd`, `ZoneController.gd`, `Bot.gd` |
| Bot Doctrine/아키타입 보정 | `BotDoctrine.gd` | `Bot.gd` 실행부, `Telemetry.gd` (doctrine/전술 카운트), `Main.gd` (`configure_ai`) |
| Bot 아키타입 외형 | `BotVisualKit.gd` | `Bot.gd` (`configure_ai` 후 apply), headless 종료 로그 |
| `MapSpec` 구조 | `MapSpec.gd` | `WorldBuilder.gd`, `Minimap.gd`, `Main.gd` autostart world generation |
| Death drop 표시 이름/색상 | `DropDisplayCatalog.gd` | `Player.gd`, `Bot.gd`, `Pickup.gd` label output |
| `Pickup` 인터페이스 | `Pickup.gd` | `Player.gd` (래퍼 메서드), `Bot.gd` (드롭 로직) |
| How to Play 행 구조 | `HelpCatalog.gd` | `HelpPanelBuilder.gd`, `Main.gd` Help panel wiring |
| Records 행 구조 | `RecordsPanelBuilder.gd` | `Telemetry.gd` match history fields, `Main.gd` Records callbacks |
| 새 pressure effect 추가 | `PressureEffectCatalog.gd` | `MissionCatalog.gd` descriptor pools, `PressureEffectApplier.gd` match 케이스, 필요 시 `Main.gd` state update 반영 |
| 새 `PressureCondition` 추가 | `MissionTracker.gd` enum + `PressureConditionEvaluator.gd` | `MissionCatalog.gd` condition mapping, `MissionHudFormatter.gd` progress HUD, MissionTracker counter hooks |
