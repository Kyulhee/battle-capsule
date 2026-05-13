# Impact Map — 배틀캡슐

> **정확성 규칙**: 이 파일이 실제 코드와 다를 경우 즉시 사용자에게 보고하고 수정하라.  
> 기준 버전: v1.7.3 / 마지막 검증: 2026-05-08

---

## 모듈 소유 관계

| 모듈 | 소유 변수 | 소유자 파일 | 타입 |
|---|---|---|---|
| ZoneController | `var zone` | `Main.gd` | RefCounted |
| WeaponSlotManager | `var slots` | `Player.gd` | RefCounted |
| MissionTracker | `var mission_tracker` | `Main.gd` | RefCounted |
| DropDisplayCatalog | death-drop display names/colors | `Player.gd`, `Bot.gd` | static catalog |

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
| Bot Doctrine/아키타입 보정 | `BotDoctrine.gd` | `Bot.gd` 실행부, `Telemetry.gd` (doctrine/전술 카운트), `Main.gd` (`configure_ai`) |
| Bot 아키타입 외형 | `BotVisualKit.gd` | `Bot.gd` (`configure_ai` 후 apply), headless 종료 로그 |
| `MapSpec` 구조 | `MapSpec.gd` | `WorldBuilder.gd`, `Minimap.gd`, `Main.gd` autostart world generation |
| Death drop 표시 이름/색상 | `DropDisplayCatalog.gd` | `Player.gd`, `Bot.gd`, `Pickup.gd` label output |
| `Pickup` 인터페이스 | `Pickup.gd` | `Player.gd` (래퍼 메서드), `Bot.gd` (드롭 로직) |
| 새 `PressureEffect` 추가 | `MissionTracker.gd` (enum) | `Main._apply_pressure_effects()` (match 케이스 추가) |
| 새 `PressureCondition` 추가 | `MissionTracker.gd` (enum + `_eval_single_condition`) | `MissionTracker.filter_feasible()` (필터 케이스 추가) |
