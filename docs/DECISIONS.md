# 결정 기록

> 최종 업데이트: 2026-07-23. 안정된 결정을 짧게 유지한다. 상세 경위는 devlog와 experiments에 둔다.

## 재검토 전까지 유지

| ID | 결정 | 이유 | 재검토 조건 |
|---|---|---|---|
| D-001 | 릴리즈 작업은 보류 | 현재는 v2-dev 프로토타입 방향 | 사용자가 릴리즈/빌드를 명시 요청 |
| D-002 | 99명 기본값 승격 금지 | 후보 맵/페이싱은 아직 비기본 테스트 표면 | M1 첫 플레이 가능 Night BR gate 통과 |
| D-003 | `target_99_probe`는 체감 목표가 아니라 구조 gate | 규모 안전성과 회귀 감시용 | 대체 구조 프로필이 생김 |
| D-004 | `playable_pacing_v4`가 현재 자동 페이싱 기준 | stage2/stage3와 first-upgrade timing을 동시에 보존 | 수동 플레이가 거부하거나 더 나은 후보가 등장 |
| D-005 | 단순 global loot/hotspot/rare 감소는 다음 lever가 아님 | N2-PACE-26에서 duration/stage3 회귀 | 글로벌 경제가 병목이라는 새 증거 |
| D-006 | 1m hard-bump 예외는 4초 opening brush 뒤에는 허용 | 충돌 가독성은 유지하고 즉시 전투 승격만 줄임 | 별도 opening collision 설계가 들어감 |
| D-007 | 생성 원본 풀은 untracked 유지 | `asset_generator/`, `plan_report/`는 런타임 콘텐츠가 아님 | 사용자가 특정 자산 통합 요청 |
| D-008 | 활성 문서는 다음 행동을 빠르게 만드는 용도 | 장문 로그가 개발 속도를 늦춤 | 과거 감사가 명시적으로 필요 |
| D-009 | role별 initial weapon multiplier는 비기본 실험만 허용 | v3는 진단용이고 승격 기준 미달 | 수동/자동 증거를 갖춘 승격 후보 |
| D-010 | 모든 페이싱 시간의 canonical 기준은 `Main.match_timer` | N2-PACE-34에서 wall-clock에 동기 초기화 시간이 섞인 것을 확인 | game loop 외 별도 canonical clock이 필요해짐 |
| D-011 | first-upgrade는 broad weapon chance가 아니라 initial non-pistol pool로 제어 | broad cut은 spike 또는 starvation을 만들었음 | 더 나은 지연 소스 설계 |
| D-012 | 기본 문서는 한글로 유지 | 사용자 확인과 1인 개발 속도를 높이기 위해 | 외부 협업자가 영어 문서를 요구 |
| D-013 | `HANDOFF.md`는 폐기하고 재개 상태는 `CURRENT.md`에 둔다 | handoff는 1회용이라 금방 낡고 기본 문서 수를 늘림 | 장기 자동 재개에 필요한 구조화된 상태 파일이 새로 필요 |
| D-014 | `playable_pacing_v5`는 비기본 duration 가설로만 유지 | bot-only 5-run 평균 434.7초로 duration gate 미달 | canonical 분산 gate와 수동 플레이를 통과 |
| D-015 | 고정 RNG seed는 재현 보장이 아니라 입력 추적값으로만 사용 | nav bake 대기 뒤에도 같은 seed가 525.4초와 909.6초로 갈림 | physics/timer 순서를 결정적으로 고정하는 실행기가 생김 |
| D-016 | `pacing_candidate` 판정은 최소 5-run으로 수행 | 비결정적 physics 결과를 3-run 또는 seed 쌍 비교로 판단하면 오판 위험이 큼 | 결정적 시뮬레이션 또는 통계 기준 재설계 |
| D-017 | nav 경로 이동도 항상 `_move_or_unstick()`을 거친다 | 유효 경로가 있을 때 stuck override를 우회해 같은 코너에서 이탈이 반복됨 | 이동/회피 파이프라인을 대체하는 구조 변경 |
| D-018 | headless simulation player는 비참가 observer로 둔다 | idle player가 actor/alive/spawn에 포함돼 봇 전멸까지 duration을 늘리고 ATTACK 245.5초 이상치를 만듦 | player 행동 모델을 가진 시뮬레이터가 도입됨 |
| D-019 | stage1 존 안쪽 선제 복귀와 실제 존 밖 탈출의 해제 깊이를 분리한다 | v6가 실제 탈출 0.75를 유지하면서 zone stuck를 51.2→10.4회로 줄임 | zone damage/경계 AI 구조를 교체 |
| D-020 | 현재 `routes`는 텔레메트리 위치 분류에만 쓰고 플레이어에게 표시하지 않는다 | 봇이 소비하지 않는 선을 전략 경로처럼 보여 준 결과 실제 플레이에서 오해와 몰입 저하를 만들었음 | route graph를 AI 목표·이동과 맵 물리 구조가 함께 소비하게 됨 |
| D-021 | 플레이어를 현재 표적으로 둔 봇은 실제로 자신을 압박하는 제3자만 outnumbered 위협으로 센다 | 주변 봇을 모두 위협으로 세면 여러 봇이 플레이어를 공격하는 장면에서 동시에 흩어짐 | 위협 점수/commitment를 포함한 전투 의사결정 계층으로 교체 |
| D-022 | 플레이어 표적의 짧은 LOS 기억은 5초, 일반 표적은 2.5초로 둔다 | squad에서 2.5초 만료 뒤 player를 지우고 loot로 돌아가는 경로를 재현했고 5초 격리 gate는 유지율 100% | 수동 Night에서 과도한 벽 너머 추적이 확인됨 |
| D-023 | 봇 분리 조향과 LOS 3m 국소 캐시는 player-target ATTACK/비loot CHASE에만 쓰고 현재 표적은 제외한다 | 전체 교전 적용은 60봇 흐름을 바꿨지만 좁힌 범위는 squad 접촉을 제거하고 60/99봇 정체·이탈을 보존 | 수동 Night에서 과도한 밀어냄 또는 AI 평균 비용 10% 이상 회귀 |
| D-024 | AI의 비즉시 판단은 짧게 캐시·분산하고 즉시 위협과 상태 변화는 캐시를 무효화한다 | 60봇 동기 검색과 위치 텔레메트리가 프레임 p95 45.5ms를 만들었고, 0.10-0.25초 캐시 뒤 13.5ms로 감소 | 수동 반응 지연, 99봇 stuck 0.20 초과, 프레임 p95 20ms 초과가 재현됨 |
| D-025 | 미니맵 배경·POI·지형은 1회 텍스처로 캐시하고 supply·zone·player만 실시간으로 그린다 | 정상 Minimap의 정적 도형 재제출이 60봇 p95 36.6-39.1ms를 만들었고 분리 뒤 15.4-15.8ms로 복구 | 경기 중 지형 자체가 변하거나 캐시와 실제 지도의 불일치가 재현됨 |
| D-026 | 확장 Night 맵의 `night_br_m1_60`을 일반 실행·수동·자동 공통 개발 기준선으로 쓴다 | 서로 다른 맵과 preset을 평가해 M1 완료 여부를 판단할 수 없었음. 무인자 Main runtime이 260m·60봇·loot 200 계약을 통과 | 해당 표면이 수동 플레이에서 폐기되거나 대체 M1 맵이 승인됨 |
| D-027 | 세 번째 물리 장소 Logging Ford 이후 새 장소 추가를 멈추고 AI 효용을 먼저 검증한다 | Cabin Row·Watch Post·Logging Ford에 지형·보상·점유 앵커가 생겨 장소 부족보다 선택 이유 부족이 다음 병목 | 수동 플레이에서 세 장소가 여전히 같은 공간처럼 읽힘 |

## 현재 설계 편향

- 끝없는 미세 조정보다 milestone 단위 판단을 우선한다.
- 진단 필드 추가보다 플레이 가능한 루프를 우선한다.
- 넓은 전역 튜닝보다, 이전 회귀를 피하는 좁은 후보를 선호한다.
- `playable_pacing_v4`는 자동 기준일 뿐 수동 기준선은 아니다.
- `playable_pacing_v5`의 bot damage 조정은 bot끼리만 적용하고 플레이어가 주거나 받는 damage는 바꾸지 않는다.
- N2-PACE-34 이전 초 단위는 현재 기준선에서 제외하고, weapon/POI/route/source 맥락만 참고한다.
- 경로 hotspot 대응은 obstacle 점 이동보다 이동 파이프라인 결함을 먼저 고친다.
- N2-PACE-36 이전 99봇 simulation duration/stuck은 player 참가 오염으로 기준선에서 제외한다.
- 초반 전투는 유예 시간을 독립적으로 늘리지 않고 이동 수렴과 collision acquisition을 먼저 분리한다.
- `playable_pacing_v6`는 pathing 후보이며 duration 또는 기본 preset 승격으로 보지 않는다.
- `visual_review`는 화면 캡처용 8봇 표면이며 gameplay 대표 preset으로 사용하지 않는다.
- route 교전 비중만 올리려고 물리 cover를 추가하지 않는다. route 선택 표면과 이동 계약을 먼저 만든다.
