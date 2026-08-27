# 실험 기록

> 최종 업데이트: 2026-08-28. 같은 실패를 반복하지 않기 위한 짧은 장부다.

## 활성 판단

| ID | 질문 | 최신 증거 | 판단 |
|---|---|---|---|
| E-001 | `playable_pacing_v2`가 late-zone pacing을 지탱하는가? | N2-PACE-25: avg 533.3초, stage2 268.1초, stage3 638.4초, scale gate PASS | late-zone 참조로 유지 |
| E-002 | 단순 global economy cut이 first upgrade를 안전하게 늦추는가? | N2-PACE-26: first upgrade 56.0초, avg duration 454.1초, stage3 없음 | 다음 lever로 폐기 |
| E-003 | v2에서 첫 upgrade는 어디서 발생하는가? | N2-PACE-27: shotgun 100%, concealment/loot-hub, on-route | weapon/source 맥락을 직접 겨냥 |
| E-004 | hard-bump acquisition은 즉시 전투 압박인가? | N2-PACE-23: acquisition만 보지 말고 contact gap으로 판단 | collision 재설계 전까지 예외 유지 |
| E-005 | role-specific initial weapon access가 안전한가? | N2-PACE-29 corrected game-time: first upgrade 97.4초, source initial_loot/stage_wave | 진단 후보로 유지 |
| E-006 | initial non-pistol pool 제어가 starvation 없이 동작하는가? | N2-PACE-30: avg 599.6초, first upgrade 294.9초, stage3 654.2초 | 자동 페이싱 후보로 채택 |
| E-007 | 좁은 opening hard-bump brush가 v4 gate를 보존하는가? | N2-PACE-32 4초: avg 554.3초, first contact 17.7초, hard-bump 1/3, first upgrade 293.9초, stage3 655.7초 | 좁은 자동 후보로 채택 |
| E-008 | bot끼리의 damage만 낮추면 timing band를 유지하며 match 여유가 생기는가? | bot-only v5 평균 434.7초, first upgrade 222.8초, stage3 590.1초 | timing 일부는 유지하지만 duration 실패. 비기본 가설 유지 |
| E-009 | 같은 seed의 소규모 쌍 비교로 분산 lever를 판정할 수 있는가? | nav bake 대기 뒤 seed 41001 반복이 525.4초와 909.6초로 갈림 | 폐기. seed 기록 + 최소 5-run 분포 사용 |
| E-010 | bot-only 45초 opening target grace가 초반 소모를 줄이는가? | 평균 552.6초지만 normalized stuck 0.18. headless player 접촉이 섞여 first-contact 원인도 분리되지 않음 | 폐기. opponent 유형별 텔레메트리 전 재시도 금지 |
| E-011 | hotspot 주변 obstacle 점 이동으로 stuck를 해결할 수 있는가? | 세 probe 모두 hotspot만 이동하고 normalized stuck 0.16-0.18, 한 후보는 평균 352.1초로 붕괴 | 주 해결책으로 폐기 |
| E-012 | nav 이동이 stuck override를 적용하면 반복 이탈이 줄어드는가? | 직접 우회 결함은 수정. 이전 stuck 0.14는 player 참가 duration 오염이며 bot-only는 0.21 | 코드 수정 유지, pathing gate는 미해결 |
| E-013 | headless player를 비참가 observer로 분리하면 bot pacing이 명확해지는가? | v5 5-run win=false, spawn 99/99, ATTACK max 16.0초, 평균 duration 434.7초 | 구조 수정 채택. 이전 duration/stuck 폐기 |
| E-014 | non-hard-bump opening guard를 6배로 늘리면 초반 소모가 안전하게 줄어드는가? | 5-run 평균 401.3초, first contact 18.0초, stuck 0.26, hard-bump first acquisition 5/5 | 폐기하고 코드 제거. 이동 수렴이 4초 hard-bump로 우회 |
| E-015 | stage1 존 안쪽 선제 복귀를 0.90에서 끝내면 실제 탈출을 해치지 않고 수렴이 줄어드는가? | v6 평균 465.1초, stuck 0.14, ZONE_ESCAPE 체류 174.0초, 해당 stuck 10.4회 | 구조 후보 채택. duration/stage1 attrition 승격은 보류 |
| E-016 | 여러 IDLE 봇이 같은 pickup을 목표로 삼는 것이 첫 교전의 주 원인인가? | v6 1-run에서 idle_loot 기존 claim 48/583(8.2%), 첫 획득은 6.7초 idle_reaction | 주 원인으로 기각. 예약 코드와 진단 계측 미유지 |
| E-017 | 첫 12초 비전투 이동에 근접 분산을 넣으면 opening attrition이 줄어드는가? | v7 평균 465.4초, first contact 7.0초, stage1 사망 95.6명, stuck 0.16 | 폐기하고 코드 제거. attrition 효과 없이 pathing만 악화 |
| E-018 | stage1 bot-vs-bot 피해를 0.35로 낮추고 stage2부터 0.55로 복원하면 과소모가 줄어드는가? | v7 평균 551.3초, stage1 사망 92.4명, first upgrade 누락 1회, long-run stuck 0.19 | 폐기하고 코드 제거. 소폭 생존보다 DISENGAGE 장기화 회귀가 큼 |
| E-019 | stage1 post-kill 능동 재획득을 2초 늦추면 킬 연쇄가 줄어드는가? | post-kill 획득 132.4→56.4회, stage1 사망 95.6명 유지, 평균 301.5초, stage3 없음 | 폐기하고 코드 제거. idle/damage 반응으로 우회하며 attrition 인과 없음 |
| E-020 | Night 월드 환경을 공통 프로필로 올리면 darkness를 유지하며 route/cover가 읽히는가? | cover blue 0.1765 vs background 0.0784, bush green 0.2235 vs 0.0627. `visual_review` PASS | 채택. Main/캡처 공유와 deterministic 대비 gate 유지 |
| E-021 | primary route에 고엄폐 2개를 추가하면 off-route 교전을 안전하게 되돌리는가? | primary 킬 14.3→23.1%, stage1 사망 95.6→94.0명. stuck 78.6→104.4회, 신규 두 셀 26.7%, 평균 431.2초 | 폐기하고 맵/테스트 제거. route 표시·이동 계약 없이 물리 cover를 추가하지 않음 |
| E-022 | route 역할을 minimap/fullmap에 표시하면 충돌물 없이 선택 정보를 만들 수 있는가? | 자동 캡처는 PASS했지만 수동 플레이에서 의미가 불명확하고 화면과 분위기에 이질적이었음 | 폐기하고 표현 코드 제거. AI가 소비하지 않는 분류선을 선택 정보로 보여 주지 않음 |
| E-023 | map route를 이동에 간섭하지 않는 world cue로 연결할 수 있는가? | 자동 캡처는 PASS했지만 실제 플레이에서 과도하게 눈에 띄고 AI 행동과도 연결되지 않았음 | 폐기하고 127개 strip·4개 MultiMesh·전용 검증 제거 |
| E-024 | 초기 pickup끼리 3.5m 간격을 두면 opening 미시 수렴이 줄어드는가? | v7 5-run first acquisition 6.7초/1.0-1.3m, stage1 사망 96.0명, 평균 434.5초, stuck 106.0회/normalized 0.15 초과 | 폐기하고 runtime/preset/test 제거. pickup 간격은 같은 POI·route 수렴을 바꾸지 못함 |
| E-025 | outnumbered를 단순 가시 적 수가 아니라 실제 압박 위협으로 계산해야 하는가? | 전역 적용 5-run 평균 516.9초였지만 2개 run 300초 미만, first upgrade 1회 누락, stuck 0.17. 수동 증거는 플레이어 표적에서만 확인됨 | 전역 적용 폐기. player-target commitment로 범위를 좁히고 bot-only 기존 판정 유지 |
| E-026 | 260m 확대와 pickup/장애물 밀도만으로 자연스러운 교전 흐름을 만들 수 있는가? | 64요소·10.6% 점유로 빈 grid는 줄었지만 5-run 평균 196.6초, 첫 조우 7.1초, 이탈 152.4회, open 피해 66.7% | 크기 whitebox는 유지, gameplay 승격 보류. AI가 위협·목표·위치 효용을 소비하기 전 장애물 추가 금지 |
| E-027 | 봇끼리의 opening grace와 회복 목표 보호가 플레이어에게도 적용되어야 하는가? | 인접 플레이어가 첫 4-10초 reveal/reaction에서 제외되고 RECOVER/회복 루팅이 5m 내 드러난 플레이어를 무시할 수 있었음 | 금지. opening grace는 bot-vs-bot 전용, 근거리 플레이어 위협은 회복 목표보다 우선 |
| E-028 | 양측 재배치 후보가 전투원 혼잡과 적정 거리를 비교하면 흐름이 개선되는가? | 5-run 평균 658.0초와 stuck 0.09였지만 open 피해 48.5→53.7%, AI update 411.7→548.8µs, DISENGAGE 623.5→1133.7µs | 폐기하고 코드 제거. Arena 분산 계측과 국소 후보 집합 없이 전역 봇 순회 금지 |
| E-029 | 국소 분리를 모든 전투에 적용해도 bot-only 흐름이 유지되는가? | 60봇 평균 종료 261.5→195.7초, 피해 16.23→22.19/개체·분, 정체 0.14→0.22. player-target 전용은 99봇 정체 0.14→0.12, AI 평균 +6.1% | 전체 교전 적용 폐기. player-target ATTACK/비loot CHASE에서만 캐시·분리 |
| E-030 | AI 검색·텔레메트리 주기를 분산·캐시하면 60봇 끊김을 행동 회귀 없이 줄일 수 있는가? | 60봇 p95 45.5→13.5ms, 33ms 초과 12.8→0.04%. 동일 seed 99봇 AI 476→353µs, stuck 0.15→0.16, ATTACK+CHASE -0.58%p | 채택. nav 0.75m 재사용은 ZONE_ESCAPE stuck 0.20을 만들어 0.35m+상태/stuck 재경로로 보완 |
| E-031 | AI가 POI/route 목적지를 소비하지 않아 확장 맵 교전이 open으로 흐르는가? | 60/99봇 spawn POI 내부 25.7/26.5%, IDLE loot 목표 내부 66.3/67.2%·route 위 약 90%. 피해 open 70-71% | 목적지 미사용 가설 기각. pickup 수렴 뒤 교전 유출로 좁히고 `Central Meadow` 단일 whitebox 진행 |
| E-032 | `Central Meadow` 가장자리의 고엄폐가 pickup 수렴을 거점 전투로 전환하는가? | 동일 시드 60봇에서 open 피해 71.2→69.5%, loot-hub 피해 9.0→15.8%, normalized stuck 0.20→0.16. 바위 셀 정체 0→15회 | 폐기하고 맵·전용 테스트 제거. 장애물 위치 반복 대신 open 피해 셀·인접 POI를 먼저 계측 |
| E-033 | open 피해 70%대는 특정 POI 경계의 빈 평지로 전투가 새는 현상인가? | 60/99봇 open 피해 74.5/72.5%, 경계 8m 밖 72.6/73.3%. 상위 셀은 6.7% 이하이며 기존 두 high rock 셀이 open 피해 10-11%·정체 15-23%를 함께 차지 | 단일 경계 가설 기각. `open=POI 밖`으로 해석하고 Arena에서 high rock ramp·nav를 먼저 격리 |
| E-034 | high `rock_cluster`의 climb ramp가 반복 정체의 공통 원인인가? | ramp 포함 Arena 24→14.19m/stuck 3, 제거 뒤 5/5회 24→2.8-3.0m/stuck 1. 60봇 rock 셀 32→15·duration 유지, 99봇 74→22·raw stuck 64.8→53.2 | ramp 제거 채택. NavigationObstacle/proxy/agent radius는 추가 이득 없어 폐기. 99 disengage 154.4는 별도 문제 |
| E-035 | ramp 제거 뒤 `Central Meadow` 동쪽 high rock을 다시 쓸 수 있는가? | 실제 맵 1대1 횡단 5/5 통과. 동일 seed 60봇 open 피해 69.7→69.9%, loot-hub 10.4→12.2%, `10,10` stuck 0→5회; 별도 seed도 14회 | 재기각·99봇 중단. high rock 추가 배치 금지, 비-rock 엄폐는 다중 traffic gate 선행 |
| E-036 | 단순 Box wall은 rock의 국소 정체 없이 엄폐를 만들 수 있는가? | open 4봇 5/5회 4.20초/stuck 0, 축 정렬 폭 4m wall 6.55초/2. log 1봇·회전 wall은 실패. 제품 60봇 wall은 `10,10` 0→16회, open 69.7→69.6% | 제품 후보 기각·99 중단, 96m traffic gate 채택. Box corner 정체를 0으로 고치는 N2-NAV-02 선행 |
| E-037 | runtime NavigationRegion이 실제 WorldBuilder geometry를 bake하고 있었는가? | 기존 메시 `polygons=0, vertices=0`. source group bake 뒤 rock stuck 1→0, 60/99봇 stuck 39.0→2.8·53.2→12.4, 평균 종료 225.1→222.5·199.7→222.9초 | 실제 geometry bake 채택, 빈 메시 gate 추가. `0,40` hotspot과 99봇 disengage는 별도 격리 |
| E-038 | `0,40` 정체가 high rock/zone 구조 때문인가? | 실제 충돌 경로는 `/Minimap/Cabin_South/Wall2`였고 Minimap UID가 TestMap을 가리켰다. UID 교정 뒤 hotspot 5.1초/stuck 0, 60/99봇 stuck 1.4/1.2 | UID 교정과 Minimap 충돌체 금지 gate 채택. rock proxy와 path 허용치 변경은 폐기 |
| E-039 | loot hub 주변의 비-rock 수목·수풀이 경로 정체 없이 빈 평지를 줄이는가? | 중앙/남쪽 개방률 80.2/39.5→16.0/17.3%, 60/99봇 POI 피해 +8.5/+6.9%p. stuck 약 0.01/0.00, 60봇 p95 15.8-16.1ms | 자동 후보 채택. 인공 route 표시는 추가하지 않고 N2-PLAY-03 수동 접근 판정 뒤 승격 |
| E-040 | 정상 Minimap 로드 뒤 60봇 렉은 AI/nav 비용인가? | 표시 p95 36.6-39.1ms, 비표시 21.7ms. 정적 지도를 1회 캐시하자 15.4-15.8ms, draw call 평균 502-519→146-234 | 정적/동적 지도 레이어 분리 채택. navigation 튜닝으로 해결하지 않음 |
| E-041 | 근거리 pickup 목표만으로 확장 맵의 장거리 이동 압력이 생기는가? | 수동으로 압력 부재. loot가 없어진 IDLE은 정지했다. POI 13개 저빈도 목적지 후보는 60봇 p95 12.9ms, 99봇 AI 146.2µs, 3-run 평균 231.1초 | 자동 후보 유지, N2-PLAY-05 전 승격 금지. actor/pickup 전역 탐색과 인공 route 표시는 재도입하지 않음 |
| E-042 | M1 공통 preset이 10-15분 자동 페이싱을 지탱하는가? | 규모만 상속한 기준은 평균 238.5초, 장기 v6 일정은 1360초. 압축 후보 5-run은 평균 660.3초·범위 488.2-875.4초·first upgrade 260.7초·stuck 0.01 | 압축 후보 자동 채택. bot-only 첫 접촉·킬은 N2-PLAY-09 수동 3판 뒤 판단 |
| E-043 | 첫 축소를 앞당기되 stage2/3와 10-15분 분포를 보존할 수 있는가? | 첫 축소 120초·축소 140초 후보 5-run 평균 727.0초, 범위 654.3-829.5초, first upgrade 262.2초, stage2/3 260.0/540.1초, stuck 0.01 | 자동 채택. 초기 압력과 회복 제약은 수동 판정 필요 |
| E-044 | 지역별 초기 무기 등급과 별도 방어구가 초반 접근을 앞당기면서 M1 페이싱을 보존하는가? | 5-run 평균 746.7초, 범위 606.0-857.9초, first upgrade 4.5초, loot hub·transit 무기 획득 69.7%, stuck 0.01 | 자동 채택. 초기 즉시 무장과 방어구 trade-off는 수동 판정 필요 |
| E-045 | 설계형 소형 거점이 단일 셀 집중 없이 경로·페이싱을 보존하는가? | `C:\tmp\n2_map_17_anchor_fix_20260726`: 평균 787.2초, open 피해/킬 41.9%/33.9%, 상위 셀 5.4%, stuck 0.01. 앵커 수정 뒤 `-50,30` 정체 6/33→1/41, focused runtime 4.85초·stuck 0, `unit_smoke` 통과. Forward+는 2회 정상·1회 p95 32.695ms 이상치 | 구조·페이싱 자동 후보 채택. 성능 이상치 재현과 장소·도로·숲 압력은 수동 승격 전 확인 |
| E-046 | `target_99_probe`의 300초 경계에서 raw count와 개체·분 gate가 뒤집히는가? | 무작위 현재 후보는 평균 266.1초·raw disengage 170.2로 기존 130 gate를 실패했지만 0.39/개체·분이다. 과거 확장 후보는 평균 196.6초·raw 152.4·0.47/개체·분으로 normalized gate를 실패한다. 입력 41000-41004 현재 후보는 평균 239.1초, stuck/disengage 0.01/0.44로 통과 | 구조 profile은 입력 41000-41004를 추적하고 match 길이와 무관하게 개체·분 0.15/0.45를 적용. 99봇 gameplay 승격 근거로는 사용 금지 |
| E-047 | POI 보장 무기·면적 균등 스폰·bounded drop TTL이 N2-PLAY-10의 무기 공백과 초기 붕괴를 함께 줄이는가? | `C:\tmp\n2_play_11_survival_20260809`: 5-run 평균 692.3초·범위 641.8-781.0초·first upgrade 3.3초·fallback 0·AI 342µs, alive@30/60/90/120/180/260 `52/35/27/22/20/15`, T50/T10 `32.7/286.8초` | D-004는 통과했지만 생존 gate 실패. 구현 계약은 유지하되 packaged 수동 승격 금지, 사망 문맥으로 종료 실패를 진단 |
| E-048 | bot-v-bot immediate 범위를 10m→2m로 줄이면 player/direct response를 보존하며 초기 붕괴가 완화되는가? | pilot alive@30/60/120 `57/35/23`, T50/T10 `42/291초` | 방향 gate 실패, 완전 revert. engagement 범위 조정 재혼합 금지 |
| E-049 | 층화 스폰이 fallback 없이 초기 조우 밀도를 낮추는가? | 평균 nearest 18.3m·fallback 0, alive@30/60/120 `52/35/19`, T50/T10 `33.2/297.3초`, first upgrade 0.5초 | 생존·경제 방향 gate 실패, 완전 revert. 다른 생존 후보와 재혼합 금지 |
| E-050 | behavior-unchanged kill context가 초기 붕괴의 종료 경로를 좁히는가? | `C:\tmp\n2_play_11_kill_context_baseline_20260809\run_1.json`: 845.8초, alive `53/38/26/26/21/15`, T50/T10 `36.2/415.1초`, first upgrade 12.2초. 60초 내 사망 22건은 gun/melee `14/8`, 생존 상태 피해자 19, 최근 보복 19, pressure 14 | 계측 유지. 교전 시작보다 RECOVER/DISENGAGE 뒤 종료 실패가 우선 가설이지만 단일 run은 gameplay PASS가 아님 |
| E-051 | 생존 상태 bot target을 양보하는 ceasefire가 재획득·이동 회귀 없이 초기 사망을 줄이는가? | `C:\tmp\n2_play_11_survival_ceasefire_pilot_20260810\run_1.json`: 738.1초, alive `58/44/37/30/28/25`, T50/T10 `41.4/328.6초`, 사망 16·생존 상태 피해자 0. release 345, 1초 내 재획득 90(26.1%), stuck/disengage `53/823` 대 기준 `6/384` | 방향 gate 실패, 완전 revert, 5-run 금지. 재획득·이동 비용을 닫지 않은 ceasefire 재시도 금지 |
| E-052 | bot-only survival HP buffer +0.08이 근접 종료 연쇄를 안전하게 늦추는가? | `C:\tmp\n2_play_11_survival_buffer_008_20260810`: 763.4초, alive@60/120/260 `34/16/14`, T10 280.2초, 1초 내 재획득 58/151(38.4%), stuck gate 실패 | 방향 gate 실패, 완전 revert, 5-run 금지. 피해/HP 완충과 다른 후보 재혼합 금지 |
| E-053 | DISENGAGE 첫 1초 bot-only counteraction grace가 보복 연쇄를 끊는가? | `C:\tmp\n2_play_11_disengage_counter_grace_20260814`: 682.5초, alive `52/34/24/14`, T10 274.5초, fast reacquire 24/69(34.8%), disengage trigger 0.22. 직접 causal path는 0건이고 5m 이내 kill은 18→21 | 원인 경로를 건드리지 못하고 방향 gate 실패, 완전 revert, 5-run 금지. grace 확대·혼합 금지 |
| E-054 | behavior-neutral continuity v2가 완전 aggregate와 bounded raw로 N2-PLAY-11을 판정할 수 있는가? | 1-run sanity는 contract PASS/stuck FAIL. `C:\tmp\n2_play_11_continuity_v2_5run_20260814`: 평균 668.8초(531.5-805.5), release/reacquire/exit `414/132/1284`, `check_scale_telemetry` PASS. 기록된 `tactics.disengage_entries/(spawned×duration_min)`은 run2 0.782·run4 0.864로 보조 watch 0.70을 2/5 초과 | schema v2 계측 계약 채택, gameplay PASS 아님. 다음 후보 전 opening 생존 상태 노출 분모로 반복 이탈·근거리 집중을 분리 |
| E-055 | behavior-neutral opening survival exposure가 상태·위치별 종료 위험을 유효한 분모로 분리하는가? | `C:\tmp\n2_play_11_survival_exposure_sanity_20260828`: 849.696초·alive `55/29/22/15`·T50/T10 `35.8/279.8초`; exact 444.3 actor-sec·known 100%·overflow false. DISENGAGE 318.4초/24명/7.54 per100초, RECOVER 126.0초/0명, entry/exit `305/303`, `survival_break` 22/24·2초 미만 18/24, fast reacquire 22/78(28.2%) | schema/data-quality·구조 gate 채택, gameplay/survival FAIL. 노출 정규화는 단일 map hotspot을 지목하지 않으므로 topology 변경 금지 |
| E-056 | `survival_break`로 들어온 DISENGAGE의 `no_threat` exit만 2.0초 늦추면 빠른 종료·재획득을 줄이면서 생존과 구조 gate를 보존하는가? | 아직 결과 없음. E-055가 지목한 dominant entry/short state-age 경로 하나만 바꾸는 1-run 방향 실험으로 등록 | 1-run 전용 후보. 생존·continuity·정체/이탈·D-004가 함께 개선될 때만 5-run; 통과 전 채택·package·수동·릴리즈 주장 금지 |

## 폐기 패턴

| 패턴 | 폐기 신호 | 다시 시도하려면 |
|---|---|---|
| Global loot_count/hotspot/rare 감소 | upgrade는 늦췄지만 duration/stage3 회귀 | 글로벌 경제가 병목이라는 새 증거 |
| concealment/loot-hub role multiplier를 완전한 해결책으로 취급 | corrected read에서도 first upgrade 97.4초 | map/wave non-pistol source 해결 후 |
| broad weapon chance cut | spike가 남거나 upgrade starvation 발생 | initial non-pistol pool와 stage/supply source 사용 |
| hard-bump threshold-only | 0.75m probe가 duration/stage3를 망침 | 더 넓은 opening 설계와 v4 duration gate 보존 |
| 5초 이상 opening hard-bump brush | first contact는 18.3초였지만 avg duration 326.9초, stage3 없음 | late-duration 여유를 먼저 확보 |
| bot weapon drop으로 first-upgrade timing 조정 | N2-PACE-29 source read가 bot_drop을 지목하지 않음 | source telemetry가 bot_drop first upgrade를 보여줌 |
| spawn-spacing-only opening fix | contact 해결 부족, no-upgrade/stuck 위험 | map/nav 이유가 증명됨 |
| stage2 이동으로 match length 해결 | stage2는 이미 watch band 안 | late-zone과 match-end gap을 분리 |
| zone damage를 match length 주 lever로 사용 | v4 control 5-run에서 zone death 0회, 사망 98/99가 stage1 combat | zone death가 종료 분포를 지배한다는 새 증거 |
| gate를 낮춰서 통과 | gate가 실제 fallback/stuck/sentinel 위험을 잡음 | 새 gate 정의가 승인됨 |
| 고정 seed 3-run 쌍 비교 | 같은 seed도 physics/timer 실행 순서에 따라 결과가 크게 달라짐 | 결정적 실행기가 생기거나 최소 5-run 분포로 재설계 |
| opponent 구분 없는 bot-only opening grace | headless player가 target에 남아 first-contact 해석이 오염됨 | 상대 유형별 접촉/target telemetry가 생김 |
| obstacle 위치 반복 이동 | hotspot 이동과 duration 회귀만 만들고 이동 복구 결함을 가림 | nav 구조 또는 수동 route 증거가 특정 배치를 지목 |
| idle headless player를 simulation 참가자로 유지 | 모든 run player win, 마지막 bot 전멸 대기, ATTACK 245.5초 이상치 | 행동 가능한 player 모델이 추가됨 |
| 이동 분리 없이 non-hard-bump opening guard만 연장 | 첫 접촉만 18.0초로 늦고 hard-bump 5/5, 평균 401.3초, stuck 0.26 | `ZONE_ESCAPE` 수렴 또는 초반 충돌 경로를 먼저 분리 |
| `ZONE_ESCAPE` 수렴을 stage1 attrition 주 lever로 취급 | v6에서 zone 체류/stuck은 감소했지만 stage1 사망은 95.6명으로 유지 | IDLE loot 이동과 acquisition 증거를 먼저 확인 |
| pickup 예약을 opening 주 해결책으로 사용 | idle_loot 공유 목표가 8.2%이고 첫 획득은 idle_reaction | 공유 목표가 first acquisition을 지배한다는 새 증거 |
| 짧은 비전투 근접 분산을 opening 해결책으로 사용 | first contact/stage1 사망은 그대로이고 stuck 0.14→0.16 | 실제 이동 충돌이 사망 분포를 지배한다는 새 증거 |
| stage1 broad damage 감소 | 사망 감소가 작고 DISENGAGE/stuck 장기화 | 피해량이 아닌 교전 시작·종료 연쇄를 제한하는 증거 필요 |
| post-kill 재획득 지연 | 해당 source는 줄지만 idle/damage acquisition으로 우회하고 사망 유지 | 구조적 encounter density가 줄어든다는 맵/화면 증거 필요 |
| route 위 고엄폐 직접 추가 | route 킬 비중은 오르지만 새 cover 셀이 stuck hotspot이 되고 duration이 짧아짐 | route가 실제 이동/선택 표면으로 구현되고 수동 동선이 특정 엄폐를 요구 |
| 초기 pickup 간격만으로 opening 수렴 해결 | 3.5m 간격에도 첫 획득 5/5가 6.7초 idle reaction, stage1 사망 96.0명 | 개별 pickup이 아니라 POI 단위 목적지 분포가 원인이라는 새 설계 필요 |
| AI가 소비하지 않는 route 분류를 플레이어에게 표시 | 자동 캡처는 읽혀도 실제 플레이에서 인공적이고 전략 의미를 오해시킴 | pickup·장애물·AI 목표가 같은 경로 구조를 실제로 소비한다는 계약 필요 |
| 수동 `visual_review` 결과를 99봇 페이싱과 동일시 | 8봇은 참가자당 약 1,018㎡, 99봇 v6는 약 191㎡로 encounter 밀도가 다름 | 화면 검증과 gameplay 대표 preset을 분리 |
| 좌표 확대와 중앙 spawn 집중으로 크기와 조우를 한 번에 해결 | 260m 후보도 첫 조우 7.1초, 180-218초 종료로 초반 과밀이 유지 | 맵 규모, 초기 밀도, AI 목표 위치를 독립 변수로 검증 |
| 위치 후보마다 전체 봇을 순회해 혼잡 계산 | open 피해가 늘고 AI update 비용이 33%, DISENGAGE 비용이 82% 증가 | Arena에서 필요한 분산 신호를 먼저 정의하고 기존 근접 관측만 재사용 |
| bot-only HP buffer로 생존 곡선 보정 | alive@120/260과 T10이 악화되고 fast reacquire 38.4%·stuck gate 실패 | 피해량이 병목이라는 새 인과 증거와 별도 후보 계약 필요 |
| DISENGAGE 직후 blanket counteraction grace | 직접 causal path 0건, 근거리 kill·churn이 늘고 방향 gate 실패 | 실제 종료 source를 지배하는 경로가 계측으로 확인될 때만 해당 경로를 좁게 설계 |

## 기록 규칙

새 행은 `E-XXX | 질문 | 출력 경로와 핵심 3지표 | 채택/폐기/재실행` 형태로 쓴다. analyzer 원문은 붙이지 않는다.
