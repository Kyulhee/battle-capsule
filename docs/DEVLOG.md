# 배틀캡슐 개발 일지

> **작성 형식**: `## vX.Y — YYYY-MM-DD` 헤더 → 한 줄 요약 → 파일명 기준 볼드 섹션 + 불릿.  
> 새 항목은 항상 **이 파일의 상단**에 추가. 업데이트 시점은 [CLAUDE.md](../CLAUDE.md) 참조.

---

## v1.4.4 — 2026-05-01

**봇 AI 감지·전략 반응성 강화**

**src/entities/bot/Bot.gd**

- IDLE 스캔 패턴 개편: 완전 랜덤 → 우측→좌측→랜덤 3단계 사이클로 옆 커버
- 스캔 간격 난이도별 축소: NORMAL 최대 1.8s / HARD 1.2s / HELL 0.9s (기존 3s)
- `_scan_alert` 플래그 추가: 발소리 감지 시 전속 회전, 일반 스캔은 0.5× 유지
- `_combat_loot_radius` 파라미터: HARD 22m, HELL 25m (기존 15m 고정)
- `combat_loot_floor`: AGGRESSIVE 봇도 탄약 부족 시 전투 이탈해 아이템 수집
  (NORMAL 20%, HARD 35%, HELL 40% 잔탄 임계치)

**src/core/bot_stats.tres**

- `dwell_time_open` 0.3 → 0.2s (시야 내 인식 충전 시간 단축)

**src/Main.gd**

- NORMAL `reaction_delay` 0.5 → 0.2s
- DIFFICULTY_PARAMS에 `combat_loot_floor`, `combat_loot_radius`, `idle_scan_interval_max` 추가

---

## v1.4.3 — 2026-05-01

**봇 AI 수정 + 포격 클러스터 개편**

**src/entities/bot/Bot.gd**

- `take_damage()` 재작성 — 칼/근접 공격 시 봇이 반격하지 않는 버그 수정
  - 어떤 공격으로 피해를 받아도 즉시 `perception_meters[source] = 1.0` → 시야 확보
  - IDLE / CHASE-loot / DISENGAGE 상태에서 공격자를 즉시 target으로 설정 후 CHASE 전환

**src/Main.gd**

- 비-BARRAGE 포격 1발(5m, 45dmg) → 10발 클러스터(3m, 18dmg/발, 15m 존, 0.18s 간격)
  - 봇 회피 로직 부재로 데미지를 낮게 유지; 튜닝 파라미터에 주석 추가

---

## v1.4.2 — 2026-04-30

**밸런스 조정 + Telemetry pressure 그룹 + 결과화면 UI 재설계**

**src/core/Telemetry.gd**

- `pressure` 그룹 JSON 출력 추가 — `_save_sim_result()`에서 누락되어 있던 항목 추가
- `log_pressure_event(event, mission_id)` 신규 — triggered/cleared/failed 카운터 + triggered_ids 목록
- `_print_report()` pressure 섹션 추가 — `Triggered / Cleared / Failed` 수치 + ID 목록 출력

**src/Main.gd**

- `_trigger_pressure_mission()`: 미션 발동 시 `tel.log_pressure_event("triggered", id)` 호출
- `_process_pressure_mission()`: success → `log_pressure_event("cleared")`, fail → `log_pressure_event("failed")`
- 결과화면 완전 재설계 (`_setup_result_panel()` 신규):
  - 고정 크기 VBoxContainer(400×500, 클리핑 발생) 제거 → CenterContainer + PanelContainer 자동 사이즈
  - 카드 레이아웃: 다크 네이비 배경, 2px 테두리, corner radius 10
  - 헤더(52px) + 랭크(28px) + 통계(17px) + 점수(24px) + 미션결과(16px) + 버튼 가로 행
  - 버튼 RESTART | RECORDS | MENU 수평 배치, 미션 결과 없을 때 관련 separator 자동 숨김
- `_result_header_label`, `_result_rank_label`, `_result_stats_label`, `_result_score_label`, `_result_mission_label` 멤버 변수로 관리

**src/Main.tscn**

- ResultPanel 하위 Content VBoxContainer + 모든 자식 노드 제거 (코드로 빌드)
- ResultPanel `color` → `Color(0.04, 0.04, 0.08, 0.92)` (진한 다크 오버레이)

**src/core/MissionTracker.gd**

- `get_pressure_hud_text()` 2줄 포맷: `"⚡ title | Xs\ndescription  [progress]"`
- `_get_pressure_progress_text()` 가독성 개선: `0/1킬` → `킬 0/1`, `피해0` → `무피해 ✓`, `힐OK` → `힐 미사용 ✓` 등

**src/entities/player/Player.gd**

- 보너스 미션 HUD font_size 13 → 15
- 압박 미션 HUD y 오프셋 68 → 96 (2줄 보너스 HUD와 겹침 방지)

**docs/TESTING.md**

- `pressure` 그룹 지표표 추가
- 압박 미션 검증 시나리오 + 체크리스트 추가

헤드리스 시뮬레이션: duration 92s, zone_stage 3, pressure 그룹 JSON 정상 출력. SCRIPT ERROR 없음.

---

## v1.4.1 — 2026-04-30

**Mission UI/UX 개선 — HUD 가시성, 보너스 미션 풀 재조정, 압박 미션 Flash 알림**

**src/core/MissionData.gd**

- `ConditionType.KILL_WITH_ALL_WEAPONS` 추가 — 피스톨·AR·샷건·레일건 각각 1킬 이상
- `@export var score_bonus: int = 500` 필드 추가 — 미션별 차등 점수 지원

**src/core/MissionTracker.gd**

- `_medkits_used` 카운터 + `on_player_medkit_used()` 훅 추가
- MEDIC RUN: 조건을 일반 치료 아이템 → MedKit(◆)만 카운트로 변경 (고난이도화)
- SCAVENGER: `COLLECT_WEAPONS` → `KILL_WITH_ALL_WEAPONS` 변경, score_bonus=1000
- HELL CHAMPION 제거 (14개 보너스 미션 풀로 축소, 1등 달성은 기본 점수로 처리)
- `get_hud_text()` 전면 개선 — 두 줄 구성 (미션명 / 진행 상황 풀어쓰기), 줄임말 제거
  - KNIFE FINISH: `"칼로 마지막 킬 달성 — 현재 어설트 라이플"` 형식
  - PISTOL ONLY / SURVIVOR: 실패 확정 시 `"✗ ... — 실패 확정"` 텍스트 표시
  - KILL_WITH_ALL_WEAPONS: 총기별 달성/미달성 분리 표시 (`✓ 피스톨  AR  /  ✗ 샷건  레일건`)
- `get_early_fail_status(tel)` 신규 — Player.gd가 HUD 색상 전환에 활용

**src/entities/player/Player.gd**

- `_flash_panel` / `_flash_label` 신규 (반투명 배경 패널, PRESET_CENTER_TOP + y+110)
- `show_pressure_flash(text, success)` 신규 — 성공 초록/실패 빨강, 0.12s 등장→2.2s 유지→0.45s 소멸
- `handle_healing()` advanced_heals 분기에 `on_player_medkit_used()` 호출 추가
- 미션 HUD: `get_early_fail_status()` 결과에 따라 실패 시 자동 빨간 색상 전환

**src/Main.gd**

- `_end_match()`: `mission_bonus_score = mission_tracker.active_mission.score_bonus` (하드코딩 500 제거)
- `_process_pressure_mission()`: success/fail 결과 후 `player_ref.show_pressure_flash()` 호출

헤드리스 시뮬레이션: duration 93s, zone_stage 3, SCRIPT ERROR 없음. active_mission/mission_result 정상 기록.

---

## v1.3 — 2026-04-30

**Challenge Mission System — 미션 선택 UI, 인게임 추적, 배지 저장**

**src/core/MissionData.gd** (신규)

- `extends Resource`, `class_name MissionData`
- 14종 `ConditionType` 열거형: FIRST_KILL / WIN_HIGH_HP / WIN_WITH_HEALS / COLLECT_WEAPONS / SURVIVE_NO_KILLS / WIN_PISTOL_ONLY / KILL_LAST_WITH_MELEE / KILLS_WITH_WEAPON / KILL_IN_BUSH / WIN_AFTER_ZONE_OUTSIDE / KILL_NEAR_SUPPLY / KILL_UNDETECTED / KILL_WHILE_DETECTED / WIN_ON_DIFFICULTY
- `@export` 필드: id, title, description, condition_type, target_value, weapon_filter, badge_label, badge_color

**src/core/MissionTracker.gd** (신규)

- `extends RefCounted` — Main.gd가 인스턴스를 보유, 씬 리로드 시 자동 해제
- `const MissionData = preload(...)` 패턴으로 class_name 파싱 순서 문제 해결
- 인매치 추적 변수: `_used_non_pistol`, `_last_kill_weapon`, `_kills_in_bush`, `_kills_near_supply`, `_kills_undetected`, `_kills_while_detected`, `_player_max_outside_sec`
- 훅: `on_player_fire()`, `on_player_kill(ctx)`, `on_player_zone_tick()`
- `evaluate()`: 14 ConditionType 전부 구현 / `get_hud_text()`: 진행도 포맷
- `save_badge()` / `has_badge()` / `load_achievements()`: `user://achievements.json`
- `static func get_all_missions()`: 15개 미션 인라인 정의

**15개 미션 (5카테고리)**

Basic: first_blood(1킬), clean_win(HP50%+WIN), medic_run(치료3+WIN), scavenger(무기3종), survivor(킬0+90s)  
Weapon: pistol_only(권총만+WIN), knife_finish(칼마지막킬+WIN), shotgun_rush(샷건3킬), railgun_moment(레일건1킬)  
Tactical: bush_hunter(수풀2킬), zone_walker(자기장밖10s+WIN), supply_thief(보급12m내1킬), ambush(비감지1킬), outnumbered(2명감지1킬)  
Hell: hell_champion(지옥+WIN)

**src/core/Telemetry.gd**

- `enabled_groups`에 `"mission": true` 추가
- mission 그룹 초기화: `active_mission`, `mission_progress`, `mission_result`
- `log_mission_start(id)`, `log_mission_result(success, progress)` 신규

**src/Main.gd**

- `const MissionTrackerScript = preload(...)` — GDScript class_name 파싱 순서 우회
- StartBtn → `_on_start_btn_pressed()` → `_show_mission_select()` 플로우
- 미션 선택 오버레이: 15개 목록, ★ 배지 획득 표시, [없음] 옵션
- `_on_bot_died()`: 플레이어 킬 시 kill context(in_bush, near_supply, undetected, num_detecting) 전달
- `handle_damage_tick()`: 플레이어 존 외부 여부 1초 단위 전달
- `_end_match()`: evaluate → save_badge → 결과 화면 MISSION CLEAR/FAILED 표시

**src/entities/player/Player.gd**

- `_notify_mission_tracker_fire(weapon_type)` 헬퍼 + 칼/샷건/총기 슬롯 3곳에 삽입
- `mission_hud_label`: 존 타이머 아래 미션 진행도 실시간 표시

헤드리스 시뮬레이션: duration 97s, zone_stage 4, stuck 4, disengage 12, 스크립트 에러 없음. mission 그룹 sim_result 정상 포함.

---

## v1.2 — 2026-04-29

**봇 DISENGAGE 클러스터링 해소 — 커버 품질 필터 + 분산 후퇴**

**Bot.gd**

- `_obs_provides_cover(obs)` 헬퍼 추가: `collision_layer & 8` (높이 >2.5m 플래그) 기준으로 실제 엄폐 가능 장애물만 선별. `log_pile`(h=1.5m), `bush_patch`(h=1m) 등 낮은 구조물은 커버로 인정 안 함.
- `_find_cover_point()` 재작성:
  - `_obs_provides_cover` 필터 추가 (낮은 장애물 제외)
  - 인스턴스별 섹터 오프셋(`get_instance_id() % 8 × TAU/8`)으로 커버 위치 분산 → 같은 장애물 뒤에 몰리지 않음
  - 이미 아군이 목표 중인 커버는 거리 +10점 패널티 (크라우딩 억제)
- `handle_disengage_state()`: `_count_visible_enemies() >= 4` 시 커버 탐색 대신 `_scatter_dir_from`으로 즉시 분산 후퇴 — 대인원 포위 시 한 지점에 뭉치는 현상 해소

헤드리스 시뮬레이션 결과: stuck 3회(이전 13~18), avg_pairwise_dist 20.1m(넓은 분산), 에러 없음.

---

## v1.1 — 2026-04-29

**미니맵 타입별 표현 개선 + 맵 전략 배치 재설계 + WorldBuilder jitter**

**Minimap.gd**

- 장애물 드로잉을 타입별로 분기:
  - `tree_cluster`: 어두운 녹색 채움 + 테두리
  - `canyon_wall`: 갈색 채움 + 두꺼운 테두리 (1.5px)
  - `log_pile`: 황갈색 채움 + 테두리
  - `rock_cluster`: 직사각형 → **회색 원** (반경 = scale.x × 0.75), 실제 방사형 배치와 일치
  - `bush_patch`: 동일 회색 박스 → **연두색 반투명 원** (α=0.38), 지상 엄폐물 시각화

**WorldBuilder.gd**

- `jitter: [dx, dz]` 필드 지원 추가: 결정론적 RNG(pos 기반 seed)로 ±dx/dz 범위 내 위치 변동
- `rot_jitter` 필드 지원: ±rot_jitter 범위 내 회전 변동
- `pos.duplicate()` 로 원본 spec 보호

**data/mapSpec_example.json** (v3.0)

- 3링 구조로 재설계: 외곽(r≈48~55) 수림 / 중간(r≈22~42) 전술 섬 / 내부(r≈0~20) 전투 구역
- canyon_wall 2개 → 6개: 동서 2개씩 + 북서·북동 능선 구성, 4방향 회랑(X·Z ±4m) 열린 상태 유지
- rock_cluster 9개 → 21개: 중심부 4방향 커버 4개 신규 + 전 POI별 근접 커버 2개 보장
- bush_patch 7개 → 5개: concealment_field POI 집중 배치
- log_pile 4개 → 8개: 회랑 측면 얕은 엄폐물 추가
- 중간링 tree_cluster에 jitter/rot_jitter 적용 → 매 실행마다 소폭 변동, 외곽·벽 근접 고정 배치는 jitter 없음

---

## v1.0 — 2026-04-29

**NavigationRegion3D + NavigationAgent3D — 봇 Pathfinding 도입**

**Main.gd**

- `_nav_region: NavigationRegion3D` 변수 추가.
- `_setup_navigation()` 추가: `NavigationMesh` 생성 (`geometry_parsed_geometry_type = PARSED_GEOMETRY_STATIC_COLLIDERS`, `cell_size=0.3`, `agent_radius=0.5`), `NavigationRegion3D`를 씬에 추가, `bake_navigation_mesh()` 비동기 베이크. `bake_finished` 신호로 완료 로그.
- `_ready()` 양쪽 경로(autostart / 일반)에 `_setup_navigation()` 호출 추가 — 월드 생성 직후 베이크 시작.

**Bot.gd**

- `_nav_agent: NavigationAgent3D` 변수 추가.
- `_ready()`: `NavigationAgent3D` 동적 생성 (`path_desired_distance=0.5`, `target_desired_distance=1.5`, `avoidance_enabled=false`), `add_child`.
- `_nav_move_toward(target_pos, delta, should_rotate)` 헬퍼 추가: nav agent로 경로 추종; 경로 없을 시 `_move_or_unstick` fallback.
- CHASE 이동 2곳, RECOVER patrol 이동, ZONE_ESCAPE 이동, DISENGAGE 커버 이동을 `_nav_move_toward`로 교체.
- ZONE_ESCAPE: thrash escalation 로직 제거 — navmesh가 장애물 우회를 처리.

헤드리스 시뮬레이션: navmesh 비어 있어 fallback 동작. 지표 정상(78s, zone_stage 3, recover 11).

---

## v0.9.5 — 2026-04-29

**점수 시스템 + 난이도별 매치 히스토리 + 버그 수정 + Hard+ 봇 전투 회피**

**Telemetry.gd**

- `match_history` 타입: `Array` → `Dictionary` (`str(difficulty)` 키, 하위는 기록 배열). 구포맷(Array) 로드 시 자동 폐기.
- `current_difficulty: int` 변수 추가 — `start_game()` 호출 전 Main이 설정.
- `DIFF_MULT = [1.0, 1.5, 2.5, 4.0]` 상수 추가.
- `calculate_score(rank, kills, assists, win, diff) -> int`: 기본점 `1000 - (rank-1)×80` + 킬×100 + 어시스트×40 + 승리+300, 전체에 난이도 배율 곱.
- `clear_history()`: `match_history = {}` 후 빈 `{}` 기록.
- `get_history_for_difficulty(diff) -> Array`: 해당 난이도 기록 배열 반환.
- `_save_history()`: 레코드에 `difficulty`, `score` 필드 추가; 딕셔너리 포맷으로 저장; score 내림차순 정렬.

**Main.gd**

- `_records_selected_diff: int = 1` 변수 추가.
- `start_game()`: Telemetry `current_difficulty = difficulty` 설정 후 `start_match()`.
- `_end_match()`: `calculate_score()` 호출 → stats_label에 `SCORE: N` 줄 추가.
- `_on_records_pressed()` → `_setup_records_controls()` 호출로 분리: 난이도 탭 버튼(쉬움/보통/어려움/지옥) + CLEAR ALL 버튼을 Scroll 위에 한 번만 생성.
- `_populate_records_list()` 재작성: `get_history_for_difficulty(_records_selected_diff)` 사용; 탭 하이라이트 갱신; 행에 Score 열(보라/골드) 추가.

**Entity.gd**

- `_spawn_damage_number()`: `get_tree().root.add_child(lbl)` 을 `lbl.global_position` 설정 전에 이동 — Label3D가 트리에 추가되기 전 `global_position` setter 호출로 발생하던 `!is_inside_tree()` 오류 수정.

**Main.gd**

- `_print_bot_state_snapshot()` / `handle_damage_tick()`: 그룹 멤버 순회 시 `is_instance_valid()` 가드 추가 — 삭제 대기 중인 노드에 `global_position` 접근 시 발생하던 동일 오류 수정.

**Bot.gd**

- `_update_state_label_visibility()`: `is_revealed_to(player)` (인식 게이지 기반, 시야 이탈 후 수 초 지속) → `player._can_i_see(self)` (실시간 LOS 판정)로 교체 — 시야 밖 봇의 `?`/`!` 아이콘이 보이던 문제 수정.
- `_combat_jump_timer` 변수 추가.
- `handle_attack_state()`: Hard+ (`_awareness_level >= 2`) 에서 2–4 초 주기로 전투 점프 (`velocity.y = 5.0`) 추가.
- 스트레이프 amplitude를 `_awareness_level`에 따라 스케일: Easy=0.2, Normal=0.4, Hard/Hell=0.6 — 상위 난이도 봇이 교전 중 더 역동적으로 움직임. 크라우치는 충돌 형상 변경이 필요하여 v1.0으로 연기.

---

## v0.9.4 — 2026-04-28

**UI 폴리시 — ESC 일시정지 메뉴, 직접 재시작, Hell 안내 개선, 설정 메뉴, 결과 화면 확장**

**Main.gd**

- `process_mode = PROCESS_MODE_ALWAYS` — 메인 노드 항상 처리, `_process()` 시작에 `if get_tree().paused: return` 가드 추가.
- `_input()` 재작성: `KEY_ESCAPE` → Hell 안내 중이면 안내 닫기, 게임 중이면 일시정지 토글. `KEY_SPACE` → Hell 안내 닫기.
- **ESC 일시정지 메뉴**: `_toggle_pause()` + `_create_pause_panel()` 추가. RESUME / RESTART / MAIN MENU 버튼. 패널 및 버튼 `PROCESS_MODE_ALWAYS`.
- **직접 재시작**: `restart_game()`에서 `Telemetry.set_meta("_restart_difficulty", difficulty as int)` 저장 후 씬 리로드. `_ready()` 말미에 메타 확인 시 `start_game()` 자동 호출.
- **Hell 안내 개선**: `_show_hell_announcement()` — `get_tree().paused = true`, 패널 `PROCESS_MODE_ALWAYS`, "START [SPACE / ESC]" 버튼 추가. 자동 fade-out 제거. `_dismiss_hell_announcement()` 추가 — 버튼/키 입력 시 fade + unpause.
- **결과 화면**: `_end_match()` stats_label에 `DAMAGE: %.0f` 줄 추가 (텔레메트리 `combat.total_damage_dealt`).
- **설정 메뉴**: 메인 메뉴에 "SETTINGS" 버튼 동적 삽입 (ExitBtn 위). `_on_settings_pressed()` — 볼륨 슬라이더 (linear 0–1 → dB), 풀스크린 토글 버튼, CLOSE 시 `_save_settings()` 호출.
- `_load_settings()` + `_save_settings()` — `user://settings.cfg` (ConfigFile). `_ready()` 최초 호출로 이전 설정 복원.

---

## v0.9.3 — 2026-04-28

**Hell 랜덤 모디파이어 — 쉴드 꺼짐 / 탄막 폭격 / 전원 적대**

**Main.gd**

- `enum HellModifier { SHIELD_OFF, BARRAGE, ALL_AGGRESSIVE }` 추가.
- `hell_modifier`: 매 Hell 매치 시작 시 `randi() % 3`으로 랜덤 결정.
- `_show_hell_announcement()`: 5줄→4줄로 재구성, 활성 모디파이어 이름·색상 표시.
- **SHIELD_OFF**: `spawn_entities()`에서 플레이어 `stats.max_shield = 0`, `current_shield = 0` 강제. 방어구 픽업 무효화.
- **BARRAGE**: `_start_bombardment()` 분기 — 반경 14 외곽 경고 디스크 + 펠릿 10발(r=2.5, 22 dmg) 0.06s 스태거로 0.7s 후 착탄. 기존 단일 폭탄(r=5, 45 dmg, 1.5s)은 비BARRAGE 시 유지.
- **ALL_AGGRESSIVE**: `spawn_entities()` 봇 루프에서 `b._apply_personality(b.Personality.AGGRESSIVE)` 호출.
- `_make_bomb_disc(radius, col)` 헬퍼 추가 — CylinderMesh 경고 디스크 생성 공용화.

**Bot.gd**

- `_awareness_level: int` 추가 (0=없음, 1=주기 스캔, 2=능동+즉각 반응).
- `apply_difficulty()`: `"awareness_level"` 파라미터 처리 추가.
- `handle_attack_state()`: `_awareness_level >= 1`이면 주기적 `_peripheral_check()` 실행 (보통 3s, 어려움+ 1.5s).
- `take_damage()`: `_awareness_level >= 2`이고 제3자에 의해 피격 시, 현재 타깃 HP ≥ 25%면 즉시 타깃 전환.
- `_peripheral_check()`: 시야 내 제3자 탐색. 보통=현재 타깃보다 30% 가까울 때만 전환, 어려움+=HP 조건만.
- `_switch_target(new_target)`: 타깃 교체 + `state_timer = 0` 리셋.

---

## v0.9.2 — 2026-04-27

**Hell Difficulty — HP 1 시작, 힐 감소, 암전 + 폭격 이벤트**

**Main.gd**

- `enum Difficulty` 에 `HELL = 3` 추가. `DIFFICULTY_PARAMS[3]`: vision_mult 1.5, reaction_delay 0, aim_spread 0.5, loot_break_mult 2.0.
- 난이도 선택 UI: 버튼 4개("쉬움"/"보통"/"어려움"/"지옥"), 지옥 버튼 색상 보라(0.75, 0.1, 1.0).
- `spawn_entities()`: HELL이면 플레이어 HP를 1로 강제 설정 후 `health_changed` 방출.
- `start_game()`: HELL + 비시뮬레이션이면 blackout/bomb 타이머 초기화, `_create_hell_overlay()` + `_show_hell_announcement()` 실행.
- `_process()`: `_process_hell_events(delta)` 호출 추가.
- `_create_hell_overlay()`: 전화면 ColorRect(z_index 10, α=0) 생성.
- `_show_hell_announcement()`: "HELL MODE / HP 1 START / HEALING REDUCED / BLACKOUTS & BOMBARDMENTS / SURVIVE IF YOU CAN" 패널, 4.5초 후 fade-out.
- `_process_hell_events(delta)`: blackout·bomb 타이머 tick.
- `_trigger_blackout()`: Tween으로 페이드인(0.3s)→홀드(2–4s)→페이드아웃(0.5s); 완료 콜백에서 타이머 리셋(15–28s). Telemetry `"blackout"` 기록.
- `_start_bombardment()`: 존 반경 85% 내 랜덤 위치에 경고 디스크(CylinderMesh r=5, 빨강), 1.5s 딜레이 후 범위 내 엔티티에 45 데미지. Telemetry `"bombardment_warned"` / `"bombardment_hit"` 기록.
- `_show_event_text(msg, col)`: 화면 상단 중앙 이벤트 텍스트, 1.5s 후 fade-out.

**Player.gd**

- `handle_healing()`: HELL이면 힐량 감소 — advanced_heal 60→33 HP (×0.55), 일반 heal regen 30→12 HP (×0.40).

**Telemetry.gd**

- `"hell"` 그룹 추가 (`enabled_groups` 기본 true).
- 지표: `blackout_count`, `bombardment_warned_count`, `bombardment_hit_count`.
- `log_hell_event(event)` 함수 추가.
- `_save_sim_result()` + `_print_report()` 에 hell 그룹 출력 추가.

---

## v0.9.1 — 2026-04-27

**Zone Escape 버그 수정 — stuck 탈출 로직 재설계 + 스테이지별 조기 진입**

**Bot.gd**

- `handle_zone_escape_state`: `_sample_zone_escape_dir` 반환값을 `_stuck_override_dir`에 실제 적용하도록 수정 (기존 dead code 버그).
  - 수정 전: `dir` 변수에 넣었으나 `_move_or_unstick`이 무시하고 기존 수직 방향 사용.
  - 수정 후: `_stuck_override_dir = _sample_zone_escape_dir(zone_c)` 로 실제 적용.
- `handle_zone_escape_state`: 에스컬레이션 로직 추가 — ZONE_ESCAPE 진입 후 3초 이상 경과 시 4초 주기로 완전 랜덤 방향 2초 burst. 코너 트랩(각도 샘플링으로 해결 불가)을 강제 돌파.
- `_zone_thrash_cooldown: float = 0.0` 멤버 추가 — 랜덤 burst 쿨다운.
- `_sample_zone_escape_dir`: 각도 샘플링(best_dot 선택) → 벽 슬라이드 방향으로 교체.
  - `(to_center + perp * sign * 0.6).normalized()` — 존 중심 방향 + 수직 성분 블렌드.
  - 인스턴스 ID 기반 sign으로 인접 봇이 좌우 분산.
- `_check_state_overrides`: 존 탈출 진입 임계값을 스테이지에 따라 선형 감소.
  - 스테이지 1→0.95, 2→0.90, 3→0.85, 4+→0.80.
- `handle_attack_state` 존 체크: 동일 스케일 적용 (0.90→0.75).

**20회 헤드리스 시뮬 검증 결과**

| 항목 | v0.9.0 | v0.9.1 |
|---|---|---|
| zone 사인 비율 | 12% | 5% |
| stuck+zone 조합 사망 | 1건 (stage 8, dist=1.75) | 0건 |
| 최대 zone_dist_ratio | 4.92 | 1.21 |
| avg outside_sec | 0.18 | 0.11 |

---

## v0.9.0 — 2026-04-27

**Combat Feedback — 봇 상태 아이콘, 히트 마커, 피해 숫자, 자기장 경고**

**Bot.gd**

- `_state_label: Label3D` 추가 — 봇 머리 위 billboard 상태 인디케이터.
  - IDLE: 숨김.
  - CHASE: `?  ◉` (노랑).
  - ATTACK: `!  ◎` (빨강).
  - DISENGAGE: `?  ◉` (주황).
- `_update_state_label()`: `change_state()` 진입 시 즉시 아이콘 갱신.
- `_update_state_label_visibility()`: `_physics_process`에서 per-frame 실행 — 플레이어가 봇을 인식하고 거리 32m 이내일 때만 표시; 그 외 숨김.

**Entity.gd**

- `_spawn_damage_number(amount, source)`: 피해 시 `Label3D` 스폰 — 위로 떠오르며 fade-out (0.85s). 총상 빨강 / 근접 주황.

**Player.gd**

- `_hit_marker: Label` + `_hit_marker_timer`: `_internal_shoot()` / `_melee_attack()` 명중 시 중앙 `×` 0.12s 표시.
- `_zone_warning_style: StyleBoxFlat (draw_center=false)` + `_zone_warning_pulse`: 플레이어가 자기장 밖이면 화면 테두리 빨간 박동(3.5Hz, 최대 α 0.58), 안쪽이면 즉시 fade.
- Kill streak 스케일링 강화: streak 1→22px, 3→골드→주황, 5+→딥 오렌지, outline +1px/streak (최대 12).

---

## v0.8.4 — 2026-04-27

**Actor Identity + Killfeed Data Foundation**

**Entity.gd**

- `display_name: String = ""` 필드 추가 — 모든 액터(봇·플레이어)에 표시 이름 부여.
- `kill_streak: int = 0` 필드 추가 — 연속 킬 카운트. `die()` 시 피해자 streak 리셋, 킬러 streak +1.

**Main.gd**

- `spawn_entities()`: 플레이어 `display_name = "YOU"`, 봇 `display_name = "Bot %d" % (i + 1)` 순서 배정.
- `_on_bot_died()`: 피해자 display_name, 킬러 display_name(Zone/YOU/Bot N), 무기 타입, 킬러 streak를 추출해 `add_kill_feed_entry()` 호출. 자기장 사망 시 killer_name = "Zone".

**Player.gd**

- `_weapon_glyph(wtype)` 헬퍼 추가: `knife→⚔  pistol→◉  ar→≡  shotgun→⊛  railgun→⚡  기타→→`.
- `add_kill_feed_entry()` 시그니처 확장: `weapon_type`, `killer_streak` 파라미터 추가.
  - 플레이어 킬: `★ YOU ×N  ⚔  Bot 3  KILL` (streak ≥ 2일 때 ×N 표시).
  - 어시스트: `◆ Bot 5  ≡  Bot 2` (킬러 이름 + glyph + 피해자 이름).
  - 봇 킬: `Bot 1  ◉  Bot 8` (회색, 소자).

---

## v0.8.3 — 2026-04-27

**UI Polish + Bot 생존 AI 강화 — HUD, 툴팁, 상태 머신 종합 개선**

**Bot.gd**

- `_flee_hp_ratio` 변수 추가 + 성격별 임계값: AGGRESSIVE=0.15, DEFENSIVE=0.35, SCAVENGER=0.25.
- `_check_survival_overrides()`: HP 기반 전역 오버라이드 — ATTACK/CHASE/DISENGAGE → RECOVER 강제 전환 (존 탈출·칼 돌진 예외 처리).
- `handle_attack_state()`: 전투 중 탄약 부족 + 근처 픽업 감지 시 루팅으로 이탈 (`_combat_loot_threshold`). 난이도별 `loot_break_mult` 스케일링 (쉬움=0, 보통=1, 어려움=1.5).
- `handle_idle_state()`: HP < 50% 봇은 `_find_best_pickup(55.0)` (힐 우선, 넓은 반경) 사용; 2.5m 이내 아이템 즉시 수집.
- `handle_chase_state()` 루팅 브랜치: 수집 거리 1.5m → 2.5m; 5초 타임아웃 후 대체 픽업 전환.
- `handle_recover_state()`: 탄약 없는 봇이 근접 적 감지 시 칼 돌진으로 반격 (`MELEE_RANGE * 2.5`).
- `_pick_patrol_target()`: 공급 캡슐 → 성격별 목표(DEFENSIVE=수풀, SCAVENGER=핫스팟) → 랜덤 존 포인트 순서로 순찰 목표 선택.
- `_find_nearest_bush()` / `_find_nearest_hotspot()`: MapSpec 기반 수풀·POI 위치 조회 헬퍼.
- `_update_stuck()`: 탈출 각도 무작위화 ±135°, 오버라이드 지속 0.65s → 1.2s.
- 공급 캡슐 흡인 반경: SCAVENGER=70m, 기타=50m.

**Player.gd**

- HUD 좌상단 margin `(8,8)` → `(12,12)`: HP/SH/stat 영역 화면 가장자리 잘림 방지.
- 킬피드 컨테이너 y 오프셋 `+60` → `+280`: 미니맵(20~260px) 아래로 이동해 겹침 제거.
- 무기 슬롯 바 하단 margin `8` → `16`: 하단 잘림 방지.
- `handle_interaction()`: 전방 반구 FOV 제한 — 플레이어 뒤편(dot < 0) 아이템은 픽업 불가.

**Main.gd**

- `_diff_tooltip` / `_diff_tooltip_label` 멤버 추가.
- `DIFF_DESCRIPTIONS` 상수: 난이도별 설명 텍스트 (한글).
- `_ready()`: 난이도 버튼별 `mouse_entered` / `mouse_exited` 시그널 연결.
- `_show_diff_tooltip(idx)`: 버튼 글로벌 rect 기준 바로 아래에 툴팁 패널 표시.
- ResultPanel MenuBtn 연결 (`return_to_menu`) 및 가시화 (기존 `visible=false` 제거).
- RestartBtn / MenuBtn에 `_apply_btn_style()` 적용.
- ResultPanel에 RECORDS 버튼 동적 추가 → `_on_records_pressed` 연결.

**Main.tscn**

- VersionLabel 텍스트 `v0.8.1` → `v0.8.2`.

---

## v0.8.2 — 2026-04-27

**Zone escape 강화 + Zone death 텔레메트리**

**Bot.gd**

- `_zone_outside_timer` 변수 추가: 봇이 zone 밖에 머문 연속 시간 추적.
- `_check_state_overrides()`: 경계의 정확한 외부 감지 → `radius * 0.95` 초과 시 조기 ZONE_ESCAPE 전환으로 변경. zone 밖이면 타이머 누적, 안이면 리셋.
- `handle_zone_escape_state()`: stuck 중에 일반 `_move_or_unstick`(수직 방향) 대신 `_sample_zone_escape_dir()`로 zone 방향 각도 탐색 사용.
- `_sample_zone_escape_dir()`: zone center 방향 기준 ±30°~±60° 5개 후보 중 zone center에 가장 가까운 방향 선택. 인스턴스별 기본 오프셋 적용으로 인접 봇끼리 분산.
- `_on_died_zone_log()`: `died` 시그널에 연결. `_zone_outside_timer > 0.5`이면 `log_zone_death(state_name, time_outside)` 기록.

**Telemetry.gd**

- `"zone"` 그룹 추가 (enabled_groups + metrics 초기화 + _save_sim_result 출력 포함).
- `log_zone_death(state_at_death, time_outside)`: zone 밖 사망 수, 상태별 분류, 최대 외부 체류 시간 기록.

**Main.gd**

- `_print_bot_state_snapshot()`: `outside_zone` 카운트 추가 — stage 전환 시 zone 밖 봇 수 출력.

**헤드리스 시뮬레이션 결과**

```
run 1: duration=82s  zone_stage=3  zone_deaths=0  stuck=14  outside_zone(snapshot)=0
run 2: duration=48s  zone_stage=2  zone_deaths=0  stuck=5   outside_zone(snapshot)=0
run 3: duration=43s  zone_stage=2  zone_deaths=0  stuck=5   outside_zone(snapshot)=0
```

---

## v0.8.1 — 2026-04-27

**전체 메뉴 UI 재설계 + HUD 아이콘 + 난이도 버튼 색상**

**Main.tscn**

- `Subtitle`, `VersionLabel` 노드를 tscn에 직접 추가 — `_ready()` 동적 생성 시 position 미적용 버그 해소.
- VBoxContainer 오프셋 ±100 → ±150, 버튼 간격 20 → 28px으로 여유로운 레이아웃.
- HelpPanel VBox 너비 ±350 → ±420, 기존 단일 Text Label 제거 (코드로 재생성).
- 서브타이틀 "1 vs 11" → "1 vs all".

**Main.gd — 메인 메뉴**

- `_setup_menu_visuals()` 추가:
  - `GradientTexture2D` 배경: 다크 네이비 → 딥 포레스트 그린 그라디언트.
  - `NoiseTexture2D` (FastNoiseLite CELLULAR) 오버레이: 18% 불투명도로 텍스처감 부여.
  - 64→80px 픽셀아트 캡슐 로고: 파란 상단 / 빨간 하단, 구분선, 외곽선 포함. 타이틀 위 배치.
  - `StyleBoxFlat` 버튼 스타일 (normal/hover/pressed): 다크 그린 배경, 밝은 그린 테두리, 둥근 모서리.
- `_apply_btn_style(btn)` 헬퍼: 난이도 버튼 포함 모든 버튼에 통일 적용.
- 난이도 버튼 색상: 쉬움 초록 / 보통 노랑 / 어려움 빨강. 미선택 회색.

**Main.gd — Records 패널**

- `_setup_secondary_panels()`: Records/Help 패널 모두 동일한 다크 포레스트 그라디언트 오버레이 적용.
- `_populate_records_list()` 재작성:
  - 행 단위: WIN 뱃지 + Rank + 해골 아이콘+Kill + 손 아이콘+Assist + Time + Date.
  - 빈 기록 시 "기록 없음" 안내 메시지.
  - 해골/손 아이콘은 `_make_menu_icon()` 픽셀아트 텍스처 사용.
- BACK 버튼 `_apply_btn_style` 적용.

**Main.gd — How to Play 패널**

- `_build_help_panel()` 전면 재작성:
  - ScrollContainer 내 세 섹션: **CONTROLS** / **HUD 아이콘** / **SYSTEMS**.
  - `_make_key_row(keys, desc)`: 키보드 키캡 스타일 PanelContainer (어두운 회색, 밝은 테두리, 라운드) + 설명.
    - [W][A][S][D] 이동, [MOUSE] 조준, [LMB] 사격, [E][Q][R][C][SPACE][0][1][2][3][4].
  - `_make_icon_row(shape, col, desc)`: 해골/손/사람 픽셀 아이콘 + 설명.
  - `_make_text_row(symbol, col, desc)`: ♥ ◆ 심볼 + 설명.
  - `_make_desc_row(label, desc)`: 시스템 설명 (자기장, 보급 캡슐, 스텔스, 무기 획득, 중복 제한).
- BACK 버튼 `_apply_btn_style` 적용.

**Main.gd — 공용**

- `_make_menu_icon(shape)`: skull/hand/person 12×12 픽셀아트 ImageTexture 생성 (static).
  Records 행과 How to Play 아이콘 행 공유.

**Player.gd**

- `_make_hud_icon(shape)`: skull/hand/person 12×12 픽셀아트 생성 (static).
- `_stat_pair_icon(container, icon_tex, col)`: TextureRect 아이콘 + 컬러 value Label 쌍 추가 헬퍼.
- HUD 스탯 아이콘 교체:
  - ★ Kill → 해골 픽셀아트 (노랑)
  - ◇ Assist → 손 픽셀아트 (주황)
  - ● Alive → 사람 픽셀아트 (회색)
- Alive 표시 포맷: `×N` → `N/12` (전체 인원 대비).
- `_update_status_hud(alive, total)`: `total = main.bot_count + 1` 전달.

---

## v0.8.0 — 2026-04-26

**AI 전투 개선 — 봇 성격 분류, 집단 공격 강화, 발소리 감지, 루팅 우선순위, 난이도 시스템**

**Bot.gd**

- `Personality` enum 추가 (AGGRESSIVE / DEFENSIVE / SCAVENGER), `_ready()`에서 랜덤 배정.
  - AGGRESSIVE: DISENGAGE 임계값 3, fire_rate_mult 0.8 (공격 중 연사 빨라짐), 발소리 반경 10m
  - DEFENSIVE: DISENGAGE 임계값 1 (쉽게 후퇴), 발소리 반경 15m
  - SCAVENGER: DISENGAGE 임계값 2, fire_rate_mult 1.15 (느린 연사), 루팅 반경 90m
- `_apply_personality()` 추가: 성격별 파라미터(`_disengage_threshold`, `_fire_rate_mult`, `_footstep_range`, `_loot_radius`) 설정.
- `apply_difficulty()` 추가: Main에서 스폰 후 호출 — `vision_range`, `_reaction_delay`, `_aim_spread_mult` 적용.
- `_check_footstep_sounds()` 추가: IDLE/RECOVER 중 반경 내 달리는 액터 감지 → perception 0.85까지 부스트 + `last_known_target_pos` 갱신.
- `_find_best_pickup()` 추가: 거리 기반 점수에 상황별 우선순위 보정 적용. HP<40% 시 힐 ×0.3, ammo==0 시 탄약 ×0.25, 다른 종류 탄약 ×3.0 (회피).
- `_count_ally_attackers()` 추가: "bots" 그룹 중 같은 `target_actor`를 ATTACK 중인 봇 수 반환.
- `handle_attack_state()`: shoot 직후 ally_attackers ≥ 1이면 `fire_cooldown *= _fire_rate_mult` (집단 공격 시 연사 가속).
- DISENGAGE 진입 조건 `_count_visible_enemies() >= 2` → `>= _disengage_threshold` 교체.
- 반응 지연: `handle_idle_state()`에 `_pending_target` + `_reaction_timer` 구조 추가. 적 발견 즉시 추적 대신 `_reaction_delay`초 후 전환.
- `shoot_predictive()` base_spread에 `_aim_spread_mult` 곱 적용.
- `_ready()`에서 `add_to_group("bots")` 추가 (집단 공격 카운트용).
- `handle_recover_state()` 내 `_find_nearest_pickup(70.0)` → `_find_best_pickup(_loot_radius)` 교체.

**Main.gd**

- `Difficulty` enum 추가 (EASY / NORMAL / HARD), `DIFFICULTY_PARAMS` const 정의.
  - Easy: vision ×0.75, reaction 1.2s, aim_spread ×1.8
  - Normal: vision ×1.0, reaction 0.5s, aim_spread ×1.0
  - Hard: vision ×1.25, reaction 0s, aim_spread ×0.65
- 메인 메뉴에 난이도 선택 UI 동적 추가 (StartBtn 위 `쉬움/보통/어려움` 버튼). 선택 시 금색 하이라이트.
- `spawn_entities()`: 봇 스폰 후 `apply_difficulty(DIFFICULTY_PARAMS[difficulty])` 호출.

**헤드리스 시뮬레이션 결과**

```
run 1: duration: 106s  zone_stage: 4  recover: 5   disengage: 11
run 2: duration: 52s   zone_stage: 2  recover: 13  disengage: 17
run 3: duration: 91s   zone_stage: 3  recover: 8   disengage: 14
```

---

## v0.7.2 — 2026-04-26

**HUD 스탯 아이콘 → Unicode 심볼 교체 + 픽업 비주얼 정리**

**Player.gd**

- `_stat_pair()`: `TextureRect` 픽셀 아트 아이콘 → `Label` Unicode 심볼로 교체. 아이콘별 형태가 명확히 구분됨.
  - ♥ 빨강 (heal), ◆ 금색 (medkit), ★ 노랑 (kill), ◇ 주황 (assist), ● 회색 (alive)
- `_make_stat_icon()` 함수 제거 (~37줄).

**Pickup.gd**

- `Sprite3D` 아이콘 빌보드 제거 — mesh + 텍스트 label 두 레이어로 정리 (기존 3레이어 → 2레이어).
- `_make_pickup_icon()` 함수 제거 (~45줄).
- 메시 형태 교체: HEAL `BoxMesh` → `CapsuleMesh`(알약), ARMOR `BoxMesh` → `CylinderMesh` 평원판(방패 대용).
- Label3D 텍스트에 Unicode 접두사 추가 (♥ heal, ◆ medkit, ◈ armor, ● ammo).
- 탄약 표시 `\n+%d` → `" +%d"` (줄바꿈 제거).

**헤드리스 시뮬레이션 결과**

```
run 1: duration: 44s   zone_stage: 2  recover: 1/7 (14%)
run 2: duration: 101s  zone_stage: 4  recover: 3/6 (50%)  disengage: 16  attack_max: 11.1s
```

---

## v0.7.1 — 2026-04-26

**Assist 버그 수정 + 아이템 픽셀 아이콘 시스템**

**Entity.gd**

- `die()` 내 어시스트 로깅: `log_combat_audit("assists", 1)` → `tel.metrics.session.assists += 1`. combat 그룹 게이트 제거 — 어시스트는 항상 session 레벨로 집계.

**Main.gd**

- `_on_bot_died()`: 킬피드 어시스트 판단에 `ASSIST_WINDOW_MS` 시간 창 체크 추가. 기존에는 `damage_history` 존재 여부만 체크해 5초 창 만료 후에도 "ASSIST" 표시됐음.

**Pickup.gd**

- `_update_visuals()`: 아이템 위 `Sprite3D` 아이콘 빌보드 추가. `pixel_size=0.028`, `TEXTURE_FILTER_NEAREST`.
- `_make_pickup_icon()` 추가: 아이템 타입별 20×20 픽셀 아트 생성.
  - HEAL: 빨간 십자가 / RARE(MedKit): 황금 십자가
  - ARMOR: 방패 형태 (상단 직사각형 + 하단 역삼각형)
  - AMMO: 총알 실루엣 (원뿔 머리 + 원통 몸체)
  - WEAPON: 총 실루엣 (손잡이 + 총신)

**Player.gd**

- HUD A구역 3행(스탯): 단일 `Label` → `HBoxContainer` + `[TextureRect 아이콘, Label 수치]` 쌍.
- `_stat_pair()` 헬퍼: 아이콘+수치 쌍을 컨테이너에 추가하고 수치 `Label` 반환.
- `_make_stat_icon()` 추가: 14×14 픽셀 아트.
  - heal: 빨간 십자가, medkit: 황금 십자가
  - kill: 노란 다이아몬드, assist: 주황 다이아몬드 테두리
  - alive: 회색 원
- 수치 레이블 5개 분리: `_stat_heal_val`, `_stat_mk_val`, `_stat_kill_val`, `_stat_asst_val`, `_stat_alive_val`.

**헤드리스 시뮬레이션 결과**

```
duration: 101s  zone_stage: 4  disengage: 15  stuck: 40  attack_max: 11.1s  recover: 1/7 (14%)
```

---

## v0.7.0 — 2026-04-26

**HUD 재설계 — ProgressBar 기반 HP/SH 상태바 + 킬피드 개선**

**Player.gd**

- A구역(좌상단) 2줄 레이아웃 도입: HP row / SH row (각 `ProgressBar` + 수치 `Label`) + stat row.
- `ProgressBar` + `StyleBoxFlat` 조합으로 SH=0일 때도 배경 테두리가 항상 표시됨.
- HP fill 색상: 초록(>40%) → 노랑(>20%) → 빨강 (프레임마다 갱신).
- B구역(중앙 상단) Zone 타이머: `PanelContainer` + 반투명 배경으로 A구역 겹침 방지.
- C구역(우상단) 킬피드: 플레이어 킬(★ 황금·22px) / 어시스트(◆ 주황·17px) / 봇끼리(회색·13px) 3단계 구분.
- 킬피드에 killer/victim 이름 표시. 플레이어 킬·어시스트는 4초 표시(봇끼리 2.5초).
- `hud_label`(기존 단일줄) 숨김 처리 유지.
- `_update_status_hud()` 함수로 정리 (HUD_MOCKUP 플래그 제거).

**Main.gd**

- `_on_bot_died()`: `bot.last_killer == player_ref` 킬 / `player_ref in bot.damage_history` 어시스트 판단 후 `add_kill_feed_entry()` 호출.

**Entity.gd**

- `var last_killer: Node3D = null` 추가. `die()` 내에서 `last_killer = killer` 설정.

**docs/UI_DESIGN.md** (신규)

- HUD 디자인 4단계 프로세스 문서: ASCII 스케치 → Godot 목업 → 스크린샷 검토 → 최종 구현.
- HUD 구역 정의(A/B/C/D), 목업 규칙, 스크린샷 체크리스트.

**헤드리스 시뮬레이션 결과**

```
duration: 69s  zone_stage: 2  disengage: 13  stuck: 5  attack_max: 7.2s
```

---

## v0.6.1 — 2026-04-26

**DISENGAGE 클러스터링 핫픽스 + 봇 상태 진단 텔레메트리**

**Bot.gd**

- `_disengage_cooldown: float` 추가. DISENGAGE 이탈 시 10초 쿨다운 설정.
- `change_state()`: DISENGAGE → 다른 상태 전환 시 `_disengage_cooldown = 10.0`.
- `handle_attack_state()`: DISENGAGE 진입 조건에 `_disengage_cooldown <= 0` 추가.
- `handle_recover_state()` patrol timeout: `log_tactics("patrol_timeout")` 추가.

**Telemetry.gd**

- `"patrol_timeout": 0` 추가. `log_tactics("patrol_timeout")` 케이스 추가. 리포트 출력 포함.

**Main.gd**

- `_print_bot_state_snapshot()` 추가 — 존 단계 전환 시 봇 상태분포(IDLE/CHASE/DISENGAGE 등) + 봇 간 평균 거리(avg_pairwise_dist) 콘솔 출력. 클러스터링 진단 전용.

**원인 분석**

데이터로 확인한 자기강화 사이클:
1. 봇 A·B가 서로를 적으로 인식 → 둘 다 DISENGAGE 진입
2. 같은 커버(중앙 바위)로 이동 → 합류
3. 합류 후 서로 2명 이상 보임 → DISENGAGE 재진입 반복
4. 전체 봇이 동일 위치에 집적, stuck 연쇄 발생

쿨다운으로 3번 사이클 차단 → 사이클 해소.

**헤드리스 시뮬레이션 결과 (3회)**

```
stuck 325 → 8~11  |  disengage 206 → 15~17
avg_pairwise_dist @stage2: 2.9m → 27~30m
매치 시간: 57~106s
```

---

## v0.6.0 — 2026-04-26

**전술 의식 — 수적 열세 감지, DISENGAGE 상태, 커버 탐색**

**Bot.gd**

- `State` 열거형에 `DISENGAGE` 추가.
- `_disengage_cover: Vector3` 변수 추가 — 현재 커버 목표 위치 캐시.
- `handle_attack_state()`: `_count_visible_enemies() >= 2` 조건 추가 → DISENGAGE 진입. Telemetry `disengage_triggered` 기록.
- `handle_disengage_state(delta)` 추가:
  - 가시 적 1명 이하 + 2초 경과 → CHASE/IDLE 복귀.
  - 탄약 없음 → RECOVER. 8초 타임아웃 → IDLE.
  - `_find_cover_point()` 호출 → 위협 반대편 장애물 뒤로 이동.
  - 커버 없으면 `_scatter_dir_from()`으로 산개.
- `_count_visible_enemies() -> int`: `perception_meters` 순회, 값 >= 1.0인 생존 Entity 수 반환.
- `_find_cover_point(threat_pos) -> Vector3`: "obstacles" 그룹 노드 순회, 위협 반대편 2m 지점 계산, 현재 위협 거리보다 멀어지는 위치만 채택, 봇에서 가장 가까운 것 반환.
- `change_state()`: DISENGAGE 진입 시 `_disengage_cover = Vector3.ZERO` 초기화.
- `_update_stuck()`: DISENGAGE를 이동 상태(`is_moving_state`)에 포함.

**WorldBuilder.gd**

- `generate_world()` else 분기: `obs.add_to_group("obstacles")` 추가 (canyon_wall, tree_cluster, log_pile).
- `_build_rock_cluster()`: `root.add_to_group("obstacles")` 추가.

**Telemetry.gd**

- `tactics` 딕셔너리에 `"disengage_triggered": 0` 추가.
- `log_tactics()`: `"disengage_triggered"` 케이스 추가.
- `_print_report()`: `Disengage triggers` 출력 추가.

**헤드리스 시뮬레이션 결과**

```
MATCH REPORT (rank #1 | 126s)
Kills: 0, Win: YES, Zone stage: 5
Shots: 113, Damage: 1311.2, Longest attack bout: 15.5s
Disengage triggers: 123, Recover bouts: 2 (50% success), Stuck: 141
Weapon drops: 10, Heals used: 12
```

disengage_triggered 123 확인 (DISENGAGE 상태 정상 동작). stuck 141은 커버 이동 중 벽 충돌 증가로 인한 예상 범위.

---

## v0.5.1 — 2026-04-26

**전장 경제 2차 — 쉴드 너프, 드랍 분리, 힐 2단계, 킬 집계 수정, 벽 투명화 수정**

**StatsData.gd**

- `max_shield` 100 → 50. `advanced_heals: int = 0` 필드 추가.

**Entity.gd**

- 초기 쉴드 0 (`current_shield = 0.0`). 방어구 아이템 파밍 전까지 쉴드 없음.
- **킬 집계 수정**: `take_damage()`의 `log_kill` 제거. `die()`에서 killer가 "players" 그룹일 때만 `log_kill` 호출 (단일 집계). 봇-봇 킬이 플레이어 킬로 잘못 집계되던 버그, 이중 집계 모두 해소.
- `last_damage_weapon`, `last_damage_dist` 변수 추가 → `die()` 에서 weapon/dist 정보 활용.

**Pickup.gd**

- HEAL 수집 시 rarity 분기: RARE → `stats.advanced_heals += 1`, COMMON → `stats.heal_items += 1`.

**Bot.gd**

- `_drop_weapon()`: 장전량 `max_ammo / 3`으로 고정 (실제 탄약은 분리 드랍).
- `_drop_ammo()` 추가: `stats.current_ammo + reserve_ammo`를 AMMO 픽업으로 스폰.
- `_drop_heals()` 추가: `heal_items` COMMON 픽업, `advanced_heals` RARE 픽업 스폰.
- `die()`: `_drop_ammo()`, `_drop_heals()` 호출 추가.
- `use_heal()`: `advanced_heals > 0`이면 먼저 소비(+60 즉시), 없으면 `heal_items`(+30).
- 힐 사용 조건에 `advanced_heals > 0` 포함.

**Player.gd**

- `die()` 오버라이드: 모든 무기 슬롯 → WEAPON + AMMO 분리 드랍, heal/advanced_heals 드랍 후 super 호출.
- `handle_healing()`: advanced 우선 소비(즉시 +60 HP), 기본은 점진 회복(`_heal_regen += 30`).
- `_heal_regen` + `HEAL_REGEN_RATE = 10.0` — `_physics_process`에서 10 HP/s로 재생.
- **벽 투명화 수정**: `_current_occluders`(frame-exact) → `_occluder_linger` (8프레임 지연 복원). 깜빡임 해소. fade 알파 0.2 → 0.35, 레이 스텝 0.05 → 0.1.
- **킬피드 통합**: `add_kill_feed_entry(by_player)` — 플레이어 킬: 노란색 `▶ ELIMINATED`, 그 외: 회색 `Bot Eliminated`. 최대 6개 유지.
- **HUD 킬/어시스트 실시간 표시**: Telemetry에서 읽어 `K:%d A:%d` 형식으로 표시.
- HUD 포맷: `HP | SH | MK H | K A | Alive`.

**Main.gd**

- `_on_bot_died()`: 모든 봇 사망 시 `add_kill_feed_entry(by_player)` 호출. damage_history로 플레이어 관여 여부 판단.
- `_categorize_templates()`: `heal_advanced_pickup.tres`를 consumable pool에 추가 (1/7 확률).
- `HEAL_ADVANCED_ITEM` const 추가.

**armor_pickup.tres**: amount 40 → 20.
**heal_advanced_pickup.tres**: 신규 생성 (RARE, amount=1, gold color).

**헤드리스 시뮬레이션 결과**

```
MATCH REPORT (rank #1 | 88s)
Kills: 0 (정상 — 헤드리스에서 플레이어 직접 킬 없음), Win: YES
Zone stage: 3, Weapon drops: 10, Heals used: 11, Rare pickups: 13
```

---

## v0.5.0 — 2026-04-26

**전장 경제 1차 — 스폰 수정, 벽 투명화, 자기장 강화, 칼 이펙트, 봇 칼 돌진**

**Main.gd**

- **스폰 끼임 해소**: `_is_clear_of_obstacles()` — 이전엔 `rock_cluster`/`canyon_wall`만 체크, 이제 `bush_patch`만 제외하고 모든 솔리드 타입 차단. `_is_clear_of_entities()` 추가 — 기존 스폰 위치와 3.5m 이내 겹침 방지. `_get_safe_spawn_pos()`에서 중앙 5m 이내 제외(`randf_range(5.0, spawn_radius)`).
- **자기장 피해 누적 강화**: `_zone_outside_time: Dictionary` (entity id → 누적 초). 틱당 `time_mult = 1.0 + min(seconds_outside, 10.0) * 0.1` → 10초 후 2× 상한. 자기장 내 진입 시 누적 초기화. 봇 사망 시 딕셔너리 항목 정리.

**WorldBuilder.gd**

- **occluder 그룹 태깅**: `_add_wall()`, `_add_rock_piece()`, 일반 장애물 인스턴스에 `add_to_group("occluder")` 추가 — 벽 투명화 레이캐스트 감지 대상.

**Player.gd**

- **벽 투명화**: `_handle_wall_transparency()` — 카메라→플레이어 방향으로 최대 5회 반복 레이캐스트. `occluder` 그룹 노드의 MeshInstance3D를 감지하면 알파 0.2 페이드. `_current_occluders` 딕셔너리로 변경 감지(전환 시에만 적용/복원). `_fade_mat_cache`로 메시당 1회만 머티리얼 복사.
- **칼 타격 이펙트**: `_melee_attack()`에서 명중 시 `ImpactEffect` 스폰 + `Sfx.play("hit", hit_pos)`.

**Bot.gd**

- **봇 칼 돌진 결정**: 탄약 소진 시 `hp_ratio > 0.35 and dist < attack_range * 0.6 and randf() < hp_ratio * 0.5` 조건 만족하면 `_knife_mode = true`. 미충족 시 기존 RECOVER 전환.
- **`_knife_mode` 동작**: ATTACK 상태에서 대상을 향해 돌진하며 `MELEE_RANGE * 1.2` 이내 접근 시 `_bot_melee()` 호출. HP 25% 미만 시 자동 탈출 → RECOVER. `change_state()` 시 ATTACK 이탈이면 플래그 초기화.
- **`_bot_melee()`**: 쿨다운 0.65s, 범위 1.8m, 피해 20. 명중 시 `ImpactEffect` 스폰 + `Sfx.play("hit")`.

**헤드리스 시뮬레이션 결과**

```
MATCH REPORT (rank #1 | 100s)
Kills: 9, Win: YES, Zone stage reached: 4
Deaths by stage: {"1": 5, "2": 3, "3": 2, "4": 1}
Weapon drops: 10 (= kills count)
```

---

## v0.4 — 2026-04-24

**봇 AI 개선 + Telemetry 재설계**

→ 테스팅 프로세스 전반은 [TESTING.md](TESTING.md) 참조

**봇 AI (Bot.gd)**

- **끼임 방지**: `_update_stuck()` — velocity < 0.35 가 1초 지속되면 봇 방향의 수직 방향으로 0.65초 burst 이동. `_move_or_unstick()`으로 모든 이동 상태에서 자동 적용.
- **분산 도주**: `_scatter_dir_from()` — `get_instance_id() % 8 * 45°` 각도 오프셋으로 각 봇이 개인화된 방향으로 도주. 여러 봇이 같은 벽에 몰리는 현상 방지.
- **봇 예비 탄약**: `reserve_ammo` 변수 추가. `receive_ammo()` 구현 — 탄약 픽업 시 직접 탄창에 넣는 대신 reserve에 적립. `change_state(RECOVER)` 진입 시 reserve > 0이면 즉시 `_try_reload()`하고 IDLE 복귀 (RECOVER 건너뜀).
- **RECOVER 3단계**: seek_cover(2.5s, scatter 도주) → seek_loot(탐색 반경 70, 4s) → patrol(랜덤 존 포인트 순회, 8s 타임아웃).
- **피격 강제 후퇴**: `take_damage()` 오버라이드 — 탄약 없는 봇이 피격되면 RECOVER 강제 전환.
- **사망 시 무기 드롭**: `die()` 오버라이드 → `_drop_weapon()` — 봇 사망 시 현재 무기를 Pickup 씬으로 스폰.

**Telemetry 재설계 (Telemetry.gd)**

기존 구조의 문제점을 전면 정리:

- `stages.match_summary` 블록 제거 (tactics/combat과 중복)
- `log_damage`, `log_shot` 실제 구현 (기존 no-op)
- `log_supply_event("telegraph")` 케이스 추가 (기존 누락)
- 죽은 스텁 제거: `log_state_duration`, `log_state_transition`, `log_engagement`, `log_loot`
- **그룹 토글 시스템**: `enabled_groups` 딕셔너리로 core / combat / tactics / economy / supply 개별 ON/OFF
- **JSON 출력**: `end_match()` 시 `user://sim_result_latest.json` 자동 저장 (QA 스크립트 연동용)
- **v0.4 신규 지표**: stuck_triggered, reserve_reload, patrol_entered, weapon_drop_spawned

**다음 버전 예고 (v0.5)**

- outnumbered 감지 + DISENGAGE 상태
- 실제 엄폐물 탐색 (obstacles 그룹 기반)
- 봇 무기 다양화 (스폰 시 랜덤 배정)
- 자기장 피해 플레이어에게도 적용

---

## v0.3.2 — 2026-04-24

**탄창 + 예비 탄약 2단계 시스템**

탄약 아이템을 주워도 바로 탄창이 채워지던 구조를 전면 개편했다. 핵심 동기는 "탄약을 줍는 것이 의미 없다"는 피드백 — 탄창이 가득 차 있으면 탄약 아이템이 완전히 낭비였기 때문이다.

**구조 변경**
- `slot_ammo[]` (탄창) + `slot_reserve[]` (예비/백팩) 두 배열로 분리
- 무기 습득 시 `current_ammo` = .tres에 적힌 값 (~1/3 탄창), `reserve = 0`
- 탄약 픽업 → `receive_ammo()` → `slot_reserve` 증가 (cap: `_get_reserve_max()`)
- R키 → `_start_reload()`: 이동 가능한 양 계산 후 `reload_ammo_start/target` 저장, 타이머 시작
- `_process()`에서 `lerp(start, target, progress)`로 카운트업 애니메이션
- `_finish_reload()`: `slot_ammo = target`, `slot_reserve -= transferred`

**무기 밸런스 (.tres 파일 직접 수정)**
| 무기 | 탄창 | 예비 max | 장전 시간 |
|---|---|---|---|
| 피스톨 | 15 | 30 | 1.3s |
| AR | 30 | 60 | 2.0s |
| 샷건 | 6 | 12 | 2.8s |
| 레일건 | 3 | 6 | 4.5s |

**macOS 빌드 fix**  
`export_presets.cfg`에서 bundle identifier 키가 `application/identifier`로 되어 있어 Godot 4.6이 "identifier is missing"으로 읽지 못했다. `application/bundle_identifier`로 수정 후 빌드 통과. `project.godot`에 `textures/vram_compression/import_etc2_astc=true` 추가 (Universal 빌드 요구사항).

**릴리즈**: Windows + macOS Universal 동시 출시. README에 배지 형태 다운로드 링크 추가.

---

## v0.3.1 — 2026-04-24

**중복 무기 방지 + R키 리로드**

- `receive_weapon()`: 루프로 같은 `weapon_type` 이미 보유 시 `return false` → `Pickup.collect()`에서 `queue_free()` 호출 안 함 (아이템 바닥에 유지)
- `_start_reload()` / `_finish_reload()`: 무기별 장전 시간 다름 (`_get_reload_time()`)
- HUD 슬롯 레이블 `"ammo/max"` 형식, 25% 이하 노란색, 0발 빨간색

**수정한 버그**
- 레일건이 피스톨로 표시되던 문제: `super_weapon_stats.tres`에 `weapon_type = "railgun"` 누락이 원인. 추가로 수정.
- 슬롯바가 화면 아래로 잘리는 문제: `grow_vertical = GROW_DIRECTION_BEGIN` 추가.

---

## v0.3.0 — 2026-04-24

**5슬롯 무기 인벤토리**

기존 단일 무기에서 5슬롯(K/1/2/3/4)으로 전환. slot 0은 칼(항상 보유), slot 1~4는 주운 총기.

- `weapon_slots[]: Array` + `slot_ammo[]: Array` 관리
- `_make_weapon_icon(wtype)`: 28×14 픽셀 아트를 `Image.set_pixel()`로 절차적 생성 (칼/피스톨/AR/샷건/레일건 각 고유 모양)
- `HBoxContainer` + `PanelContainer` per slot, `PRESET_CENTER_BOTTOM` + `GROW_DIRECTION_BEGIN`
- 무기/탄약/힐/방어구 픽업 비주얼 차별화: 각각 다른 Mesh + emission 색상
- `ammo_weapon_type` 필드를 `ItemData`에 추가 → 종류별 탄약 픽업 분리

**기본 피스톨 지급**  
`_ready()`에서 `receive_weapon(PISTOL_STATS.duplicate())` 호출. 플레이어가 빈손으로 시작하지 않음.

---

## v0.2.1 — 2026-04-23

**버그 수정 패치**

- 웅크리기: hold 방식 → `KEY_C` 토글 방식으로 변경
- 풀숲 높이 1.0 → 2.0 (플레이어 캡슐 높이와 맞춤), 알파 0.4 → 0.55
- 웅크릴 때 메시가 바닥으로 꺼지는 현상: `_mesh_origin_y`를 `_ready()`에서 저장해두고, 웅크리기 해제 시 복원
- Godot 4 컴파일 에러 수정: `PRESET_TOP_CENTER` → `PRESET_CENTER_TOP`

---

## v0.2.0 — 2026-04-23

**Tier 1 + Tier 2 컨텐츠**

- 보급 캡슐 (Supply Drop): 존 stage 2 시작 시 맵 중앙에 낙하, 레일건 포함
- 스텔스 시스템: `stealth_modifier`, 풀숲(Bush) `is_in_bush`, 웅크리기 감지율 감소
- 인식 게이지(perception_meters): 0→1 점진적 감지, 시야 + FOV + LOS 체크
- 미니맵 UI
- 기록(Records) 화면: Telemetry 기반 매치 히스토리
- 스폰 핫스팟 기반 아이템 배치 (mapSpec POI 활용)

---

## v0.1.0 — 2026-04-23

**초기 프로토타입**

- CharacterBody3D 기반 플레이어/봇 이동 (WASD + 마우스 조준)
- 봇 AI: IDLE / CHASE / ATTACK 상태 머신
- 자기장(Zone): 수축 + 틱 데미지
- 아이템 픽업: 무기, 힐, 방어구
- 절차적 사운드: `AudioStreamWAV` 버퍼를 코드로 생성 (발사/피격/치유 등)
- MapSpec JSON 파서 + WorldBuilder 절차적 맵 배치
- Telemetry: 데미지/킬/경제 통계 로컬 저장

---

## 다음 버전 예고 (v0.4)

- 봇 끼임 방지 (`stuck_timer` 우회 로직)
- 봇 분산 도주 (`get_instance_id()` 기반 개인화 각도)
- 봇 reserve ammo + 리로드 (RECOVER 시 reserve 먼저 확인)
- 봇 사망 시 무기 드롭
- 루팅 탐색 반경 확대 (35 → 70) + 패트롤 서브스테이트
