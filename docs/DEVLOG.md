# Battle Capsule 개발 로그

> 최종 업데이트: 2026-07-18. 최근 검증된 작업만 유지한다. 과거 내용은 Git 이력을 참조한다.

## N2-AI-07 POI 목적지 수렴 감사

- 구현: spawn 반경 대역·POI·route 점유를 한 번 계산하는 `SpawnDistributionMetrics`를 분리하고 loot 목적지 POI 이름을 JSON과 분석기에 연결했다.
- 결과: 60/99봇 spawn은 POI 내부 25.7/26.5%, IDLE loot 목표는 66.3/67.2%가 내부이고 약 90%가 route 위였다. 전투 피해는 open 70-71%였다.
- 판단: AI가 pickup 배치를 소비하지 않는 것이 아니라 POI에서 교전이 개방지로 유출된다. 단일 99봇 진단에서 `Central Meadow`가 IDLE loot 113/300으로 가장 커 다음 whitebox 대상으로 정했다.
- 검증: `unit_smoke` 통과. 60/99봇 각 5-run 완료. 99봇 gate는 기존 구조 실패인 stuck 75.4>60, disengage 156.4>130을 유지했다.

## N2-PLAY-02 60봇 성능 수동 통과

- 표면: 확장 Night whitebox `xlarge_60`, 사용자 직접 플레이.
- 결과: N2-PERF-01 뒤 이전의 심한 렉이 확실히 줄었다. 앞서 통과한 조우·간격·공격·추적·사망 압박 판단도 유지한다.
- 결정: 성능 미세조정을 종료하고 AI 목적지 결정과 확장 맵 흐름 연결로 이동한다.

## N2-PERF-01 60봇 프레임 안정화

- 진단: Forward+ 60봇 기준 프레임 p95 45.5ms, 33ms 초과 12.8%. 렌더보다 동기화된 perception/sensory와 매 프레임 표적·픽업·후퇴 위협 검색, 교리 위치 텔레메트리가 병목이었다.
- 수정: 갱신 위상 분산, 0.10-0.25초 상태 인식 캐시, 교리 텔레메트리 0.25초 누적 기록, nav target 0.35m 갱신과 상태/stuck 복구 시 재경로를 적용했다. 픽업 상태 변화와 이미 공개된 근접 표적은 즉시 캐시를 무효화한다.
- 검증: 최종 60봇 p95 13.5ms, p99 17.5ms, 33ms 초과 0.04%. 동일 seed 99봇 대조에서 AI 평균 476→353µs, stuck 0.15→0.16, ATTACK+CHASE -0.58%p. `unit_smoke` 통과.
- 잔여: 확장 whitebox `scale_99`는 기존 disengage 161.6>130으로 실패한다. 성능 회귀와 구분하며 다음은 `xlarge_60` 수동 끊김 재확인이다.

## N2-AI-06 Night 규모 분산 회귀

- 실패 범위: 국소 캐시·분리를 모든 ATTACK/비loot CHASE에 적용하자 60봇 평균 종료 261.5→195.7초, 피해 16.23→22.19/개체·분, 정체 0.14→0.22로 bot-only 흐름이 바뀌었다.
- 최종 범위: 플레이어를 현재 표적으로 둔 ATTACK/비loot CHASE만 근접 캐시를 만들고 분리한다. bot-only 이동과 불필요한 캐시 비용은 보존한다.
- 검증: 99봇 대조군 대비 종료 220.6→217.1초, 정체 0.14→0.12, 이탈 0.42→0.43/개체·분, AI 평균 482.1→511.4µs(+6.1%). Arena 강제 쌍 0.2초 분리·표적 유지 100%, `unit_smoke` 통과.
- 다음: `xlarge_60` 실제 첫 1분에서 접촉 빈도, 다중 교전 간격, 시야 차단 뒤 추적, 대인 압박을 판정한다.

## N2-AI-05 국소 전투원 분산

- 기준선: `squad_4` 5-run 중 3회가 1.5m 미만으로 붙었고 접촉 샘플은 최대 7.65%, 최소 거리는 0.97m였다.
- 수정: 기존 perception LOS 결과에서 3m 근접 캐시를 만들고 ATTACK/비loot CHASE 이동에 2.75m 분리 조향을 합성한다. 현재 표적과 벽 너머 봇은 제외하며 새 전역 순회는 없다.
- 검증: 자연 5-run 모두 1.5m 미만 접촉 0%, 최소 거리 1.89m 이상. 무작위 gate 실패를 막기 위해 1.1m 쌍과 동일 strafe를 강제했고 5/5회 0.15-0.25초 안에 분리됐다. 표적 유지율 100%, 공격 참여 4명이며 `ai_test_arena`, `unit_smoke` 통과.
- 다음: 확장 Night 60/99봇에서 AI update 비용, stuck, 이탈 회귀를 확인한 뒤 수동 first-minute로 넘긴다.

## N2-AI-04 플레이어 표적 기억

- 원인: `squad_4`에서 네 봇 모두 공격해도 짧은 LOS 상실이 2.5초를 넘으면 player 표적을 지우고 IDLE/loot로 복귀했다.
- 수정: 일반 bot 표적 기억은 2.5초로 보존하고 player 표적만 5초로 연장했다. 결정값은 `BotDecisionPolicy`가 소유한다.
- 검증: 실제 Main의 자연 행동 2초 뒤 교차 피해·combat-loot·sniper 최소 사거리를 격리한 3초 commitment gate를 추가했다. 유지율 100%, 동시 표적 4명, 공격 참여 4명, 표적 이탈 0으로 `ai_test_arena`와 `unit_smoke` 통과.
- 잔여: 격리 전 자연 다자전은 표적 전환 분산이 있고 봇 간 최소 거리가 약 1m까지 줄었다. 다음은 전역 봇 순회 없는 국소 분산이다.

## N2-TOOLS-02 Arena 실제 Duel Smoke

- 구현: `verify_ai_arena_runtime.gd`가 실제 `Main.tscn`과 `duel_1`을 시작해 player/bot 고정 스폰과 초기 loot 0개를 확인한다.
- 행동 gate: 4.5m 인접 봇이 3초 안에 플레이어를 표적으로 획득하고 실제 피해를 주어야 통과한다. 현재 결과는 HP 100→90이다.
- 연결: `run_verify.py`에 Godot script 인자 전달 helper를 추가하고 `ai_test_arena`, `unit_smoke` 양쪽에 runtime smoke를 포함했다.
- 검증: 두 profile 통과. 기존 AssetCatalog 7개 fallback과 ObjectDB 종료 경고는 유지된다.

## N2-AI-02 AI 결정 정책 분리

- 구조: `BotDecisionPolicy`를 추가해 추가 위협 판정, archetype 표적 점수, 엄폐 위치 효용을 scene tree 조회와 상태 실행에서 분리했다.
- 보존: player-target commitment, bot-only 가시 적 기준, AGGRESSIVE 최근접 표적, OPPORTUNIST 저체력 표적, 기존 엄폐 거리·혼잡 벌점을 그대로 유지했다.
- 검증: 정책 단독 smoke를 `ai_test_arena`와 `unit_smoke`에 연결했다. 위협/방관자 구분, 표적 성향, 혼잡·위험 엄폐 거부와 기존 AI 회귀가 통과했다.
- 다음: `squad_4`에서 목표 유지와 엄폐 분산을 관찰 가능한 행동 계약으로 만든 뒤 Night 후보에서 재검증한다.

## N2-TOOLS-01 AI Test Arena

- 구현: `72m` 소형 맵에 오픈 듀얼, LOS 벽, 수풀 시야, 회복·루팅, 존 가장자리 구역을 배치했다. `duel_1`, `squad_4`, `systems_8`, `random_8` preset을 제공한다.
- 재현성: 맵 runtime의 `fixed_positions`를 플레이어 슬롯부터 순서대로 소비한다. 앵커 수·경계·간격·장애물 겹침을 validation하고 simulation은 플레이어 슬롯을 건너뛴다.
- 격리: `initial_spawn_enabled=false`로 duel의 초기 loot를 제거했다. 일반 맵 기본값과 4/8봇 시스템 preset은 초기 loot를 유지한다.
- 검증: `ai_test_arena` 전용 profile과 `unit_smoke` 통과. 전체 지도/미니맵 5구역과 4.5m duel 실제 교전을 캡처로 확인했다.
- 사용 경계: 작은 AI 오류 재현과 회귀 확인 전용이다. 실제 Night BR의 조우 빈도·페이싱 판정에는 사용하지 않는다.

## N2-AI-02A 플레이어 근접 위협 계약 복구

- 원인: 봇끼리의 초반 스폰 충돌을 줄이는 4-10초 유예가 플레이어에게도 적용됐다. RECOVER와 회복 루팅도 이미 드러난 근거리 플레이어보다 목적지를 우선할 수 있었다.
- 수정: 초반 IDLE·근접 reveal·loot interrupt·zone counteraction 유예를 bot-vs-bot 전용으로 제한했다. 드러난 플레이어가 5m 전방위 근접 범위에 들어오면 RECOVER는 대응 상태로 전환하고 회복 루팅은 중단한다.
- 보존: 일반 봇은 기존 1-2m opening brush 유예를 유지한다. 화면의 얇은 원은 3.2m 야간 주변 조명이며 AI 감지 범위 표시는 아니다.
- 검증: opening IDLE 즉시 reveal/target, RECOVER 대응, 회복 루팅 interrupt, bot-vs-bot 기존 유예를 자동 검증했다. `unit_smoke` 통과.
- 다음: `xlarge_60` 실제 플레이에서 정지 상태로 근접해 IDLE/RECOVER 봇이 5m 안에서 목표 전환·대응하는지 확인한다.

## N2-MAP-05 260m 확장 Night whitebox

- 구현: 기존 이름뿐인 180m large 후보를 `mapSpec_night_forest_expanded_candidate.json`으로 교체했다. 260m, 환경 요소 64개, POI 13개, `xlarge_60`/`target_99_probe`를 분리했다.
- 공간 신호: 직선 횡단 30.0→43.3초, 환경 점유 4.6→10.6%, 카메라 반폭보다 장애물이 먼 grid 55.9→30.8%. 전체맵은 landmark 라벨만 남겼다.
- 런타임 수정: 실제 60봇 캡처에서 외곽 spawn 가림을 발견해 spawn을 90m/100m로 줄이고 벽 높이와 수풀 크기를 낮췄다. 사망한 chase target 참조 오류도 수명 방어와 smoke로 수정했다.
- 실패 신호: 99봇 5-run 평균 196.6초, 범위 180.2-217.8초, 첫 조우 7.1초, 이탈 152.4회, stuck 49회, open 피해 66.7%. `scale_99` gate 실패.
- 결정: 크기·시각 밀도 실험으로는 유지하되 기본 맵으로 승격하지 않는다. 다음은 obstacle 추가가 아니라 위협·목표·위치 효용을 분리하는 AI 결정 계층이다.

## N2-AI-01 플레이어 표적 위협 판정

- 원인: outnumbered 판정이 현재 표적과 단순 방관자까지 모두 세어 `DEFENSIVE`/`SNIPER`는 1대1에서도 즉시 이탈하고, 여러 봇이 플레이어를 공격하면 서로를 보고 흩어졌다.
- 실패 후보: 실제 압박 위협만 세는 판정을 모든 교전에 적용했으나 5-run에서 평균 516.9초, 2개 run 300초 미만, first upgrade 1회 누락, stuck 0.17로 gate 실패했다.
- 채택 범위: 플레이어를 현재 표적으로 둔 경우에만 자신을 추적하거나 최근 5초 안에 공격한 제3자를 센다. bot-only는 기존 가시 적 판정을 유지한다.
- 검증: 현재 표적, 방관자, 추적자, 최근/만료 공격자를 구분하고 bot-only 계약 보존을 확인하는 smoke를 추가했다. `unit_smoke` 통과.
- 다음: 180m/장애물 4.2% 맵과 8봇/99봇 표면 불일치를 해소하는 whitebox를 설계한다.

## 기록 보존

이 문서는 최근 10개 작업 또는 120줄까지만 유지한다. 오래된 항목과 삭제된 전체 사본은 `git log -- docs/DEVLOG.md docs/MASTERPLAN.md`로 찾고, 필요한 커밋에서만 읽는다.
