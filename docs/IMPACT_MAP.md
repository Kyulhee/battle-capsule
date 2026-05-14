# Impact Map — 배틀캡슐

> **정확성 규칙**: 이 파일이 실제 코드와 다를 경우 즉시 사용자에게 보고하고 수정하라.  
> 기준 버전: v1.10-dev / 마지막 검증: 2026-05-14

---

## 모듈 소유 관계

| 모듈 | 소유 변수 | 소유자 파일 | 타입 |
|---|---|---|---|
| ZoneController | `var zone` | `Main.gd` | RefCounted |
| WeaponSlotManager | `var slots` | `Player.gd` | RefCounted |
| MissionTracker | `var mission_tracker` | `Main.gd` | RefCounted |
| ArtifactCatalog | starting artifact specs/descriptions | `Main.gd`, `Player.gd` | static catalog |
| ItemDisplayFormatter | pickup/HUD item text | `Pickup.gd`, `Player.gd` | static formatter |
| DropDisplayCatalog | death-drop display names/colors | `Player.gd`, `Bot.gd` | static catalog |
| HellEventController | Hell blackout/bombardment runtime | `Main.gd` | RefCounted runtime controller |
| DifficultySelectorBuilder | difficulty selector/tooltip UI | `Main.gd` | static UI builder |
| SettingsPanelBuilder | settings modal UI | `Main.gd` | static UI builder |
| ResultPanelBuilder | result panel layout/population | `Main.gd` | static UI builder |
| ArtifactSelectionPanelBuilder | artifact selection modal UI | `Main.gd` | static UI builder |
| HellAnnouncementBuilder | Hell announcement modal UI | `Main.gd` | static UI builder |
| MenuController | panel routing and menu button wiring | `Main.gd` | RefCounted UI controller |
| MatchBootstrap | match-start initialization helpers | `Main.gd` | static system helper |
| MatchTuning | match/zone tuning interpretation | `Main.gd` | static system helper |

---

## 파일별 양방향 참조

### `src/core/ZoneController.gd`
- **읽는 파일**: `Bot.gd` (`main.zone.current_center/radius/stage`), `Minimap.gd` (`main.zone.current/next_center/radius`), `Player.gd` (`main.zone.shrinking`, `main.zone.timer`, `main.zone.is_outside()`)
- **쓰는 파일**: `Main.gd` 만 (`zone.timer +=`, `zone.wait_time`, `zone.shrink_time`)
- **시그널 수신처**: `Main.gd` — `stage_advanced` → `_on_zone_stage_changed()`, `zone_warning` → `_on_zone_warning()`
- **내부에서 호출하는 외부 API**: `entity.take_damage()` (duck-typed), `mission_tracker.on_player_zone_tick()` / `on_pressure_zone_tick()` (duck-typed)

### `src/core/WeaponSlotManager.gd`
- **읽는 파일**: `Player.gd` (소유, 모든 접근), `Main.gd` (`player_ref.slots.fill_all_ammo()` / `clear_all_ammo()` / `clear_active_ammo()`)
- **쓰는 파일**: `Player.gd` 만
- **시그널 수신처**: `Player.gd` — `slot_switched` → `_on_slot_switched()`, `reload_started` → `Sfx.play("reload")`, `reload_done` → `_on_reload_done()`, `inventory_changed` → `_refresh_slot_hud()`, `gun_count_changed` → `_on_gun_count_changed()`
- **외부 진입점**: `Pickup.gd` → `Player.receive_weapon()` / `receive_ammo()` 래퍼 → `slots.*()` (Pickup은 WeaponSlotManager를 직접 참조하지 않음)

### `src/core/MissionTracker.gd`
- **읽는 파일**: `Main.gd` (소유), `ZoneController.gd` (`tick_damage` 내 duck-typed)
- **쓰는 파일**: `Main.gd` 만
- **시그널**: 없음 — `tick_pressure(delta, num_detecting)` 반환값 `"success"` / `"fail"` / `""` 을 Main이 폴링
- **훅 호출자**: `Main.gd` (`on_pressure_kill`, `on_pressure_damage`, `on_weapon_slot_used` 등), `ZoneController.gd` (`on_player_zone_tick`, `on_pressure_zone_tick`)

### `src/core/HellEventController.gd`
- **읽는 파일**: 직접 scene lookup 없음. `Main.gd`가 `game_config`, host, overlay parent, Telemetry를 주입.
- **호출자**: `Main.gd` `start_game()` / `_process()`에서 `configure()`, `start_match()`, `tick()` 호출.
- **역할**: Hell blackout/bombardment timer, warning disc creation, overlay flash, bomb damage application, and `Telemetry.log_hell_event()` delegation.
- **소유하지 않는 것**: 난이도 선택, Hell modifier enum compatibility, announcement panel, match-global state, Telemetry schema.
- **수정 영향**: Hell tuning constants or event names 변경 시 `Main.gd` Hell wiring, `Player.gd` SCARCITY read, `Telemetry.gd` event aggregation, `data/game_config.json` Hell timer keys를 함께 확인.

### `src/entities/Entity.gd` (base)
- **시그널 수신처**:
  - `died` → `Main.gd` (`_on_player_died`, `_on_bot_died`)
  - `health_changed` / `shield_changed` → `Player.gd` 자기 연결 (`_on_health_changed`, `_on_shield_changed`)
  - `health_changed` / `shield_changed` → `Main.gd` 에서도 직접 `.emit()` 호출 (압박 미션 효과 적용 시)
- **인식 API**: `_can_i_see(target)`는 actor perception, `can_sense_item(world_pos)`는 아이템 표시/플레이어 상호작용/봇 루팅 후보 필터에 공통 사용.

### `src/entities/bot/Bot.gd`
- **Main 참조 방법**: `get_tree().get_root().get_node("Main")` 런타임 조회 — 읽기 전용
- **읽는 Main 필드**: `main.zone.current_center`, `main.zone.current_radius`, `main.zone.stage`, `main.alive_count`
- **전술 계층**: State/movement/firing 실행은 `Bot.gd`, 전술 선택과 profile merge는 `BotDoctrine.gd`.
- **Death drop 표시**: `DropDisplayCatalog`에서 무기/탄약/회복 아이템 표시 이름과 death-drop 색상을 가져옴.

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

### `src/ui/DifficultySelectorBuilder.gd`
- **읽는 파일**: `DifficultyCatalog.gd`.
- **호출자**: `Main.gd` main menu setup and difficulty state refresh.
- **역할**: 난이도 버튼, hover tooltip, pressure opt-in checkbox UI, difficulty highlight 갱신.
- **소유하지 않는 것**: 실제 `difficulty`, `pressure_opt_in_hard`, match start behavior.

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

### `src/ui/panels/ArtifactSelectionPanelBuilder.gd`
- **읽는 파일**: 직접 scene 참조 없음. 표시할 artifact catalog array를 `Main.gd`에서 받음.
- **호출자**: `Main.gd` `_show_artifact_select()`.
- **역할**: artifact selection overlay, artifact cards, skip/select buttons 생성.
- **소유하지 않는 것**: `ArtifactCatalog` lookup, `_pending_artifact`, artifact apply path, `start_game()` transition.

### `src/ui/panels/HellAnnouncementBuilder.gd`
- **읽는 파일**: 직접 scene 참조 없음. 표시할 Hell modifier description array를 `Main.gd`에서 받음.
- **호출자**: `Main.gd` `_show_hell_announcement()`.
- **역할**: Hell announcement overlay, card, penalty/event rows, start button 생성.
- **소유하지 않는 것**: Hell modifier selection, pause/unpause, active panel lifetime, dismiss fade, Hell runtime controller.

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

### `src/entities/bot/Bot.gd`
- **목표 이동**: `is_targeting_loot` CHASE는 `_nav_move_toward(..., false)`로 pickup 방향 이동을 유지하고 `_update_objective_scan()`으로 시야 회전을 따로 갱신.
- **감지 연결**: footstep/ambient awareness는 loot chase 중에도 `_scan_alert`를 걸 수 있음. 비회복성 opportunistic loot만 완전 감지된 적에게 중단될 수 있고, recovery/combat-loot는 기존 damage/gunshot override가 우선.
- **수정 영향**: loot 추적, RECOVER, perception, gunshot/footstep awareness를 함께 확인. Telemetry hook 이름과 JSON schema를 임의로 추가하지 않음.

### `src/entities/bot/BotDoctrine.gd`
- **읽는 파일**: 직접 scene 참조 없음 — `Bot.gd`가 넘긴 context/profile만 사용.
- **공개 API**: `build_profile()`, `choose_combat_plan()`, `choose_supply_decision()`, `explain_profile()`.
- **수정 영향**: plan 문자열을 변경하면 `Bot.gd` 실행부, `Telemetry.gd`, `tools/analyze_results.py`를 함께 확인.

### `src/entities/bot/BotVisualKit.gd`
- **읽는 파일**: 직접 scene 참조 없음 — `Bot.gd`가 `apply_skin(bot, archetype_id, seed)` 호출.
- **소유 노드**: 각 Bot 하위 `ArchetypeSkin` Node3D와 primitive MeshInstance3D 파츠.
- **수정 영향**: material override를 몸통 MeshInstance3D에 직접 적용하면 headless 종료 오류가 날 수 있으므로 얼굴/머리 파츠 중심으로 유지.

### `src/entities/pickup/Pickup.gd`
- **호출 대상**: `collector.receive_weapon(wstats)` / `collector.receive_ammo(type, amount)` — `has_method()` duck-typed, Player·Bot 동시 지원
- **표시 조건**: 플레이어의 `Entity.can_sense_item()`을 통과한 경우에만 pickup node가 표시됨. Label은 `Pickup` 내부 LOD/focus 정책을 따르고, 현재 상호작용 후보 focus는 `Player.gd`가 `set_focused()`로 전달.

### `src/ui/HelpPanelBuilder.gd`
- **읽는 파일**: `HelpCatalog.gd` section/row data, `MenuIconFactory.gd` procedural icons.
- **호출자**: `Main.gd` `_setup_secondary_panels()`.
- **소유 범위**: How to Play scroll content 생성. Help panel 표시 전환, close button 연결, 버튼 스타일은 `Main.gd`가 유지.

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
| `MissionTracker` 훅 추가/변경 | `MissionTracker.gd` | `Main.gd` (훅 호출 추가), 존 관련이면 `ZoneController.gd` |
| `Entity.take_damage()` 시그니처 | `Entity.gd` | `Bot.gd`, `Player.gd`, `ZoneController.tick_damage()` |
| `StatsData` 필드 추가 | `StatsData.gd` | `WeaponSlotManager.gd`, `Bot.gd`, `Player.gd` |
| `Main.DIFFICULTY_PARAMS` | `Main.gd` | `Bot.gd` (스폰 시 1회 읽힘, 이후 변경 불가) |
| Artifact modifier 값/설명 | `ArtifactCatalog.gd` | `Main.gd` artifact card/apply flow, `Player.gd` combat/heal modifier reads |
| Pickup/HUD item text | `ItemDisplayFormatter.gd` | `Pickup.gd`, `Player.gd`, `ItemData.gd`, `WeaponSlotManager.gd` |
| Hell 정전/포격 이벤트 | `HellEventController.gd` | `Main.gd` start/tick wiring, `Player.gd` SCARCITY reads, `Telemetry.gd`, `data/game_config.json` Hell keys |
| Difficulty selector UI | `DifficultySelectorBuilder.gd` | `Main.gd` difficulty callbacks, `DifficultyCatalog.gd` labels/descriptions |
| Settings modal UI | `SettingsPanelBuilder.gd` | `Main.gd` settings callbacks, `user://settings.cfg` key compatibility |
| Result panel UI | `ResultPanelBuilder.gd` | `Main.gd` finalization/score data, Telemetry score fields |
| Artifact selection UI | `ArtifactSelectionPanelBuilder.gd` | `ArtifactCatalog.gd`, `Main.gd` pending/apply flow, `Player.gd` `apply_artifact()` |
| Hell announcement UI | `HellAnnouncementBuilder.gd` | `Main.gd` Hell modifier/dismiss wiring, `HellEventController.gd` modifier description |
| Menu panel routing | `MenuController.gd` | `Main.gd` callbacks, scene panel names, Records/Help close buttons |
| Match start initialization | `MatchBootstrap.gd` | `Main.gd` state ownership, `ZoneController.gd`, `MissionTracker.gd`, Hell modifier enum compatibility |
| Match/zone tuning config 또는 CLI alias | `MatchTuning.gd` | `Main.gd` apply path, `data/game_config.json`, `tools/simulate_matches.py`, TESTING/문서 예시 |
| Bot Doctrine/아키타입 보정 | `BotDoctrine.gd` | `Bot.gd` 실행부, `Telemetry.gd` (doctrine/전술 카운트), `Main.gd` (`configure_ai`) |
| Bot 아키타입 외형 | `BotVisualKit.gd` | `Bot.gd` (`configure_ai` 후 apply), headless 종료 로그 |
| `MapSpec` 구조 | `MapSpec.gd` | `WorldBuilder.gd`, `Minimap.gd`, `Main.gd` autostart world generation |
| Death drop 표시 이름/색상 | `DropDisplayCatalog.gd` | `Player.gd`, `Bot.gd`, `Pickup.gd` label output |
| `Pickup` 인터페이스 | `Pickup.gd` | `Player.gd` (래퍼 메서드), `Bot.gd` (드롭 로직) |
| How to Play 행 구조 | `HelpCatalog.gd` | `HelpPanelBuilder.gd`, `Main.gd` Help panel wiring |
| Records 행 구조 | `RecordsPanelBuilder.gd` | `Telemetry.gd` match history fields, `Main.gd` Records callbacks |
| 새 `PressureEffect` 추가 | `MissionTracker.gd` (enum) | `Main._apply_pressure_effects()` (match 케이스 추가) |
| 새 `PressureCondition` 추가 | `MissionTracker.gd` (enum + `_eval_single_condition`) | `MissionTracker.filter_feasible()` (필터 케이스 추가) |
