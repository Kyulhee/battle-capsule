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
- 최신 gameplay slice: N2-PACE-33 bot-vs-bot damage pacing 후보
- 최신 검증 기반: N2-PACE-34부터 `Main.match_timer`를 canonical time으로 사용하고 navigation bake 완료 뒤 시뮬레이션 시작
- 최신 자동 결과: 재측정 필요. N2-PACE-34 이전 초 단위 결과에는 동기 초기화 시간이 포함되어 현재 기준선으로 사용하지 않음

## Night BR 페이싱 판정 창

| 지표 | 목표 창 | 현재 | 판단 |
|---|---|---|---|
| first upgrade | 120-300초 | 재측정 필요 | 보류 |
| stage2 | 240-420초 | 재측정 필요 | 보류 |
| stage3 | 540-720초 | 재측정 필요 | 보류 |
| match duration | 600-900초 | 재측정 필요 | 보류 |

첫 1분은 즉사나 랜덤 충돌보다 위험을 읽고 선택하는 느낌이어야 한다. 먼저 v4/v5를 canonical clock으로 각각 5-run 이상 재측정한다. 그 분포로 조기 종료와 과도한 장기전을 다시 판단한 뒤 수동 플레이에서 오프닝과 route/cover 판독을 확인한다.

## 현재 구현 상황

| 영역 | 구현됨 | 후보/검증 신호 | 아직 아님 | 다음 판단 |
|---|---|---|---|---|
| 매치/preset | map spec 기반 match 구성, pacing preset, runtime combat tuning, `run_verify.py` profile | v4/v5 구조와 player damage 불변 unit PASS | 99명 default 승격, release 기준선, v5 기본 승격 | canonical v4/v5 5-run 기준선 재구축 |
| 전투/AI | bot doctrine, opening guard, 4초 hard-bump brush, bot끼리만 적용되는 damage multiplier | N2-PACE-33 동작 검증. 기존 시간값은 재측정 대상 | 완전한 flashlight/fear/battery 전술 | duration 기준선 뒤 첫 1분 수동 판정 |
| loot/economy | initial non-pistol pool 제어, first-upgrade source telemetry, stage/supply upgrade 흐름 | source/context 구조 유지. 기존 초 단위는 재측정 대상 | broad weapon chance cut, broad economy cut | canonical upgrade band 확인 |
| zone/pacing | canonical match clock, nav bake 대기, stage timing, zone pressure telemetry | 같은 seed도 물리 결과가 달라 최소 5-run 필요 | 안정된 10-15분 분포 | v4/v5 분포 재측정 |
| 맵/경로 | night forest candidate, POI/route telemetry, minimap/fullmap 데이터 | 구조 gate 통과, route 체감은 미확정 | 최종 맵 승격, stuck hotspot 수동 검증 | pathing watch와 route read |
| 화면/UI | HUD, minimap, inventory, pickup label/glow, `visual_review` | player/pickup은 읽힘 | 수풀/지형/cover 윤곽 안정 | T3 visual readability pass |
| 자산/audio | 핵심 icon/audio 일부, bush GLB 런타임 통합 | gameplay read에 필요한 자산만 일부 승격 | rock/tree/landmark 대량 승격 | 가독성 문제를 줄이는 prop만 선별 |
| 운영/문서 | 한글 활성 문서 7개, 기술/자산 참조 분리 | 재개 경로와 검증 루틴 정리 | 장문 로그와 날짜별 사본 운영 | 문서 예산과 Git 이력 원칙 유지 |

## 남은 작업 구조

| 트랙 | 목표 | 현재 신호 | 종료 조건 | 다음 slice |
|---|---|---|---|---|
| T1 페이싱 안정화 | 안정된 10-15분 match 분포 확보 | 이전 결과는 initialization 오염으로 재측정 필요 | canonical 5-run 이상에서 평균 600-900초와 개별 run 허용 범위를 함께 만족, timing band 유지 | v4/v5 기준선 재구축 후 좁은 분산 lever 결정 |
| T2 오프닝 체감 | 첫 1분이 즉사/랜덤 충돌처럼 느껴지지 않게 함 | 기존 초 단위는 재측정 필요, 5초 brush는 실패 | opening 변경이 duration gate를 깨지 않고 수동 플레이에서 납득됨 | T1 이후 first-minute playtest |
| T3 야간 가독성 | 플레이어/픽업/cover/route가 실제 화면에서 읽힘 | 수풀/지형 윤곽이 매우 어두움 | `visual_review` 캡처와 수동 기록에서 route/cover 판독 가능 | visual readability pass |
| T4 맵/경로 체감 | route choice가 bot collision보다 강하게 느껴짐 | transit/choke/flank 지표는 있으나 수동 체감 미확정 | 주요 POI/route가 플레이 중 구분되고 stuck hotspot이 gate 안에 있음 | pathing watch + 수동 route read |
| T5 자산 승격 | gameplay를 돕는 자산만 런타임으로 승격 | bush와 핵심 icon/audio 일부만 통합 | 자산이 가독성/피드백 문제를 실제로 줄임 | rock/tree/landmark visual replacement 후보 검토 |
| T6 기술 부채 | 큰 파일과 문서 부채를 작업 흐름을 막지 않는 수준으로 유지 | `Bot.gd`, `Main.gd`, `Player.gd`, `Telemetry.gd` 큼 | slice가 닿는 도메인만 작은 추출, 기본 문서 부하 유지 | 변경 도메인별 opportunistic extraction |

## 우선순위 원칙

1. T1을 먼저 안정화한다. v4/v5를 canonical clock으로 5-run 이상 재측정하고 평균과 개별 분포를 함께 본다.
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
- gate 완화로 candidate 통과.

## 문서 운영

- `CURRENT.md`: 지금 할 일과 다음 slice.
- `DECISIONS.md`: 안정 결정.
- `EXPERIMENTS.md`: 채택/폐기 실험.
- `PLAYTEST.md`: 수동 체감.
- `DEVLOG.md`: 최근 완료 작업.
- 구조/검증/맵/릴리즈 자료는 `reference/`, 자산 자료는 `assets/`에서 필요할 때만 읽는다.
- 오래된 장문과 압축 전 원문은 별도 사본을 만들지 않고 Git 이력에서 확인한다.
