# 마스터플랜

> 최종 업데이트: 2026-07-19. 남은 작업은 마일스톤 -> 트랙 -> 종료 조건 -> 다음 slice 순서로 관리한다.

## 현재 제품 목표

Battle Capsule은 low-poly quarter-view tactical roguelite battle royale 프로토타입이다. 현재 목표는 “많은 봇이 도는 시뮬레이션”이 아니라, 플레이어가 읽고 판단할 수 있는 10-15분 Night BR 한 판을 만드는 것이다.

## 마일스톤

| ID | 이름 | 상태 | 완료 기준 |
|---|---|---|---|
| M0 | 운영 정리 | 진행 중 | 기본 문서 3개 중심으로 재개 가능하고, 검증/푸쉬 루틴이 반복 가능 |
| M1 | 첫 플레이 가능한 Night BR | 진행 중 | `playable_pacing_v4` 계열 후보가 자동 gate와 수동 체감 기준을 모두 통과 |
| M2 | 버티컬 슬라이스 | 계획 | 맵, 전투, 루트, 존, UI, 자산이 한 화면에서 설득력 있게 동작 |
| M3 | 콘텐츠 안정화 | 이후 | 검증된 코어 루프 위에서 밸런스/자산/시스템 확장 |

## 현재 기준선

- 페이싱 후보 맵: `data/mapSpec_night_forest_candidate.json`
- 구조 whitebox: `data/mapSpec_night_forest_expanded_candidate.json` (비기본, 승격 보류)
- 구조 gate: `target_99_probe`
- 자동 페이싱 기준: `playable_pacing_v4`
- 매치 길이 후보: `playable_pacing_v5` (`bot_vs_bot_damage_mult=0.55`, initial zone timer 150초)
- 경로 후보: `playable_pacing_v6` (stage1 존 안쪽 선제 복귀 0.90, 실제 존 밖 탈출 0.75 유지)
- 최신 gameplay slice: N2-PLAY-03 발걸음 채택, 거점 이동감과 laser 계열 무기음 폐기
- 최신 map/world slice: N2-MAP-10 260m 공간 감사와 중앙·남쪽 거점 자연 엄폐 후보
- 최신 UI slice: N2-UI-01 플레이어 중심 120m/280px 미니맵과 Main 단일 소유권
- 최신 asset slice: N2-ASSET-02 CC0 실사 무기 단발 4종 교체 후보, 발걸음 3종 수동 채택
- 최신 검증 기반: N2-PACE-34부터 `Main.match_timer`를 canonical time으로 사용하고 navigation bake 완료 뒤 시뮬레이션 시작
- N2-PACE-35 v4/v5 수치는 idle headless player가 참가자에 포함되어 duration/stuck 기준선에서 제외
- bot-only v5 5-run: 평균 434.7초, 범위 271.0-655.5초, first upgrade 222.8초, stage2 220.1초, stage3 590.1초, normalized stuck 0.21
- N2-PACE-37 guard 6배 진단: 첫 접촉은 18.0초로 늦었지만 평균 401.3초, stuck 0.26, hard-bump 첫 획득 5/5로 악화되어 코드 제거
- bot-only v6 5-run: 평균 465.1초, 범위 236.3-1132.7초, first upgrade 224.4초, stage2 220.1초, stage3 590.1초, normalized stuck 0.14
- N2-PACE-41 stage1 피해 0.35 진단: 평균 551.3초, stage1 사망 92.4명으로 소폭 개선됐지만 first upgrade 누락 1회와 long-run stuck 0.19로 실패해 코드 제거
- N2-PACE-42 post-kill 2초 지연: 해당 획득은 평균 132.4→56.4회로 줄었지만 stage1 사망 95.6명은 그대로고 평균 301.5초, stage3 없음으로 실패해 코드 제거
- N2-VIS-01: Night 전용 월드 주변광 0.38과 달빛 0.32를 Main/캡처에서 공유하고 cover·수풀 픽셀 대비 gate를 추가. `unit_smoke`, `visual_review` 통과
- N2-MAP-01: primary cover 2개로 primary 킬 14.3→23.1%를 만들었지만 stuck 78.6→104.4회, 신규 cover 셀 26.7%, 평균 431.2초로 실패해 맵/테스트 제거
- N2-MAP-02/03: map/world route 표현은 자동 캡처를 통과했지만 실제 플레이에서 과도하고 이질적이며 AI 행동과 무관해 폐기. 표현 코드와 전용 검증 제거
- N2-MAP-04: minimap/fullmap/world route 표현을 제거하고 전체 지도를 미니맵과 같은 45도 좌표계로 정렬. 방향 smoke와 실제 캡처 통과
- N2-PACE-43: 초기 pickup 간격 3.5m에도 첫 획득 6.7초/1.0-1.3m, stage1 사망 96.0명, 평균 434.5초, stuck 106.0회로 실패해 코드와 v7 제거
- N2-AI-01: 전역 active-threat 변경은 5-run에서 평균 516.9초, 2개 run 300초 미만, first upgrade 누락 1회, stuck 0.17로 실패. 플레이어 표적에만 실제 압박 제3자를 세도록 좁히고 bot-only 판정 보존
- N2-MAP-05 audit: 180m 맵은 플레이어 직선 30초·대각선 42.4초 횡단, 28개 상부 장애물 추정 점유 4.2%. `visual_review` 8봇과 v6 99봇은 encounter 밀도가 약 5.3배 다름
- N2-MAP-05 candidate: 260m·43.3초 횡단·64요소·10.6% 점유. 99봇 5-run은 평균 196.6초, 첫 조우 7.1초, 이탈 152.4회, open 피해 66.7%로 scale gate 실패해 비기본 whitebox 유지
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
- N2-ASSET-01/02: 핵심 오디오 7종을 연결했지만 laser proxy 무기음 4종은 수동 폐기했다. CC0 실사 CZ/SKS/shotgun/Mosin 단발로 교체하고 peak·볼륨·pitch variation을 제한했으며 발걸음 3종은 채택됐다
- N2-UI-01: 260m 전역을 압축하던 상시 미니맵을 플레이어 중심 120m/280px로 바꾸고 주요 지명을 표시했다. Main/Player 중복 미니맵을 Main 하나로 정리해 60봇 p95 13.3-14.2ms로 개선했다
- 판단: v6는 ZONE_ESCAPE 체류 345.2→174.0초와 해당 stuck 51.2→10.4회로 구조 개선되어 비기본 후보로 유지한다. duration 분포와 stage1 과소모는 미해결이다.

## Night BR 페이싱 판정 창

| 지표 | 목표 창 | 현재 | 판단 |
|---|---|---|---|
| first upgrade | 120-300초 | v6 224.4초 | 통과 |
| stage2 | 240-420초 | v6 220.1초 | 이른 편 |
| stage3 | 540-720초 | v6 590.1초 | 통과, 1/5 run 도달 |
| match duration | 600-900초 | v6 평균 465.1초 | 실패, 분산 과대 |

첫 1분은 즉사나 랜덤 충돌보다 위험을 읽고 선택하는 느낌이어야 한다. bot-only는 stage1 과소모지만 실제 플레이어는 정지 시 접촉이 적고 4봇이 견제 후 이탈해 오히려 너무 덜 죽었다. 두 현상을 같은 피해 수치로 묶지 않고 대인 교전 종료와 맵 encounter 구조를 분리한다.

## 현재 구현 상황

| 영역 | 구현됨 | 후보/검증 신호 | 아직 아님 | 다음 판단 |
|---|---|---|---|---|
| 매치/preset | map spec 기반 match 구성, runtime combat/bot tuning, bot-only simulation participant | 올바른 월드 60/99봇 normalized stuck 약 0.01/0.00. 99봇 disengage 0.41은 실패 유지 | 99명 default 승격, release 기준선, v5/v6 기본 승격 | N2-PLAY-03 수동 거점 판정 |
| 전투/AI | bot doctrine, opening guard, player 위협/5초 기억, 순수 결정·이동 정책, player-target 국소 분산, 분산 갱신·단기 검색 캐시, bot damage, nav unstick | squad 유지율 100%, 강제 근접 0.2초 분리. 60봇 Forward+ p95 15.4-15.8ms | Night 근거 효용 가중치, 완전한 flashlight/fear/battery 전술 | 현재 AI 기준을 보존하며 맵 후보 검증 |
| loot/economy | initial non-pistol pool 제어, first-upgrade source telemetry, stage/supply upgrade 흐름 | source/context 구조 유지. 기존 초 단위는 재측정 대상 | broad weapon chance cut, broad economy cut | canonical upgrade band 확인 |
| zone/pacing | canonical match clock, nav bake 대기, bot-only participant, stage timing | v6 465.1초, 피해/post-kill/cover 후보 모두 gate 실패 | 안정된 10-15분 분포 | route 선택 표면과 수동 첫 1분 뒤 재설계 |
| 맵/경로 | 기존 Night + 260m 확장 whitebox, 공간/POI 엄폐 감사, 실제 geometry nav bake, 96m Arena traffic, 45도 정렬 지도 | 중앙·남쪽 자연 엄폐 후보, 60/99봇 stuck 약 0.01/0.00, POI 피해 +8.5/+6.9%p | 최종 맵 승격, 자연스러운 병목 | `xlarge_60`에서 픽업 접근·우회 선택 수동 판정 |
| 화면/UI | HUD, 120m 로컬 minimap, `M` 전체 지도, inventory, pickup label/glow, Night 가독성 | 단일 미니맵·768px 정적 캐시·주요 지명, 방향/캡처 통과, 60봇 p95 13.3-14.2ms | 지역 이동감 수동 승격 | N2-PLAY-04 로컬 지도 판정 |
| 자산/audio | 핵심 icon, 실사 무기 4종 후보·채택된 발걸음 3종, bush GLB | catalog 누락 0, 스트림 캐시, 무기별 peak·볼륨 제한 | 새 무기음 수동 채택, rock/tree/landmark 대량 승격 | N2-PLAY-04 무기음 피로도 판정 |
| 운영/문서 | 한글 활성 문서 7개, 기술/자산 참조 분리 | 재개 경로와 검증 루틴 정리 | 장문 로그와 날짜별 사본 운영 | 문서 예산과 Git 이력 원칙 유지 |

## 남은 작업 구조

| 트랙 | 목표 | 현재 신호 | 종료 조건 | 다음 slice |
|---|---|---|---|---|
| T1 페이싱 안정화 | 안정된 10-15분 match 분포 확보 | micro lever와 primary cover에도 stage1 사망 92-96명, pathing 회귀 | canonical 5-run 이상에서 평균 600-900초와 개별 run 허용 범위를 함께 만족, timing band 유지 | route 표시와 수동 첫 1분 뒤 후보 재설계 |
| T2 오프닝 체감 | 첫 1분이 즉사/무접촉 양극단이 아니게 함 | `xlarge_60` 수동 조우·간격·추적·사망 압박과 성능 체감 통과. 확장 자동은 첫 조우 7.1초 과밀 | 현재 수동 기준을 보존하며 자동 duration도 납득됨 | AI 목적지 결정과 확장 맵 흐름 연결 |
| T3 야간 가독성 | 플레이어/픽업/cover가 실제 화면에서 읽힘 | route 표현 제거, Night/지도 deterministic 캡처 통과 | `xlarge_60` 수동 기록에서 cover·픽업·위협 판독 가능 | first-minute read |
| T4 맵/경로 체감 | pickup과 지형이 자연스러운 이동·병목 선택을 만듦 | 로컬 미니맵으로 지역 읽기는 개선, 월드 자체 거점 정체성은 미검증 | 주요 POI가 물리 동선과 AI 목표로 연결되고 수동 체감 통과 | N2-PLAY-04 뒤 지역별 실루엣·밀도 감사 |
| T5 자산 승격 | gameplay를 돕는 자산만 런타임으로 승격 | 발걸음 채택, 실사 무기음 교체 후보와 bush/icon 통합 | 무기음 재청취 통과와 자산이 실제 피드백 문제를 줄임 | N2-PLAY-04 오디오 판정 |
| T6 기술 부채 | 큰 파일과 문서 부채를 작업 흐름을 막지 않는 수준으로 유지 | `Bot.gd`, `Main.gd`, `Player.gd`, `Telemetry.gd` 큼 | slice가 닿는 도메인만 작은 추출, 기본 문서 부하 유지 | 변경 도메인별 opportunistic extraction |

## 우선순위 원칙

1. T1이 최우선이지만 같은 미세 AI lever나 route cover 추가를 반복하지 않는다. 먼저 bot-vs-bot 과소모와 bot-vs-player 과소압박의 갈라지는 원인을 찾는다.
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
