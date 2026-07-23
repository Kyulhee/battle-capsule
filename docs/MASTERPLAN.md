# 마스터플랜

> 최종 업데이트: 2026-07-23. 남은 작업은 마일스톤 -> 트랙 -> 종료 조건 -> 다음 slice 순서로 관리한다.

## 현재 제품 목표

Battle Capsule은 low-poly quarter-view tactical roguelite battle royale 프로토타입이다. 현재 목표는 “많은 봇이 도는 시뮬레이션”이 아니라, 플레이어가 읽고 판단할 수 있는 10-15분 Night BR 한 판을 만드는 것이다.

## 마일스톤

| ID | 이름 | 상태 | 완료 기준 |
|---|---|---|---|
| M0 | 운영 정리 | 진행 중 | 기본 문서 3개 중심으로 재개 가능하고, 검증/푸쉬 루틴이 반복 가능 |
| M1 | 첫 플레이 가능한 Night BR | 진행 중 | `night_br_m1_60` 한 표면이 자동 gate와 수동 체감 기준을 모두 통과 |
| M2 | 버티컬 슬라이스 | 계획 | 맵, 전투, 루트, 존, UI, 자산이 한 화면에서 설득력 있게 동작 |
| M3 | 콘텐츠 안정화 | 이후 | 검증된 코어 루프 위에서 밸런스/자산/시스템 확장 |

## 현재 기준선

- M1 개발 맵: `data/mapSpec_night_forest_expanded_candidate.json`
- M1 공통 preset: `night_br_m1_60` (일반 실행·수동 플레이·후보 페이싱 검증)
- 기존 `mapSpec_night_forest_candidate.json`과 `playable_pacing_v4-v6`는 과거 비교 기준으로만 유지
- 구조 gate: `target_99_probe`
- 자동·수동 gameplay 기준: `night_br_m1_60`
- 자동 페이싱 기준: `night_br_m1_60` 5-run 평균 660.3초, 개별 488.2-875.4초
- 존 기준: stage2 260초, stage3 540초. first upgrade 평균 260.7초
- 최신 gameplay slice: N2-PLAY-08 지면·지역 표현 개선, 도로/숲 위험 차이와 자기장 선점은 반복
- 최신 AI slice: N2-AI-10 상태·도착 시간·점유·노출 효용 기반 목적지/도로/선점 선택
- 최신 map/world slice: N2-MAP-16 Cabin Row-참조 초소-Logging Ford 3거점 이동 루프
- 최신 UI slice: N2-UI-01 플레이어 중심 120m/280px 미니맵과 Main 단일 소유권
- 최신 asset slice: N2-ASSET-05 감시탑·천막·대형 바위·통나무·쓰러진 나무 GLB 승격
- 최신 검증 기반: N2-PACE-34부터 `Main.match_timer`를 canonical time으로 사용하고 navigation bake 완료 뒤 시뮬레이션 시작
- N2-VIS-01: Night 전용 월드 주변광 0.38과 달빛 0.32를 Main/캡처에서 공유하고 cover·수풀 픽셀 대비 gate를 추가. `unit_smoke`, `visual_review` 통과
- N2-MAP-04: minimap/fullmap/world route 표현을 제거하고 전체 지도를 미니맵과 같은 45도 좌표계로 정렬. 방향 smoke와 실제 캡처 통과
- N2-AI-02: `BotDecisionPolicy`로 추가 위협, 표적 점수, 엄폐 위치 효용을 scene/state 실행에서 분리. 기존 수치를 보존하고 정책 smoke, Arena, `unit_smoke` 통과
- N2-TOOLS-02: 실제 Main의 `duel_1`을 3초 실행해 고정 스폰, 초기 loot 격리, 플레이어 표적 획득과 HP 100→90을 검증하는 runtime smoke를 `ai_test_arena`/`unit_smoke`에 연결
- N2-AI-04: 일반 표적 기억은 2.5초로 보존하고 플레이어 표적만 5초로 연장. 격리된 `squad_4` 3초 구간에서 유지율 100%, 동시 표적 4명, 공격 참여 4명
- N2-AI-05: 기존 perception 순회에서 LOS가 있는 3m 근접 캐시를 만들고 ATTACK/비loot CHASE에만 2.75m 분리 조향 적용. 자연 5-run의 1.5m 미만 접촉이 3회에서 0회로 감소했고, 강제 1.1m 쌍은 5/5회 0.15-0.25초 안에 분리
- N2-AI-06: 전체 bot 교전 분리는 60봇에서 평균 종료 261.5→195.7초와 정체 0.14→0.22/개체·분으로 흐름을 바꿔 폐기. player-target 전투에만 캐시·분리를 적용한 최종안은 99봇 종료 220.6→217.1초, 정체 0.14→0.12, 이탈 0.42→0.43, AI 평균 비용 +6.1%로 회귀 통과
- N2-PERF-01/02: AI 검색·텔레메트리를 분산·캐시해 60봇 p95 45.5→13.5ms로 줄였다. 실제 Minimap 정상 로드 뒤 정적 지형의 매 프레임 draw가 p95 36.6-39.1ms를 만들자 배경·POI·지형을 1회 텍스처로 캐시해 15.4-15.8ms, 33ms 초과 0.14-0.27%로 복구했다
- N2-AI-07: spawn 반경·POI·route 점유와 loot 목적지 POI 이름을 계측했다. 60/99봇 spawn은 POI 내부 25.7/26.5%지만 IDLE loot 목표는 66.3/67.2%가 내부이고 약 90%가 route 위였다. 피해 70-71%가 open이라 AI 목적지 부재보다 POI 교전 유출을 다음 원인으로 판정
- N2-MAP-06/08/09: 중앙 high rock은 ramp 제거 뒤에도 셀 정체가 재발했다. 비-rock 폭 4m wall은 Arena 4봇 5/5회 6.55초·stuck 2였지만 제품 60봇 `10,10` 셀 0→16회, open 피해 69.7→69.6%라 기각하고 traffic 재현기만 유지했다
- N2-MAP-07: open 피해를 10m 셀·인접 POI·경계 대역 복합 키로 계측했다. 60/99봇 상위 셀은 6.7% 이하로 분산됐고 기존 바위 `(-6,-48)`, `(8,46)` 셀이 open 피해 약 10-11%와 정체 약 15-23%를 함께 차지해 단일 POI 입구 가설을 기각했다
- N2-NAV-01/02/03: 실제 geometry bake와 빈 nav gate를 복구한 뒤 `0,40` 정체를 추적해, 잘못된 Minimap UID가 `TestMap/Wall2` 물리를 UI 아래에 주입한 사실을 확인했다. UID 교정과 물리 UI 금지 gate 뒤 60/99봇 stuck은 1.4/1.2, 반복 `0,40` 정체는 0이 됐다
- N2-MAP-10: 260m 구조를 카메라 크기·방사 대역·POI 엄폐로 감사하고 중앙·남쪽 loot hub에 수목 3개와 수풀 3개를 배치했다. 중앙/남쪽 개방률은 80.2/39.5%→16.0/17.3%, 60/99봇 POI 피해는 37.0/30.4%→45.6/37.3%로 이동했으며 stuck·성능 회귀는 없었다
- N2-ASSET-01/02/03: 핵심 오디오 8종을 연결했다. 총성은 CC0 실사 CZ/SKS/shotgun/Mosin, 칼은 CC0 swish Foley로 교체하고 권총 -8.5dB, 앉기 발걸음 -10dB·AI 청취 45%를 적용했다
- N2-UI-01: 260m 전역을 압축하던 상시 미니맵을 플레이어 중심 120m/280px로 바꾸고 주요 지명을 표시했다. Main/Player 중복 미니맵을 Main 하나로 정리해 60봇 p95 13.3-14.2ms로 개선했다
- N2-AI-08: POI 메타데이터가 근거리 pickup 배치에는 쓰였지만 loot가 없어진 IDLE은 정지했다. 전투 정책을 보존하고 POI 13개만 저빈도로 선택하는 아키타입별 장기 목적지를 추가했다. 60봇 p95 12.9ms, 3-run 평균 231.1초이며 수동 승격은 보류한다
- N2-MAP-11/N2-ASSET-04: 지면 10구역으로 도로·숲·마당을 구분하고 Cabin Row에 cabin 3동, 외곽 수목, 벽·crate·barrel·fire pit을 묶었다. 칼은 휘두름 3종과 피격음을 분리했다. `unit_smoke`와 실제 캡처를 통과했고 지면은 렌더 노드 2개로 병합했다
- N2-MAP-12: 높이 추정 엄폐를 `hard/screen/soft` 계약으로 교체했다. Cabin Row는 건물 3동과 남·서·동 입구, 입구별 벽 어깨·접근 엄폐·외곽 시야 차폐를 가진 compound로 재배치했다. 세 입구 NavMesh 경로 25.7/32.1/32.1m와 60봇 p95 12.71-12.86ms를 확인했다
- N2-MAP-13: loot·AI용 POI 반경은 유지하되 전체 지도 반경 원을 제거했다. `identity`가 있는 실제 landmark만 물리 앵커에 이름을 표시하며 안전구역 원은 보존한다
- N2-MAP-14/N2-ASSET-05: West Ridge에 감시탑·천막·벌목 프롭·바위 능선을 묶고 노출 도로와 숲 우회에 AI 앵커 5개를 연결했다. 두 NavMesh 경로와 60봇 p95 13.14-13.15ms를 확인했다
- N2-AI-09/N2-MAP-15: surface를 실제 이동 속도에 연결하고 일부 봇이 물리 도로 waypoint를 사용한다. 축소 35-65초 전부터 다음 원 안 접근 앵커를 선점해 다음 stage까지 유지하며 Night runtime gate를 통과했다
- N2-AI-10: 고정 도로 확률을 제거하고 장비·생존·위협·도착 시간·실제 점유로 목적지와 경로를 고른다. Arena/Night/전체 회귀와 60봇 p95 13.82-13.87ms를 통과했다
- N2-HELL-01: 지옥은 `현재 HP 1/최대 HP 100`으로 시작해 회복할 수 있다. `heal_mult=0` 유물만 최대 체력까지 `1/1`로 잠근다
- N2-BASE-01: 확장 Night 맵의 기존 60봇 수치를 `night_br_m1_60`으로 승격하고 무인자 `Main.tscn` 실행, 수동 플레이, 후보 페이싱 명령을 같은 표면으로 통합했다. `xlarge_60`은 과거 명령 호환 alias만 유지한다
- N2-PACE-44: M1 preset에 지연 업그레이드·bot 대 bot 피해·존 일정을 통합했다. 5-run 평균 660.3초, 범위 488.2-875.4초, first upgrade 260.7초, stage2/3 260.1/540.1초, 정체 0.01/개체·분으로 자동 gate를 통과했다

## Night BR 페이싱 판정 창

| 지표 | 목표 창 | 현재 | 판단 |
|---|---|---|---|
| first upgrade | 120-300초 | 260.7초 | 자동 통과 |
| stage2 | 240-420초 | 260.1초 | 자동 통과 |
| stage3 | 540-720초 | 540.1초 | 자동 통과 |
| match duration | 평균 600-900초, 개별 480-960초 | 평균 660.3초, 488.2-875.4초 | 자동 통과, 수동 3판 필요 |

첫 1분은 즉사나 랜덤 충돌보다 위험을 읽고 선택하는 느낌이어야 한다. bot-only는 stage1 과소모지만 실제 플레이어는 정지 시 접촉이 적고 4봇이 견제 후 이탈해 오히려 너무 덜 죽었다. 두 현상을 같은 피해 수치로 묶지 않고 대인 교전 종료와 맵 encounter 구조를 분리한다.

## 현재 구현 상황

| 영역 | 구현됨 | 후보/검증 신호 | 아직 아님 | 다음 판단 |
|---|---|---|---|---|
| 매치/preset | `night_br_m1_60` 일반·수동·자동 공통 표면, bot-only simulation participant | 5-run 평균 660.3초와 개별 상·하한 gate 통과 | 수동 3판 체감, 99명 default 승격 | N2-PLAY-09 |
| 전투/AI | bot doctrine, player 위협/5초 기억, 국소 분산, 상태 기반 POI·도로·다음 원 선점 | 효용 정책·Arena 상태 변환·Night 선점 runtime 통과 | 도로 교통량과 선점 조우 수동 승격, flashlight/fear/battery 전술 | N2-PLAY-09 이동 압력 판정 |
| loot/economy | initial non-pistol pool 제어, first-upgrade source telemetry, stage/supply upgrade 흐름 | first upgrade 평균 260.7초, 누락 0/5 | 거점 보상 차이를 만드는 최소 무기 변형·방어구 archetype | 코어 압력 통과 뒤 M2 범위 확정 |
| zone/pacing | canonical match clock, nav bake 대기, bot-only participant, stage timing, 선축소 점유 | 평균 660.3초, stage2/3 260.1/540.1초, next-zone 접근 선점 runtime 통과 | 실제 플레이의 선점·후반 체감 | N2-PLAY-09 수동 3판 |
| 맵/경로 | 260m 후보, Cabin Row·West Ridge·Logging Ford, 실제 landmark 지도, 표면 이동 경제와 road waypoint | 세 장소와 빠른 도로·느린 엄폐 숲·동쪽 나루 NavMesh 통과 | 최종 맵 승격, 도로 노출과 숲 엄폐의 수동 선택 판정 | N2-PLAY-09 수동 판정 |
| 화면/UI | HUD, 120m 로컬 minimap, `M` 전체 지도, inventory, pickup label/glow, Night 가독성 | 단일 미니맵·768px 정적 캐시, POI 원 없는 전체 지도 방향/캡처 통과 | 장시간 매치에서 지역 이동감 유지 | N2-PLAY-09 수동 3판 |
| 자산/audio | 실사 총성·칼 분리음·발걸음, Cabin Row와 West Ridge GLB | catalog 누락 0, 프롭 수량·엄폐 계약, 60봇 p95 13.14-13.15ms | 칼 재청취, 검증되지 않은 나머지 지역 자산 | N2-PLAY-09에서 회귀만 기록 |
| 운영/문서 | 한글 활성 문서 7개, 기술/자산 참조 분리 | 재개 경로와 검증 루틴 정리 | 장문 로그와 날짜별 사본 운영 | 문서 예산과 Git 이력 원칙 유지 |

## 남은 작업 구조

| 트랙 | 목표 | 현재 신호 | 종료 조건 | 다음 slice |
|---|---|---|---|---|
| T1 페이싱 안정화 | 안정된 10-15분 match 분포 확보 | 자동 5-run 평균·개별 상하한 통과 | 실제 플레이 3판에서도 지나친 공백·즉사·후반 지연이 없음 | N2-PLAY-09 |
| T2 오프닝 체감 | 첫 1분이 즉사/무접촉 양극단이 아니게 함 | 자동 첫 접촉 7.4초·첫 킬 21.9초와 과거 수동 과소압박이 갈림 | 교전 품질을 보존하며 이동 압력과 과소모가 함께 납득됨 | N2-PLAY-09 첫 2분 |
| T3 야간 가독성 | 플레이어/픽업/cover가 실제 화면에서 읽힘 | route 표현 제거, Night/지도 deterministic 캡처 통과 | `night_br_m1_60` 수동 기록에서 cover·픽업·위협 판독 가능 | first-minute read |
| T4 맵/경로 체감 | pickup과 지형이 자연스러운 이동·병목 선택을 만듦 | 세 장소와 상황 기반 목적지·경로·선점 자동 계약 통과 | 세 장소를 다른 선택으로 이동하고 선점 조우를 수동 플레이로 설명 가능 | N2-PLAY-09 수동 3판 |
| T5 자산 승격 | gameplay를 돕는 자산만 런타임으로 승격 | 총성·발걸음, 칼 분리음, tree·landmark 후보 | 현재 수동 판정 중 오디오·가독성 회귀 없음 | N2-PLAY-09 회귀 감시 |
| T6 기술 부채 | 큰 파일과 문서 부채를 작업 흐름을 막지 않는 수준으로 유지 | `Bot.gd`, `Main.gd`, `Player.gd`, `Telemetry.gd` 큼 | slice가 닿는 도메인만 작은 추출, 기본 문서 부하 유지 | 변경 도메인별 opportunistic extraction |

## M2 후반 콘텐츠 후보

- 무기 변형은 같은 종류의 단순 수치 복제가 아니라 획득 경로·위험·식별성을 함께 설계한다. 맵 압력과 canonical 페이싱 기준 통과 전에는 구현하지 않는다.
- 방어구는 용량 증가만 반복하지 않고 이동, 소음, 피해 유형 등 명확한 trade-off가 있는 소수 archetype부터 검토한다.

## 우선순위 원칙

1. 자동 페이싱은 통과했다. 다음 수치 조정 전에 같은 M1 표면의 수동 3판으로 실제 플레이 흐름을 판정한다.
2. T2는 수치만으로 승격하지 않는다. `PLAYTEST.md`에 첫 1분 체감 기록이 필요하다.
3. T3/T4는 함께 본다. 어두워서 route가 안 읽히면 맵 구조가 좋아도 체감되지 않는다.
4. T5는 cosmetic backlog가 아니라 gameplay readability/feedback 문제를 줄이는 순서로 진행한다.
5. T6는 별도 대형 리팩터링으로 시작하지 않는다. 실제 slice가 닿을 때만 분리한다.

## 금지된 빠른 해결책

- 99명 default promotion.
- release/build 작업 선행.
- broad economy cut으로 first upgrade 해결.
- broad weapon chance cut.
- hard-bump threshold-only fix.
- 5초 이상 opening hard-bump brush.
- opponent 구분 없는 텔레메트리 상태에서 bot-only opening grace 추가.
- 이동 수렴 원인을 그대로 둔 채 non-hard-bump opening guard 시간만 연장.
- stage1 사망이 변하지 않은 상태에서 opening 이동 예외를 계속 추가.
- stuck 원인 분리 없이 장애물 위치만 반복 이동.
- gate 완화로 candidate 통과.

## 문서 운영

- `CURRENT.md`: 지금 할 일과 다음 slice.
- `DECISIONS.md`: 안정 결정.
- `EXPERIMENTS.md`: 채택/폐기 실험.
- `PLAYTEST.md`: 수동 체감.
- `DEVLOG.md`: 최근 완료 작업.
- 구조/검증/맵/릴리즈 자료는 `reference/`, 자산 자료는 `assets/`에서 필요할 때만 읽는다.
- 오래된 장문과 압축 전 원문은 별도 사본을 만들지 않고 Git 이력에서 확인한다.
