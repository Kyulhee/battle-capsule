# 배틀캡슐 개발 일지

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
