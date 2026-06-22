# 배틀 캡슐 마스터플랜

> 마지막 업데이트: 2026-06-23 (playable_pacing_v2 late-zone candidate 완료)

현재 세션에서 기본으로 읽는 압축 로드맵이다. 압축 전 전체 원문은 [archive/MASTERPLAN_full_2026-06-08.md](archive/MASTERPLAN_full_2026-06-08.md)에 보존했다. 더 오래된 기록은 `docs/archive/`에 남아 있다.

## 현재 요약

| 항목 | 상태 |
|---|---|
| 현재 개발 라인 | v2-dev: 구조 안전성 게이트 + 99인 야간 맵 후보 전환 |
| 최신 완료 작업 슬라이스 | N2-PACE-25 playable_pacing_v2 late-zone candidate |
| 현재 문서 슬라이스 | playable_pacing_v2 late-zone candidate 기록 |
| 다음 구현 후보 | `playable_pacing_v2` first-upgrade/economy pacing 후보 |
| 목표 플레이 시간 | 10-15분 본편 매치 |
| 현재 telemetry 역할 | 최종 밸런스가 아니라 구조 안전성 게이트 |
| 99인 런타임 상태 | 기본 맵/기본 프리셋 승격 금지. 후보 맵과 `target_99_probe`에서만 검증 |
| 수동 화면 검토 | `visual_review` 프리셋 사용. `xlarge_60`/`target_99_probe`는 렉이 큰 구조 부하 검증용 |
| 성능 LOD 상태 | 픽업 광원 LOD와 AI perception/sensory tick LOD 1차 적용 |
| 현재 미확인 항목 | `playable_pacing_v2`에서 no-first-upgrade 없이 first upgrade를 늦추고 265.9s short-run variance를 줄이는 경제/tempo 후보 |
| 릴리즈 상태 | 일시 중지. 명시 요청 전까지 버전별 개발 지속 |
| 로컬 참고 자료 | `plan_report/`는 참고용 로컬 디렉토리이며 커밋 대상 아님 |
| 외부 에셋 | `asset_generator/`, 로컬 프롬프트 스크래치는 선택 통합 전까지 untracked 유지 |

생성 에셋 일부가 아직 연결되지 않은 상태에서는 Godot 시작 시 다음 경고가 예상된다.

```text
AssetCatalog: 7 configured asset paths are missing; fallbacks remain active.
```

## 현재 결정

- v2.0.40까지의 긴 telemetry 작업은 "99인 완성 밸런스"가 아니라 "맵/스폰/루트/AI 비용이 무너지지 않는지 보는 구조 안전성 백본"으로 격하한다.
- 다음 본편 후보는 기존 Balanced 99 Forest 개념을 그대로 구현하는 대신, `plan_report/`의 **야간 인공 숲 콜로세움** 방향을 우선 검토한다.
- 중앙 만능 허브보다 대각선 강/수문/횡단로가 회전 압력을 만드는 구조가 더 적합하다. `Sluice Crossing`은 중심 충돌축, `Black Ridge`는 제한된 파워 포지션, `False Clinic`은 회복/스토리 루프 역할을 맡긴다.
- 99인 맵은 `data/mapSpec_night_forest_candidate.json`으로 첫 구조 후보를 만들었다. POI 미니맵은 `Sluice Crossing`, `Wire Maze`, `Black Ridge`, `False Clinic`, `Supply Flats`, `Ammunition Pockets`, `Cabin Row`, `Broadcast Fence`까지 분리했고 모두 smoke/runtime과 3-run reference simulation 기준선을 확보했다. 이 결과를 바탕으로 후보 맵은 `0.2-poi-probe-integrated`까지 소폭 반복했다. 완성 체감을 매번 전체 맵으로 검증하지 않고, POI 미니맵과 주요 기능 프록시 시뮬레이션을 병행한다.
- 손전등, 배터리, 공포, 정전은 본편 체감의 핵심 후보지만 첫 단계부터 모든 봇에게 풀 시스템으로 적용하지 않는다. 처음에는 플레이어-facing 시스템과 봇의 추상 야간 인지만 검증한다.
- 수동 화면 확인 렉은 99 AI 포기 신호가 아니라 테스트 계층 혼선과 렌더링/AI 부하가 섞인 신호로 본다. `visual_review`는 화면 검토용, `xlarge_60`/`target_99_probe`는 구조 부하 검증용으로 분리하고, 픽업 광원 LOD부터 적용했다.
- AI LOD 1차는 봇 의사결정/전투/이동을 건너뛰지 않고 perception tick과 footstep/gunshot/close-range all-actor scan 주기만 낮춘다. 99 후보 1-run은 fallback 0과 regression sentinel clear를 유지했다.
- 봇 추상 야간 인지 1차는 완료했다. 첫 강한 보정은 99 smoke에서 sentinel은 clear였지만 stuck 96.0/run으로 scale gate를 실패했다. 보정값을 완화한 뒤 단발 1-run은 no first upgrade 변동으로 gate를 실패했지만, 이어서 돌린 `target_99_probe` 3-run은 avg duration 149.7s, first upgrade 23.0s, stuck 55.7/run, fallback 0.0/run, sentinel clear, AI avg 511.6us로 통과했다.
- N2-PACE-01은 gameplay tuning 없이 telemetry row를 추가했다. 첫 shot/contact/damage/kill, 첫 non-pistol upgrade, zone stage 도달을 수집하고, analyzer는 기존 doctrine CHASE context와 route/POI dwell도 함께 출력한다. 반복 stuck 실패는 threshold를 낮추지 않고 stuck state/route/cell 진단을 추가해 Black Ridge와 south/clinic 고정 장애물 clearance로 해결했다. 최종 `target_99_probe` 3-run은 avg duration 143.6s, first upgrade 27.3s, fallback 0.0/run, stuck 20.3/run, AI avg 661.2us, sentinel clear로 통과했다.
- N2-PACE-02는 `tools/summarize_pacing_baseline.py`로 10-15분 목표 대비 gap report를 추가했다. 최종 3-run 기준 avg duration 143.6s는 10분 바닥까지 4.18x, 12.5분 midpoint까지 5.22x 짧은 구조 smoke로 분류된다. 단, N2-PACE-04 이전 pacing milestone 값은 wall-clock 기준이었으므로 milestone phase 해석은 fresh run으로 갱신해야 한다.
- N2-PACE-03은 gameplay tuning 없이 10-15분 pacing 조정안 초안을 정리했다. `target_99_probe`는 구조 gate로 유지하고, 본편 체감은 별도 비기본 playable pacing 후보에서 자기장 schedule, loot/economy spacing, POI rotation, combat/AI 순서로 검증한다. 초안 watch band는 first contact 45-150s, first upgrade 120-300s, stage 2 240-420s, stage 3/late compression 540-720s, match end 600-900s다.
- N2-PACE-04는 `Telemetry._elapsed_seconds()`를 `core.duration`과 같은 game seconds 기준으로 정규화했다. `verify_pacing_telemetry.gd`에 time-scale 회귀 검사를 추가했고, fresh 1-run `C:\tmp\game_dev_pacing_time_scale_v1`은 duration 150.9s, first upgrade 25.1s, stage2 121.3s, fallback 0.0/run, stuck 25.0/run, sentinel clear, scale checker pass를 기록했다.
- N2-MISSION-01은 `CLEAN WIN`을 절대 HP 50이 아니라 현재 최대 체력의 50% 이상으로 바꿨다. Zone Battery처럼 `heal_mult=0`인 no-heal artifact와 Hell 시작 HP 1은 현재 체력만 깎지 않고 max HP도 1로 잠근다. `tools/verify_mission_health_rules.gd`가 clean-win ratio와 no-heal max-HP lock 경로를 검증한다.
- N2-PACE-05는 N2-PACE-04 이후 fresh `target_99_probe` 3-run 기준선을 확보했다. `C:\tmp\game_dev_pacing_game_time_v2_3run`은 avg duration 163.1s, first contact 1.4s, first upgrade 27.4s, stage2 130.2s, fallback 0.0/run, zone deaths 0, stuck 16.7/run, AI avg 628.9us, sentinel clear로 구조 gate를 통과했다. gap report는 10분 바닥까지 3.68x, 12.5분 midpoint까지 4.60x 부족한 compressed structural smoke로 판정했다.
- N2-PACE-06은 Night 후보에 비기본 `playable_pacing_v1`을 추가했다. `target_99_probe`는 구조 gate로 그대로 두고, 99 bots/spawn radius/safe spawn attempts는 유지했다. 최종 v1은 loot_count 210, hotspot 1.04, rare 1.15, stage wave 0.045/0.055 x6, initial 160s, stage2 170/70s다. 첫 낮은 economy 후보는 3-run에서 `no first upgrade`가 재현되어 폐기했고, verifier에 economy 하한을 넣어 같은 실패를 막았다. 최종 3-run `C:\tmp\game_dev_playable_pacing_v1_3run_v2`는 avg duration 294.0s, first contact 1.2s, first upgrade 36.6s, stage2 268.5s, fallback 0.0/run, stuck 16.7/run, AI avg 529.0us, sentinel clear로 `check_scale_telemetry.py --min-runs 3`을 통과했다. gap report는 10분 바닥까지 2.04x, 12.5분 midpoint까지 2.55x 부족하다고 판정했다.
- N2-PACE-07은 `summarize_pacing_baseline.py`에 opening pressure 출력을 추가했다. `playable_pacing_v1` 3-run은 spawn fallback 0.0/run, min nearest 3.5m, avg-min 3.7m, avg-nearest 7.4m, saturation 0.20, attempts 1.3/5 max다. 로컬 5m spacing smoke는 fallback 없이 min nearest를 5.0m로 올렸지만 first contact가 1.4s로 거의 안 움직이고 no first upgrade가 나와 폐기했다. 이 실험 변경은 커밋하지 않았다.
- N2-PACE-08은 pacing telemetry에 첫 target acquisition 시간/source/state/distance/band를 추가했다. 새 3-run `C:\tmp\game_dev_opening_acq_v1_3run`은 avg duration 347.9s, first acquisition 0.6s, first contact 1.0s, first upgrade 53.7s, stage2 262.0s, fallback 0.0/run, stuck 23.0/run, AI avg 474.0us, sentinel clear로 구조 gate를 통과했다. 첫 acquisition은 평균 5.2m 거리의 retreat_counteraction / ZONE_ESCAPE였고, acquisition-to-contact gap은 0.4s였다.
- N2-PACE-09는 `zone.initial_radius`가 런타임에 전달되지 않던 문제를 수정했다. `Main`/`MatchBootstrap`/`ZoneController`가 초기 존 반경을 적용하고, `playable_pacing_v1`은 78m spawn ring이 즉시 `ZONE_ESCAPE`에 들어가지 않도록 initial_radius 86m를 사용한다. 새 3-run `C:\tmp\game_dev_zone_initial_radius_v1_3run`은 avg duration 389.3s, first acquisition 1.7s, first contact 2.6s, first upgrade 32.6s, stage2 275.2s, fallback 0.0/run, zone deaths 0, stuck 41.0/run, AI avg 509.0us, sentinel clear로 통과했다. 첫 acquisition은 14.2m 거리의 objective_interrupt / CHASE로 바뀌었으므로 즉시 ZONE_ESCAPE 문제는 해소됐고, 남은 sub-5s contact는 opening objective/proximity pressure로 분류한다. `check_scale_telemetry.py`는 300초 이상 playable run에서 stuck/disengage를 spawned entity/minute로 판정하고, 짧은 구조 smoke는 기존 raw gate를 유지한다.
- N2-PACE-10은 첫 objective interrupt 진단을 pacing telemetry에 추가했다. 새 3-run `C:\tmp\game_dev_objective_interrupt_v1_3run`은 avg duration 441.0s, first acquisition 1.6s, first contact 2.4s, first upgrade 56.5s, stage2 278.0s, stage3 519.8s, fallback 0.0/run, zone deaths 0, stuck 46.3/run, AI avg 474.5us, sentinel clear로 통과했다. 첫 objective interrupt는 enemy 7.5m, objective 13.4m, source idle_loot, kind heal/armor, need combat_low_ammo였다. 남은 문제는 match start loot objective selection/interrupt 규칙이며, combat damage나 AI aggression이 아니다.
- N2-PACE-11은 idle_loot objective interrupt guard를 추가했다. idle_loot 목표는 2초 grace 동안 6m 초과 enemy interrupt를 미루고, 6m 이내 근접 enemy는 그대로 즉시 반응한다. ammo ratio가 combat loot threshold와 정확히 같은 경우는 `combat_low_ammo`가 아니라 `ammo_low`로 분류한다. 새 3-run `C:\tmp\game_dev_opening_loot_rules_v1_3run`은 avg duration 450.5s, first acquisition 1.5s, first contact 2.2s, first upgrade 36.6s, stage2 268.3s, stage3 509.5s, fallback 0.0/run, zone deaths 0, stuck 62.0/run, AI avg 468.7us, sentinel clear로 통과했다. 첫 objective interrupt는 enemy 4.8m, objective 8.4m, source idle_loot, kind heal/armor, need ammo_low 66.7% / combat_low_ammo 33.3%다. 7-8m 중거리 interrupt는 제거됐고, 남은 sub-5s contact는 근접 spawn/proximity pressure로 본다.
- N2-PACE-12는 immediate-value loot scoring을 보수적으로 보정했다. healthy heal은 같은 무기 ammo보다 낮은 우선순위가 되지만, wounded bot은 여전히 heal을 우선한다. immediate-value 검색에서는 pistol -> non-pistol upgrade 보너스를 끄고, first upgrade가 2.7s까지 당겨진 실패 후보를 폐기했다. 채택한 새 3-run `C:\tmp\game_dev_idle_loot_priority_v2_3run`은 avg duration 414.8s, first acquisition 1.5s, first contact 2.1s, first upgrade 54.5s, stage2 269.7s, stage3 510.4s, fallback 0.0/run, zone deaths 0, stuck 53.7/run, AI avg 441.1us, sentinel clear로 통과했다. 첫 objective interrupt는 enemy 4.5m, objective 21.8m, source idle_loot, kind armor/heal이다. 남은 문제는 loot target quality보다 근접 opening proximity pressure다.
- N2-PACE-13은 `playable_pacing_v1` opening spawn clearance를 5.0m로 올리고 safe spawn attempts를 260으로 높였다. idle_loot close interrupt cutoff는 6m에서 5m로 낮췄고, verifier가 5.5m defer와 4.0m 즉시 interrupt를 함께 검증한다. 5m spawn-only 후보는 first objective interrupt enemy 5.6m로 남아 폐기했고, 채택한 새 3-run `C:\tmp\game_dev_opening_proximity_guard_v1_3run`은 avg duration 360.7s, first acquisition 1.8s, first contact 2.6s, first upgrade 29.4s, stage2 269.9s, spawn fallback 0.0/run, min nearest 5.0m, saturation 0.42, AI avg 466.3us, sentinel clear로 통과했다. 첫 acquisition은 objective_interrupt 66.7% / idle_reaction 33.3%라서 다음 문제는 opening idle reaction/awareness grace로 분류한다.
- N2-PACE-14는 spawn-age 기반 opening IDLE reaction grace를 추가했다. IDLE 봇은 spawn 후 3초 동안 2m bump 범위 밖의 visible enemy acquisition을 미루지만, 2m bump, 피격, 총성, recovery melee, objective interrupt 경로는 유지한다. 새 3-run `C:\tmp\game_dev_opening_idle_reaction_grace_v1_3run`은 avg duration 328.2s, first acquisition 2.6s, first contact 3.4s, first upgrade 38.3s, stage2 280.5s, spawn fallback 0.0/run, min nearest 5.0m, saturation 0.42, zone deaths 0, AI avg 531.6us, sentinel clear로 통과했다. 첫 acquisition은 objective_interrupt 100%가 되어 idle_reaction 경로는 분리됐고, 남은 문제는 4-5m close objective interrupt다.
- N2-PACE-15는 opening idle-loot safety guard를 추가했다. spawn 후 3초 동안 5m 안에 actor가 있으면 먼 idle-loot objective 시작을 미루고, idle-loot objective interrupt도 2m bump 밖에서는 미룬다. v1은 first objective interrupt가 2.1s/enemy 4.8m로 남아 폐기했다. 채택한 v2 `C:\tmp\game_dev_opening_loot_safety_v2_3run`은 avg duration 393.8s, first acquisition 5.9s, first contact 6.5s, first upgrade 20.2s, stage2 280.9s, stage3 520.6s, spawn fallback 0.0/run, min nearest 5.0m, saturation 0.42, AI avg 514.7us, sentinel clear로 통과했다. 첫 objective interrupt는 9.8s/enemy 8.3m까지 밀렸고, 남은 첫 acquisition은 1.1m bump-range idle_reaction이다.
- N2-PACE-16은 opening close-range reveal guard를 추가했다. 5.7m spawn-spacing 후보는 fallback 0이었지만 stuck/entity/min 0.16으로 scale gate를 실패해서 폐기했다. 채택한 `C:\tmp\game_dev_opening_bump_reveal_guard_v1_3run`은 spawn 후 7초 동안 IDLE 1-2m near-bump forced reveal을 미루고 1m hard bump는 유지한다. avg duration 458.8s, first acquisition 5.4s, first contact 6.0s, first upgrade 19.0s, stage2 270.6s, stage3 511.7s, spawn fallback 0.0/run, min nearest 5.1m, saturation 0.42, stuck 0.06/entity/min, AI avg 462.5us, sentinel clear로 long-run scale gate를 통과했다. 첫 acquisition은 objective_interrupt 100% / enemy 2.9m라서 다음 문제는 post-window close objective interrupt다.
- N2-PACE-17은 idle-loot objective interrupt safety를 start safety와 분리했다. 먼 idle-loot objective 시작 safety는 3초로 유지하고, idle-loot objective interrupt만 7초 / 1m hard bump 기준으로 미룬다. 채택한 `C:\tmp\game_dev_opening_objective_interrupt_window_v1_3run`은 avg duration 345.6s, first acquisition 8.6s, first contact 9.2s, first upgrade 54.9s, stage2 268.4s, spawn fallback 0.0/run, min nearest 5.0m, saturation 0.42, stuck 0.09/entity/min, AI avg 420.0us, sentinel clear로 long-run scale gate를 통과했다. 첫 objective interrupt는 28.6s/enemy 8.5m까지 밀렸고, 남은 첫 acquisition은 5.4m idle_reaction이다.
- N2-PACE-18은 2m 밖 visible enemy에 대한 IDLE opening reaction window를 10초로 늘렸다. 1m hard bump, 1-2m near-bump 7초 guard, idle-loot objective interrupt 7초/1m guard는 유지한다. 채택한 `C:\tmp\game_dev_opening_idle_reaction_window_v1_3run`은 avg duration 577.1s, first acquisition 13.9s, first contact 14.3s, first upgrade 38.1s, stage2 281.3s, stage3 524.3s, spawn fallback 0.0/run, min nearest 5.0m, saturation 0.42, stuck 0.07/entity/min, AI avg 462.3us, sentinel clear로 long-run scale gate를 통과했다. 첫 acquisition source는 objective_interrupt / idle_reaction / retreat_counteraction으로 갈라졌으므로 다음 문제는 mixed opening acquisition context다.
- N2-PACE-19는 gameplay 변경 없이 mixed opening acquisition report를 추가했다. `analyze_results.py`와 `summarize_pacing_baseline.py`가 run별 first acquisition sample을 출력한다. N2-PACE-18 기준 run 1은 11.3s objective_interrupt/CHASE/0.9m, run 2는 18.6s idle_reaction/IDLE/1.4m, run 3은 11.8s retreat_counteraction/ZONE_ESCAPE/9.9m이다. 다음은 combat/AI/zone 수치 튜닝이 아니라 retreat_counteraction / ZONE_ESCAPE와 post-window objective/idle 경로가 같은 opening pressure인지 분리 확인한다.
- N2-PACE-20은 gameplay 변경 없이 first acquisition self/zone context를 telemetry에 추가했다. `C:\tmp\game_dev_first_acq_context_v2_3run`은 avg duration 341.9s, first acquisition/contact/damage 16.4s, first kill 24.9s, first upgrade 21.2s, stage2 294.4s, spawn fallback 0.0/run, stuck 0.08/entity/min, disengage 0.26/entity/min, AI avg 546.5us, sentinel clear로 scale gate를 통과했다. 첫 acquisition은 3/3 모두 retreat_counteraction/ZONE_ESCAPE였고, self zone ratio는 모두 0.95 edge, spawn age는 3.4s/6.8s/6.0s였다. 다음 문제는 opening edge ZONE_ESCAPE entry/exit와 retreat-counteraction gating이다.
- N2-PACE-21은 spawn 후 10초 안에 아직 zone 안쪽 edge에 있는 `ZONE_ESCAPE` 봇의 retreat-counteraction target acquisition만 미루는 guard를 추가했다. 1m hard bump, 실제 zone 밖 counteraction, zone escape movement는 유지한다. 채택한 `C:\tmp\game_dev_opening_zone_edge_guard_v1_3run`은 avg duration 342.1s, first acquisition 12.9s, first contact/damage 17.3s, first kill 23.9s, first upgrade 18.7s, stage2 275.9s, spawn fallback 0.0/run, stuck 0.08/entity/min, disengage 0.26/entity/min, AI avg 474.6us, sentinel clear로 scale gate를 통과했다. 첫 acquisition에서 retreat_counteraction/ZONE_ESCAPE는 0%가 됐고, 남은 빠른 acquisition은 1.0m hard-bump objective_interrupt 예외다.
- N2-PACE-22는 gameplay 변경 없이 hard-bump acquisition impact report를 추가했다. `analyze_results.py`와 `summarize_pacing_baseline.py`가 run별 acquisition-to-contact gap과 hard_bump marker를 출력하고, hard-bump first acquisition count / avg contact gap / 5s+ delayed count를 요약한다. N2-PACE-21 기준 hard-bump first acquisition은 3/3, avg contact gap은 4.4s, delayed 5s+는 1/3이다. 따라서 first acquisition만으로 즉시 교전 압력이라고 해석하지 않고, 1m hard-bump 예외를 유지할지 별도 design으로 다룰지 분리 판단한다.
- N2-PACE-23은 gameplay 변경 없이 hard-bump exception read policy를 고정했다. 1.0m hard-bump는 intentional collision/readability rule로 유지하고, `analyze_results.py`와 `summarize_pacing_baseline.py` hard-bump impact summary가 `read=contact_gap_not_acquisition_only` / `read=contact-gap-not-acquisition-only`를 출력한다. 다음 pacing 작업은 opening 예외가 아니라 `playable_pacing_v1`의 10-15분 duration, stage progression, first-upgrade gap으로 돌아간다.
- N2-PACE-24는 gameplay 변경 없이 `summarize_pacing_baseline.py`에 `Phase gap read`를 추가했다. `playable_pacing_v1` 3-run 기준 first contact 1.2s, first kill 15.0s, first upgrade 36.6s는 watch band보다 빠르고, stage2 268.5s는 240-420s band 안이며, stage3는 없고 match end 294.0s는 600s floor보다 306.0s 빠르다. 따라서 다음 gameplay 후보는 stage2를 다시 움직이기보다 late-zone compression과 first-upgrade 지연을 분리해서 설계한다.
- N2-PACE-25는 비기본 `playable_pacing_v2`를 추가했다. v2는 v1의 match/spawn/loot/opening/base zone을 유지하고 stage2 이후 wait/shrink를 늘리고 damage를 낮춘 late-zone 후보다. 3-run `C:\tmp\game_dev_playable_pacing_v2_late_zone_v1_3run`은 avg duration 533.3s, stage2 268.1s, stage3 638.4s, first upgrade 19.4s, fallback 0.0/run, stuck 0.09/entity/min, AI avg 418.9us, sentinel clear로 scale gate를 통과했다. stage2/stage3는 band 안이고 match end는 600s floor보다 66.7s 짧다.
- 10-15분 목표는 현재 짧은 scale smoke의 수치와 별도 축이다. 자기장, 루팅, 첫 교전, 중반 이동, 최종 교전 페이싱은 야간 맵 후보 이후 다시 잡는다.

## 활성 문서

| 문서 | 용도 |
|---|---|
| [../CLAUDE.md](../CLAUDE.md) | 세션 온보딩과 기본 작업 규칙 |
| [HANDOFF.md](HANDOFF.md) | 다음 세션용 짧은 상태와 로컬 git 주의점 |
| [DOCS_INDEX.md](DOCS_INDEX.md) | 문서 라우팅과 활성 문서 예산 |
| [DEVLOG.md](DEVLOG.md) | 최근 검증 작업의 압축 로그 |
| [IMPACT_MAP.md](IMPACT_MAP.md) | 소유권과 변경 영향 확인 |
| [ARCHITECTURE.md](ARCHITECTURE.md) | 구조 변경 시 모듈 경계 확인 |
| [TESTING.md](TESTING.md) | 검증 명령과 해석 기준 |
| [ASSET_STATUS.md](ASSET_STATUS.md) | 현재 통합/보류 에셋 상태 |
| [MAP_TILE_GROUPS.md](MAP_TILE_GROUPS.md) | 99인 맵 배치 그룹과 후보 맵 브리프 |
| [NIGHT_BR_PACING_PLAN.md](NIGHT_BR_PACING_PLAN.md) | 10-15분 야간 배틀로얄 페이싱과 테스트 계층 |

## 운영 원칙

- `Main.gd`는 경기 전역 상태, scene wiring, lifecycle orchestration, Telemetry hook의 소유자로 유지한다.
- 정적 데이터, 수치, 표시 문자열, 평가 조건은 catalog, tuning, formatter, evaluator, controller, director, store 경계로 나눈다.
- UI에 표시되는 수치와 실제 로직 수치는 가능하면 같은 data/tuning에서 가져온다.
- 99인 기본 승격, 새 기본 맵, 봇 artifact, artifact upgrade tree, 화재/정전/공포 시스템은 명시된 migration plan 없이 시작하지 않는다.
- 활성 문서는 짧게 유지한다. 긴 원문은 `docs/archive/` 또는 `docs/devlog/` snapshot에 남긴다.
- `plan_report/`는 외부 기획 참고 자료다. 그 안의 이미지/리포트는 분석에 쓰되 사용자가 요청하기 전까지 커밋하지 않는다.

## 경계 규칙

| 역할 | 소유해야 하는 것 | 소유하면 안 되는 것 |
|---|---|---|
| `Main.gd` | 경기 전역 상태, scene wiring, 생명주기 orchestration, Telemetry hook | 정적 catalog, 재사용 tuning 기본값, 표시 테이블 |
| `*Tuning.gd` | 수치 threshold, fallback 값, 해당 수치의 label helper | runtime counter, scene lookup, mutation |
| `*Catalog.gd` / `*Data.gd` | 정적 id, descriptor, resource/data lookup | runtime progress, 평가 side effect |
| `*Formatter.gd` / `*Builder.gd` / `*Resolver.gd` | 텍스트, 표시 spec, node/icon 구성 | gameplay decision, 숨겨진 중복 threshold |
| `*Evaluator.gd` | 명시 context와 descriptor data를 받는 pure check | counter, timer, file I/O, reward/penalty execution |
| `*Controller.gd` / `*Director.gd` / `*Planner.gd` | 한 domain 안의 제한된 runtime process 또는 placement | 경기 전역 소유권 |
| `*Store.gd` | 한 관심사의 파일 persistence와 schema compatibility | gameplay timing, UI formatting, evaluation rule |

## 버전 스레드

### v1.10-v1.11 구조 정리

상태: 구조적으로 종료.

- `Main.gd`에서 item/resource pool, runtime match tuning, UI builder, bootstrap helper, pressure effect execution, bot spawn planning, loot/supply creation, world/menu presentation 기본값을 1차 분리했다.
- Mission, Hell, Zone, Loot/Supply, Player, Bot, Entity/Pickup은 현재 역할 경계가 유지 가능한 수준이다.
- `Main.gd`에 남기는 것: scene callback, exported default, current match state, zone, mission tracker, player reference, alive count, game-over flow, pressure trigger/effect flow, Telemetry hook call.
- v1.11 이후 helper extraction은 줄 수 기준이 아니라 실제 ownership 충돌이 있을 때만 재개한다.

### v1.12 artifact/asset 기반

상태: 1차 완료.

- 시작 artifact: Red Trigger, Armor Sponge, Silent Core, Zone Battery, Escape Capsule, Ghost Grass.
- Artifact runtime state는 `PlayerArtifactRuntime.gd`, 시각 효과는 `PlayerArtifactVisuals.gd`, 아이콘 해석은 `ArtifactIconResolver.gd` 쪽으로 분리되어 있다.
- 6종 artifact icon PNG는 runtime catalog에 통합되어 있다.
- Bush GLB는 visual-only replacement다. `Bush.tscn` Area3D가 gameplay authority다.
- 생성된 tree/rock/log/landmark GLB는 보류다. 충돌/cover 권한을 명확히 유지할 수 있을 때만 선택 통합한다.

### v2.0 MapDefinition/scale 백본

상태: 구조 안전성 백본은 쓸 수 있는 상태. 최종 99인 밸런스는 아님.

- `MapDefinition.gd`가 legacy `mapSpec` JSON을 감싸고 map id/name, POI, obstacle, route, scale preset, spawn/loot/zone profile을 검증한다.
- Full Map overlay는 read-only foundation으로 추가됐다.
- Scale path는 baseline -> medium_24 -> large_40 -> xlarge_60 -> candidate-only `target_99_probe` 순서로 열렸다.
- `target_99` envelope는 preferred 180m world / 78m spawn radius / 3.5m clearance / fallback 0을 기준으로 한다.
- `data/mapSpec_large_candidate.json`는 180m 후보 맵과 route/POI telemetry를 검증하기 위한 비기본 후보로 남긴다.
- `data/mapSpec_night_forest_candidate.json`는 야간 인공 숲 방향의 첫 비기본 구조 후보로 남긴다.
- v2.0.30 이후 primary choke와 transit choke 압력은 telemetry상 읽히기 시작했다. 다만 v2.0.40 기준 60 -> 99에서 `ATTACK+CHASE`와 `CHASE combat` 비중이 여전히 얇다.
- 이제 이 얇은 combat coverage를 최종 목표로 직접 맞추지 않는다. 야간 시야/손전등/맵 구조가 들어오면 수치가 크게 흔들릴 수 있으므로 현재 계층은 구조 안전성 확인에 사용한다.

## 야간 인공 숲 방향

목표: 99인 본편의 첫 후보 맵을 10-15분 야간 배틀로얄로 만든다.

| POI | 1차 역할 | 검증 포인트 |
|---|---|---|
| Supply Flats | `loot_hub` | 열린 보급지. 초반 무기 접근성은 높지만 노출 비용이 커야 한다 |
| Ammunition Pockets | loot support / edge flow | 탄약 경로를 만들되 안전 루프가 되면 안 된다 |
| Cabin Row | `concealment_field` / close quarters | 은폐와 근접전 체감. 과도한 시야 차단과 stuck 위험 확인 |
| False Clinic | `recovery_pocket` | 회복/스토리 루프. 회복 후 재진입 압력이 있어야 한다 |
| Wire Maze | `transit_choke` | 고위험 구조물. 첫 구현은 경량 장애물로 stuck을 줄인다 |
| Broadcast Fence | `transit_choke` / objective compound | 감시/방송 테마와 중반 이동 압력 |
| Black Ridge | `power_position_overlook` | 강한 위치지만 fortress가 되면 안 된다 |
| Sluice Crossing | `primary_choke` | 대각선 강의 핵심 횡단로. 우회로와 시간 비용이 필요하다 |

중앙 구조는 "모두가 모이는 십자 허브"보다 "강 때문에 어쩔 수 없이 선택해야 하는 횡단/우회"에 가깝게 잡는다.

## 다음 작업 순서

1. **문서 정리**
   - `MASTERPLAN`을 한국어 중심 압축본으로 유지한다.
   - [NIGHT_BR_PACING_PLAN.md](NIGHT_BR_PACING_PLAN.md)에 10-15분 pacing, 야간 시스템 단계, 테스트 계층을 기록한다.
   - [MAP_TILE_GROUPS.md](MAP_TILE_GROUPS.md)에 야간 인공 숲 후보와 8개 POI mapping을 반영한다.
2. **99인 후보 mapSpec 초안**
   - 상태: `data/mapSpec_night_forest_candidate.json` 생성 및 0.2 구조 반복 완료.
   - `Sluice Crossing`, `Black Ridge`, `False Clinic`, `Wire Maze`를 우선 축으로 삼은 180m 후보다.
   - `tools/verify_night_forest_candidate.gd`, `xlarge_60` runtime load, `target_99_probe` runtime load는 통과했다.
3. **POI 미니맵/기능 프록시**
   - 상태: 핵심 8개 POI 프로브 생성, smoke/runtime, 3-run reference simulation 통과.
   - 전체 99인 맵만 반복 실행하지 않는다.
   - 후보 맵 1-run 구조 기준선: duration 165.4s, fallback 0.0/run, sentinel clear, primary_choke damage 48.9%, stuck 101.0/run, zone deaths 4.0/run.
4. **야간 시야 1차 prototype**
   - 상태: 플레이어 전용 `VisionSpot`/`ProximityLight` night profile smoke 완료.
   - 봇은 처음부터 배터리/공포/손전등 inventory를 갖지 않는다. 추상 night awareness와 player reveal 반응부터 시작한다.
   - 수동 화면 확인은 `scale_preset=visual_review`로 한다. 8봇/45픽업/느린 자기장 프리셋이며, 더 가볍게 보려면 `bot_count=0 loot_count=24`를 추가한다.
   - 픽업 광원은 거리 기반 LOD로 가까운 아이템만 full light, 중거리 아이템은 dim light, 먼 아이템은 light off로 처리한다.
   - 다음 확인: 수동 화면에서 손전등 프레이밍, 아이템 판독성, 부쉬 판독성, 교전 판독성을 확인한다.
5. **봇 AI LOD/야간 인지 설계**
   - 99 AI 목표는 유지하지만 수동 화면 검토용 프리셋에서 full 99 AI를 돌리지 않는다.
   - AI perception/sensory LOD 1차는 완료했다. 전투/이동/피격/존 탈출은 매 frame 유지하고, perception/sound/proximity scan만 tick rate로 제한했다.
   - 봇 야간 작업은 cone-vs-cone 손전등 시뮬레이션이 아니라 거리/확신도 기반 추상 인지로 제한한다.
   - 상태: 1차 완료. 완화된 상수로 `target_99_probe` 3-run과 `check_scale_telemetry.py --min-runs 3`을 통과했다. 단발 1-run의 no first upgrade 실패는 변동성 기록으로 남긴다.
6. **10-15분 pacing gate**
   - 상태: telemetry 1차 완료. 첫 교전 시간, 첫 non-pistol upgrade, zone stage timing을 우선 수집하고 route/POI dwell은 기존 doctrine telemetry를 재사용한다.
   - 현재 100-170초 scale smoke 수치는 구조 확인용으로만 해석한다.

## 장기 작업 단위

사용자가 장기간 확인하기 어려운 동안에는 아래 단위 순서를 따른다. 검증 가능한 slice마다 계획 확인, 작업, 검증, 커밋/푸쉬 루틴을 반복한다. 같은 문제가 뒤 과정까지 계속 영향을 주는지 먼저 확인하고, 3회 이상 같은 차단 조건이 반복되어 더 진행할 수 없을 때만 작업 연쇄를 멈춘다. 기본 맵/기본 99인 승격 같은 큰 결정은 여전히 보류한다.

| ID | 단위 | 산출물 | 검증 | 중단/전환 기준 |
|---|---|---|---|---|
| N2-POI-01 | Sluice Crossing 구조 프로브 | `data/mapSpec_poi_sluice_crossing_probe.json`, 전용 verifier | JSON parse, `verify_poi_sluice_crossing_probe.gd`, runtime load | smoke 실패 원인이 route/POI 구조면 즉시 수정. 시뮬레이션 밸런스 튜닝은 다음 단위로 분리 |
| N2-POI-02 | Sluice Crossing 짧은 시뮬레이션 | 1-3 run 결과와 문서 기록 | `simulate_matches.py` + `analyze_results.py`; 기존 scale gate는 참고용만 | stuck/fallback/nav 문제가 나오면 맵 구조 수정. duration/upgrade threshold 튜닝은 금지 |
| N2-POI-03 | Wire Maze 구조 프로브 | 소형 Wire Maze `mapSpec`, verifier | JSON parse, Godot verifier, runtime load | 장애물/시야가 복잡해지면 fence 밀도 축소. full maze 구현 금지 |
| N2-POI-04 | Wire Maze 짧은 시뮬레이션 | 1-3 run 결과와 문서 기록 | `simulate_matches.py` + `analyze_results.py`; 기존 scale gate는 참고용만 | stuck/fallback/nav 문제가 나오면 maze 밀도 축소. combat 비율 튜닝은 금지 |
| N2-POI-05 | Black Ridge 구조 프로브 | 파워 포지션 소형 `mapSpec`, verifier | key position classification, runtime load | ridge가 fortress가 되면 hard cover 축소. climb/interior 구현 금지 |
| N2-POI-06 | False Clinic 회복 재진입 프로브 | recovery pocket + re-entry `mapSpec`, verifier | recovery_exit classification, runtime load | 안전 루프가 되면 회복/loot 밀도 축소 |
| N2-POI-07 | Supply Flats 초반 루팅 프로브 | open loot hub + exposed route `mapSpec`, verifier | loot_hub classification, runtime load | 열린 보급지가 safe armory가 되면 hard cover/rare bias 축소 |
| N2-POI-08 | Ammunition Pockets 탄약 경로 프로브 | low-rare ammo breadcrumb `mapSpec`, verifier | loot_hub limit, runtime load | 안전 탄약 루프가 되면 density/cover 축소 |
| N2-POI-09 | Cabin Row 은폐/근접전 프로브 | concealment field + readable lane `mapSpec`, verifier | concealment classification, runtime load | interior/climb 구현 금지. 시야가 과밀하면 wall/bush 축소 |
| N2-POI-10 | Broadcast Fence 통과/목표지 프로브 | fence gate + flanks `mapSpec`, verifier | transit_choke classification, runtime load | searchlight/전력 시스템 구현 금지. 구조만 검증 |
| N2-SIM-01 | Black/False/Supply/Ammo/Cabin/Broadcast 짧은 시뮬레이션 | 6개 POI 3-run reference 결과와 문서 기록 | `simulate_matches.py`, JSON summary | duration/first upgrade 튜닝 금지. fallback, zone death, stuck, zero sentinel만 hard signal로 본다 |
| N2-MAP-01 | 야간 후보 맵 구조 반복 | `mapSpec_night_forest_candidate.json` 소폭 수정 | `verify_night_forest_candidate.gd`, runtime load, 99인 1-run reference | POI 프로브 결과 없이 전체 맵 수치 튜닝 금지 |
| N2-VIS-01 | 플레이어-facing 손전등 1차 | 플레이어 조명/readability prototype | Godot headless, 필요 시 수동 screenshot | 모든 봇 full flashlight/fear/battery 금지 |
| N2-PERF-01 | 픽업 광원 LOD 1차 | 거리 기반 pickup light full/dim/off | `verify_pickup_light_lod.gd`, `visual_review` runtime load | 봇 AI update cadence와 같은 단위에서 처리 금지 |
| N2-AI-LOD-01 | AI perception/sensory LOD 1차 | 상태별 perception tick, 보조 감지 loop throttle | `verify_ai_lod_perception.gd`, 60/99 1-run smoke | combat/movement/state handler skip 금지 |
| N2-AI-01 | 봇 추상 야간 인지 | 거리/확신도 보정만 있는 작은 AI patch | 1-3 run smoke, AI cost 확인 | cone-vs-cone 고비용 시뮬레이션으로 확장 금지 |
| N2-PACE-01 | 10-15분 pacing telemetry | match duration, first contact, crossing usage 등 row | smoke + analyzer 출력 확인 | 기존 100-170초 smoke 기준을 최종 목표로 오해하지 않기 |
| N2-PACE-02 | pacing baseline report | 10-15분 목표 대비 구조 smoke gap report | `summarize_pacing_baseline.py`, py_compile | 리포트만으로 gameplay tuning 적용 금지 |
| N2-PACE-03 | 10-15분 pacing 조정안 초안 | watch band, tuning 순서, 검증 루프 | `git diff --check` | 초안만으로 gameplay tuning 적용 금지 |
| N2-PACE-04 | pacing game-time 정규화 | milestone seconds를 `core.duration`과 같은 축으로 기록 | `verify_pacing_telemetry.gd`, 1-run reference, scale checker | pre-fix milestone phase를 tuning 기준으로 사용 금지 |
| N2-MISSION-01 | mission health rule fix | clean win ratio, no-heal max HP lock | `verify_mission_health_rules.gd`, artifact/player verifier | no-heal 상태에서 current HP만 깎고 max HP 유지 금지 |
| N2-PACE-05 | fresh game-time 3-run baseline | post-fix `target_99_probe` 3-run 결과와 gap report | simulate/analyze/summarize/check 3-run | 구조 smoke를 playable pacing으로 오해하지 않기 |
| N2-PACE-06 | playable pacing preset v1 | Night 후보 비기본 `playable_pacing_v1`, zone/economy spacing, verifier | JSON parse, playable/night verifier, runtime load, candidate 3-run analyze/summarize/check | `target_99_probe`/default 승격 금지. no-first-upgrade 경제 starvation 반복 금지 |
| N2-PACE-07 | opening pressure report | spawn fallback/min-nearest/saturation/attempts를 gap report에 출력 | py_compile, summarize playable 3-run | first contact 문제를 zone/economy만으로 오해하지 않기 |
| N2-PACE-08 | opening acquisition telemetry | 첫 target acquisition time/source/state/distance/band를 pacing에 기록 | pacing verifier, py_compile, playable 3-run analyze/summarize/check | first contact 전 acquisition 원인 없이 combat/AI 수치 조정 금지 |
| N2-PACE-09 | opening zone radius tuning | `zone.initial_radius` runtime 적용, playable opening radius guard, long-run normalized scale gate | zone radius verifier, playable/night verifier, runtime load, playable 3-run analyze/summarize/check | spawn ring을 즉시 ZONE_ESCAPE로 두지 않기. 긴 playable run에서 raw disengage count로 오판하지 않기 |
| N2-PACE-10 | opening objective interrupt telemetry | 첫 objective interrupt source/kind/need/match, enemy/objective distance를 pacing에 기록 | pacing verifier, py_compile, backward-compatible analyzer/summarizer, playable 3-run analyze/summarize/check | objective_interrupt 원인 없이 loot/AI/combat 수치 조정 금지 |
| N2-PACE-11 | opening loot rule guard | idle_loot 2초/6m interrupt grace, exact threshold ammo_low 분류 | bot opening loot verifier, pacing/AI LOD smoke, playable 3-run analyze/summarize/check | 중거리 objective interrupt와 근접 proximity pressure를 섞어 해석하지 않기 |
| N2-PACE-12 | opening loot target quality guard | healthy heal보다 same-weapon ammo 우선, immediate upgrade rush 억제 | bot opening loot verifier, rejected/accepted playable 3-run analyze/summarize/check | target quality 보정으로 first upgrade gate를 깨지 않기 |
| N2-PACE-13 | opening proximity guard | playable 5m spawn clearance, 5m idle-loot close interrupt cutoff | playable/zone/bot opening verifiers, spawn-only rejection, accepted playable 3-run analyze/summarize/check | spawn spacing과 close idle reaction을 분리해서 해석하기 |
| N2-PACE-14 | opening idle reaction grace | spawn 후 3초/2m IDLE acquisition defer | bot opening verifier, accepted playable 3-run analyze/summarize/check | idle_reaction 제거 후 남은 close objective interrupt를 별도로 해석하기 |
| N2-PACE-15 | opening loot safety guard | spawn 후 3초 동안 near actor 주변 먼 idle-loot start/interrupt defer | bot opening verifier, rejected v1, accepted playable v2 3-run analyze/summarize/check | objective interrupt 해결 뒤 남은 bump-range proximity를 별도로 해석하기 |
| N2-PACE-16 | opening bump reveal guard | spawn 후 7초 동안 IDLE 1-2m near-bump forced reveal defer, 1m hard bump 유지 | bot/playable/zone/pacing/AI verifiers, rejected spacing, accepted playable 3-run analyze/summarize/check | spawn envelope 확대로 해결하지 않고 post-window close objective interrupt를 별도로 해석하기 |
| N2-PACE-17 | opening objective interrupt window | idle-loot start safety 3초 유지, interrupt safety 7초/1m hard bump로 분리 | bot/playable/zone/pacing/AI verifiers, accepted playable 3-run analyze/summarize/check | close objective interrupt 해결 뒤 남은 post-window idle_reaction을 별도로 해석하기 |
| N2-PACE-18 | opening idle reaction visual window | 2m 밖 IDLE visible enemy reaction window 10초, hard/near-bump/objective guard 유지 | bot/playable/zone/pacing/AI verifiers, accepted playable 3-run analyze/summarize/check | 단일 idle_reaction이 아니라 mixed opening acquisition으로 다음 원인을 분리하기 |
| N2-PACE-19 | mixed opening acquisition report | run별 first acquisition sample 출력 | py_compile, old playable 3-run analyze/summarize | mixed source를 단일 combat/AI 문제로 오해하지 않기 |
| N2-PACE-20 | first acquisition self/zone context | self band, zone ratio/status, spawn age 출력 | pacing verifier, py_compile, playable 3-run analyze/summarize/check | ZONE_ESCAPE edge context 없이 retreat counteraction만 튜닝하지 않기 |
| N2-PACE-21 | opening zone-edge counteraction guard | opening edge ZONE_ESCAPE retreat-counteraction acquisition defer, hard bump 유지 | bot opening verifier, playable 3-run analyze/summarize/check | 실제 zone 밖 counteraction과 1m hard bump 예외를 막지 않기 |
| N2-PACE-22 | hard-bump acquisition impact report | hard_bump marker, acquisition-to-contact gap, aggregate impact 출력 | py_compile, existing 3-run analyze/summarize | first acquisition만으로 즉시 교전 압력이라고 판정하지 않기 |
| N2-PACE-23 | hard-bump exception read policy | hard-bump impact summary에 contact-gap read policy 명시 | py_compile, existing 3-run analyze/summarize, diff check | opening exception churn으로 10-15분 pacing 작업을 계속 미루지 않기 |
| N2-PACE-24 | playable pacing phase gap report | watch band 대비 contact/kill/upgrade/stage/end gap 출력 | py_compile, playable/opening 3-run summarize | stage2가 band 안인데도 stage2만 다시 움직이지 않기 |
| N2-PACE-25 | playable_pacing_v2 late-zone candidate | stage2 entry 유지, stage2 이후 compression 확장 | playable/night/zone verifiers, runtime load, v2 3-run analyze/summarize/check | late-zone 개선 뒤 남은 first-upgrade/economy 문제를 zone으로 덮지 않기 |

자율 진행 규칙:

- 현재 사용자 지시가 유지되는 동안 검증된 slice는 커밋/푸쉬까지 진행한다.
- 기본 맵, 기본 scale preset, release 관련 작업은 명시 요청 전까지 보류한다.
- 새 단위마다 `DEVLOG`와 `HANDOFF`를 짧게 갱신한다.
- `plan_report/`, `asset_generator/`, `docs/ASSET_GENERATION_PROMPTS.md`, 기존 `.gitignore` 로컬 변경은 건드리지 않는다.
- 시뮬레이션 결과가 애매하면 "수치 튜닝"보다 "다음 POI 구조 프로브"를 우선한다.
- `target_99_probe` 단발 run은 reference smoke로만 본다. 완료 판정은 최소 3-run과 `check_scale_telemetry.py --min-runs 3` 통과를 기준으로 한다.
- 단발 no first upgrade는 즉시 튜닝하지 않고 3-run으로 재확인한다. stuck, spawn fallback, zero damage/shot/plan sentinel, AI budget 초과는 구조 회귀로 보고 바로 수정한다.

현재 단위 상태:

- N2-POI-01 완료: Sluice Crossing 프로브 smoke와 runtime load 통과.
- N2-POI-02 완료: 3-run smoke에서 avg duration 69.1s, fallback 0.0/run, zone deaths 0, regression sentinel 없음. 기존 scale gate는 avg duration 69.1s < 70.0s, first upgrade 8.2s < 10.0s로 참고용 FAIL이지만 POI 프로브 hard gate로 보지 않는다.
- N2-POI-03 완료: Wire Maze 프로브 smoke와 runtime load 통과. 장애물은 sparse wall 4개와 low fence/log 위주로 유지했다.
- N2-POI-04 완료: 3-run reference simulation에서 avg duration 66.6s, fallback 0.0/run, zone deaths 0, zero damage/shot/combat-plan sentinel 없음. 전투 피해는 primary_choke 46.0%, flank 27.1%, recovery_exit 17.0%로 경로 압력이 읽힌다. stuck은 8.7/run으로 관찰 대상이지만 이번 단위에서는 maze 밀도 축소가 필요한 hard fail은 아니다. 기존 scale gate는 avg duration 66.6s, 60초 미만 1회, first upgrade 6.9s 때문에 참고용 FAIL이며 POI 프로브 hard gate로 보지 않는다.
- N2-POI-05 완료: Black Ridge 프로브 smoke와 runtime load 통과. 직접 능선 루트는 `primary_choke`, 북쪽 우회와 남쪽 저지대 우회는 `flank`, Field Aid Hollow 재진입은 `recovery_exit`로 분류된다. hard cover는 high ridge wall 3개와 large rock cluster 3개로 제한했다.
- N2-POI-06 완료: False Clinic 프로브 smoke와 runtime load 통과. False Clinic은 낮은 loot/rare의 `recovery_pocket`으로 유지하고, `clinic_reentry`가 `Clinic Doorway`의 `primary_choke` 압력으로 돌아가도록 고정했다. facade wall은 3개, soft cover는 6개로 제한했다.
- N2-POI-07 완료: Supply Flats 프로브 smoke와 runtime load 통과. 열린 `loot_hub` 중심에 sparse cover만 두고, `supply_exposed_lane`과 side flank/reentry를 분리했다.
- N2-POI-08 완료: Ammunition Pockets 프로브 smoke와 runtime load 통과. 낮은 rare와 작은 breadcrumb 구조로 안전 탄약 루프가 되지 않도록 제한했다.
- N2-POI-09 완료: Cabin Row 프로브 smoke와 runtime load 통과. cabin interior는 만들지 않고 facade wall, bush, readable lane만 검증했다.
- N2-POI-10 완료: Broadcast Fence 프로브 smoke와 runtime load 통과. fence/log gate와 flanks, Fuse Shelter reentry만 검증하고 searchlight/전력 시스템은 보류했다.
- N2-SIM-01 완료: Black Ridge, False Clinic, Supply Flats, Ammunition Pockets, Cabin Row, Broadcast Fence 3-run reference simulation 완료. 6개 모두 fallback 0.0/run, zero damage/shot/combat-plan sentinel 0. Cabin Row와 Broadcast Fence는 stuck 관찰 대상이고, Broadcast Fence는 zone death 1회가 있었다.
- N2-MAP-01 완료: `data/mapSpec_night_forest_candidate.json`를 `0.2-poi-probe-integrated`로 갱신했다. Cabin Row와 Broadcast Fence 주변 장애물 밀도를 낮추고 route/POI 분류 좌표는 유지했다. JSON parse, `verify_night_forest_candidate.gd`, `xlarge_60` runtime load, `target_99_probe` runtime load, 99인 1-run reference simulation을 통과했다. 1-run 결과는 duration 165.4s, fallback 0.0/run, sentinel clear, stuck 101.0/run, zone deaths 4.0/run이다.
- N2-VIS-01 1차 완료: `PlayerNightReadability.gd`가 야간 후보 map metadata에서 기존 `VisionSpot`/`ProximityLight`를 손전등 프로필로 전환한다. 기본 맵에서는 기존 조명값을 복원한다. `verify_player_night_readability.gd`, Night 후보 `xlarge_60` runtime load, Night 후보 `xlarge_60` 1-run smoke를 통과했다.
- N2-VIS-01 수동 검토 프리셋 추가: `visual_review`는 8봇, 45픽업, stage loot wave 0, 느린 자기장으로 구성했다. 1-run smoke는 duration 287.2s, fallback 0.0/run, zone deaths 0, sentinel clear, AI update avg 184.4us였다. `xlarge_60`은 60봇/150픽업/다수 pickup light 때문에 수동 검토용으로 쓰지 않는다.
- N2-PERF-01 완료: pickup `OmniLight3D`에 거리 기반 LOD를 적용했다. 감지된 픽업 body/icon은 유지하되, 광원은 가까우면 full, 중거리면 dim, 멀면 off로 처리하고 focus 상태에서는 full로 복원한다. `verify_pickup_light_lod.gd`, `verify_player_night_readability.gd`, Night 후보 `visual_review` runtime load를 통과했다.
- N2-AI-LOD-01 완료: `Entity` perception은 누적 delta tick으로 바꾸고, 봇은 ATTACK 0.05s / 이동계 상태 0.08s / IDLE 0.12s로 perception LOD를 적용했다. footstep/gunshot/close-range 스캔은 0.15s/0.10s/0.05s로 제한했다. `visual_review`, `xlarge_60`, `target_99_probe` 1-run smoke와 60/99 `check_scale_telemetry.py --min-runs 1`을 통과했다. 99 결과는 duration 178.2s, fallback 0.0/run, zone deaths 1, stuck 51.0/run, AI update avg 463.0us, sentinel clear다.
- N2-AI-01 완료: 봇 viewer에만 적용되는 추상 야간 인지를 추가했다. 강한 1차 상수는 `visual_review`, `xlarge_60`, `target_99_probe`에서 sentinel clear였지만 target 99 scale checker가 stuck 96.0/run으로 실패했다. 상수 완화 후 `verify_bot_night_awareness.gd`, `verify_ai_lod_perception.gd`, `verify_bush_interaction.gd`가 통과했고, `target_99_probe` 3-run도 avg duration 149.7s, first upgrade 23.0s, fallback 0.0/run, stuck 55.7/run, AI update avg 511.6us, sentinel clear로 `check_scale_telemetry.py --min-runs 3`을 통과했다. 별도 1-run은 no first upgrade로 실패했으나 stuck/AI/sentinel은 정상 범위였다.
- N2-PACE-01 완료: `Telemetry.gd`에 `pacing` 그룹을 추가하고 analyzer 출력과 smoke verifier를 붙였다. stuck 반복 실패를 막기 위해 stuck state/route/cell 진단을 추가했고, Night 후보 Black Ridge 및 south/clinic pathing clearance를 소폭 수정했다. `target_99_probe` 3-run은 avg duration 143.6s, first upgrade 27.3s, fallback 0.0/run, stuck 20.3/run, AI avg 661.2us, sentinel clear로 통과했다.
- N2-PACE-02 완료: `tools/summarize_pacing_baseline.py`를 추가했다. `C:\tmp\game_dev_pacing_map_clearance_v2_3run` 기준 avg duration 143.6s는 10분 바닥까지 4.18x, 12.5분 midpoint까지 5.22x 짧은 구조 smoke로 분류된다. 이 run의 pacing milestone 값은 N2-PACE-04 이전 wall-clock 기준이므로 phase 해석은 fresh run으로 갱신한다.
- N2-PACE-03 완료: [NIGHT_BR_PACING_PLAN.md](NIGHT_BR_PACING_PLAN.md)에 10-15분 watch band, tuning 순서, 검증 루프를 추가했다. `target_99_probe`는 구조 gate로 유지하고, 본편 체감 tuning은 별도 비기본 playable pacing 후보에서만 검증한다.
- N2-PACE-04 완료: pacing milestone seconds를 game-time 기준으로 정규화했다. fresh 1-run은 duration 150.9s, first upgrade 25.1s, stage2 121.3s, fallback 0.0/run, stuck 25.0/run, scale checker pass다.
- N2-MISSION-01 완료: clean win은 현재 HP가 현재 max HP의 50% 이상이면 통과한다. Hell 시작 HP 1과 Zone Battery 같은 no-heal artifact는 `apply_health_capacity_lock(1.0)`으로 current/max HP를 모두 1로 잠근다.
- N2-PACE-05 완료: fresh `target_99_probe` 3-run은 avg duration 163.1s, first contact 1.4s, first upgrade 27.4s, stage2 130.2s, fallback 0.0/run, zone deaths 0, stuck 16.7/run, AI avg 628.9us, sentinel clear로 `check_scale_telemetry.py --min-runs 3`을 통과했다. gap report는 10분 바닥까지 3.68x, 12.5분 midpoint까지 4.60x 부족하다고 판정했다.
- N2-PACE-06 완료: `playable_pacing_v1`은 avg duration 294.0s까지 늘었고 fallback/stuck/AI/sentinel은 정상이다. 다만 first contact 1.2s, first upgrade 36.6s는 10-15분 목표 대비 빠르다. 첫 낮은 economy 후보의 `no first upgrade` 실패는 verifier 하한으로 막았다.
- N2-PACE-07 완료: pacing gap report가 opening pressure를 함께 보여준다. 5m spawn spacing 로컬 smoke는 first contact 개선이 거의 없어 폐기했다.
- N2-PACE-08 완료: first target acquisition이 0.6초에 retreat_counteraction / ZONE_ESCAPE에서 발생하고 contact까지 0.4초밖에 없다는 것을 확인했다.
- N2-PACE-09 완료: `playable_pacing_v1`의 initial_radius 86m가 런타임에 적용되면서 첫 acquisition이 objective_interrupt / CHASE로 바뀌었다. 즉시 ZONE_ESCAPE 원인은 spawn radius 78m 대비 implicit initial zone 50m였고, 남은 문제는 sub-5s objective/proximity contact다.
- N2-PACE-10 완료: 첫 objective interrupt는 idle_loot heal/armor 목표가 combat_low_ammo need로 잡힌 뒤 7-8m enemy에 끊긴다. 새 telemetry는 old summary와 backward-compatible이다.
- N2-PACE-11 완료: idle_loot 목표는 2초 grace 동안 6m 초과 enemy interrupt를 미루고, exact combat threshold ammo는 `ammo_low`로 분류한다. 새 playable 3-run은 enemy 4.8m/objective 8.4m first interrupt로 바뀌어 7-8m 중거리 interrupt가 사라졌고, scale gate도 통과했다.
- N2-PACE-12 완료: healthy heal을 same-weapon ammo보다 낮게 보되 non-pistol upgrade rush는 억제했다. broad non-pistol boost 후보는 first upgrade 2.7s로 gate 실패해서 폐기했고, 채택 후보는 first upgrade 54.5s로 통과했다.
- N2-PACE-13 완료: `playable_pacing_v1`은 5m spawn clearance와 260 safe attempts를 사용하고, idle_loot close interrupt cutoff는 5m로 낮췄다. 채택 후보는 spawn fallback 0.0/run, min nearest 5.0m, saturation 0.42, first contact 2.6s, first upgrade 29.4s, long-run scale gate 통과다.
- N2-PACE-14 완료: spawn 후 3초 동안 IDLE enemy acquisition을 2m 밖에서는 미룬다. 채택 후보는 first acquisition source가 objective_interrupt 100%로 바뀌고 idle_reaction이 첫 read에서 사라졌으며, first contact 3.4s, first upgrade 38.3s, long-run scale gate 통과다.
- N2-PACE-15 완료: spawn 후 3초 동안 5m 안 actor 주변 먼 idle-loot start와 2m 밖 objective interrupt를 미룬다. v1은 first objective interrupt가 2.1s로 남아 폐기했고, v2는 first contact 6.5s, first objective interrupt 9.8s, first upgrade 20.2s, long-run scale gate 통과다.
- N2-PACE-16 완료: 5.7m spawn-spacing 후보는 stuck gate 실패로 폐기했고, 채택 후보는 spawn 후 7초 동안 IDLE 1-2m near-bump forced reveal을 미룬다. first acquisition은 objective_interrupt 100%, first contact 6.0s, first upgrade 19.0s, long-run scale gate 통과다.
- N2-PACE-17 완료: idle-loot objective interrupt safety만 7초 / 1m hard bump 기준으로 분리했다. first objective interrupt는 28.6s까지 밀렸고 first contact는 9.2s, first upgrade 54.9s, long-run scale gate 통과다.
- N2-PACE-18 완료: 2m 밖 IDLE visible enemy reaction window를 10초로 늘렸다. first contact는 14.3s, first acquisition은 objective_interrupt / idle_reaction / retreat_counteraction으로 분산됐고, avg duration 577.1s, long-run scale gate 통과다.
- N2-PACE-19 완료: gameplay 변경 없이 run별 first acquisition sample을 추가했다. mixed opening acquisition은 objective_interrupt / idle_reaction / retreat_counteraction으로 분리되어 단일 combat/AI 수치 문제가 아님을 확인했다.
- N2-PACE-20 완료: first acquisition에 self band, zone ratio/status, spawn age를 추가했다. 첫 acquisition 3/3은 retreat_counteraction/ZONE_ESCAPE였고, 모두 opening edge context였다.
- N2-PACE-21 완료: spawn 후 10초 안에 zone 안쪽 edge에 있는 `ZONE_ESCAPE` 봇의 retreat-counteraction target acquisition만 미뤘다. `C:\tmp\game_dev_opening_zone_edge_guard_v1_3run`은 first acquisition 12.9s, first contact 17.3s, first upgrade 18.7s, scale gate 통과다.
- N2-PACE-22 완료: hard-bump acquisition impact report를 추가했다. N2-PACE-21 기준 hard-bump first acquisition은 3/3, avg contact gap 4.4s, delayed 5s+ 1/3이다.
- N2-PACE-23 완료: 1m hard-bump 예외를 intentional collision/readability rule로 유지하고, hard-bump pressure는 first acquisition 단독이 아니라 acquisition-to-contact gap으로 읽는 정책을 리포트에 고정했다.
- N2-PACE-24 완료: `summarize_pacing_baseline.py`가 `Phase gap read`를 출력한다. `playable_pacing_v1`은 stage2 268.5s가 band 안이지만 stage3가 없고 match end가 306.0s 빠르며, first upgrade도 83.4s 빠르다.
- N2-PACE-25 완료: `playable_pacing_v2`는 stage2 entry timing을 유지하면서 late-zone compression만 늘렸다. 3-run은 avg duration 533.3s, stage2 268.1s, stage3 638.4s, match end 66.7s short, first upgrade 19.4s, scale gate 통과다.
- 다음 우선순위: `playable_pacing_v2`를 기준으로 first-upgrade/economy pacing을 늦추되 no-first-upgrade starvation을 재발시키지 않는 작은 후보를 검증한다.

## 비목표

- 이번 전환에서 기본 맵이나 기본 scale preset을 99인으로 승격하지 않는다.
- 모든 봇에게 full flashlight/battery/fear state를 바로 넣지 않는다.
- Wire Maze, cabin interior, watchtower climb, fire spread, blackout event를 한 번에 구현하지 않는다.
- 생성 GLB를 대량 승격하지 않는다.
- combat 비율 하나를 목표값으로 잡고 AI aggression, damage, zone speed를 직접 밀어붙이지 않는다.

## 검증 게이트

문서만 바꿀 때:

- `git diff --check`

후보 맵 구조를 소폭 반복할 때:

- `tools/verify_night_forest_candidate.gd`
- runtime load: `map_spec_path=res://data/mapSpec_night_forest_candidate.json scale_preset=xlarge_60`
- runtime load: `map_spec_path=res://data/mapSpec_night_forest_candidate.json scale_preset=target_99_probe`
- 1-run `target_99_probe` reference simulation
- `git diff --check`

후보 맵을 승격/비교 게이트로 올릴 때:

- `tools/verify_strategic_flow_map.gd`
- `tools/verify_candidate_99_probe.gd`
- fresh 5-run `xlarge_60`
- fresh 5-run `target_99_probe`
- `tools/compare_scale_profiles.py`
- `tools/check_scale_telemetry.py`

반복 실패 방지 판정:

- `stuck > 60/run`: scale gate를 낮추지 않는다. 맵 구조, nav 압박, night range/dwell 보정 순서로 수정한다.
- `spawn fallback > 0` 또는 placed/requested mismatch: 스폰/맵 envelope 문제로 보고 AI나 전투 수치를 건드리지 않는다.
- zero total damage, zero weapon damage, zero shot, zero combat plan: AI/전투 회귀로 보고 즉시 코드 경로를 확인한다.
- 1-run no first upgrade: economy seed 변동 가능성이 있으므로 3-run으로 재확인한다. 3-run에서도 실패하면 loot/upgrade 접근성 문제로 분류한다.
- 평균 AI update budget 초과: behavior 튜닝보다 perception/sensory 비용과 loop cadence를 먼저 확인한다.

야간/페이싱을 바꿀 때:

- `tools/verify_pacing_telemetry.gd`
- `tools/verify_bot_night_awareness.gd`
- `tools/verify_ai_lod_perception.gd`
- `tools/verify_pickup_light_lod.gd`
- `tools/verify_player_night_readability.gd`
- `tools/summarize_pacing_baseline.py <run_dir>`
- 10-15분 목표에 맞춘 별도 telemetry row 추가
- flashlight on ratio, battery depletion, darkness hit/kill, crossing usage, POI dwell, first-contact, first-upgrade, final-zone timing 확인
- 봇 full night system 적용 전 AI cost와 behavior complexity review

## 보존 문서

| 경로 | 내용 |
|---|---|
| [archive/MASTERPLAN_full_2026-06-08.md](archive/MASTERPLAN_full_2026-06-08.md) | 야간 인공 숲 기획 압축 전 전체 로드맵 |
| [archive/MASTERPLAN_full_2026-05-26.md](archive/MASTERPLAN_full_2026-05-26.md) | v1.11.35 압축 전 전체 로드맵 |
| [archive/MASTERPLAN_full_2026-05-13.md](archive/MASTERPLAN_full_2026-05-13.md) | 이전 장문 마스터플랜 |
| [devlog/DEVLOG_full_2026-05-26.md](devlog/DEVLOG_full_2026-05-26.md) | v1.11.35 압축 전 전체 devlog |
| [devlog/v1.11_full_2026-05-26.md](devlog/v1.11_full_2026-05-26.md) | 압축 전 v1.11 슬라이스 요약 |

## 다음 에이전트 체크리스트

- 작업 전 [HANDOFF.md](HANDOFF.md), [DOCS_INDEX.md](DOCS_INDEX.md), 이 파일을 읽는다.
- 코드 변경 전 [IMPACT_MAP.md](IMPACT_MAP.md)에서 소유권과 영향 범위를 확인한다.
- 야간 인공 숲과 야간 시야 시스템이 반영되기 전까지 v2 telemetry는 구조 안전성 지표로 해석한다.
- `plan_report/`, `asset_generator/`, `docs/ASSET_GENERATION_PROMPTS.md`는 명시 요청 전까지 untracked로 둔다.
- 문서만 바꾸면 `git diff --check`로 검증하고, 코드 변경은 위험도에 맞춰 Godot/simulation check를 추가한다.
