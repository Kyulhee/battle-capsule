# 배틀캡슐 마스터 플랜

> 마지막 업데이트: 2026-04-26 (v0.7.2 완료, v0.8~v1.0 로드맵 재정립)  
> 이 문서는 AI 에이전트 간 인수인계 및 장기 방향 공유를 위해 작성되었습니다.

## 현재 상태

**현재**: v0.9.2 완료 — 다음: v0.9.3 미정

v0.8.1까지 메인 메뉴 난이도 UI, 봇 성격, 난이도 파라미터, 발소리 감지, 루팅 우선순위가 구현되었다.  
다음 라운드는 신규 콘텐츠 확장보다 자기장/봇 이동 안정화, UI 가독성, 전투 로그 기반 정리를 우선한다.

**문서 구조** *(각 파일의 업데이트 시점 기준 → [CLAUDE.md](../CLAUDE.md))*

- [CLAUDE.md](../CLAUDE.md) — 세션 시작 시 온보딩 (현재 상태, 핵심 파일, 퀵 커맨드)
- [MASTERPLAN.md](MASTERPLAN.md) — 전체 로드맵 & 설계 원칙 ← 지금 여기
- [DEVLOG.md](DEVLOG.md) — 버전별 구현 상세 (완료된 것)
- [TESTING.md](TESTING.md) — 헤드리스 시뮬레이션 검증 (구현 후 실행)
- [RELEASE.md](RELEASE.md) — 빌드 → GitHub 릴리즈 → README 업데이트

---

## 프로젝트 개요

**배틀캡슐 (Battle Capsule)** 은 Godot 4.6.2 / GDScript로 개발 중인 쿼터뷰(탑다운 45°) 배틀로얄 프로토타입입니다.

- 플레이어 1명 vs 봇 all (기본 11명), 자기장이 좁아지며 최후의 1인 생존
- 숲 맵 1개 (절차적 배치, MapSpec JSON 기반)
- Windows / macOS Universal 동시 출시 목표
- 프로젝트 저장소: `https://github.com/Kyulhee/battle-capsule`

**핵심 설계 원칙**

1. 절차적 우선 — 에셋보다 코드 생성(절차적 사운드, 픽셀 아이콘, 맵 배치)으로 빠른 이터레이션
2. 상태 머신 AI — 봇은 State enum + 핸들러 함수 구조로 확장 가능하게 유지
3. 데이터 분리 — 무기/아이템 밸런스는 `.tres` 리소스 파일에서 관리, 코드 수정 최소화
4. 난이도는 파라미터 — AI 행동을 하드코딩하지 않고 변수로 노출해 난이도 시스템으로 연결

---

## 코드베이스 구조

```
src/
├── core/
│   ├── Entity.gd           # 모든 캐릭터의 기반 클래스 (CharacterBody3D)
│   ├── StatsData.gd        # 무기/캐릭터 스탯 Resource
│   ├── ItemData.gd         # 아이템 정의 Resource (type, rarity, ammo_weapon_type)
│   ├── SoundManager.gd     # 절차적 오디오 생성 (Autoload: Sfx)
│   ├── Telemetry.gd        # 매치 통계 기록 (Autoload: Telemetry)
│   ├── MapSpec.gd          # JSON 맵 스펙 파서
│   ├── pistol_stats.tres   # 기본 지급 피스톨 스탯
│   ├── player_stats.tres   # 플레이어 기본 스탯
│   ├── bot_stats.tres      # 봇 기본 스탯
│   └── super_weapon_stats.tres  # 레일건 스탯
├── entities/
│   ├── Entity.gd           # HP, 방어막, 인식 시스템, 이동
│   ├── player/Player.gd    # 입력, 무기 슬롯, HUD, 재장전
│   ├── bot/Bot.gd          # AI 상태 머신 (IDLE/CHASE/ATTACK/ZONE_ESCAPE/RECOVER)
│   └── pickup/Pickup.gd    # 아이템 픽업 (Area3D)
├── items/                  # .tres 아이템 정의 파일
├── maps/
│   └── WorldBuilder.gd     # MapSpec을 읽어 맵 오브젝트 생성
├── environment/
│   ├── Bush.gd             # 풀숲 (스텔스 영역)
│   └── WorldElement.gd     # 맵 환경 요소 기반
├── fx/                     # 시각 이펙트 (MuzzleFlash, BulletTrail 등)
├── ui/
│   └── Minimap.gd
└── Main.gd                 # 게임 루프, 존, 스폰, 보급 캡슐
data/
└── mapSpec_example.json    # 맵 POI 및 배치 정보
```

---

## 핵심 시스템 요약

### 무기 인벤토리 (Player.gd)

- 5슬롯: slot 0 = 칼(항상), slot 1~4 = 총기
- `weapon_slots[]: Array[StatsData]` — 슬롯별 무기 데이터
- `slot_ammo[]: Array[int]` — 탄창 (장전된 탄)
- `slot_reserve[]: Array[int]` — 예비 탄약 (백팩)
- R키 → `_start_reload()`: reserve → ammo 이동, 장전 시간 중 카운트업 애니메이션
- 같은 weapon_type 중복 습득 불가

### 봇 AI (Bot.gd)

상태 머신: `IDLE → CHASE → ATTACK → RECOVER → ZONE_ESCAPE`

| 상태          | 전환 조건                                     |
| ----------- | ----------------------------------------- |
| IDLE        | 적 없음, 루팅 없음                               |
| CHASE       | 적 발견 (ammo > 0) 또는 픽업 목표 있음               |
| ATTACK      | 적과 engage 거리 이내                           |
| RECOVER     | ammo == 0 (seek_cover → seek_loot 서브스테이트) |
| ZONE_ESCAPE | 자기장 밖 감지                                  |

**현재 한계**: 직선 이동(pathfinding 없음), 같은 벽에 클러스터링, 아군 봇 인식 없음

### 인식 시스템 (Entity.gd)

- `perception_meters: Dictionary` — 대상별 0.0~1.0 감지 게이지
- 시야 범위 + FOV 각도 + 레이캐스트 LOS 체크
- `stealth_modifier`: 풀숲/웅크리기 시 감소
- `is_revealed_to(viewer)` → perception_meters >= 1.0

### 존 & 보급 (Main.gd)

- 2단계 자기장 수축 (stage 1 → stage 2)
- stage 2에서 supply 캡슐 낙하 (희귀 무기 포함)
- `zone_damage`: 자기장 밖 틱 데미지 (설정값 존재, 적용 로직은 `handle_damage_tick`)

### 사운드 (SoundManager.gd)

절차적 오디오 — 파일 없이 코드로 WAV 버퍼 생성.  
`Sfx.play("shoot")` / `Sfx.play("shoot", global_position)` (3D)

---

## 릴리즈 히스토리

| 버전     | 날짜         | 핵심 내용                                              |
| ------ | ---------- | -------------------------------------------------- |
| v0.1.0 | 2026-04-23 | 초기 프로토타입: 봇 AI, 자기장, 기본 루팅                         |
| v0.2.0 | 2026-04-23 | 보급 캡슐, 스텔스/풀숲, 미니맵, 기록 화면                          |
| v0.2.1 | 2026-04-23 | 웅크리기 버그 수정, 풀숲 높이/투명도 수정                           |
| v0.3.0 | 2026-04-24 | 5슬롯 무기 인벤토리, 픽셀 아이콘, 픽업 비주얼                        |
| v0.3.1 | 2026-04-24 | 중복 무기 방지, R키 리로드, 탄약/최대 HUD                        |
| v0.3.2 | 2026-04-24 | 탄창+예비 2단계 탄약, 무기 밸런스, macOS 출시                     |
| v0.4.0 | 2026-04-25 | 봇 AI 개선 (끼임/분산/reserve), Telemetry 재설계, 헤드리스 시뮬레이션 |
| v0.5.0 | 2026-04-26 | 스폰 수정, 벽 투명화, 자기장 누적 강화, 칼 이펙트, 봇 칼 돌진             |
| v0.5.1 | 2026-04-26 | 쉴드 너프, 드랍 분리, 힐 2단계, 킬 집계 수정, 벽 투명화 수정, 킬피드 전체 표시  |
| v0.6.0 | 2026-04-26 | DISENGAGE 상태, 수적 열세 감지, 장애물 그룹 기반 커버 탐색            |
| v0.6.1 | 2026-04-26 | DISENGAGE 클러스터링 핫픽스, Alive 버그 수정, 킬피드 개선           |
| v0.7.0 | 2026-04-26 | HUD 재설계 — ProgressBar HP/SH, Zone 패널, 킬피드 3단계      |
| v0.7.1 | 2026-04-26 | 아이템 픽셀 아이콘 시스템, HUD 스탯 아이콘, assist 버그 수정           |
| v0.7.2 | 2026-04-26 | HUD 스탯 Unicode 심볼 교체, 픽업 Sprite3D 제거, 메시 형태 개선     |
| v0.8.0 | 2026-04-26 | 봇 성격 3종, 집단 공격 강화, 발소리 감지, 루팅 우선순위, 난이도 시스템        |
| v0.8.1 | 2026-04-27 | 전체 메뉴 UI 재설계 (그라디언트 배경, 픽셀 캡슐 로고, 키캡 How to Play, 해골/손/인물 HUD 아이콘) |
| v0.8.2 | 2026-04-27 | Zone escape 강화 (95% 조기 탈출, 각도 샘플링 unstuck, zone death 텔레메트리) |
| v0.8.3 | 2026-04-27 | HUD safe margin, 킬피드-미니맵 겹침 제거, 난이도 툴팁, Result 버튼 3종, Bot AI 생존 강화 |
| v0.8.4 | 2026-04-27 | display_name/kill_streak 추가, 킬피드 weapon glyph + 봇 번호 + streak 표시 |
| v0.9.0 | 2026-04-27 | 봇 상태 아이콘(? ! ◉ ◎), 히트 마커, 피해 숫자 플로팅, 자기장 경고 오버레이 |
| v0.9.1 | 2026-04-27 | Zone escape stuck 버그 수정 — dead code 제거, 에스컬레이션 thrash, 스테이지별 조기 진입 임계값 |
| v0.9.2 | 2026-04-27 | Hell Difficulty — HP 1 시작, 힐 감소(×0.40/×0.55), 암전(15–28s), 폭격(18–28s, r=5, 45dmg) |

---

## 로드맵

### ~~v0.4 — 봇 AI 개선~~ (완료)

우선순위 높음:

- **끼임 방지**: 일정 시간 속도 < 0.3 감지 → 임시 우회 방향 주입 (`stuck_timer`)
- **개인화 분산 (scatter)**: `get_instance_id() % 8 * (PI/4)` 각도 오프셋으로 봇마다 다른 방향으로 도주 → 벽 클러스터링 방지
- **봇 reserve ammo + 리로드**: RECOVER 진입 시 reserve 있으면 리로드 후 복귀, 없으면 루팅 탐색
- **루팅 탐색 반경 확대**: RECOVER 시 35 → 70, 없으면 랜덤 patrol point 생성
- **봇 사망 시 무기 드롭**: `Entity.die()`에서 현재 무기를 Pickup으로 스폰
- **피격 도주 트리거**: 탄약 없는 봇이 피격되면 RECOVER 강제 전환

### ~~v0.5 — 전장 경제~~ (완료: v0.5.0 + v0.5.1)

자기장·아이템·힐·근접전 시스템을 개편하여 초반 의사결정(교전 vs 파밍)을 의미있게 만든다.

**버그픽스**

- **스폰 끼임 해소**: 스폰 포인트가 지오메트리와 겹치는 현상 방지 (유효 위치 검증 후 배치)
- **벽 투명화**: 카메라와 플레이어 사이에 벽이 끼면 해당 벽을 반투명 처리, 시야 확보

**자기장**

- **자기장 피해 플레이어 적용**: 현재 봇에만 적용 → 플레이어도 포함
- **자기장 피해 누적 강화**: stage별 기본 피해 증가 + 외부 체류 시간에 비례한 점진 가중 (tick당 multiplier)

**근접전**

- **칼 사운드 + 타격 이펙트**: 휘두를 때 사운드, 적 히트 시 이펙트 추가
- **봇 칼 돌진 결정**: 탄약 소진 시 봇이 자신의 HP·거리를 고려해 칼 돌진 vs 루팅 탐색을 랜덤 확률로 결정

**아이템 경제**

- **초반 쉴드 너프**: 방어구 수치 대폭 감소, 초반 권총·칼 교전에서 빠른 제거 가능하도록
- **드랍 아이템 분리**: 봇·플레이어 사망 시 무기와 탄약을 별도 아이템으로 드랍. 신규 습득 시 탄약 일부 자동 장전은 유지
- **사망 시 힐 전량 드랍**: 보유 힐 아이템 전부 드랍하여 킬의 경제적 가치 부여
- **힐 2단계**: 기본 힐(점진 회복, 낮은 등급) / 고급 힐(즉시 회복, 희귀). Q키 사용 시 고급 우선 소비

*구현 중 범위가 크면 v0.5.x 단위로 분리*

### ~~v0.6 — 전술 의식~~ (완료: v0.6.0~v0.6.1)

DISENGAGE 상태, 수적 열세 감지, 장애물 기반 엄폐물 탐색, 클러스터링 핫픽스.

### ~~v0.7 — HUD/UI 재설계~~ (완료: v0.7.0~v0.7.2)

HUD 레이아웃 구역 분리, ProgressBar HP/SH, 킬피드 3단계, Unicode 스탯 심볼, 픽업 비주얼 정리, assist 버그 수정.

---

### ~~v0.8 — AI 전투 개선~~ (완료: v0.8.0)

봇 행동의 밀도와 다양성을 높인다. 글로벌 상태 없이 봇 각각의 독립 판단으로 구현.

#### 집단 공격 강화

같은 목표를 공격 중인 봇이 많을수록 개별 봇이 더 공격적으로 변한다.

- **공격자 수 감지**: ATTACK 진입 시 `"bots"` 그룹 순회 → `target_actor` 일치 봇 수 집계
- **공격성 스케일**: 공격 봇 ≥ 2이면 `fire_rate` 단축 + DISENGAGE 진입 임계값 상향
- **접근각 자연 분산**: 기존 scatter offset 유지 — 인위적 포위 없이 다른 방향에서 자연스럽게 접근

#### 봇 성격 분류

스폰 시 각 봇에 성격 프리셋을 랜덤 배정. 기존 파라미터를 묶는 방식이라 상태 머신 수정 불필요.

| 성격         | 특징                                              |
| ---------- | ----------------------------------------------- |
| aggressive | vision_range↑, reaction_delay↓, DISENGAGE 임계 높음 |
| defensive  | DISENGAGE 적극 활용, 엄폐 우선, 교전 거리 유지                |
| scavenger  | RECOVER 반경 확대, 루팅 우선, 교전 회피 성향                  |

#### 발소리 감지

플레이어가 달리면 반경 내 봇의 `last_known_position` 갱신 — 기존 시야 인식에 청각 레이어 추가.

- 달리기 시 `footstep_range` (기본 12m) 내 봇에게 위치 노출
- 웅크리기·정지 시 발소리 없음 → 풀숲 스텔스와 상호작용

#### 봇 루팅 우선순위

현재 근처 픽업 무작위 수집 → 상황별 우선순위 정렬.

- HP < 40% → 힐 아이템 우선
- ammo == 0 → 탄약/무기 우선
- 그 외 → 기존 거리 기반

#### 난이도 시스템

메인 메뉴에서 선택. `BotDifficulty` Dictionary로 파라미터 묶음 관리.

```gdscript
var DIFFICULTY_PRESETS = {
    "easy":   { "vision_range": 16.0, "reaction_delay": 1.2, "aim_spread_mult": 1.8 },
    "normal": { "vision_range": 22.0, "reaction_delay": 0.8, "aim_spread_mult": 1.0 },
    "hard":   { "vision_range": 28.0, "reaction_delay": 0.4, "aim_spread_mult": 0.6 },
}
```

`reaction_delay`: `_find_nearest_target()` 결과를 `pending_target`에 저장, 타이머 후 `target_actor`로 확정.



## v0.8.2 — Zone / Bot Survival Hotfix

**목표**  
봇들이 존이 충분히 넓은데도 자기장에 타죽는 현상을 진단하고 수정한다.

**배경 가설**  
봇이 자기장 밖이거나 자기장 경계 근처에 있는데도 `DISENGAGE`, `RECOVER`, `CHASE`, `ATTACK` 같은 전술 상태가 우선되어 벽 또는 장애물 근처에서 빠져나오지 못하는 것으로 보인다.  
또는 `ZONE_ESCAPE`가 발동해도 직선 이동/pathfinding 한계 때문에 벽에 막힌 상태에서 자기장 피해를 계속 받는 상황일 수 있다.

**핵심 작업**

- Zone 사망 진단 Telemetry 추가
  - `death_cause = zone`
  - `state_at_death`
  - `time_outside_zone`
  - `distance_to_zone_center`
  - `stuck_time_before_death`
  - `last_state_transitions`
- `ZONE_ESCAPE` 우선순위 상향
  - 자기장 밖이면 `DISENGAGE`, `RECOVER`, `CHASE`보다 우선
  - 단, 공격 중이라도 zone damage 누적 시간이 일정 이상이면 강제 탈출
- Zone escape용 unstuck 로직 추가
  - zone 밖 + velocity 낮음 + 0.8초 이상 정체 시, 일반 scatter가 아니라 zone center 방향으로 강제 보정
  - 장애물에 막히면 좌/우 후보 방향을 샘플링해 더 zone 중심에 가까워지는 방향 선택
- 봇 상태 snapshot 강화
  - stage 전환 시 봇별 state, HP, zone inside/outside, stuck 여부 출력
- 헤드리스 시뮬레이션 기준 추가
  - zone이 충분히 넓은 stage 1~2에서 zone death가 과도하면 실패
  - zone 밖 누적 사망이 대부분 stuck과 연결되면 실패

**수정 후보 파일**

- `src/entities/bot/Bot.gd`
- `src/Main.gd`
- `src/core/Telemetry.gd`

**검증 기준**

- 10회 headless simulation 기준 stage 1~2 zone death가 비정상적으로 높지 않아야 한다.  
- zone outside 상태에서 stuck이 발생하면 1~2초 내 탈출 시도가 기록되어야 한다.  
- 기존 DISENGAGE / RECOVER / CHASE / ATTACK 동작이 깨지지 않아야 한다.

---

## v0.8.3 — UI Polish + Difficulty Tooltip

**목표**  
메인 메뉴, 기록, 도움말, 결과 화면을 제품형 UI에 가깝게 다듬고, 난이도 설명 팝업을 추가한다.

**핵심 작업**

- HUD safe margin 정리
  - 좌상단 HP/SH/stat 영역 잘림 방지
  - 하단 무기 슬롯 잘림 방지
  - 미니맵과 킬피드 겹침 완화
- Difficulty tooltip
  - `쉬움 / 보통 / 어려움 / Hell` 버튼 hover 시 설명 패널 표시
  - 예시:
    - 쉬움: “봇 시야 감소, 반응 느림, 조준 부정확”
    - 보통: “기본 밸런스”
    - 어려움: “봇 시야 증가, 즉시 반응, 조준 정확”
    - Hell: “HP 1 시작, 회복량 감소, 특수 이벤트 발생”
- Result screen 버튼 추가
  - `RESTART`
  - `MAIN MENU`
  - `RECORDS`

**수정 후보 파일**

- `src/Main.gd`
- `src/entities/player/Player.gd`
- `src/ui/Minimap.gd`
- 필요 시 `src/ui/UiTheme.gd` 신규 생성

**검증 기준**

- 1280x720, 1600x900, 1920x1080에서 UI가 잘리지 않아야 한다.  
- 난이도 버튼 hover 시 설명 패널이 정상 표시/숨김 처리되어야 한다.  
- 기존 records 저장/로드가 깨지지 않아야 한다.

---

## v0.8.4 — Actor Identity + Killfeed Data Foundation

**목표**  
Bot 번호, 플레이어 이름, 무기 타입, 킬스트릭 정보를 전투 로그에서 안정적으로 사용할 수 있게 만든다.

이 단계에서는 “화려한 연출”보다 **데이터 구조 정리**가 우선이다.

**핵심 작업**

- Bot 번호 부여
  - 스폰 순서대로 `Bot 1` ~ `Bot 11`
  - `display_name` 필드 추가
  - 플레이어는 `YOU` 또는 `Player`
- Kill event 구조 정리
  - killer display name
  - victim display name
  - weapon type
  - killer type: player/bot
  - victim type: player/bot
  - kill streak count
- Weapon icon/glyph 매핑
  - Knife
  - Pistol
  - Assault Rifle
  - Shotgun
  - Railgun
- 기존 킬피드가 새 event 구조를 사용하도록 변경
- 봇끼리 킬도 “Bot 1 → Bot 2”처럼 표시

**예시 출력**

Bot 3  [Pistol Icon]  Bot 7  
YOU    [Railgun Icon] Bot 2  
Bot 1  [Knife Icon]   Bot 4

**수정 후보 파일**

- `src/Main.gd`
- `src/entities/Entity.gd`
- `src/entities/bot/Bot.gd`
- `src/entities/player/Player.gd`
- `src/core/Telemetry.gd`

**검증 기준**

- 모든 봇이 고유 display_name을 가져야 한다.  
- killfeed에서 killer/victim이 null 또는 빈 문자열로 표시되면 안 된다.  
- 봇끼리 킬과 플레이어 킬이 동일한 event 구조로 처리되어야 한다.  
- 기존 K/A 집계가 깨지지 않아야 한다.

---

## v0.9.0 — Combat Feedback + Visual Killfeed

전투 중 피드백을 강화하되, 기존 v0.9 로드맵의 Metal Gear 스타일 봇 경계 아이콘은 그대로 유지한다.

### 보존할 요소: 봇 경계 아이콘

기존 설계를 변경하지 않는다.

- IDLE: 표시 없음
- CHASE: 노란색 `?`
- ATTACK: 빨간색 `!`
- 눈 아이콘:
  - IDLE: `―`
  - CHASE: `◉`
  - ATTACK: 빨간색 `◎`

구현 시 수정 가능한 범위는 다음으로 제한한다.

- 아이콘이 봇 머리 위에 안정적으로 표시되도록 위치 보정
- 카메라를 향하도록 billboard 처리
- 너무 멀리 있는 봇은 표시 축소 또는 숨김
- 전투 중 다른 UI와 겹치지 않도록 outline/shadow 적용
- 상태 변화 시 즉시 갱신

아이콘 체계, 색상 의미, 기호 의미는 변경하지 않는다.

### 추가할 요소

1. Visual killfeed
   
   - `killer` + `weapon icon` + `victim` 구조
   - 플레이어 관련 킬은 강하게 강조
   - 봇끼리 킬은 저채도 표시

2. Kill streak scaling
   
   - 동일 캐릭터가 2킬, 3킬, 4킬, 5킬 이상 기록할 때 메시지 강조 증가
   - 5킬부터 최대 크기로 제한

3. Hit marker
   
   - 플레이어가 피해를 주면 화면 중앙에 짧은 `×` 표시

4. Damage number
   
   - 대상 머리 위에 피해량 표시

5. Zone warning
   
   - 플레이어가 zone 밖에 있을 때 Zone timer 또는 화면 가장자리 pulse

### 명시적 금지

- Metal Gear 스타일 경계 아이콘을 다른 디자인으로 교체하지 않는다.
- `? / !` 구조를 삭제하지 않는다.
- 봇 상태 표시와 killfeed를 하나의 UI로 합치지 않는다.
- 봇 AI 판단 로직은 이 단계에서 변경하지 않는다.

---

## v0.9.1 — Hell Difficulty Prototype

**목표**  
기존 Easy/Normal/Hard와 다른 “도전 모드”를 추가한다.  
단, 밸런스 완성보다 이벤트 구조와 모드 분리를 우선한다.

**Hell 난이도 기본 규칙**

- 플레이어 HP 1로 시작
- 최대 HP는 유지하되, 시작 HP만 1
- 회복량 감소
  - 일반 힐: 기존 대비 30~50%
  - 고급 힐: 기존 대비 50~70%
- 봇 시야 +1.0
  - 기존 Hard 파라미터에 절대값으로 추가
- 봇 반응속도 Hard 기준 유지 또는 소폭 강화
- 시작 시 5초 알림 표시

**시작 알림 예시**

HELL MODE  
HP 1 START  
HEALING REDUCED  
BLACKOUTS AND BOMBARDMENTS ENABLED  
SURVIVE IF YOU CAN

**Hell 이벤트**

1. Blackout
   - 주기적으로 2~4초 암전
   - HUD는 최소한 보이게 유지
   - 완전한 검은 화면보다는 시야 반경 축소/어두운 overlay 추천
2. Bombardment
   - 랜덤 위치에 경고 원 표시
   - 1.5초 후 폭격
   - 플레이어와 봇 모두 피해 가능
   - 초반 10초 grace period 적용
3. Event announcement
   - 이벤트 발생 전 짧은 경고 텍스트 표시
   - 예: `BOMBARDMENT INCOMING`

**중요 제약**

- Hell 이벤트는 `HELL` 난이도에서만 활성화
- Easy/Normal/Hard에는 영향 없음
- 이벤트는 seed 기반으로 재현 가능하게 설계
- headless simulation에서는 event log만 기록하거나, 시각 효과 없이 피해 로직만 검증

**수정 후보 파일**

- `src/Main.gd`
- `src/entities/player/Player.gd`
- `src/entities/bot/Bot.gd`
- `src/core/Telemetry.gd`
- 필요 시 `src/core/HellEventManager.gd` 신규 생성

**검증 기준**

- Hell 선택 시에만 HP 1 시작이 적용되어야 한다.  
- Easy/Normal/Hard의 HP, 회복량, 이벤트 상태가 변하면 안 된다.  
- blackout과 bombardment가 동시에 과도하게 겹치지 않아야 한다.  
- 폭격 경고 표시 후 실제 피해까지 delay가 있어야 한다.

---

## v0.9.2 — Hell Balance + Event Telemetry

**목표**  
Hell 난이도를 “불합리한 장난 모드”가 아니라 “읽을 수 있는 고난도 모드”로 조정한다.

**핵심 작업**

- Hell event telemetry
  - blackout_count
  - bombardment_count
  - damage_by_bombardment
  - death_by_bombardment
  - survived_hell_time
- 이벤트 간 최소 간격 설정
- 초반 grace period 조정
- 폭격 반경/피해량 조정
- 회복량 감소 배율 조정
- Hell records 분리 여부 검토
  - 일반 기록과 Hell 기록을 분리할지 결정

**검증 기준**

- Hell이 어렵지만 즉사 운빨만으로 결정되지 않아야 한다.  
- 10회 테스트에서 최소 일부 run은 30초 이상 생존 가능해야 한다.  
- 폭격과 암전이 겹쳐 플레이 불가능한 구간이 반복되면 실패.

---

## v1.0 — Navigation / Map / Alpha Completion

**목표**  
알파 버전으로 보여줄 수 있는 구조적 완성도를 만든다.

**핵심 작업**

- NavigationRegion3D + NavigationAgent3D
  - 봇 직선 이동 한계 해결
  - zone escape, chase, recover, disengage 모두 pathfinding 기반으로 전환
- 맵 경계 충돌체
- 커버 오브젝트 추가
- Settings menu
  - 볼륨
  - 마우스 감도
  - 화면 크기
- 결과 화면 확장
  - 피해량
  - 명중률
  - 생존 시간
  - 최고 킬스트릭
- Bot name variation
  - 기본은 Bot 1~11 유지
  - 추후 별칭 선택 가능



## 다음 AI 에이전트에게

**작업 시작 전 확인할 파일**

- `Bot.gd` — AI 로직 전체
- `Player.gd` — 무기 슬롯, 재장전, HUD
- `Entity.gd` — 공통 베이스 (이동, 피해, 인식)
- `Main.gd` — 게임 루프, 존, 스폰

**알아야 할 Godot 4 quirks**

- Control preset은 `PRESET_CENTER_BOTTOM` (not `PRESET_BOTTOM_CENTER`)
- `grow_vertical = GROW_DIRECTION_BEGIN` 없으면 bottom anchor가 화면 밖으로 나감
- macOS export preset key는 `application/bundle_identifier` (not `application/identifier`)
- `--export-release` headless 시 macOS 공증 경고가 hard error로 처리됨 → 위 키 문제 해결 후 통과

**현재 미해결 이슈**

- `src/fx/ShotPing.tscn`과 `src/fx/ImpactEffect.tscn`의 UID 충돌 경고 (기능에는 무해)
- NavigationMesh 없어서 봇 직선 이동만 가능 (v0.9 목표)
