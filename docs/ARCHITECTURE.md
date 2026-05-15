# 배틀캡슐 아키텍처 보고서 (v1.11-dev)

> 최종 업데이트: 2026-05-15
> 이 문서는 v1.11-dev 확장 기반(config/debug/asset/item resource catalog/LootSpawner/SupplyDropController/catalog/UI/world presentation builders/systems match/Hell helpers 경계) 기준이다.
> `Main.gd`는 v1.10.20 기준 1097줄이며, match-global state/wiring orchestrator로 남긴다.

---

## 1. 전체 레이어 구조

```
┌─────────────────────────────────────────────────────┐
│  Orchestrator        Main.gd                        │
│  (Node3D, 씬 루트)   게임 루프 · 스폰 · UI · 이벤트 연결  │
├──────────────────────┬──────────────────────────────┤
│  Entity Layer        │  UI / World                  │
│  Entity.gd (base)    │  Minimap.gd                  │
│  Player.gd           │  WorldBuilder.gd             │
│  Bot.gd              │  Pickup.gd                   │
│  BotDoctrine.gd      │                              │
│                      │  MenuIconFactory.gd          │
│                      │  MenuVisualBuilder.gd        │
│                      │  WorldPresentationBuilder    │
│                      │  DifficultySelectorBuilder   │
│                      │  HelpPanelBuilder.gd         │
│                      │  RecordsPanelBuilder.gd      │
│                      │  SettingsPanelBuilder.gd     │
│                      │  panels/ResultPanelBuilder   │
│                      │  panels/PausePanelBuilder    │
│                      │  panels/ArtifactSelection     │
│                      │  panels/HellAnnouncement      │
│                      │  overlays/EventTextBuilder   │
│                      │  menu/MenuController          │
├──────────────────────┴──────────────────────────────┤
│  Core Modules / Runtime Controllers                  │
│  ZoneController · WeaponSlotManager · MissionTracker│
│  LootSpawner · SupplyDropController                │
│  GameConfig · AssetCatalog · Telemetry · Sfx        │
│  Systems           match bootstrap/tuning/spawn/effects│
│                    hell runtime controller          │
├─────────────────────────────────────────────────────┤
│  Data / Config  (Resource/JSON — 순수 데이터)          │
│  StatsData · ItemData · MissionData · MapSpec        │
│  ArtifactCatalog · DifficultyCatalog · HelpCatalog   │
│  game_config.json · asset_catalog.json               │
└─────────────────────────────────────────────────────┘
```

---

## 2. 모듈 상세

### 2-A. Data / Config (최하위 — 의존성 없음)

| 파일 | 역할 | 접근 패턴 |
|---|---|---|
| `src/core/StatsData.gd` | 무기·캐릭터 스탯 Resource | `@export var stats: StatsData`로 인스펙터 연결 |
| `src/core/ItemData.gd` | 아이템 정의 (이름, 타입, 수량) | `src/items/*.tres` 파일로 인스턴스화 |
| `src/core/MissionData.gd` | 보너스 미션 스펙 Resource | MissionTracker가 내부에서 로드 |
| `src/core/MapSpec.gd` | 맵 POI·장애물·월드 크기 정의 | WorldBuilder, Minimap이 읽기 전용으로 참조 |
| `data/game_config.json` | 매치 수치, 난이도 파라미터, Hell 타이머 | `GameConfig.gd`가 로드, Main/시스템 컨트롤러가 적용 |
| `data/asset_catalog.json` | audio/icon/prop/cosmetic ID와 fallback | `AssetCatalog.gd`가 로드, Sfx/UI/월드가 점진 참조 |
| `src/core/ItemResourceCatalog.gd` | 기본 loot item templates, extra consumables, pickup scene, supply railgun 리소스 | Main이 런타임 참조를 로드하고 loot/supply state wiring은 유지 |
| `src/core/ArtifactCatalog.gd` | 시작 아티팩트 선택지, modifier 정의, modifier 기반 설명 생성 | Main 메뉴가 읽고 선택 결과를 Player modifier로 적용 |
| `src/core/ItemDisplayFormatter.gd` | pickup detail 및 HUD ammo 문자열 포맷 | Pickup과 Player HUD가 실제 item/slot 값을 넘겨 사용 |
| `src/core/DifficultyCatalog.gd` | 난이도 label/description/color 정의 | Main 메뉴와 Records가 같은 UI 데이터를 참조 |
| `src/core/HelpCatalog.gd` | How to Play 섹션/행 데이터 정의 | `HelpPanelBuilder.gd`가 읽어 key/icon/desc 행으로 렌더 |
| `src/core/LootSpawner.gd` | POI 기반 루트 hotspot/위치/개수 계산 | Main이 Pickup 생성은 유지하고 계산만 위임 |
| `src/core/SupplyDropController.gd` | 보급 캡슐 위치·타이머·클러스터 계산 | Main이 미니맵 상태와 실제 노드 생성은 유지 |
| `src/systems/match/MatchTuning.gd` | GameConfig/CLI match-zone tuning 해석과 clamp | Main이 exported 상태를 소유하고 반환된 값만 적용 |
| `src/systems/match/MatchRuntimeTuning.gd` | Main-owned spawn/navigation/stage-loot/supply-fallback runtime tuning 해석과 clamp | `data/game_config.json` `runtime` 섹션을 읽어 Main 알고리즘에 적용 |

수정 시 주의: Resource를 공유 참조로 쓰면 인스턴스 간 오염 발생 → 런타임에서 반드시 `.duplicate()` 호출 (Player.gd:88, receive_weapon 진입부 참조).

---

### 2-B. Core Modules / Runtime Controllers

대부분의 코어 모듈은 RefCounted이며 씬트리 독립을 목표로 한다. Runtime domain controllers under `src/systems/` may create runtime visuals only through explicit references provided by `Main.gd`; they should not discover `Main.gd` or other systems through scene lookup.

#### ZoneController (`src/core/ZoneController.gd`)

```
소유 상태
  current_center / current_radius    ← 현재 자기장
  next_center / next_radius          ← 예고 자기장
  stage, timer, shrinking            ← 수축 상태 머신
  _outside_time: Dict[uid → sec]    ← 개체별 외부 체류 시간 (private)
  _damage_tick_timer                 ← 1초 간격 피해 누적

공개 API
  generate_next()                    ← 다음 원 위치 계산
  tick_lifecycle(delta)              ← 수축 상태 머신 진행
  tick_damage(delta, actors, mission_tracker, player_ref)
  is_outside(pos_2d) → bool         ← 위치 판정
  get_outside_time(uid) → float     ← 외부 체류 조회
  on_entity_died(uid)               ← 개체 사망 시 추적 정리

시그널
  stage_advanced(new_stage: int)
  zone_warning()
```

**접근 방법**: Main.gd가 `zone: ZoneController`를 소유. 외부에서 읽을 때는 `main.zone.current_center` 등 직접 필드 접근(Bot, Minimap). 쓰기는 Main만 허용.

---

#### WeaponSlotManager (`src/core/WeaponSlotManager.gd`)

```
소유 상태
  weapon_slots[0..4]     ← 슬롯별 StatsData (0=칼, null=비어있음)
  slot_ammo[0..4]        ← 슬롯별 장전 탄약
  slot_reserve[0..4]     ← 슬롯별 예비 탄약
  active_slot            ← 현재 활성 슬롯
  reload_timer / reload_total_time / reload_ammo_* ← 재장전 진행

공개 API
  receive_weapon(wstats) → bool      ← 픽업 처리 (중복 거부)
  receive_ammo(type, amount)
  consume_ammo()                     ← 발사 1회 차감
  try_auto_switch()                  ← 탄 소진 시 슬롯 탐색
  start_reload() → bool             ← 재장전 시작 (bool: 실제 시작 여부)
  tick(delta)                        ← 재장전 타이머 진행
  fill_all_ammo() / clear_all_ammo() / clear_active_ammo()
  static get_reserve_max(type) → int

시그널
  slot_switched(slot, wdata, ammo)
  reload_started / reload_done
  inventory_changed
  gun_count_changed(count)
```

**접근 방법**: Player.gd가 `slots: WeaponSlotManager`를 소유. 외부(Pickup.gd)는 Player의 래퍼 메서드(`receive_weapon`, `receive_ammo`)를 통해 접근 — WeaponSlotManager를 직접 참조하지 않음.

---

#### MissionTracker (`src/core/MissionTracker.gd`)

```
소유 상태
  active_mission          ← 현재 보너스 미션
  pressure_active         ← 압박 미션 진행 여부
  _active_pressure        ← 현재 압박 미션 딕셔너리
  pressure_deadline       ← 남은 시간
  _p_* (10개 카운터)      ← 압박 미션 조건별 누적값

공개 API
  static get_hard_pool() / get_hell_pool() → Array  ← 미션 풀 정의
  static filter_feasible(pool, zone_stage, bot_alive) → Array
  start_pressure(descriptor, deadline)
  tick_pressure(delta, num_detecting) → String   ← "success"/"fail"/"" 반환
  evaluate() → bool                              ← 보너스 미션 달성 판정
  on_pressure_kill / on_pressure_damage / on_pressure_heal_used 등
  get_hud_text() / get_pressure_hud_text()
```

**접근 방법**: Main.gd가 `mission_tracker: MissionTracker`로 소유. 이벤트 훅은 Main이 해당 게임 이벤트 발생 시 직접 호출. ZoneController가 `tick_damage` 안에서 duck-typed으로 `on_player_zone_tick` 호출.

---

#### HellEventController (`src/systems/hell/HellEventController.gd`)

```
소유 상태
  modifier                    ← 이번 Hell match modifier
  blackout/bomb timers         ← Hell 이벤트 주기
  overlay reference            ← 정전/착탄 flash용 ColorRect

공개 API
  configure(game_config)
  start_match(host, modifier, overlay_parent, telemetry)
  tick(delta, match_timer, zone_controller)
  clear()
  static modifier_description(modifier) → Array

시그널
  event_text_requested(message, color)
```

**접근 방법**: Main.gd가 `hell_events`를 소유하고 `start_game()`에서 modifier, overlay parent, Telemetry를 넘긴다. `Main.gd`는 Hell modifier 선택과 announcement panel을 유지하고, 실제 blackout/bombardment runtime은 컨트롤러가 맡는다.

v1.11.1 기준 `HellEventController`는 `core`에서 `systems/hell`로 이동했다. 이 이동은 path ownership 정리이며, tuning data 분리는 v1.11.2에서 다룬다.

---

#### Autoloads (전역 싱글톤)

| 이름 | 파일 | 사용법 |
|---|---|---|
| `Sfx` | `src/core/SoundManager.gd` | `Sfx.play("reload")` — fire-and-forget |
| `Telemetry` | `src/core/Telemetry.gd` | `Telemetry.log_kill(...)` — 매치 통계 기록 |

두 Autoload는 씬트리 어느 위치에서든 `if has_node("/root/Sfx")`로 안전하게 호출 가능. 코어 모듈(RefCounted)에서는 씬트리 접근이 없으므로 Sfx를 직접 호출하지 않음 — 대신 시그널로 알리고 호출자가 처리.

---

### 2-C. Entity / UI Helper Layer

#### UI Helpers

| 파일 | 역할 | 접근 패턴 |
|---|---|---|
| `src/ui/MenuIconFactory.gd` | 메뉴/Records/Help에서 쓰는 절차적 픽셀 아이콘 생성 | Main UI 빌더가 `make_icon()` / `make_capsule_logo()` 호출 |
| `src/ui/MenuVisualBuilder.gd` | 메인/보조 메뉴 배경, 로고 배치, 공통 버튼 스타일 | Main이 대상 패널/버튼만 넘기고 builder가 presentation 생성 |
| `src/ui/WorldPresentationBuilder.gd` | zone ring mesh/material defaults, supply pillar drop visual update | Main이 zone/supply state를 유지하고 builder가 표시 노드 생성/동기화 |
| `src/ui/DifficultySelectorBuilder.gd` | 메인 메뉴 난이도 버튼, tooltip, 압박 미션 opt-in UI 생성 | Main이 선택 상태와 callback을 넘기고 builder가 노드 생성과 highlight 갱신 |
| `src/ui/HelpPanelBuilder.gd` | How to Play scroll content 렌더링 | Main이 Help panel root를 넘기고, builder가 `HelpCatalog` + `MenuIconFactory`로 행 생성 |
| `src/ui/RecordsPanelBuilder.gd` | Records 탭/clear/history row 렌더링 | Main이 selected difficulty와 콜백을 유지하고, builder가 Telemetry history를 행으로 렌더 |
| `src/ui/SettingsPanelBuilder.gd` | Settings modal layout/control 생성 | Main이 volume/fullscreen/save 동작 callback을 유지하고, builder가 UI 생성 |
| `src/ui/panels/ResultPanelBuilder.gd` | Result panel layout/buttons/label population | Main이 match finalization, mission evaluation, score calculation을 유지하고 결과 표시 데이터만 넘김 |
| `src/ui/panels/PausePanelBuilder.gd` | Pause overlay/title/buttons 생성 | Main이 pause state와 resume/restart/menu callback을 유지 |
| `src/ui/panels/ArtifactSelectionPanelBuilder.gd` | Artifact selection overlay/cards/buttons | Main이 catalog lookup, pending artifact, panel lifetime, start transition을 유지 |
| `src/ui/panels/HellAnnouncementBuilder.gd` | Hell announcement overlay/card/rows/button | Main이 Hell modifier selection, pause/unpause, panel lifetime, dismiss fade를 유지 |
| `src/ui/overlays/EventTextBuilder.gd` | Top-center transient event text label/fade 생성 | Main/HellEventController signal path가 message/color만 넘김 |
| `src/ui/menu/MenuController.gd` | Panel visibility routing and menu button wiring | Main이 callbacks/settings/content builders를 유지하고 controller가 scene panel visibility와 button connect만 처리 |
| `src/systems/match/MatchBootstrap.gd` | Match-start object/value initialization | Main이 match-global state ownership을 유지하고 bootstrap helper가 zone/mission/pressure/Hell modifier 초기값만 반환 |
| `src/systems/match/MatchTuning.gd` | Match/zone config and CLI override interpretation | Main이 exported match fields, loot spawner wiring, and difficulty state ownership을 유지 |
| `src/systems/match/BotSpawnPlanner.gd` | Weighted bot archetype plan 생성 | Main이 Bot scene instancing, position, signal, Telemetry spawn logging을 유지 |
| `src/systems/match/LootSpawnDirector.gd` | Loot/supply pickup 생성 절차와 supply pillar 생성 | Main이 supply state, parent nodes, pickup scene, templates, Telemetry hooks를 넘김 |
| `src/systems/match/PressureEffectApplier.gd` | Pressure reward/penalty effect 실행 | Main이 player/zone/actors context를 넘기고 반환된 pressure state flags만 반영 |

```
Entity (CharacterBody3D)
  시그널: health_changed, shield_changed, died
  공통 상태: current_health, current_shield, is_dead
             is_in_bush, stealth_modifier
             perception_meters: Dict[target → 0.0~1.0]
  공통 API: take_damage(), heal(), move_toward()
       ↑
       ├── Player.gd
       │     소유: slots (WeaponSlotManager)
       │     HUD: zone_timer_label, mission_hud_label, pressure_hud_label
       │            _hp_bar, _sh_bar, slot_panels[] 등
       │     API: receive_weapon(), receive_ammo() (Pickup 래퍼)
       │          show_pressure_flash()
       │
       └── Bot.gd
             상태 머신: IDLE/CHASE/ATTACK/RECOVER/ZONE_ESCAPE/DISENGAGE
             인식: perception_meters (Entity 공통)
             개인 교전 수칙: 문자열 combat plan 실행
             전술 파라미터: _awareness_level, _flee_hp_ratio,
                           _disengage_threshold 등
```

**Bot이 Main을 참조하는 방법**: `get_tree().get_root().get_node("Main")`으로 런타임 조회. `main.zone`, `main.alive_count`, `main.zone.stage` 읽기만 함.

---

### 2-D. Orchestrator — Main.gd

Main.gd는 유일하게 모든 레이어를 연결하는 노드다.

```
소유
  zone: ZoneController
  mission_tracker: MissionTracker
  player_ref: Entity (Player 인스턴스)
  alive_count, difficulty, game_over
  heal_pickup_banned, railgun_unlimited_until_stage

담당 영역별 함수 그룹
  ─ 게임 루프    start_game(), restart_game(), _process()
  ─ 스폰        spawn_entities(), _get_safe_spawn_pos()
  ─ 자기장      handle_zone_lifecycle(), handle_damage_tick()
                _on_zone_stage_changed(), _on_zone_warning()
  ─ 전리품      _categorize_templates(), _spawn_initial_loot(), spawn_loot()
  ─ 보급 캡슐   telegraph_supply_zone(), activate_supply_zone()
  ─ 압박 미션   _trigger_pressure_mission(), _process_pressure_mission()
                _apply_pressure_effects()
  ─ 결과 화면   _end_match(), _setup_result_panel()
  ─ UI/메뉴     _setup_menu_visuals(), _setup_secondary_panels(), etc.
  ─ Hell 이벤트 modifier 선택, announcement UI, HellEventController tick wiring
```

v1.8~v1.10 분리 기준:
- v1.8은 `Main.gd` 전체 분해가 아니라 config/debug/asset catalog의 진입점을 만든다.
- 수치와 리소스 ID는 `GameConfig`/`AssetCatalog` 쪽으로 이동시키고, Main은 로드된 값을 연결하는 역할만 맡긴다.
- 메뉴 선택지처럼 순수 데이터에 가까운 목록은 `ArtifactCatalog`, `DifficultyCatalog`, `HelpCatalog`처럼 작은 catalog로 우선 분리한다.
- 첫 분리 후보는 `LootSpawner`, `SupplyDropController`, `MenuController`, `MatchBootstrap` 순서다.
- `zone`, `mission_tracker`, `player_ref`, `alive_count`, Telemetry hook의 single source는 유지한다.
- 새 gameplay tuning 숫자는 `Main.gd` 지역 상수보다 data/config/catalog/controller spec에 먼저 둔다.

v1.10.20 closure 기준:
- `Main.gd`에 남은 exported count/zone defaults는 `GameConfig`/CLI 적용 전 merge points로 유지한다.
- `current_state`, `difficulty`, pressure flags, supply minimap state, `game_over`, `match_timer`, scene callbacks, and Telemetry hook calls are intentionally Main-owned.
- Hell start-state policy, mission/artifact feasibility glue, mission context thresholds, result text formatting, and debug snapshot aggregation are deferred to v1.11 domain slices.

---

## 3. 의존성 맵

```
Main ──owns──► zone: ZoneController
     ──owns──► mission_tracker: MissionTracker
     ──owns──► hell_events: HellEventController
     ──owns──► player_ref (Player)
     ──owns──► Bot[] (alive_count 관리)
     ──reads─► Sfx, Telemetry (Autoload)

Player ──owns──► slots: WeaponSlotManager
       ──reads─► main.zone.* (필요 시 Main 조회)
       ──reads─► main.mission_tracker (간접)

Bot ──reads──► main.zone.current_center/radius/stage
    ──reads──► main.alive_count

ZoneController ──calls──► entity.take_damage()      (duck-typed)
               ──calls──► mission_tracker.on_*()    (duck-typed)

MissionTracker ──uses──► 자체 풀 정의 + filter_feasible()
               (외부 의존 없음 — RefCounted 순수)

Minimap ──reads──► main.zone.* (current/next center, radius)
        ──reads──► main.supply_pos, supply_telegraphed

Pickup ──calls──► collector.receive_weapon() / receive_ammo()
                 (has_method 검사, Player·Bot 동시 지원)
```

---

## 4. 시그널 흐름

```
ZoneController ──stage_advanced(stage)──► Main._on_zone_stage_changed()
                                             → Telemetry.set_stage()
                                             → spawn_loot()
                                             → _trigger_pressure_mission()
               ──zone_warning()─────────► Main._on_zone_warning()
                                             → Sfx.play("zone_warning")

WeaponSlotManager ──slot_switched(slot, wdata, ammo)──► Player._on_slot_switched()
                  ──reload_started()─────────────────► Player: Sfx.play("reload")
                  ──reload_done()──────────────────────► Player._on_reload_done()
                  ──inventory_changed()────────────────► Player._refresh_slot_hud()
                  ──gun_count_changed(count)───────────► Player._on_gun_count_changed()
                                                            → mission_tracker.on_weapon_slot_used()

Entity ──health_changed(cur, max)──► Player._on_health_changed() (자기 연결)
                                ──► PressureEffectApplier: pressure HP effect 적용 시 emit
       ──shield_changed(cur, max)──► Player._on_shield_changed()
       ──died──────────────────────► Main._on_player_died() / _on_bot_died()
```

---

## 5. 수정 영향 범위 — 빠른 참조

| 수정 목표 | 주요 파일 | 연쇄 영향 |
|---|---|---|
| 자기장 타이밍·피해 | `data/game_config.json` `zone` + `ZoneController.gd` | 수치 조정은 config, stage 전환 알고리즘은 controller |
| 자기장/보급 월드 표시 | `WorldPresentationBuilder.gd` + `Main.gd` zone/supply wiring | 표시 색/크기/드롭 시각화는 builder, 실제 zone/supply state는 Main/ZoneController |
| Main runtime spawn/navigation/loot fallback tuning | `data/game_config.json` `runtime` + `MatchRuntimeTuning.gd` | Main이 spawn/navigation/supply 알고리즘과 state wiring 유지 |
| 새 무기 추가 | `StatsData`, `items/*.tres`, `WeaponSlotManager.get_reload_time()` + `get_reserve_max()` | Pickup.gd 수정 불필요 |
| 압박 미션 풀 확장 | `MissionTracker.get_hard_pool()` / `get_hell_pool()` + `PressureEffectCatalog.gd` | 새 Effect 추가 시 catalog id/표시, `PressureEffectApplier.gd` 실행 케이스, 필요 시 Main state update 확인 |
| 새 PressureCondition | `MissionTracker` enum + `filter_feasible()` | `_evaluate_pressure_conditions()` 케이스 추가 |
| HUD 레이아웃 | `Player._ready()` HUD 구성 블록 (L91~332) | CanvasLayer/Control 하위 — 순서가 z-order 결정 |
| 봇 AI 튜닝 | `BotDoctrine.gd` profile/context + `Bot.gd` 실행부 + `GameConfig` difficulty params | profile merge 결과와 plan count를 Telemetry로 확인 |
| 난이도 파라미터 | `data/game_config.json` + `GameConfig.difficulty_params()` | Bot 스폰 시 `Main._get_difficulty_params()`로 읽힘, 실행 중 변경 불가 |
| Hell 정전/포격 튜닝 | `src/systems/hell/HellEventController.gd` + `GameConfig.hell_value()` | Main modifier wiring, Player.gd SCARCITY reads, Telemetry hell event names |
| 맵 구조 변경 | `MapSpec` Resource + `WorldBuilder.gd` | Minimap은 MapSpec 읽기만 함 |
| 사운드 추가 | `SoundManager.gd` + `Sfx.play("key")` 호출 위치 | 코어 모듈에서는 시그널로 위임 |
| 보급 캡슐 로직 | `SupplyDropController.gd` + `LootSpawnDirector.gd` + Main supply state | Minimap이 `supply_telegraphed` / `supply_pos` 읽음 |

---

## 6. 설계 원칙 요약

1. **RefCounted 코어 모듈**: ZoneController, WeaponSlotManager, MissionTracker는 씬트리에 속하지 않는다. `get_tree()`, `add_child()` 호출 없음 → 단위 테스트 가능, 씬 구조 변경에 무관.

2. **시그널 소유권**: 시그널은 상태를 소유한 모듈이 정의하고 emit한다. 수신자가 connect한다. 역방향 없음.

3. **duck-typed 외부 호출**: ZoneController가 `mission_tracker.on_player_zone_tick()`을 호출할 때 MissionTracker를 import하지 않고 duck-type으로 호출. 순환 의존 방지.

4. **Main = 글루 레이어**: 다수 모듈을 동시에 건드리는 코드(`_apply_pressure_effects()` 등)는 Main에 남긴다. 이 코드를 별도 클래스로 추출하면 의존성이 좁아지지 않기 때문이다.

5. **Pickup 인터페이스 보존**: Pickup.gd는 `has_method("receive_weapon")`으로 Player·Bot를 동일하게 처리. Player는 내부 구현이 WeaponSlotManager로 바뀌었어도 래퍼 메서드를 유지해 Pickup을 보호한다.
