# Night BR 페이싱 계획

> 최종 업데이트: 2026-06-30. 10-15분 Night BR 후보를 판단하는 기준 문서다.

## 목표

- 플레이어가 첫 1분에 즉사/랜덤 충돌이 아니라 “위험을 읽고 선택하는” 느낌을 받게 한다.
- 첫 non-pistol upgrade는 120-300초 창에 들어오게 한다.
- stage2는 240-420초, stage3는 540-720초 창을 지향한다.
- 최종 match duration은 600-900초를 지향한다.

## 현재 후보

| Preset | 역할 | 상태 |
|---|---|---|
| `target_99_probe` | 구조 gate | 체감 목표 아님 |
| `playable_pacing_v2` | late-zone 참조 | stage2/stage3 기준 참고 |
| `playable_pacing_v3` | role weapon multiplier 진단 | 승격 후보 아님 |
| `playable_pacing_v4` | 현재 자동 후보 | first-upgrade timing 해결 |

## 최신 수치

N2-PACE-32 4초 opening hard-bump brush:

- avg duration 554.3초
- first contact 17.7초
- first kill 24.4초
- first upgrade 293.9초
- stage2 285.8초
- stage3 655.7초
- hard-bump first acquisition 1/3

## 현재 해석

- first upgrade, stage2, stage3는 watch band 안에 있다.
- match end는 600초 floor보다 약 45.7초 짧다.
- first contact는 여전히 빠르다.
- opening pressure를 더 지연하면 duration이 무너질 수 있으므로, 먼저 match-length margin을 확보해야 한다.

## 다음 후보 방향

1. late-zone/match-end 여유를 안전하게 확보한다.
2. opening contact를 직접 더 지연하기 전 duration gate가 안정적으로 남는지 확인한다.
3. 수동 visual/playtest로 야간 가독성과 첫 1분 체감을 확인한다.
