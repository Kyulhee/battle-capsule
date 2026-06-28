# Night BR Pacing Plan

> Last updated: 2026-06-14. Planning document for the 10-15 minute 99-player Night Artificial Forest direction.

## 목적

이 문서는 Night Artificial Forest 99인 본편 후보를 만들 때 현재 scale telemetry를 어떻게 해석하고, 어떤 테스트를 먼저 만들지 정리한다.

핵심 결정:

- 목표 매치 길이는 10-15분이다.
- v2.0.40까지의 `xlarge_60` / `target_99_probe` telemetry는 최종 밸런스가 아니라 구조 안전성 게이트다.
- 손전등, 배터리, 공포, 정전, 야간 시야가 들어가면 combat/CHASE/loot 비율은 크게 흔들릴 수 있다.
- 따라서 지금은 "수치가 완성 체감과 맞는가"보다 "99인 후보가 무너지지 않는가"를 먼저 본다.

## Gate 재정의

### 구조 안전성 게이트

지금 유지할 기준:

- spawn fallback은 반복 게이트에서 0이어야 한다.
- 99인 후보 맵은 preferred envelope인 180m world / 78m spawn radius / 3.5m clearance를 만족해야 한다.
- primary choke, flank, loot flow, recovery exit가 `mapSpec`에 명시되어야 한다.
- POI/route role telemetry가 읽혀야 한다.
- stuck, disengage, zone escape, AI update cost가 급격히 폭발하지 않아야 한다.
- 후보 맵은 기본 맵이나 기본 scale preset으로 승격하지 않는다.

이 게이트는 "돌아가는 백본" 확인이다. 재미, 공포, 시야 싸움, 10-15분 pacing을 보장하지 않는다.

### 기준선 gap report

`tools/summarize_pacing_baseline.py <run_dir>`는 구조 게이트를 통과한 simulation set을 10-15분 목표에 맞춰 해석하는 리포트다.

- `check_scale_telemetry.py`는 통과/실패를 내는 구조 gate다.
- `summarize_pacing_baseline.py`는 tuning을 적용하기 전의 해석 도구다.
- report가 "compressed structural smoke"라고 나오면 duration, first upgrade, stage timing을 최종 체감값으로 읽지 않는다.
- N2-PACE-04 이전 `target_99_probe` 3-run 기준선 `C:\tmp\game_dev_pacing_map_clearance_v2_3run`은 avg duration 143.6s로, 10분 바닥까지 4.18x, 12.5분 midpoint까지 5.22x 짧다. 이 run의 pacing milestone은 wall-clock seconds로 저장되었으므로 phase 판단에는 쓰지 않는다.
- N2-PACE-05 fresh game-time 3-run `C:\tmp\game_dev_pacing_game_time_v2_3run`은 avg duration 163.1s, first contact 1.4s, first kill 17.5s, first non-pistol upgrade 27.4s, stage 2 130.2s를 기록했다. 구조 gate는 fallback 0.0/run, zone deaths 0, stuck 16.7/run, AI avg 628.9us, sentinel clear로 통과했지만, 10분 바닥까지 3.68x, 12.5분 midpoint까지 4.60x 짧은 compressed structural smoke다.
- N2-PACE-06 `playable_pacing_v1` 3-run `C:\tmp\game_dev_playable_pacing_v1_3run_v2`는 avg duration 294.0s, first contact 1.2s, first kill 15.0s, first non-pistol upgrade 36.6s, stage 2 268.5s를 기록했다. 구조 지표는 fallback 0.0/run, zone deaths 0.7/run, stuck 16.7/run, AI avg 529.0us, sentinel clear로 통과했지만, 10분 바닥까지 2.04x, 12.5분 midpoint까지 2.55x 짧다.
- N2-PACE-07 이후 `summarize_pacing_baseline.py`는 opening pressure를 함께 출력한다. `playable_pacing_v1` 3-run은 spawn fallback 0.0/run, min nearest 3.5m, avg-nearest 7.4m, saturation 0.20이다. 로컬 5m spawn spacing smoke는 min nearest를 5.0m로 올렸지만 first contact가 1.4s로 거의 변하지 않았고 no first upgrade가 나와 폐기했다.
- N2-PACE-08 이후 pacing telemetry는 첫 target acquisition을 따로 기록한다. `C:\tmp\game_dev_opening_acq_v1_3run`은 first acquisition 0.6s, first contact 1.0s, acquisition-to-contact gap 0.4s를 기록했다. 첫 acquisition은 retreat_counteraction / ZONE_ESCAPE, 평균 거리 5.2m였다.

### 체감/페이싱 게이트

Night Artificial Forest 후보 이후 새로 볼 기준:

- 첫 교전이 너무 즉시 발생하거나 너무 늦게 발생하지 않는가.
- 첫 non-pistol upgrade가 초반 목표를 만들되 게임을 너무 빨리 결정하지 않는가.
- Sluice Crossing 같은 횡단 지점이 중반 이동 압력을 만드는가.
- False Clinic 같은 회복 포켓이 안전한 반복 루프가 아니라 위험한 재진입을 만드는가.
- Black Ridge 같은 파워 포지션이 강하지만 우회/압박 가능하게 남는가.
- Wire Maze가 전술적 긴장을 만들면서 stuck/LOS 오류를 과도하게 만들지 않는가.
- 최종 10-15분까지 루팅, 교전, 이동, 회복, 은폐의 역할이 단계적으로 바뀌는가.

## 10-15분 매치 구조

| 구간 | 의도 |
|---|---|
| 0-2분 | 스폰, 기본 무기/탄약 확보, 가까운 보급지 선택 |
| 2-5분 | 첫 교전, 첫 upgrade, 지역별 POI 압력 형성 |
| 5-9분 | 강/수문/횡단로 중심 회전, 회복 포켓 재진입, 파워 포지션 선점 |
| 9-12분 | 자기장 압축, 야간 시야/조명 리스크 증가, 주요 우회로 폐쇄 |
| 12-15분 | 최종 교전. 은폐와 시야 정보가 강하지만 확정 승리 수단이 되면 안 됨 |

자기장은 초반에는 느리게, 후반에는 점진적으로 빠르게 좁아져야 한다. 지금처럼 짧은 smoke run에 맞춘 속도는 본편 후보에서는 그대로 쓰면 안 된다.

## 10-15분 pacing 조정안 초안

이 초안은 tuning 적용 순서와 검증 경로만 정의한다. `target_99_probe`는 계속 구조 안전성 게이트로 유지하고, 10-15분 체감 수치는 별도 비기본 pacing 후보에서 검증한다.

### 목표 watch band

아래 값은 첫 candidate tuning을 해석하기 위한 관찰 밴드다. hard gate로 쓰기 전에는 최소 3-run 반복과 구조 gate 통과를 먼저 요구한다.

| 지표 | 초안 watch band | 해석 |
|---|---|---|
| 첫 shot/contact | 45-150s | 0-5초에 고정되면 spawn/proximity artifact를 의심한다 |
| 첫 kill | 60-210s | 초반 교전은 가능하되 즉시 탈락이 평균 패턴이 되면 안 된다 |
| 첫 non-pistol upgrade | 120-300s | 2-5분 구간의 첫 목표가 되어야 한다 |
| stage 2 도달 | 240-420s | 첫 회전 압력이 생기되 초반 루팅을 끊지 않아야 한다 |
| 첫 crossing pressure | 240-540s | Sluice Crossing 또는 우회로가 중반 선택지가 되어야 한다 |
| stage 3 / late compression | 540-720s | 9-12분 압축 구간에 맞춘다 |
| match end | 600-900s | 10-15분 본편 목표 범위 |

N2-PACE-04 이후 fresh 1-run은 duration 150.9초, first upgrade 25.1초, stage 2 121.3초를 기록했다. N2-PACE-05 fresh 3-run은 duration 163.1초, first contact 1.4초, first upgrade 27.4초, stage 2 130.2초다. 둘 다 구조 smoke이며, 이 값을 그대로 늘리거나 scale gate threshold를 낮추지 않는다.

N2-PACE-06 `playable_pacing_v1`은 duration을 294.0초까지 늘리고 stage 2를 268.5초로 보냈지만, first contact 1.2초와 first upgrade 36.6초는 여전히 목표보다 빠르다. 첫 낮은 economy 후보는 3-run에서 `no first upgrade`를 재현했으므로 폐기했고, 최종 verifier는 loot_count 190 이상, hotspot 1.0 이상, rare 1.05 이상, stage wave 하한을 요구한다.

N2-PACE-07의 5m spawn spacing 로컬 smoke는 first contact를 유의미하게 늦추지 못했다. 다음은 단순 clearance 증가보다 spawn/proximity와 target acquisition behavior를 분리해서 봐야 한다.

N2-PACE-08 결과상 first contact 이전에 이미 0.6초 target acquisition이 발생한다. 다음 조정 전에는 초기 ZONE_ESCAPE / retreat_counteraction이 왜 spawn 직후 생기는지 먼저 확인한다.

N2-PACE-24부터 `summarize_pacing_baseline.py`는 `Phase gap read`를 출력한다. `playable_pacing_v1` 3-run 기준 first contact 1.2s는 45-150s band보다 43.8s 빠르고, first kill 15.0s는 45.0s 빠르며, first non-pistol upgrade 36.6s는 83.4s 빠르다. 반면 stage2 268.5s는 240-420s band 안이고, stage3는 없으며, match end 294.0s는 600s floor보다 306.0s 빠르다. 따라서 다음 gameplay 후보는 stage2를 다시 움직이기보다 late-zone compression과 first-upgrade 지연을 분리해서 설계한다.

N2-PACE-25는 비기본 `playable_pacing_v2`를 추가했다. v2는 v1의 99 bots, loot_count 210, 5m opening clearance, loot economy, initial_radius 86, initial/base zone timing을 유지하고 stage2 이후 wait/shrink를 늘리며 damage를 낮춘다. 3-run `C:\tmp\game_dev_playable_pacing_v2_late_zone_v1_3run`은 avg duration 533.3s, stage2 268.1s, stage3 638.4s, first upgrade 19.4s, fallback 0.0/run, stuck 0.09/entity/min, AI avg 418.9us로 scale gate를 통과했다. stage2/stage3는 band 안이고 match end는 600s floor보다 66.7s 짧다. 다음 후보는 v2 기준 first-upgrade/economy pacing을 늦추되 no-first-upgrade starvation을 피한다.

N2-PACE-26의 local `playable_pacing_v3` economy 후보는 폐기했다. loot_count 205, hotspot 1.02, rare 1.08은 first upgrade를 56.0s까지 늦췄지만 avg duration 454.1s, stage3 none으로 v2의 late-zone 개선을 깨뜨렸다. 다음 후보는 global loot/rare 축소가 아니라 first-upgrade source/weapon/route context를 먼저 진단한다.

N2-PACE-29는 first-upgrade source telemetry와 game-time fix를 추가했다. corrected v3 read는 avg duration 579.2s, first upgrade 97.4s였지만 실제 샘플은 initial_loot 5.6s/9.8s와 stage_wave 276.9s가 섞인 평균이었다. 따라서 다음 조정은 전체 무기 확률을 낮추는 방식이 아니라 초기 비권총 풀과 중반 공급원을 분리해야 한다.

N2-PACE-30 `playable_pacing_v4`는 초기 루팅의 비권총 무기 가중치를 0으로 낮추고 stage/supply source를 첫 업그레이드 창으로 남긴다. `C:\tmp\game_dev_N2_PACE_30_v4_initial_pool_fix_3run`은 avg duration 599.6s, first upgrade 294.9s, missing 0, stage2 284.3s, stage3 654.2s로 자동 pacing gate를 통과했다. 남은 큰 gap은 first contact 14.1s / hard-bump acquisition 3/3이므로, 다음 후보는 zone/economy가 아니라 opening pressure를 본다.

### playable_pacing_v1 값

`playable_pacing_v1`은 Night 후보 mapSpec에만 있는 비기본 프리셋이다. `target_99_probe`와 기본 맵은 바꾸지 않는다.

| 항목 | target_99_probe | playable_pacing_v1 | 의도 |
|---|---:|---:|---|
| bots | 99 | 99 | 구조 부하 유지 |
| loot_count | 240 | 210 | stage wave 경제는 낮추되 starvation 방지 |
| spawn_radius | 78.0 | 78.0 | 구조 spawn envelope 유지 |
| safe_spawn_attempts | 180 | 260 | fallback 0과 5m opening clearance 유지 |
| hotspot_density_mult | 1.16 | 1.04 | target보다 낮게 유지 |
| rare_bias_mult | 1.45 | 1.15 | non-pistol seed는 유지 |
| stage_wave_base/per | 0.08 / 0.08 | 0.045 / 0.055 | stage wave를 줄이되 제거하지 않음 |
| stage_wave_count_mult | 9 | 6 | midgame supply 폭발 완화 |
| initial_timer | 52s | 160s | 초반 zone 압박 완화 |
| base wait/shrink | 48s / 34s | 150s / 70s | stage 2를 5분 전후로 이동 |
| stage 2 wait/shrink/dps | 40s / 28s / 4 | 170s / 70s / 2 | 중반 회전 시간 확보 |

### 조정 순서

1. `target_99_probe`를 변경하지 않고 Night 후보 전용 비기본 pacing preset 또는 zone/economy override를 만든다. 1차는 `playable_pacing_v1`으로 완료했다.
2. 자기장 schedule을 먼저 늘린다. early safe time과 stage duration을 늘리되 zone death가 구조 gate를 다시 깨지 않는지 확인한다.
3. loot/economy spacing을 조정한다. 기본 무기 접근성은 유지하고, non-pistol upgrade 평균을 2-5분 구간으로 보낸다.
4. POI rotation 압력을 조정한다. Sluice Crossing, False Clinic 재진입, Black Ridge 우회가 중반에 읽히는지 route/POI dwell과 crossing telemetry로 본다.
5. combat damage, AI aggression, night awareness 상수는 마지막에 조정한다. duration을 맞추기 위해 전투 수치를 먼저 낮추지 않는다.

### 검증 루프

- 문서/수치 계획만 바꿀 때는 `git diff --check`를 통과해야 한다.
- 첫 candidate tuning을 적용하면 기존 night verifier와 `target_99_probe` 3-run 구조 gate를 먼저 유지한다.
- 구조 gate가 통과한 뒤 `summarize_pacing_baseline.py`로 duration scale-up, milestone phase, stuck route/cell을 다시 읽는다.
- fallback, zero damage/shot/combat-plan sentinel, AI update budget 초과, stuck > 60/run은 pacing tuning보다 구조 회귀로 먼저 처리한다.
- 단발 no first upgrade는 바로 tuning하지 않고 3-run으로 재확인한다.
- candidate pacing sample은 구조 smoke와 별도 디렉토리에 저장하고, 구조 gate 결과와 섞어 해석하지 않는다.

## 야간 시스템 단계

### Phase A: 플레이어-facing 손전등

먼저 구현할 수 있는 범위:

- 플레이어 손전등 cone, 밝기, on/off, 소리/시각 노출.
- 어둠 속 item/POI/readability 체감.
- 봇은 기존 perception을 유지하되 플레이어 손전등 사용, 발사, 소음, 근접 노출에 반응한다.

하지 않을 것:

- 모든 봇에게 배터리 inventory, 공포 state, 손전등 cone aiming을 즉시 넣지 않는다.

### Phase B: 봇 추상 야간 인지

봇은 full flashlight system이 아니라 간단한 night awareness modifier를 쓴다.

- 어둠 속 감지 거리/확신도 감소.
- 플레이어 flashlight/noise/reveal에 대한 target acquisition 보정.
- POI 또는 route role에 따른 경계/정찰 가중치.
- 고비용 cone-vs-cone 시뮬레이션은 피한다.

### Phase C: 특수 봇 또는 엘리트만 full light behavior

필요할 때만 제한적으로 적용한다.

- guard/searcher archetype이 특정 POI에서 손전등 sweep을 한다.
- Black Ridge, Broadcast Fence, Wire Maze 같은 일부 구역에만 강화 인지를 준다.
- 모든 봇에게 동일한 고비용 행동을 주지 않는다.

## 테스트 계층

### 1. Whole-map structural probe

목적: 99인 후보가 기본적으로 무너지지 않는지 확인한다.

사용:

- `verify_strategic_flow_map.gd`
- `verify_candidate_99_probe.gd`
- fresh 5-run `xlarge_60`
- fresh 5-run `target_99_probe`
- `compare_scale_profiles.py`
- `check_scale_telemetry.py`

판단:

- fallback 0, clearance, route/POI role coverage, stuck/AI cost를 본다.
- combat 비율 하나를 목표값으로 직접 맞추지 않는다.

### 2. POI minimap probes

목적: 전체 99인 매치를 반복하지 않고 핵심 공간을 빠르게 검증한다.

우선 후보:

- `Sluice Crossing`: 직접 횡단, 우회, 시야 노출, choke pressure.
- `Wire Maze`: 장애물 밀도, stuck, LOS, 근접전.
- `Black Ridge`: power position, 우회 가능성, 과도한 지배력.
- `Supply Flats`: 초반 루팅 노출 비용, cover line.
- `False Clinic`: 회복 후 재진입 압력.
- `Cabin Row`: 은폐/근접전/readability.

형태:

- 작은 `mapSpec` 또는 test scene.
- 4-12 bots로 특정 POI behavior만 반복.
- 수치보다 collision, readability, route choice, visibility를 먼저 본다.

### 3. Feature proxy simulations

목적: 기능 전체 구현 전, 결과가 맵 구조를 얼마나 흔드는지 확인한다.

예시:

- flashlight-on actor는 더 멀리 탐지되지만 어둠 속 target 탐지는 제한된다.
- blackout window 동안 acquisition confidence를 낮춘다.
- battery depletion을 실제 아이템 없이 시간/사용률 row로만 기록한다.
- bush/concealment 안에서 reveal/ambush 이벤트만 간단히 표시한다.

### 4. Manual feel pass

목적: 플레이어 체감 문제를 찾는다.

확인:

- 어둠 때문에 item과 적을 못 읽는지.
- 손전등을 켜는 선택이 장점과 노출 비용을 동시에 갖는지.
- POI 이름과 구조가 기억되는지.
- 10-15분 목표에서 지루한 이동 구간이 생기는지.

## 추가 telemetry 후보

| Metric | 이유 |
|---|---|
| `match_duration_seconds` | 10-15분 목표 직접 확인 |
| `first_contact_seconds` | 초반 pacing 확인 |
| `first_non_pistol_upgrade_seconds` | 무기 성장 tempo 확인 |
| `first_crossing_seconds` | Sluice Crossing 압력 확인 |
| `flashlight_on_ratio` | 손전등 사용 선택이 의미 있는지 확인 |
| `darkness_hit_count` / `darkness_kill_count` | 어둠이 combat에 미치는 영향 |
| `revealed_by_light_count` | 빛이 노출 비용을 만드는지 확인 |
| `battery_empty_count` | 배터리 시스템 도입 필요성 판단 |
| `poi_dwell_seconds_by_role` | POI별 체류/정체 확인 |
| `crossing_usage_by_route` | 직접 횡단/우회 선택 확인 |
| `bot_night_awareness_cost_us` | 봇 야간 인지 비용 확인 |

## 다음 구현 판단

1. `target_99_probe`는 구조 안전성 게이트로 유지한다.
2. Night 후보 전용 비기본 playable pacing preset 또는 zone/economy override를 추가한다.
3. 첫 적용은 자기장 schedule과 economy spacing에 제한한다.
4. 적용 후 기존 night verifier, playable preset verifier, 3-run candidate sample, `summarize_pacing_baseline.py`를 함께 돌린다.
5. 다음은 초기 ZONE_ESCAPE / retreat_counteraction acquisition 원인을 확인하는 것이다. crossing, flashlight, darkness telemetry가 부족하면 combat tuning 전에 telemetry를 보강한다.
