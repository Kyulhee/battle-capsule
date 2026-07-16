# 마스터플랜

> 최종 업데이트: 2026-07-16. 남은 작업은 마일스톤 -> 트랙 -> 종료 조건 -> 다음 slice 순서로 관리한다.

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

- 후보 맵: `data/mapSpec_night_forest_candidate.json`
- 구조 gate: `target_99_probe`
- 자동 페이싱 기준: `playable_pacing_v4`
- 매치 길이 후보: `playable_pacing_v5` (`bot_vs_bot_damage_mult=0.55`, initial zone timer 150초)
- 경로 후보: `playable_pacing_v6` (stage1 존 안쪽 선제 복귀 0.90, 실제 존 밖 탈출 0.75 유지)
- 최신 gameplay slice: N2-PACE-38 inside-edge `ZONE_ESCAPE` 분리
- 최신 검증 기반: N2-PACE-34부터 `Main.match_timer`를 canonical time으로 사용하고 navigation bake 완료 뒤 시뮬레이션 시작
- N2-PACE-35 v4/v5 수치는 idle headless player가 참가자에 포함되어 duration/stuck 기준선에서 제외
- bot-only v5 5-run: 평균 434.7초, 범위 271.0-655.5초, first upgrade 222.8초, stage2 220.1초, stage3 590.1초, normalized stuck 0.21
- N2-PACE-37 guard 6배 진단: 첫 접촉은 18.0초로 늦었지만 평균 401.3초, stuck 0.26, hard-bump 첫 획득 5/5로 악화되어 코드 제거
- bot-only v6 5-run: 평균 465.1초, 범위 236.3-1132.7초, first upgrade 224.4초, stage2 220.1초, stage3 590.1초, normalized stuck 0.14
- 판단: v6는 ZONE_ESCAPE 체류 345.2→174.0초와 해당 stuck 51.2→10.4회로 구조 개선되어 비기본 후보로 유지한다. duration 분포와 stage1 과소모는 미해결이다.

## Night BR 페이싱 판정 창

| 지표 | 목표 창 | 현재 | 판단 |
|---|---|---|---|
| first upgrade | 120-300초 | v6 224.4초 | 통과 |
| stage2 | 240-420초 | v6 220.1초 | 이른 편 |
| stage3 | 540-720초 | v6 590.1초 | 통과, 1/5 run 도달 |
| match duration | 600-900초 | v6 평균 465.1초 | 실패, 분산 과대 |

첫 1분은 즉사나 랜덤 충돌보다 위험을 읽고 선택하는 느낌이어야 한다. v6는 `ZONE_ESCAPE` 수렴과 stuck를 줄였지만 첫 획득 6.2초, 첫 접촉 6.7초, run당 stage1 사망 94-97명으로 attrition이 변하지 않았다. 다음은 예약 없는 pickup 선택이 여러 IDLE 봇을 같은 목표로 보내는지 확인하고, acquisition 시간을 독립적으로 늘리지 않는다.

## 현재 구현 상황

| 영역 | 구현됨 | 후보/검증 신호 | 아직 아님 | 다음 판단 |
|---|---|---|---|---|
| 매치/preset | map spec 기반 match 구성, runtime combat/bot tuning, bot-only simulation participant | v6 spawn 99/99, stuck 0.14. duration 평균 465.1초 | 99명 default 승격, release 기준선, v5/v6 기본 승격 | IDLE loot 수렴 후보 분리 |
| 전투/AI | bot doctrine, opening guard, 4초 hard-bump brush, bot damage, nav unstick, inside-edge zone release | v6 zone stuck는 감소했지만 첫 접촉 6.7초와 stage1 사망 95.6명 | 완전한 flashlight/fear/battery 전술 | pickup 목표 공유와 idle acquisition 분리 |
| loot/economy | initial non-pistol pool 제어, first-upgrade source telemetry, stage/supply upgrade 흐름 | source/context 구조 유지. 기존 초 단위는 재측정 대상 | broad weapon chance cut, broad economy cut | canonical upgrade band 확인 |
| zone/pacing | canonical match clock, nav bake 대기, bot-only participant, stage timing | v5 평균 434.7초, 같은 seed도 최소 5-run 필요 | 안정된 10-15분 분포 | stage1 attrition 완화 후보 |
| 맵/경로 | night forest candidate, POI/route telemetry, minimap/fullmap 데이터 | nav override는 적용됐지만 bot-only normalized stuck 0.21 | 최종 맵 승격, hotspot 수동 검증 | obstacle 점 이동 없이 pathing 원인 분리 |
| 화면/UI | HUD, minimap, inventory, pickup label/glow, `visual_review` | player/pickup은 읽힘 | 수풀/지형/cover 윤곽 안정 | T3 visual readability pass |
| 자산/audio | 핵심 icon/audio 일부, bush GLB 런타임 통합 | gameplay read에 필요한 자산만 일부 승격 | rock/tree/landmark 대량 승격 | 가독성 문제를 줄이는 prop만 선별 |
| 운영/문서 | 한글 활성 문서 7개, 기술/자산 참조 분리 | 재개 경로와 검증 루틴 정리 | 장문 로그와 날짜별 사본 운영 | 문서 예산과 Git 이력 원칙 유지 |

## 남은 작업 구조

| 트랙 | 목표 | 현재 신호 | 종료 조건 | 다음 slice |
|---|---|---|---|---|
| T1 페이싱 안정화 | 안정된 10-15분 match 분포 확보 | v6 평균 465.1초, 범위 236.3-1132.7초 | canonical 5-run 이상에서 평균 600-900초와 개별 run 허용 범위를 함께 만족, timing band 유지 | IDLE loot 수렴 영향 분리 |
| T2 오프닝 체감 | 첫 1분이 즉사/랜덤 충돌처럼 느껴지지 않게 함 | zone 이동 분리 뒤에도 첫 접촉 6.7초와 stage1 사망 95.6명 | opening 변경이 duration gate를 깨지 않고 수동 플레이에서 납득됨 | loot/IDLE 후보 뒤 first-minute playtest |
| T3 야간 가독성 | 플레이어/픽업/cover/route가 실제 화면에서 읽힘 | 수풀/지형 윤곽이 매우 어두움 | `visual_review` 캡처와 수동 기록에서 route/cover 판독 가능 | visual readability pass |
| T4 맵/경로 체감 | route choice가 bot collision보다 강하게 느껴짐 | bot-only stuck 0.21로 gate 실패, hotspot과 수동 체감 미확정 | 주요 POI/route가 플레이 중 구분되고 stuck hotspot이 gate 안에 있음 | pathing 원인 분리 + 수동 route read |
| T5 자산 승격 | gameplay를 돕는 자산만 런타임으로 승격 | bush와 핵심 icon/audio 일부만 통합 | 자산이 가독성/피드백 문제를 실제로 줄임 | rock/tree/landmark visual replacement 후보 검토 |
| T6 기술 부채 | 큰 파일과 문서 부채를 작업 흐름을 막지 않는 수준으로 유지 | `Bot.gd`, `Main.gd`, `Player.gd`, `Telemetry.gd` 큼 | slice가 닿는 도메인만 작은 추출, 기본 문서 부하 유지 | 변경 도메인별 opportunistic extraction |

## 우선순위 원칙

1. T1을 먼저 안정화한다. v6 기준선에서 IDLE loot 이동과 first acquisition이 stage1 소모에 미치는 영향을 분리한다.
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
