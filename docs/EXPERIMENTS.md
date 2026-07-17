# 실험 기록

> 최종 업데이트: 2026-07-17. 같은 실패를 반복하지 않기 위한 짧은 장부다.

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

## 기록 규칙

새 행은 `E-XXX | 질문 | 출력 경로와 핵심 3지표 | 채택/폐기/재실행` 형태로 쓴다. analyzer 원문은 붙이지 않는다.
