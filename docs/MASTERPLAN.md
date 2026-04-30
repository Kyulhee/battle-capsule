# 배틀캡슐 마스터 플랜

> 마지막 업데이트: 2026-04-30 (v1.3 완료, v1.4 로드맵 확정)  
> 이 문서는 AI 에이전트 간 인수인계 및 장기 방향 공유를 위해 작성되었습니다.

## 현재 상태

**현재**: v1.3 완료 — 다음: v1.4 (Pressure Mission Redesign)

**문서 구조** *(각 파일의 업데이트 시점 기준 → [CLAUDE.md](../CLAUDE.md))*

- [CLAUDE.md](../CLAUDE.md) — 세션 시작 시 온보딩 (현재 상태, 핵심 파일, 퀵 커맨드)
- [MASTERPLAN.md](MASTERPLAN.md) — 전체 로드맵 & 설계 원칙 ← 지금 여기
- [DEVLOG.md](DEVLOG.md) — 버전별 구현 상세 (완료된 것)
- [TESTING.md](TESTING.md) — 헤드리스 시뮬레이션 검증 (구현 후 실행)
- [RELEASE.md](RELEASE.md) — 빌드 → GitHub 릴리즈 → README 업데이트

---

## 프로젝트 개요

**배틀캡슐 (Battle Capsule)** — Godot 4.6.2 / GDScript, 쿼터뷰 배틀로얄 프로토타입.

- 플레이어 1명 vs 봇 11명, 자기장이 좁아지며 최후의 1인 생존
- 장르 포지셔닝: **캡슐형 전술 로그라이트 배틀로얄** — 매 판 조건이 달라지는 짧은 전술 실험장
- 숲 맵 1개 (MapSpec JSON 기반, WorldBuilder 절차적 생성)
- Windows / macOS Universal 동시 출시 목표
- 프로젝트 저장소: `https://github.com/Kyulhee/battle-capsule`

**핵심 설계 원칙**

1. 절차적 우선 — 에셋보다 코드 생성으로 빠른 이터레이션
2. 상태 머신 AI — 봇은 State enum + 핸들러 함수 구조로 확장 가능하게 유지
3. 데이터 분리 — 무기/아이템/미션/아티팩트 밸런스는 Resource 파일에서 관리, 코드 수정 최소화
4. 난이도는 파라미터 — AI 행동을 하드코딩하지 않고 변수로 노출해 난이도 시스템으로 연결
5. 헤드리스 검증 우선 — 새 기능은 Telemetry 훅 → 시뮬레이션 통과 후 릴리즈

---

## 코드베이스 구조

```
src/
├── core/
│   ├── StatsData.gd            # 무기/캐릭터 스탯 Resource
│   ├── ItemData.gd             # 아이템 정의 Resource
│   ├── SoundManager.gd         # 절차적 오디오 생성 (Autoload: Sfx)
│   ├── Telemetry.gd            # 매치 통계 기록 (Autoload: Telemetry)
│   ├── MapSpec.gd              # JSON 맵 스펙 파서
│   ├── pistol_stats.tres / bot_stats.tres / player_stats.tres / super_weapon_stats.tres
├── entities/
│   ├── Entity.gd               # HP, 방어막, 인식 시스템, 이동 (CharacterBody3D 기반)
│   ├── player/Player.gd        # 입력, 무기 슬롯(5슬롯), HUD, 재장전
│   ├── bot/Bot.gd              # AI 상태 머신 + NavigationAgent3D
│   └── pickup/Pickup.gd        # 아이템 픽업 (Area3D)
├── items/                      # .tres 아이템 정의 파일
├── maps/
│   └── WorldBuilder.gd         # MapSpec을 읽어 맵 오브젝트 생성 (jitter 지원)
├── environment/
│   ├── Bush.gd                 # 풀숲 (스텔스 영역)
│   └── WorldElement.gd         # 맵 환경 요소 기반
├── fx/                         # MuzzleFlash, BulletTrail, ImpactEffect 등
├── ui/
│   └── Minimap.gd              # 타입별 장애물 표현 (rock→원, bush→반투명 연두 등)
└── Main.gd                     # 게임 루프, 존, 스폰, 보급 캡슐, NavigationRegion3D 베이크
data/
└── mapSpec_example.json        # 맵 POI 및 배치 정보 (v3.0 — 3링 구조)
```

---

## 핵심 시스템 요약

### 무기 인벤토리 (Player.gd)

- 5슬롯: slot 0 = 칼(항상), slot 1~4 = 총기
- `weapon_type`: pistol / ar / shotgun / (railgun = super_weapon)
- R키 → `_start_reload()`: reserve → ammo 이동, 장전 시간 중 카운트업 애니메이션
- 같은 weapon_type 중복 습득 불가

### 봇 AI (Bot.gd)

상태 머신: `IDLE → CHASE → ATTACK → RECOVER → ZONE_ESCAPE → DISENGAGE`

| 상태 | 전환 조건 |
|---|---|
| IDLE | 적 없음, 루팅 없음 |
| CHASE | 적 발견(ammo > 0) 또는 픽업 목표 |
| ATTACK | engage 거리 이내 |
| RECOVER | ammo == 0 (seek_cover → seek_loot 서브스테이트) |
| ZONE_ESCAPE | 자기장 밖 감지 (최우선) |
| DISENGAGE | 수적 열세 또는 HP 임계 이하 |

모든 이동: `NavigationAgent3D` 기반 pathfinding (`_nav_move_toward()` 헬퍼). 경로 없을 때 `_move_or_unstick()` fallback.

**DISENGAGE 커버 품질**: `collision_layer & 8`(높이 >2.5m) 필터 + 인스턴스별 섹터 분산 + 크라우딩 패널티. 4인 이상 감지 시 scatter 후퇴.

### 봇 성격 (현재 3종, v1.6에서 4종으로 확장 예정)

| 성격 | 특징 |
|---|---|
| aggressive | vision_range↑, 반응↑, DISENGAGE 임계 높음 |
| defensive | DISENGAGE 적극 활용, 엄폐 우선 |
| scavenger | RECOVER 반경↑, 루팅 우선 |

### 인식 시스템 (Entity.gd)

- `perception_meters: Dictionary` — 대상별 0.0~1.0 감지 게이지
- 시야 범위 + FOV 각도 + LOS 레이캐스트
- `stealth_modifier`: 풀숲/웅크리기 시 감소
- `_can_i_see(target)`: 실시간 LOS | `is_revealed_to(viewer)`: 게이지 1.0 도달 여부

### 존 & 보급 (Main.gd)

- 자기장 4단계 수축. 피해: 2/5/10/15 per tick. 반경: 50 → ×0.6 per stage
- zone escape 임계: stage 1 = 0.95, stage 4+ = 0.80
- stage 2에서 supply 캡슐 낙하 (희귀 무기 포함)

### 점수 시스템

`(max(0, 1000-(rank-1)×80) + kills×100 + assists×40 + 300 if win) × DIFF_MULT`  
DIFF_MULT = [1.0, 1.5, 2.5, 4.0] (쉬움/보통/어려움/지옥)

### 사운드 (SoundManager.gd)

절차적 오디오 — 파일 없이 코드로 WAV 버퍼 생성.  
`Sfx.play("shoot")` / `Sfx.play("shoot", global_position)` (3D 공간음)

---

## 릴리즈 히스토리

| 버전 | 날짜 | 핵심 내용 |
|---|---|---|
| v0.1.0 | 2026-04-23 | 초기 프로토타입: 봇 AI, 자기장, 기본 루팅 |
| v0.2.0 | 2026-04-23 | 보급 캡슐, 스텔스/풀숲, 미니맵, 기록 화면 |
| v0.2.1 | 2026-04-23 | 웅크리기 버그 수정, 풀숲 높이/투명도 수정 |
| v0.3.0 | 2026-04-24 | 5슬롯 무기 인벤토리, 픽셀 아이콘, 픽업 비주얼 |
| v0.3.1 | 2026-04-24 | 중복 무기 방지, R키 리로드, 탄약/최대 HUD |
| v0.3.2 | 2026-04-24 | 탄창+예비 2단계 탄약, 무기 밸런스, macOS 출시 |
| v0.4.0 | 2026-04-25 | 봇 AI 개선(끼임/분산/reserve), Telemetry 재설계, 헤드리스 시뮬레이션 |
| v0.5.0 | 2026-04-26 | 스폰 수정, 벽 투명화, 자기장 누적 강화, 칼 이펙트, 봇 칼 돌진 |
| v0.5.1 | 2026-04-26 | 쉴드 너프, 드랍 분리, 힐 2단계, 킬 집계 수정, 킬피드 전체 표시 |
| v0.6.0 | 2026-04-26 | DISENGAGE 상태, 수적 열세 감지, 장애물 그룹 기반 커버 탐색 |
| v0.6.1 | 2026-04-26 | DISENGAGE 클러스터링 핫픽스, Alive 버그 수정, 킬피드 개선 |
| v0.7.0 | 2026-04-26 | HUD 재설계 — ProgressBar HP/SH, Zone 패널, 킬피드 3단계 |
| v0.7.1 | 2026-04-26 | 아이템 픽셀 아이콘, HUD 스탯 아이콘, assist 버그 수정 |
| v0.7.2 | 2026-04-26 | HUD 스탯 Unicode 심볼 교체, 픽업 Sprite3D 제거, 메시 형태 개선 |
| v0.8.0 | 2026-04-26 | 봇 성격 3종, 집단 공격 강화, 발소리 감지, 루팅 우선순위, 난이도 시스템 |
| v0.8.1 | 2026-04-27 | 전체 메뉴 UI 재설계 (그라디언트 배경, 픽셀 캡슐 로고, 키캡 How to Play) |
| v0.8.2 | 2026-04-27 | Zone escape 강화 (95% 조기 탈출, 각도 샘플링 unstuck, zone death 텔레메트리) |
| v0.8.3 | 2026-04-27 | HUD safe margin, 킬피드-미니맵 겹침 제거, 난이도 툴팁, Result 버튼 3종 |
| v0.8.4 | 2026-04-27 | display_name/kill_streak, 킬피드 weapon glyph + 봇 번호 + streak 표시 |
| v0.9.0 | 2026-04-27 | 봇 상태 아이콘(? ! ◉ ◎), 히트 마커, 피해 숫자 플로팅, 자기장 경고 오버레이 |
| v0.9.1 | 2026-04-27 | Zone escape stuck 버그 수정 — 에스컬레이션 thrash, 스테이지별 조기 진입 임계값 |
| v0.9.2 | 2026-04-27 | Hell Difficulty — HP 1 시작, 힐 감소, 암전(15–28s), 폭격(18–28s, r=5, 45dmg) |
| v0.9.3 | 2026-04-28 | Hell 랜덤 모디파이어 (SHIELD_OFF/BARRAGE/ALL_AGGRESSIVE) + 난이도별 봇 주변 인식 |
| v0.9.4 | 2026-04-28 | ESC 일시정지 메뉴, 직접 재시작, Hell 안내 dismiss, 설정 메뉴, 결과 DAMAGE |
| v0.9.5 | 2026-04-29 | 점수 시스템(난이도 배율×1/1.5/2.5/4), 난이도별 Records 탭, Hard+ 봇 전투 점프/스트레이프 |
| v1.0   | 2026-04-29 | NavigationRegion3D + NavigationAgent3D 봇 pathfinding 전환 |
| v1.1   | 2026-04-29 | 미니맵 타입별 표현(rock→원, bush→반투명 연두), mapSpec v3.0(3링), WorldBuilder jitter |
| v1.2   | 2026-04-29 | 봇 DISENGAGE 클러스터링 해소 — 커버 높이 필터, 섹터 분산, 4인↑ scatter |
| v1.3   | 2026-04-30 | Challenge Mission System — 15미션, 미션선택UI, 배지저장, Telemetry mission 그룹 |
| v1.4.0 | 2026-04-30 | Pressure Mission Redesign — HARD/HELL pool 17종, 압박 미션 시스템, 랜덤 보너스 배정 |
| v1.4.1 | 2026-04-30 | Mission UI/UX — HUD 두 줄, 실패 확정 빨간 표시, Flash 알림, SCAVENGER/MEDIC 재조정 |

---

## 로드맵

> 각 버전의 규모 표기: **S(소)** = 파일 2~3개 집중 수정 / **M(중)** = 새 시스템 1개 추가 / **L(대)** = 새 시스템 + 연동 UI + 저장

---

### ~~v1.3 — Challenge Mission System~~ ✅ 2026-04-30

**한 줄 요약**: 단순 생존 외의 플레이 목적을 만든다.

**핵심 변경 파일**
- `src/core/MissionData.gd` (신규 Resource)
- `src/core/MissionTracker.gd` (신규 — Main Autoload 또는 _ready 내부)
- `src/core/Telemetry.gd` (훅 추가)
- `src/Main.gd` (미션 선택 화면 진입, 결과 연동)
- `src/entities/player/Player.gd` (인게임 미션 HUD)
- `user://achievements.json` (신규 저장 파일)

**구현 순서** *(이 순서로 나눠야 디버깅이 쉬움)*
1. `MissionData` 리소스 정의 (condition_type enum, target_value, badge_id) — UI 없이 데이터만
2. Telemetry 훅 추가 (kill_with_weapon, heal_used, survive_seconds 등) — 헤드리스로 훅 발화 확인
3. `MissionTracker` — 활성 미션 1개 유지, 조건 충족 판정, badge 저장
4. 미션 선택 UI (매치 전 화면)
5. 인게임 진행도 HUD (1줄 라벨)
6. 결과 화면 미션 성공/실패 표시

**미션 목록 (15개)**

| 카테고리 | 미션 | 조건 |
|---|---|---|
| 기본 | First Blood | 첫 킬 기록 |
| 기본 | Clean Win | 1등 + HP 50 이상 |
| 기본 | Medic Run | 치료 아이템 3회 이상 사용 후 승리 |
| 기본 | Scavenger | 무기 3종 이상 획득 |
| 기본 | Survivor | 킬 없이 90초 생존 |
| 무기 | Pistol Only | 피스톨만 사용해 승리 |
| 무기 | Knife Finish | 마지막 적을 칼로 처치 |
| 무기 | Shotgun Rush | 샷건으로 3킬 |
| 무기 | Railgun Moment | 레일건으로 한 방 킬 |
| 전술 | Bush Hunter | 수풀 안/근처에서 2킬 |
| 전술 | Zone Walker | 자기장 밖에서 10초 이상 생존 후 승리 |
| 전술 | Supply Thief | 보급 캡슐 근처에서 적 처치 |
| 전술 | Ambush | 봇이 플레이어를 완전 인식하기 전 처치 |
| 전술 | Outnumbered | 2명 이상에게 감지된 상태에서 킬 |
| Hell | Hell Champion | Hell 난이도 승리 |

> Blackout Kill / Bomb Dodge는 Hell 이벤트 조건 추적이 필요해 2차 미션 풀로 보류.

**헤드리스 검증 기준**
- 활성 미션 선택 없이 매치 진행 시 기존 동작 변화 없음
- 미션 조건 훅이 Telemetry에 기록됨 (sim_result에 `active_mission`, `mission_progress` 필드)
- achievements.json이 corrupt 없이 저장/로드됨

---

### v1.4 — Pressure Mission Redesign `M`

**한 줄 요약**: 매치 중 위험한 행동을 강요하거나 안전한 선택을 금지하는 압박 미션으로 긴장감을 높인다.

**설계 원칙**
- 나쁜 조건: "힐 사용하기" "자기장 안 있기" — 수동적으로 달성 가능
- 좋은 조건: "힐 금지" "자기장 밖으로 나가기" — 위험 감수 필요

**핵심 변경 파일**
- `src/core/MissionTracker.gd` (압박 미션 pool, 추적 로직 대폭 확장)
- `src/Main.gd` (미션 선택 UI 제거, 랜덤 배정, zone 단계 hook, 결과 적용)
- `src/entities/player/Player.gd` (pressure HUD, railgun_unlimited 플래그, 힐 픽업 금지 플래그)

**시스템 구조**

| 요소 | 내용 |
|---|---|
| 보너스 미션 | 매치 시작 시 자동 랜덤 배정 1개 (기존 15개 pool), 성공 시 +500점 + 배지 |
| 압박 미션 | zone_stage 증가마다 트리거, 달성 시 즉각 리워드, 실패 시 즉각 패널티 |
| 어려움 | 보너스 미션 + HARD_POOL 압박 미션 (opt-in 토글) |
| 지옥 | 보너스 미션 + HELL_POOL 압박 미션 (강제) |

**HARD_POOL — 8종 (단일 조건)**

| ID | 제목 | 조건 | 성공 리워드 | 실패 패널티 |
|---|---|---|---|---|
| h_kill | 계약 킬 | 킬 1 | 전 탄약 풀충전 | 전 탄약 전소 |
| h_no_heal | 금욕 | 힐 사용 금지 *(위반→즉시 실패)* | 방어막 +50 | 다음 존 힐 픽업 불가 |
| h_zone_dare | 존 도전자 | 자기장 밖 5초 이상 체류 | HP +40 | 즉시 존 피해 40 |
| h_no_dmg | 무결 | 피해 0 *(존 피해 포함)* | 방어막 +50 | HP -30 |
| h_stealth_kill | 은신 사냥 | 미탐지 킬 1 | 전 봇 awareness 초기화 | 1존 동안 전 봇 감지 상태 |
| h_melee_kill | 칼잡이 | 칼로 킬 1 | 전 탄약 풀충전 | 활성 슬롯 탄약 전소 |
| h_target_practice | 표적 생존 | 봇 2마리+ 감지 상태에서 10초 생존 | 힐 +1 + 방어막 +30 | HP -20 |
| h_zone_kill | 경계선 | 자기장 밖에서 킬 1 | HP 전회복 | HP -40 즉시 |

**HELL_POOL — 9종**

Hell-A: 조건 강화

| ID | 제목 | 조건 | 성공 리워드 | 실패 패널티 |
|---|---|---|---|---|
| ha_kill2 | 이중 계약 | 킬 2 | 레일건 무제한 (1 존) | 탄약 전소 + HP -20 |
| ha_no_heal_nodmg | 완벽한 금욕 | 힐 금지 + 피해 0 | HP 전회복 | HP -50 |
| ha_zone_dare_long | 지옥 존 | 자기장 밖 10초 + 킬 1 | HP 전회복 + 방어막 +50 | HP -50 |

Hell-B: 콤보 조건 (AND)

| ID | 제목 | 조건 | 성공 리워드 | 실패 패널티 |
|---|---|---|---|---|
| hb_stealth_clean | 완벽한 암살 | 미탐지 킬 1 + 피해 0 | 레일건 무제한 + 힐 +2 | 전 봇 감지 + HP -30 |
| hb_no_heal_2kill | 금욕 학살 | 힐 금지 + 킬 2 | 레일건 무제한 + 힐 +3 | 힐 전소 + HP -30 |
| hb_melee_nodmg | 무적 칼잡이 | 칼 킬 1 + 피해 0 | HP 전회복 + 방어막 +50 | HP -40 |

Hell-C: 특수 조건

| ID | 제목 | 조건 | 성공 리워드 | 실패 패널티 |
|---|---|---|---|---|
| hc_blood_pact | 피의 계약 | HP 30% 이하에서 킬 1 | 레일건 무제한 + HP 전회복 | 현재 HP 절반 |
| hc_berserker | 광전사 | 봇 3마리+ 감지 상태에서 킬 1 | 레일건 무제한 + HP 전회복 | HP -50 |
| hc_zone_massacre | 존 바깥의 학살 | 자기장 밖에서 킬 2 | HP 전회복 + 방어막 +50 + 힐 +1 | HP -50 즉시 |

**신규 조건 타입**: `NO_HEAL` / `ZONE_OUTSIDE_SEC` / `KILL_MELEE` / `SURVIVE_DETECTED_SEC` / `KILL_WHILE_ZONE_OUTSIDE` / `KILL_LOW_HP`

**신규 리워드/패널티 타입**: `AMMO_REFILL` / `AMMO_CLEAR` / `HP_RESTORE` / `HP_DAMAGE` / `SHIELD_ADD` / `HEAL_ADD` / `HEAL_CLEAR` / `RAILGUN_UNLIMITED` / `ALL_BOTS_DETECT` / `HEAL_PICKUP_BAN` / `BOT_AGGRO` / `ZONE_EXTEND`

**구현 마일스톤**
- ~~v1.4.0~~: 미션 선택 UI 제거, 랜덤 보너스, HARD_POOL 8종 + 기본 리워드 7종, 결과 화면 클리핑 버그 수정 ✅
- ~~v1.4.1~~: Mission UI/UX 개선 — HUD 두 줄, 실패 확정 표시, Flash 알림, SCAVENGER/MEDIC 풀 재조정 ✅
- v1.4.2: 밸런스 조정, Telemetry pressure 그룹, TESTING.md 갱신, 릴리즈

**헤드리스 검증 기준**
- 랜덤 보너스 미션이 매치마다 다른 ID로 배정됨 (로그 확인)
- zone_stage >= 2 매치에서 `pressure_triggered >= 1` (지옥 모드)
- `pressure_cleared + pressure_failed == pressure_triggered` (누락 없음)
- 기존 봇 AI, 존 수축, 보급 동작 변화 없음

---

### v1.4.3 — Weapon Depth `S`

**한 줄 요약**: 각 무기의 역할을 명확히 구분해 전투 선택지에 깊이를 더한다.

**핵심 변경 파일**
- `src/core/StatsData.gd` (knockback_force 필드 추가)
- `src/entities/Entity.gd` (take_damage 시 knockback impulse 적용)
- `src/core/railgun_stats.tres` (스탯 조정)

**레일건 밸런스 조정**

현재 레일건은 탄창 3발 + AR과 사거리 차이 미미로 사용 이유가 약함.

| 스탯 | 현재 | 목표 |
|---|---|---|
| `attack_range` | ~20m | 60m (화면 거의 전체) |
| `attack_damage` | ~35 | 95 (2발 처치, 원샷 불가) |
| `max_ammo` (탄창) | 3 | 2 |
| `fire_rate` (쿨다운) | 1.0s | 2.8s |
| 리저브 최대 | 6 | 4 |

장기 옵션: 레일건 관통 샷 — raycast를 한 번의 hit에서 멈추지 않고 계속 진행, 같은 직선 봇 2마리 동시 적중. 쿼터뷰 포지셔닝 가치 극대화.

**저지력(Knockback) 시스템**

피격 시 무기별 힘으로 피격자 이동 (CharacterBody3D velocity 즉시 추가).

| 무기 | knockback_force | 방향 |
|---|---|---|
| 피스톨 | 0 (없음) | — |
| AR | 4 (너프 대신 저지력 부여) | 공격자→피격자 방향 |
| 샷건 | 거리에 반비례, 최대 18 (근거리 강타 효과) | 공격자→피격자 방향 |
| 레일건 | 8 (고관통 충격) | 공격자→피격자 방향 |
| 칼 | 6 (근접 밀치기) | 위와 같음 |

AR은 attack_damage -15% 너프 대신 저지력으로 보상. 샷건은 근거리 `min(distance, 8) / 8` 역비례 계수 적용.

**무기슬롯 제한 미션 (PISTOL ONLY 변형)**

보너스 미션 풀에 추가할 고난이도 미션:

| 미션 | 조건 | 성공 점수 |
|---|---|---|
| ONE SLOT RUN | 칼 + 한 가지 총기만으로 1등 (다른 총기 픽업 금지) | +1500 |

구현: 새 `ConditionType.WIN_ONE_SLOT` 추가, 픽업 시 2번째 총기 슬롯 이후 습득 여부 추적.

**헤드리스 검증 기준**
- 레일건 스탯 변경 후 10회 시뮬에서 railgun 킬 비율 > 0 확인
- 저지력 적용 후 SCRIPT ERR 없음, 봇 이동 동작 변화 없음

---

### v1.5 — Artifact System `M`

**한 줄 요약**: 매 판의 조건을 다르게 만드는 핵심 로그라이트 메커닉.

**핵심 변경 파일**
- `src/core/ArtifactData.gd` (신규 Resource)
- `src/entities/player/Player.gd` (EntityMods 적용)
- `src/Main.gd` (매치 시작 시 3-선택 UI 진입, 보급 드롭 연동)
- `src/entities/player/Player.gd` HUD (활성 아티팩트 표시)

**구현 순서**
1. `ArtifactData` 리소스 정의 (`stat_delta: Dictionary`, `ability_flags: Array`)
2. Player에 `EntityMods` 레이어 추가 — stat 계산 시 delta 합산, 코드 나머지 무변경
3. 3-선택 UI (매치 전) — 선택만 되고 효과는 아직 없는 상태로 테스트
4. stat_delta 효과 적용 (6개씩 묶어 하나씩 확인)
5. 보급 캡슐 드롭으로 추가 아티팩트 획득
6. HUD 활성 아티팩트 표시 + 미션 HUD와 공존 레이아웃

**1차 아티팩트 (12개, stat-delta only)**

| 카테고리 | 이름 | 효과 |
|---|---|---|
| 공격 | Red Trigger | 공격력 +25%, 탄퍼짐 +20% |
| 공격 | Last Bullet | 탄창 마지막 탄 피해 +100%, 재장전 시간 +20% |
| 공격 | Double Tap | 같은 대상 연속 명중 시 2번째 탄 피해 +30% |
| 공격 | Execution Spark | HP 30% 이하 대상에게 피해 +40% |
| 생존 | Med Loop | 치료 아이템 사용 후 5초간 이동속도 +20% |
| 생존 | Armor Sponge | 방어구 획득량 +50%, 회복량 -20% |
| 은신 | Silent Core | 발소리 감지 반경 -50%, 이동속도 -10% |
| 은신 | Vulture Protocol | 봇 사망 위치 3초간 미니맵 표시, 킬 후 2초간 플레이어 위치 노출 |
| 자기장 | Zone Skin | 자기장 피해 -40%, 회복량 -30% |
| 자기장 | Zone Eater | 자기장 경계 근처에서 공격력 +25% |
| 자기장 | Blue Lung | 자기장 피해 -25% |
| 자기장 | Panic Sprint | 자기장 밖 이동속도 +30%, 자기장 밖 사격 정확도 -25% |

**2차 아티팩트 (v1.7에서 추가)**: Emergency Shell, Ghost Grass, Pulse Scanner, Marked King, Glass Capsule — 별도 능력 로직 필요.

> Ricochet Core(탄 반사), False Signal(가짜 소음), Second Capsule(부활), Zone Debt(피해 누적 정산)는 구현 난도 높아 v2.x 이후 검토.

**헤드리스 검증 기준**
- 아티팩트 선택 없이 매치 진행 시 기존 동작 변화 없음
- 10회 시뮬레이션에서 stat_delta 적용 후 Player 스탯이 범위를 벗어나지 않음
- 아티팩트 ID가 Telemetry `active_artifact` 필드에 기록됨

---

### v1.6 — Bot Archetypes `S`

**한 줄 요약**: 봇 11명이 각기 다른 전술 성향으로 행동해 전장이 살아있는 느낌을 만든다.

**핵심 변경 파일**
- `src/entities/bot/Bot.gd` (아키타입 enum + 파라미터 오버라이드)
- `src/Main.gd` (스폰 시 아키타입 배정)
- `src/core/Telemetry.gd` (아키타입별 생존 분포 추적)

**구현 내용**
- `BotArchetype` enum: `AGGRESSIVE / DEFENSIVE / SNIPER / OPPORTUNIST`
- 스폰 시 비율 배정 (기본 3:3:2:3, 난이도별 조정 가능)
- 아키타입별 파라미터 오버라이드 (스폰 시 1회):

| 아키타입 | 주요 차이 |
|---|---|
| AGGRESSIVE | attack_range 감소, DISENGAGE 임계 높음, 적극 CHASE |
| DEFENSIVE | DISENGAGE 적극 활용, 보급 우선도 높음, 원거리 유지 |
| SNIPER | vision_range 최대, attack_range 최대, 커버 의존도 높음, 근접 회피 |
| OPPORTUNIST | 교전 중인 약한 봇 우선 타겟, 밀집 구역 회피, 보급 캡슐 적극 수집 |

**헤드리스 검증 기준**
- Telemetry에 `archetype_distribution`과 `archetype_alive_at_zone2` 기록
- SNIPER 봇이 AGGRESSIVE 봇보다 평균 생존 시간이 길어야 함 (전술적 분화 확인)
- 기존 DISENGAGE / RECOVER / CHASE 동작 변화 없음

---

### v1.7 — Complex Artifacts + Director Lite `M`

**한 줄 요약**: 2차 아티팩트(능력 로직 포함) 추가 + 전장 페이싱 자동 조절.

**핵심 변경 파일**
- `src/entities/player/Player.gd` (2차 아티팩트 ability 처리)
- `src/core/GameDirector.gd` (신규 — 매 30초 tick, 개입 판단)
- `src/Main.gd` (Director 인스턴스화, 개입 콜백 연결)

**2차 아티팩트 (6개)**

| 이름 | 효과 | 구현 포인트 |
|---|---|---|
| Emergency Shell | HP 20% 이하 시 3초 실드, 매치당 1회 | Player에 일회성 트리거 플래그 |
| Ghost Grass | 수풀 밖에서도 2초간 은신 보너스 유지 | Bush 이탈 후 timer 기반 stealth_modifier |
| Pulse Scanner | 15초마다 근처 봇 방향 HUD 표시 | 미니맵 연동 ping UI |
| Marked King | 킬당 회복, 킬 후 2초간 위치 노출 | Telemetry kill 이벤트 훅 |
| Glass Capsule | 최대 HP 50%, 모든 피해 ×2 | EntityMods에서 max_health_mult 추가 |
| Overheat Barrel | 연사할수록 공격력 증가, 오래 쏘면 탄퍼짐 증가 | fire_timer 누적값으로 계수 |

**Director Lite 설계**
- 관찰: 남은 봇 수, 플레이어 HP, 무교전 시간(초), zone 단계
- 개입 (30초 tick마다 1회 판정, 매치당 최대 3회):
  - 무교전 45초↑ → 보급 핑 강제 발생
  - 남은 봇 4명↓ + 플레이어 HP 60%↑ + 무교전 30초↑ → AGGRESSIVE 아키타입 봇 중 가장 가까운 봇을 플레이어 방향으로 이동
- 원칙: 개입이 티 나면 실패. 발동 조건을 좁게 유지.

**헤드리스 검증 기준**
- 2차 아티팩트 비활성 시 1차와 동일한 동작 확인
- Director 개입이 Telemetry에 `director_event` 로 기록됨
- 10회 시뮬레이션에서 Director 개입이 0회~5회 범위 (과개입 방지)

---

### v1.8 — Meta Progression `S`

**한 줄 요약**: 장기 목표를 만든다. 단, 영구 스탯 강화는 없음.

**핵심 변경 파일**
- `src/ui/AchievementGallery.gd` (신규 화면)
- `src/Main.gd` (결과 화면 → 배지 갱신 연결)
- `user://achievements.json` (v1.3에서 생성, 필드 확장)

**구현 내용**
- 배지 갤러리 UI (미션 완료 배지 모음 화면)
- 해금 항목:
  - 추가 미션 묶음 (챌린지 티어 — harder variants)
  - 색상 스킨 (Material albedo_color 교체, 코드 기반)
  - 킬피드 타이틀 (display_name 앞에 붙는 접두어)
  - 시작 무기 변형 (pistol → AR or shotgun 선택)
- Hell 챌린지 재정의: Hell Champion 배지 달성자는 Records 화면에서 별도 표시 (기존 Hell 난이도는 이미 해금 상태)

**명시적 제외**
- 영구 공격력/HP 강화 없음 — 배틀로얄 공정성과 긴장감 보호
- 아티팩트 잠금 해제 없음 — 모든 아티팩트는 처음부터 선택 가능

**헤드리스 검증 기준**
- achievements.json 없을 때 정상 초기화
- 해금 항목이 적용된 상태에서 10회 시뮬레이션 — 기존 Telemetry 지표 변화 없음

---

### v1.9 — Public Alpha Polish `S`

**한 줄 요약**: 외부에 공개할 수 있는 상태로 다듬는다.

**핵심 작업**
- README: 게임 설명, 스크린샷/GIF, 조작법, 다운로드 링크
- 인게임 Credits / Licenses 화면 (Godot MIT 라이선스 텍스트 포함 — 배포 요건)
- 프로젝트 자체 라이선스 파일 (`LICENSE.md`)
- Windows/macOS GitHub Release 자동화 (`RELEASE.md` 기준 스크립트 정비)
- Known Issues 문서화
- itch.io 페이지 초안 준비

**판매 전환 검토 시점**: itch.io 무료 배포 후 피드백 수집 → 아래 조건 4개 이상 충족 시 검토.

| 조건 | 상태 |
|---|---|
| 맵 2개 이상 | ❌ (v2.2 이후) |
| 아티팩트 20개 이상 | ❌ (v1.5+v1.7 합산 약 18개) |
| 미션 20개 이상 | ❌ (v1.4 보너스 15종 + 압박 17종은 성격 상이, v1.8 추가 후 재검토) |
| 난이도 4종 | ✅ |
| 1시간 반복 플레이 지루하지 않음 | 검증 필요 |
| itch.io 긍정 피드백 | 미배포 |
| Windows/macOS 빌드 안정 | Windows ✅ / macOS 미확인 |

---

## Phase 2 — 세계 확장 (v2.0+)

> Phase 1(v1.3~v1.8) 완료 후 진행. 각 버전 착수 전 선행 조건 확인 필수.

### v2.0 — Map System Refactor `M`

**선행 조건**: 없음 (v1.8 완료 후 바로 시작 가능)

현재 `MapSpec.gd` + `mapSpec_example.json` 구조를 `MapDefinition` Resource로 일반화.

```
MapDefinition
  map_id, display_name, theme
  world_size, zone_profile (수축 배율 배열)
  spawn_rules (밀도, 안전 반경)
  loot_tables (아이템 종류별 가중치)
  obstacle_sets (JSON 경로 또는 인라인)
  cover_density, bush_density, verticality
  bot_count_range
```

이 구조 없이 도시 맵을 추가하면 `if map == "city"` 분기가 코드 전체에 퍼진다.

---

### v2.1 — Forest 2.0 + AI LOD 기반 `M`

**선행 조건**: v2.0 MapDefinition 완료

**맵**: 서브 바이옴 추가 (늪지대 이동속도 감소, 높은 풀숲 은신 강화, 폐허 캠프 루팅 집중 지역)

**AI LOD** (봇 수 확장 전 필수):
- Near (< 30m): 현재와 동일한 풀 AI 업데이트
- Mid (30~60m): perception 업데이트 주기 2배 감소
- Far (> 60m): state update만, 이동 없음
- Offscreen: 단순 생존/사망 확률 계산만

---

### v2.2 — City Map `L`

**선행 조건**: v2.0 MapDefinition + v1.0 NavigationMesh 안정 확인

도시 맵 전용: 골목/건물벽/교차로, Building Occlusion (카메라-플레이어 사이 건물 투명화), Noise Echo (발소리 감지 반경 확대).

---

### v2.3 — Larger Battles `M`

**선행 조건**: v2.1 AI LOD 완료

단계적 확장: Classic 1v11 → Large 1v15 → Chaos 1v23  
(Hell 1v31은 AI LOD 성능 확인 후 결정)

필수 동반 작업: killfeed 필터링, loot density / zone timing 재스케일, spawn safety 반경 재조정.

---

## Phase 3 — 서사 레이어 (v3.0, 조건부)

### v3.0 — Operation Mode

판매 전환 기준 충족 + 콘텐츠 볼륨이 확보된 시점에서 검토.

풀 캠페인보다 **미션 묶음(Operation)으로 그루핑 + 짧은 텍스트 브리핑** 방식을 권장.  
Boss/Captain Bot은 AGGRESSIVE 아키타입의 강화형으로 구현.

---

## 다음 AI 에이전트에게

**작업 시작 전 확인할 파일**
- `Bot.gd` — AI 로직 전체 (NavigationAgent3D 포함)
- `Player.gd` — 무기 슬롯, 재장전, HUD
- `Entity.gd` — 공통 베이스 (이동, 피해, 인식)
- `Main.gd` — 게임 루프, 존, 스폰, NavigationRegion3D 베이크
- `Telemetry.gd` — 매치 통계 (print 문자열 형식 변경 금지)

**알아야 할 Godot 4 quirks**
- NavigationMesh 속성명: `geometry_parsed_geometry_type` (not `parsed_geometry_type`)
- Control preset: `PRESET_CENTER_BOTTOM` (not `PRESET_BOTTOM_CENTER`)
- `grow_vertical = GROW_DIRECTION_BEGIN` 없으면 bottom anchor가 화면 밖으로 나감
- macOS export key: `application/bundle_identifier` (not `application/identifier`)
- 헤드리스 빌드: `textures/vram_compression/import_etc2_astc=true` 필요

**현재 미해결 이슈**
- `src/fx/ShotPing.tscn`과 `src/fx/ImpactEffect.tscn`의 UID 충돌 경고 (기능에는 무해)
