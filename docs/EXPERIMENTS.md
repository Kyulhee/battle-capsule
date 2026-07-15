# 실험 기록

> 최종 업데이트: 2026-07-16. 같은 실패를 반복하지 않기 위한 짧은 장부다.

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
| E-008 | bot끼리의 damage만 낮추면 timing band를 유지하며 match 여유가 생기는가? | v4 control avg 350.6초; v5 0.55+initial 150초: avg 689.0초, 범위 336.2-1219.9초, first upgrade 285.5초, stage3 654.2초 | 자동 후보 채택, 분산 안정화 전 승격 보류 |

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

## 기록 규칙

새 행은 `E-XXX | 질문 | 출력 경로와 핵심 3지표 | 채택/폐기/재실행` 형태로 쓴다. analyzer 원문은 붙이지 않는다.
