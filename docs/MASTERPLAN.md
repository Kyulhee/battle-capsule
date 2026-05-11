# 배틀캡슐 마스터 플랜

> 마지막 업데이트: 2026-05-11 (v1.10 UI catalog splits)
> 이 문서는 AI 에이전트 간 인수인계 및 장기 방향 공유를 위해 작성되었습니다.

## 현재 상태

**현재**: v1.10-dev — 릴리즈 없이 v1.9 asset hook 커밋 후 Main Slimdown/UI catalog 분리 진행 중

**문서 구조** *(각 파일의 업데이트 시점 기준 → [CLAUDE.md](../CLAUDE.md))*

- [CLAUDE.md](../CLAUDE.md) — 세션 시작 시 온보딩 (현재 상태, 핵심 파일, 퀵 커맨드)
- [MASTERPLAN.md](MASTERPLAN.md) — 전체 로드맵 & 설계 원칙 ← 지금 여기
- [DEVLOG.md](DEVLOG.md) — 버전별 구현 상세 (완료된 것)
- [TESTING.md](TESTING.md) — 헤드리스 시뮬레이션 검증 (구현 후 실행)
- [RELEASE.md](RELEASE.md) — 빌드 → GitHub 릴리즈 → README 업데이트
- [ASSET_BRIEF.md](ASSET_BRIEF.md) — 외부 에셋 생성용 스타일/파일/프롬프트 명세

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
│   ├── GameConfig.gd           # match/zone/difficulty/Hell 수치 JSON 로더
│   ├── AssetCatalog.gd         # audio/icon/prop/cosmetic ID JSON 로더
│   ├── ArtifactCatalog.gd      # 시작 아티팩트 선택지 catalog
│   ├── DifficultyCatalog.gd    # 난이도 UI label/description/color catalog
│   ├── HelpCatalog.gd          # How to Play 섹션/행 catalog
│   ├── LootSpawner.gd          # POI/밀도 기반 루트 위치 계산
│   ├── SupplyDropController.gd # 보급 캡슐 위치/타이밍/클러스터 계산
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
├── game_config.json            # bot/loot/zone/difficulty/Hell 기본값
├── asset_catalog.json          # 에셋 ID → path/fallback/색상/태그
└── mapSpec_example.json        # 맵 POI 및 배치 정보 (v3.1 — 숲 레이어 구조)
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

### 봇 아키타입과 개인 교전 수칙

| 아키타입 | 특징 |
|---|---|
| AGGRESSIVE | 근접 선호, DISENGAGE 임계 높음, 적극 CHASE |
| DEFENSIVE | DISENGAGE 적극 활용, 원거리 유지, 생존 우선 |
| SNIPER | vision/attack range 최대, 근접 회피, 엄폐 의존 |
| OPPORTUNIST | 낮은 HP 적 우선, 핫스팟/보급 우선 |

v1.7.1 기준 ATTACK 상태는 문자열 combat plan을 사용한다. 전술 ID는 `strafe / advance / kite / peek_cover / reposition / hold_angle`이며, 선택 이유는 `BotDoctrine` profile/context에서 설명한다.

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

AssetCatalog → `assets/sfx/{name}.wav` → 절차음 순서로 fallback.
`Sfx.play("shoot")` / `Sfx.play("shoot", global_position)` (3D 공간음)
무기별/바닥별 확장은 `Sfx.play_weapon_shot("ar")`, `Sfx.play_footstep("grass", global_position)`처럼 ID만 바꿔 연결한다.

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
| v1.4.2 | 2026-04-30 | Telemetry pressure 그룹, 결과화면 UI 재설계 (클리핑 수정), 압박 HUD 2줄 + 가독성 |
| v1.4.3 | 2026-05-01 | 봇 근접 반격 수정 (칼 blind spot), 포격 10발 클러스터 15m 존 개편 |
| v1.4.4 | 2026-05-01 | 봇 AI 감지·전략 반응성 강화 (스캔 패턴, combat_loot_floor, 딜레이 단축) |
| v1.4.5 | 2026-05-01 | 레일건 리워크, 넉백, ONE SLOT RUN 미션, 압박 타이밍 수정, 리워드/패널티 HUD |
| v1.5.0 | 2026-05-01 | 아티팩트 시스템 4종, AR 열 퍼짐, 봇 사주경계 (근거리 즉시·360°·Hard+ 스윕) |
| v1.5.1 | 2026-05-01 | 봇 총소리 반응, 웅크리기 전술 (stealth 0.45·시야 절반) |
| v1.5.2 | 2026-05-02 | 한국어 UI 텍스트 정리, 붕대/구급상자 명칭 통일, 조작키 E→F 버그 수정 |
| v1.5.3 | 2026-05-02 | 봇 전술 심화 — 교전 교환비 판단, 재장전 후퇴, 킬 후 스캔, 후반부 수렴 |
| v1.5.4 | 2026-05-03 | 미션/아티팩트 호환성 필터, 레일건 순간 미션, VersionLabel 정리 |
| v1.5.5 | 2026-05-04 | ZoneController·WeaponSlotManager 분리, 구조 안정화 |
| v1.6   | 2026-05-06 | 봇 아키타입 4종, 아키타입별 생존 Telemetry |
| v1.6.1 | 2026-05-06 | 개인 교전 수칙, RECOVER 안정화, Telemetry/시뮬레이션 도구 정리 |
| v1.6.2 | 2026-05-07 | 쿼터뷰 벽 가림 투명화 복구/점멸 수정, ATTACK 장기 교전 안전밸브 |
| v1.6.3 | 2026-05-07 | 후퇴/자기장 탈출 중 응전 레이어, 위협 기반 stuck 탈출, 아이템 시야 인식 제한, 보급 군집 완화 |
| v1.7.1 | 2026-05-08 | AI Doctrine 계층화, Doctrine Telemetry/analyzer, 아키타입 얼굴/머리 파츠, 스킨 시야/웅크리기 동기화 |
| v1.7.2 | 2026-05-08 | 아키타입별 Doctrine 지표, 행동 편향 1차 튜닝, 헬 총성 인식 보정, 단순 아키타입 마커 |
| v1.7.3 | 2026-05-08 | 미니맵 generated footprint 연결, 높이/우선순위 렌더, 숲 맵 v3.1 레이어 정리, 루트 밀도 연결 |
| v1.7.3.1 | 2026-05-08 | 메인 메뉴 난이도 UI 겹침 완화, How to Play 키/최신 시스템 안내 정리 |

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

### ~~v1.5 — Artifact System~~ ✅ v1.5.0 출시

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

**2차 아티팩트 (v1.8에서 추가)**: Emergency Shell, Ghost Grass, Pulse Scanner, Marked King, Glass Capsule — 별도 능력 로직 필요.

> Ricochet Core(탄 반사), False Signal(가짜 소음), Second Capsule(부활), Zone Debt(피해 누적 정산)는 구현 난도 높아 v2.x 이후 검토.

**헤드리스 검증 기준**
- 아티팩트 선택 없이 매치 진행 시 기존 동작 변화 없음
- 10회 시뮬레이션에서 stat_delta 적용 후 Player 스탯이 범위를 벗어나지 않음
- 아티팩트 ID가 Telemetry `active_artifact` 필드에 기록됨

---

### ~~v1.6 — Bot Archetypes~~ ✅ 2026-05-06

**한 줄 요약**: 봇 11명이 4개 아키타입으로 나뉘어 서로 다른 전술 성향을 갖는다.

**완료 내용**
- `BotArchetype`: `AGGRESSIVE / DEFENSIVE / SNIPER / OPPORTUNIST`.
- 스폰 비율 기본 3:3:2:3.
- 아키타입별 range, flee, disengage, loot, target scoring 조정.
- Telemetry에 spawn/alive@zone2/death 분포 기록.

---

### ~~v1.6.1 — Release Stabilization~~ ✅ 2026-05-06

**한 줄 요약**: v1.6 아키타입 위에 개인 교전 수칙을 얹고 공개 패치 릴리즈 기준을 고정한다.

**핵심 내용**
- `CombatPlan`: `STRAFE / ADVANCE / KITE / PEEK_COVER / REPOSITION / HOLD_ANGLE`.
- RECOVER는 즉시 루팅보다 엄폐 → 루팅 순서를 우선.
- 저체력 봇은 탄약이 있으면 RECOVER 대신 DISENGAGE/재장전/엄폐를 우선.
- Telemetry: `cover_peek`, `combat_reposition`, `combat_kite`, `survival_break`, `died_in_recover`, 무기명 정규화.
- 반복 시뮬레이션 도구는 현재 JSON 스키마를 직접 읽고 summary를 생성.

**릴리즈 기준**
- `python tools/simulate_matches.py 5` 통과.
- `died_in_recover / recover_bouts < 0.5`.
- `attack_max_continuous < 20.0`.
- combat plan 카운트가 0에 고정되지 않음.

---

### ~~v1.6.2 — Visual Occluder Stabilization~~ ✅ 2026-05-07

**한 줄 요약**: 쿼터뷰 시점에서 캐릭터를 가리는 벽이 안정적으로 투명화되고 원래 재질로 복구된다.

**완료 내용**
- `Player.gd`의 occluder fade를 mesh별 상태 캐시로 전환.
- 원본 `surface_override_material`을 보존해 fade 후 흰색 material 점멸이 발생하지 않도록 수정.
- 머리/몸통/좌우/하단 5-ray 샘플과 linger/alpha lerp로 벽 모서리 점멸 완화.
- `TestMap.tscn` 경계벽에 `occluder` 그룹 추가.
- ATTACK 장기 교전은 16초 이후 짧은 재배치로 끊어 `attack_max_continuous` 안정화.

---

### ~~v1.6.3 — Retreat Combat + Item Sight Layer~~ ✅ 2026-05-07

**한 줄 요약**: 후퇴와 자기장 탈출 중에도 가까운 위협에는 견제 사격/칼 반격을 수행하고, 아이템은 시야 안에서만 표시/인식한다.

**완료 내용**
- `ZONE_ESCAPE`/`DISENGAGE`가 이동만 독점하지 않고 가까운 위협에 응전.
- 후퇴 사격은 10m 이내 위협, 긴 쿨다운, 높은 산탄도로 제한해 탈출 보조 행동으로 유지.
- stuck 탈출 방향을 자기장 중심, 위협 반대, 측면 회피를 섞어 결정.
- `Entity.can_sense_item()` 공통 판정으로 플레이어 아이템 표시/상호작용과 봇 루팅 인식을 같은 기준으로 통일.
- 아이템 시야는 근거리 원형(`fov_near_range`) + 원거리 부채꼴(`vision_range`, `fov_angle`) + LOS 차단을 모두 만족해야 한다.
- 보급 지점 이동은 OPPORTUNIST/저체력/저탄약/일부 근거리 봇으로 제한해 전원 중앙 집결을 방지.
- Telemetry/analyzer에 후퇴 응전, 위협 중 stuck, zone-assisted death 지표 추가.

---

### ~~v1.7.1 — AI Doctrine Hierarchy Refactor~~ ✅ 2026-05-08

**한 줄 요약**: 봇 전술을 코드 곳곳의 조건문에서 분리해 디버깅 가능한 계층형 프로파일로 만든다.

**새 구조**
- `Bot.gd`: 상태 머신, 이동/사격 실행, 센서 입력 수집을 담당.
- `BotDoctrine.gd`: 전술 선택, 수치 merge, 아키타입/난이도/무기 보정 계산을 담당하는 순수 로직.
- `Telemetry.gd`: doctrine profile 요약과 전술 선택 결과를 기록.

**v1.7.1 완료**
- `Bot.configure_ai(archetype_id, difficulty_params)` 도입.
- `BotDoctrine.build_profile()`, `choose_combat_plan()`, `choose_supply_decision()`, `explain_profile()` 추가.
- 전술 ID를 문자열로 통일.
- 보급 관심, 순찰 선호, OPPORTUNIST 타겟 점수를 profile 기반으로 이동.
- Telemetry/analyzer에 Doctrine profile/plan 카운트 추가.
- `BotVisualKit.gd` 추가: 외부 이미지 없이 primitive mesh 기반 아키타입 얼굴/머리 파츠 적용.
- 스킨 파츠는 플레이어 인식 상태와 웅크리기 높이에 동기화.

**계층 우선순위**
1. Global Safety Rules — zone escape, death guard, no-ammo, stuck, LOS 안전 규칙. 아키타입이 덮어쓸 수 없음.
2. Base Doctrine — 모든 봇 공통 전술 기본값.
3. Archetype Overlay — AGGRESSIVE/DEFENSIVE/SNIPER/OPPORTUNIST별 성향 보정.
4. Difficulty Scalar Pass — 시야, 반응속도, 전투 중 루팅 floor, 사주경계, aim spread, 업데이트 빈도.
5. Weapon Doctrine — shotgun advance, railgun/sniper hold angle, AR sustained fire.
6. Runtime Context — HP, 탄약, 주변 적 수, zone 단계, 최근 피격, 후반부 여부.

**공개 인터페이스**
- `Bot.configure_ai(archetype_id, difficulty_params)`.
- `BotDoctrine.build_profile(archetype_id, difficulty_params) -> Dictionary`.
- `BotDoctrine.choose_combat_plan(context, profile) -> String`.
- combat plan ID는 문자열 `strafe`, `advance`, `kite`, `peek_cover`, `reposition`, `hold_angle`로 통일.

**헤드리스 검증 기준**
- 리팩터 전후 5회 평균 duration, zone_stage, recover ratio가 큰 폭으로 흔들리지 않음.
- `BotDoctrine.explain_profile(profile)`가 Telemetry JSON에 포함됨.
- 기존 아키타입 분포와 combat plan 카운트가 유지됨.
- 중앙 군집/무피해 회귀 방지: 5회 시뮬레이션에서 `total_damage_dealt > 0`, deaths > 0, zone stage snapshot의 `avg_pairwise_dist`가 10m 이하로 고정되지 않음.
- 보급 관심 정책은 `Bot.gd` 분기 대신 doctrine profile/runtime context로 설명 가능해야 함.
- 아이템 시야, 후퇴 응전, stuck 탈출은 Global Safety Rules/Base Doctrine/Runtime Context 중 어느 계층이 소유하는지 문서화한다.

---

### ~~v1.7.2 — Archetype Readability Stabilization~~ ✅ 2026-05-08

**한 줄 요약**: 아키타입이 보이기만 하는 수준을 넘어 실제 행동 차이로 체감되도록, 안정성을 해치지 않는 범위에서 지표 기반 튜닝을 진행한다.

**핵심 작업**
- `Telemetry.gd`에 `plan_by_archetype`, `state_time_by_archetype`, `engage_range_by_archetype` 추가.
- analyzer가 아키타입별 plan 분포를 출력하도록 확장.
- AGGRESSIVE/DEFENSIVE/SNIPER/OPPORTUNIST별 고유 행동을 수치 과장이 아니라 조건별 행동 우선순위로 추가.
- v1.7.1 검증에서 남은 60초 미만 early finish 편차를 아키타입/교전거리/무기 획득 흐름으로 분해해 확인.
- `BotVisualKit` 파츠 가독성 조정: 쿼터뷰에서 얼굴 방향과 아키타입이 더 잘 읽히는지 수동 확인.

**v1.7.2 완료**
- Doctrine 지표 3종과 analyzer 출력은 1차 구현 완료.
- AGGRESSIVE advance, DEFENSIVE cover, OPPORTUNIST finish/reposition, SNIPER kite 편향을 profile overlay로 1차 적용.
- 헬 총성 인식이 partial `?` 확인 상태에 머무르지 않도록 보정.
- 표정/머리 파츠는 단순 전술 마커로 교체.

**헤드리스 검증 기준**
- zone deaths 0 유지.
- `plan_by_archetype`에서 각 아키타입의 대표 plan 편향이 확인됨.
- visual skin 변경 후 headless 종료 material 오류 없음.
- duration 편차는 허용하되, 급증/급락 시 `total_damage_dealt`, `shots_fired`, combat plan 카운트가 0에 고정되지 않는지 확인.

---

### ~~v1.7.3 — Minimap Map Consistency~~ ✅ 2026-05-08

**한 줄 요약**: 미니맵이 실제 맵을 하늘에서 본 최종 형태와 일치하도록 데이터 연결과 렌더 우선순위를 정리한다.

**핵심 작업**
- `MapSpec`/`WorldBuilder`/`Minimap`의 좌표계, 회전, 크기 변환을 같은 기준으로 맞춘다.
- 부쉬와 건물처럼 요소가 겹칠 때 미니맵은 상단 시점에서 나중에 덮는 물체가 최종 색/형태를 결정하도록 그린다.
- 실제 맵에 보이는 건물/장애물이 미니맵에 누락되지 않도록 `WorldBuilder` 생성 데이터와 미니맵 입력 데이터를 단일 소스로 맞춘다.
- 미니맵 전략도 확장을 위해 terrain category, cover/LOS importance, route layer를 이후 추가 가능한 구조로 남긴다.

**v1.7.3 완료**
- `WorldBuilder.get_minimap_features()`로 실제 생성 footprint를 Minimap에 전달하는 1차 연결 완료.
- headless autostart도 실제 월드를 생성하도록 변경해 테스트와 플레이 맵의 차이를 줄였다.
- 실제 장애물 맵 기준 시뮬레이션에서 zone death/stuck 증가가 확인되어, 미니맵 이후 zone escape pathing을 재점검한다.
- 타입별 minimap layer + height tie-break를 추가해 부쉬/낮은 구조물 위에 높은 rock/tree/canyon footprint가 최종적으로 덮이도록 보정.
- `mapSpec_example.json` v3.1에서 외곽 산악 지형, 중간 나무 지형, 내부 부쉬 지형, 개활지 loot hub 구조로 숲 맵 레이어를 1차 정리.
- `item_density`/`rare_bias`를 실제 루트 스폰 가중치에 연결해 개활지에 더 높은 보상을 주는 전략적 트레이드 오프를 만들었다.

**테스트 방향**
- 게임이 장기적으로 10분까지 늘어나는 것을 정상 성장 방향으로 보고, duration 상한 자체를 실패로 보지 않는다.
- 대신 `total_damage_dealt == 0`, weapon damage 전부 0, attack/combat plan 카운트 0, zone deaths 급증처럼 "전투가 아예 죽은" 회귀를 우선 감지한다.
- 맵 크기 5배/99명 스케일업은 현재 AI 업데이트/zone/pathing 비용을 그대로 둔 채 바로 적용하지 않고, 120m 숲 맵 안정화 → 중간 배율 실험 → AI LOD/스폰/루트 밀도 재스케일 순으로 진행한다.

---

### v1.8 — Expansion Foundation `M`

**한 줄 요약**: 에셋/맵/봇 확장을 시작하기 전에 config, debug, asset registry, Main 분리 기준을 먼저 고정한다.

**목표**
- 단순 수치 변경이 `Main.gd` 직접 수정으로 이어지지 않도록 `GameConfig`/`BalanceConfig` 계층을 만든다.
- DebugMode/DebugOverlay flag 체계를 도입해 인식, 피해, 루팅, 존, 경로 문제를 화면/로그에서 구분한다.
- AssetCatalog 기초 구조를 만든다: weapon sound, footstep, item icon, artifact logo, prop set, cosmetic tint ID → resource path.
- `Main.gd`는 한 번에 크게 쪼개지 않고, 가장 안전한 루트/보급/메뉴/도움말 경계부터 점진 분리한다.
- v1.7.3.1의 플레이 루프와 Telemetry 기준은 유지한다.

**1차 구현 순서**
1. `src/core/GameConfig.gd` 또는 `data/game_config.json`: bot count, spawn radius, loot count, zone base values, difficulty params, hell timings.
2. `src/core/DebugFlags.gd` + command-line parse: `debug=true debug_flags=ai,perception,damage,loot,zone,nav`.
3. `src/ui/DebugOverlay.gd`: release default off, debug on에서만 간단한 화면 지표 표시.
4. `data/asset_catalog.json` + `src/core/AssetCatalog.gd`: 에셋 ID, fallback, missing ID 경고.
5. `Main.gd`에서 loot hotspot/spawn 함수만 `LootSpawner` 후보로 분리하거나, 먼저 interface만 고정한다.

**검증 기준**
- config 기본값으로 기존 1v11 Normal/Hell 단독 시뮬레이션 정상.
- debug off에서 UI/성능/Telemetry 출력 변화 없음.
- debug on에서 crash 없이 overlay와 flag 로그 표시.
- AssetCatalog missing ID는 fallback으로 처리되고 runtime error 없음.
- `python tools/simulate_matches.py 5`, `python tools/simulate_matches.py 1 hell`, `git diff --check`.

---

### v1.9 — Asset Pipeline First Pass `M`

**한 줄 요약**: 반복 확장이 가능한 에셋 명명/등록/적용 흐름을 만든다.

**대상**
- 총별 발사/장전/탄착음, 바닥 질감별 발자국, 배경음악 cue.
- 아이템별 간단한 3D 모양과 UI icon, 아티팩트 logo.
- 플레이어/봇 장신구, 얼굴/복장 tint, 아키타입 마커.
- 나무/풀/돌/산악/산장/성벽 prop set의 variant ID.

**검증 기준**
- 에셋이 없어도 fallback primitive/색상/무음으로 플레이 가능.
- 카탈로그 ID만 바꿔 같은 기능에 다른 에셋을 연결할 수 있음.
- export preset이 신규 에셋을 포함하고, 빌드 크기가 비정상적으로 커지지 않음.

---

### v1.10 — Main Slimdown + UI Controllers `M`

**한 줄 요약**: `Main.gd`의 오케스트레이션 책임은 유지하되, 화면/스폰/루트/보급처럼 독립성이 높은 영역을 분리한다.

**우선 분리 후보**
- `MenuController`: 메인 메뉴, How to Play, Records, Settings.
- `LootSpawner`: loot hotspot, item density, rare bias, drop table.
- `SupplyDropController`: supply schedule, capsule spawn, ping/HUD event.
- `MatchBootstrap`: config load, difficulty apply, seed/map setup.

**분리 원칙**
- 게임 상태의 single source는 유지한다. 분리 모듈이 서로를 직접 찾지 않고 Main을 통해 연결한다.
- Telemetry hook 이름과 JSON schema는 변경하지 않는다.
- 작은 파일 수 증가보다 “수치 변경 시 읽어야 할 코드 범위 감소”를 우선한다.

---

### v1.11 — Complex Artifacts `M`

**한 줄 요약**: 기반 구조 위에서 2차 아티팩트로 반복 플레이 변수를 늘린다.

**2차 아티팩트 후보**
- Emergency Shell: HP 20% 이하 시 3초 실드, 매치당 1회.
- Ghost Grass: 수풀 밖에서도 2초간 은신 보너스 유지.
- Pulse Scanner: 15초마다 근처 봇 방향 HUD 표시.
- Marked King: 킬당 회복, 킬 후 2초간 위치 노출.
- Glass Capsule: 최대 HP 50%, 모든 피해 x2.
- Overheat Barrel: 연사할수록 공격력 증가, 오래 쏘면 탄퍼짐 증가.

**헤드리스 검증 기준**
- 아티팩트 비활성 시 v1.7.3.1 지표 유지.
- 각 아티팩트 ID가 Telemetry에 기록됨.
- 5회 시뮬레이션에서 스탯이 비정상 범위로 누적되지 않음.

---

### v1.12 — Director Lite `M`

**한 줄 요약**: 무교전/후반부 흩어짐을 완화하는 미세한 전장 페이싱 개입.

**설계**
- 관찰: 남은 봇 수, 플레이어 HP, 무교전 시간, zone 단계.
- 개입: 무교전 45초 이상이면 보급 핑, 후반부 흩어짐이면 가까운 봇을 플레이어 쪽으로 유도.
- 매치당 최대 3회, 30초 tick 기준. 개입이 티 나지 않게 좁은 조건으로 유지.

**헤드리스 검증 기준**
- Director 이벤트가 Telemetry에 `director_event`로 기록됨.
- 10회 시뮬레이션에서 Director 개입 0~5회 범위.

---

### v1.13 — Public Alpha Polish `S`

**한 줄 요약**: 외부에 공개할 수 있는 상태로 다듬는다.

**핵심 작업**
- README/GIF/스크린샷, 조작법, Known Issues 정리.
- 인게임 Credits / Licenses 화면.
- 프로젝트 라이선스 파일.
- Windows/macOS GitHub Release 절차 정비.
- itch.io 페이지 초안 준비.

**판매 전환 검토 시점**: itch.io 무료 배포 후 피드백 수집 → 아래 조건 4개 이상 충족 시 검토.

| 조건 | 상태 |
|---|---|
| 맵 2개 이상 | ❌ (v2.4 이후) |
| 아티팩트 20개 이상 | ❌ (v1.5+v1.11 합산 약 18개) |
| 미션 20개 이상 | ❌ (v1.4 보너스 15종 + 압박 17종은 성격 상이, v1.13 이후 재검토) |
| 난이도 4종 | ✅ |
| 1시간 반복 플레이 지루하지 않음 | 검증 필요 |
| itch.io 긍정 피드백 | 미배포 |
| Windows/macOS 빌드 안정 | Windows ✅ / macOS 미확인 |

---

## Phase 2 — 세계 확장 (v2.0+)

> Phase 1(v1.6.1~v1.13) 완료 후 진행. 각 버전 착수 전 선행 조건 확인 필수.

### v2.0 — MapDefinition + Full Map UI `M`

**선행 조건**: v1.8 config/debug 기반, v1.10 Main slimdown 완료

현재 `MapSpec.gd` + `mapSpec_example.json` 구조를 `MapDefinition` Resource로 일반화하고, `M` 키 전체 지도 UI를 추가한다.

```
MapDefinition
  map_id, display_name, theme
  world_size, zone_profile (수축 배율 배열)
  spawn_rules (밀도, 안전 반경)
  loot_tables (아이템 종류별 가중치)
  obstacle_sets (JSON 경로 또는 인라인)
  cover_density, bush_density, verticality
  bot_count_range
  minimap_layers, full_map_layers
```

이 구조 없이 도시 맵을 추가하면 `if map == "city"` 분기가 코드 전체에 퍼진다.

---

### v2.1 — Forest 2.0 `L`

**선행 조건**: v2.0 MapDefinition 완료

**맵 목표**
- 외곽: 산악/절벽/협곡으로 큰 경로 제한과 시야 차단 제공.
- 중간: 나무 지형으로 교전 라인과 회전 경로를 조절.
- 내부: 부쉬/개활지/작은 구조물을 섞어 은신과 루트 보상 사이의 선택을 만든다.
- 산장, 성벽/폐허, 캠프는 큰 지형지물 몇 개로 제한하고 작은 prop은 랜덤 variant로 배치한다.
- 개활지는 위험하지만 item density/rare bias가 높은 hotspot으로 둔다.

---

### v2.2 — AI LOD + Medium Battles `M`

**선행 조건**: v2.0 MapDefinition + v2.1 Forest 2.0 기준맵 완료

**AI LOD** (봇 수 확장 전 필수):
- Near (< 30m): 현재와 동일한 풀 AI 업데이트
- Mid (30~60m): perception 업데이트 주기 2배 감소
- Far (> 60m): state update만, 이동 없음
- Offscreen: 단순 생존/사망 확률 계산만

**스케일 단계**: Classic 1v11 → 1v23 → 1v47.

---

### v2.3 — Larger Battles `M`

**선행 조건**: v2.2 AI LOD + Medium Battles 안정 확인

단계적 확장: 1v60 → 1v80 → 1v99.

필수 동반 작업: killfeed 필터링, loot density / zone timing 재스케일, spawn safety 반경 재조정, full map 성능 확인.

---

### v2.4 — City Map `L`

**선행 조건**: v2.0 MapDefinition + 대규모 NavigationMesh 안정 확인

도시 맵 전용: 골목/건물벽/교차로, Building Occlusion (카메라-플레이어 사이 건물 투명화), Noise Echo (발소리 감지 반경 확대).

---

## Phase 3 — 서사 레이어 (v3.0, 조건부)

### v3.0 — Operation Mode

판매 전환 기준 충족 + 콘텐츠 볼륨이 확보된 시점에서 검토.

풀 캠페인보다 **미션 묶음(Operation)으로 그루핑 + 짧은 텍스트 브리핑** 방식을 권장.  
Boss/Captain Bot은 AGGRESSIVE 아키타입의 강화형으로 구현.

---

## 다음 AI 에이전트에게

**작업 시작 전 확인할 파일**
- `Bot.gd` — AI 상태 머신, combat plan 실행, NavigationAgent3D
- `BotDoctrine.gd` — AI profile merge, combat/supply decision
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
- `Main.gd`/`Bot.gd`/`Player.gd`가 길어져 수치 변경, debug, asset 연결 변경 시 읽어야 할 범위가 넓다. v1.8~v1.10에서 config/debug/asset/UI 경계를 먼저 줄인다.
- 맵 크기 5배/99명 실험은 MapDefinition, full map, AI LOD, 스폰/루트 밀도, zone/pathing 재스케일 전에는 바로 적용하지 않는다.
- 중앙 군집/무피해 같은 AI 회귀는 Telemetry 기준으로 자동 감지되도록 더 보강한다.
- `first_upgrade_time`은 actor-wide 지표라 플레이어 전용 경제/루팅 속도 튜닝 전에는 별도 지표가 필요하다.
