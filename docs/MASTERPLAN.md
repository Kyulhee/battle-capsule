# 배틀캡슐 마스터 플랜

> 마지막 업데이트: 2026-04-26 (v0.7.2 완료, v0.8~v1.0 로드맵 재정립)  
> 이 문서는 AI 에이전트 간 인수인계 및 장기 방향 공유를 위해 작성되었습니다.

**현재**: v0.7.2 완료 — 다음: v0.8 (AI 전투 개선)

**문서 구조** *(각 파일의 업데이트 시점 기준 → [CLAUDE.md](../CLAUDE.md))*
- [CLAUDE.md](../CLAUDE.md) — 세션 시작 시 온보딩 (현재 상태, 핵심 파일, 퀵 커맨드)
- [MASTERPLAN.md](MASTERPLAN.md) — 전체 로드맵 & 설계 원칙 ← 지금 여기
- [DEVLOG.md](DEVLOG.md) — 버전별 구현 상세 (완료된 것)
- [TESTING.md](TESTING.md) — 헤드리스 시뮬레이션 검증 (구현 후 실행)
- [RELEASE.md](RELEASE.md) — 빌드 → GitHub 릴리즈 → README 업데이트

---

## 프로젝트 개요

**배틀캡슐 (Battle Capsule)** 은 Godot 4.6.2 / GDScript로 개발 중인 쿼터뷰(탑다운 45°) 배틀로얄 프로토타입입니다.

- 플레이어 1명 vs 봇 11명, 자기장이 좁아지며 최후의 1인 생존
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

| 상태 | 전환 조건 |
|---|---|
| IDLE | 적 없음, 루팅 없음 |
| CHASE | 적 발견 (ammo > 0) 또는 픽업 목표 있음 |
| ATTACK | 적과 engage 거리 이내 |
| RECOVER | ammo == 0 (seek_cover → seek_loot 서브스테이트) |
| ZONE_ESCAPE | 자기장 밖 감지 |

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

| 버전 | 날짜 | 핵심 내용 |
|---|---|---|
| v0.1.0 | 2026-04-23 | 초기 프로토타입: 봇 AI, 자기장, 기본 루팅 |
| v0.2.0 | 2026-04-23 | 보급 캡슐, 스텔스/풀숲, 미니맵, 기록 화면 |
| v0.2.1 | 2026-04-23 | 웅크리기 버그 수정, 풀숲 높이/투명도 수정 |
| v0.3.0 | 2026-04-24 | 5슬롯 무기 인벤토리, 픽셀 아이콘, 픽업 비주얼 |
| v0.3.1 | 2026-04-24 | 중복 무기 방지, R키 리로드, 탄약/최대 HUD |
| v0.3.2 | 2026-04-24 | 탄창+예비 2단계 탄약, 무기 밸런스, macOS 출시 |
| v0.4.0 | 2026-04-25 | 봇 AI 개선 (끼임/분산/reserve), Telemetry 재설계, 헤드리스 시뮬레이션 |
| v0.5.0 | 2026-04-26 | 스폰 수정, 벽 투명화, 자기장 누적 강화, 칼 이펙트, 봇 칼 돌진 |
| v0.5.1 | 2026-04-26 | 쉴드 너프, 드랍 분리, 힐 2단계, 킬 집계 수정, 벽 투명화 수정, 킬피드 전체 표시 |
| v0.6.0 | 2026-04-26 | DISENGAGE 상태, 수적 열세 감지, 장애물 그룹 기반 커버 탐색 |
| v0.6.1 | 2026-04-26 | DISENGAGE 클러스터링 핫픽스, Alive 버그 수정, 킬피드 개선 |
| v0.7.0 | 2026-04-26 | HUD 재설계 — ProgressBar HP/SH, Zone 패널, 킬피드 3단계 |
| v0.7.1 | 2026-04-26 | 아이템 픽셀 아이콘 시스템, HUD 스탯 아이콘, assist 버그 수정 |
| v0.7.2 | 2026-04-26 | HUD 스탯 Unicode 심볼 교체, 픽업 Sprite3D 제거, 메시 형태 개선 |

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

### v0.8 — AI 전투 개선

봇 행동의 밀도와 다양성을 높인다. 글로벌 상태 없이 봇 각각의 독립 판단으로 구현.

#### 집단 공격 강화

같은 목표를 공격 중인 봇이 많을수록 개별 봇이 더 공격적으로 변한다.

- **공격자 수 감지**: ATTACK 진입 시 `"bots"` 그룹 순회 → `target_actor` 일치 봇 수 집계
- **공격성 스케일**: 공격 봇 ≥ 2이면 `fire_rate` 단축 + DISENGAGE 진입 임계값 상향
- **접근각 자연 분산**: 기존 scatter offset 유지 — 인위적 포위 없이 다른 방향에서 자연스럽게 접근

#### 봇 성격 분류

스폰 시 각 봇에 성격 프리셋을 랜덤 배정. 기존 파라미터를 묶는 방식이라 상태 머신 수정 불필요.

| 성격 | 특징 |
|---|---|
| aggressive | vision_range↑, reaction_delay↓, DISENGAGE 임계 높음 |
| defensive | DISENGAGE 적극 활용, 엄폐 우선, 교전 거리 유지 |
| scavenger | RECOVER 반경 확대, 루팅 우선, 교전 회피 성향 |

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

---

### v0.9 — 피드백 & 전장 시각화

전투의 느낌과 전장 정보 가독성을 집중 개선. 봇 인식 상태를 플레이어가 읽을 수 있게 한다.

#### 봇 경계 표시 (눈 아이콘 + 경계 아이콘)

봇 머리 위 Label3D 두 개로 구현. 빌보드 모드, 아웃라인 포함.

**경계 아이콘** (Metal Gear 스타일) — 감지 상태 표시:

| 상태 | 표시 | 색상 |
|---|---|---|
| IDLE | *(없음)* | — |
| CHASE | `?` | 노랑 |
| ATTACK | `!` | 빨강 |

**눈 아이콘** — 각성 수준 표시:

| 상태 | 기호 | 의미 |
|---|---|---|
| IDLE | `―` | 눈 감음 (비활성) |
| CHASE | `◉` | 눈 뜸 (탐색 중) |
| ATTACK | `◎` 빨강 | 눈 충혈 (전투 중) |

두 아이콘은 수직으로 배치: 눈 아이콘(하단) + 경계 아이콘(상단). 상태 변화 시 즉시 갱신.

#### 미니맵 방향 쐐기

현재 미니맵 봇 점에 작은 삼각형 덧붙여 facing 방향 표시. 전략 정보 레이어만 추가, 메인 화면 부하 없음.

#### 히트마커

피격 성공 시 화면 중앙에 `×` 0.15초 표시 후 fade-out. `CanvasLayer` + `Label`로 구현.

#### 피해 수치 표시

피격 시 대상 머리 위에 숫자 Label3D 생성 → 위로 float하며 0.6초 내 fade-out.

- 일반 피해: 흰색
- 크리티컬(백어택): 주황 + 크기 1.3×

#### 백어택 크리티컬

대상 등 뒤 180° 에서 피격 시 피해 1.5×. `_take_damage()` 내 `attacker.global_position`과 `victim.basis.z` 내적으로 판단.

포지셔닝에 전술적 의미 부여 — 칼 근접전에서 특히 유효.

#### Zone 경고음

자기장 밖에 있을 때 틱 데미지마다 비프음. 기존 `Sfx.play()` 패턴으로 추가.

#### 사망 후 관전 모드

플레이어 사망 시 카메라가 랜덤 생존 봇을 자동 추적. 결과 화면(v1.0) 전까지 공백 해소.

#### 보급 캡슐 2차 드롭

현재 stage 2 1회 → stage 3 추가 드롭. 후반 교전 유인. 위치는 zone 중심 근처 랜덤.

---

### v1.0 — 이동·맵·알파 완성

#### 이동 & 맵

- **NavigationRegion3D + NavigationAgent3D**: 장애물 우회 경로탐색 — 봇 끼임 근본 해결
- **맵 커버 오브젝트 추가**: WorldBuilder에서 바위·창고·나무 군집을 POI 주변 배치, `"obstacles"` 그룹 태그
- **맵 경계 충돌체**: 봇/플레이어 맵 이탈 방지

#### 알파 완성

- **매치 결과 화면**: 순위, 킬수, 어시스트, 피해량, 생존 시간
- **봇 이름 랜덤 생성**: 킬피드 표시용
- **기본 이동/사격 애니메이션**: CharacterBody3D에 AnimationPlayer 연결
- **볼륨/감도 옵션 메뉴**: 메인 메뉴 Settings 탭
- **맵 2개 이상**: 두 번째 맵 추가 (도시/실내 테마 검토)

---

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
