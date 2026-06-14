# 다음 세션 핸드오프

> 마지막 업데이트: 2026-06-14 (opening objective interrupt telemetry 완료). 기존 긴 handoff는 제거했고, 새 관리자 권한 Codex 세션이 이어받는 데 필요한 내용만 남긴다.

## 먼저 확인할 것

1. VS Code를 **관리자 권한**으로 열고 `C:\test\game_dev`에서 Codex 새 세션을 시작한다.
2. 새 세션 첫 shell 테스트:

```powershell
Get-Location
```

권한 상승 없이 성공하면 Windows sandbox 문제가 해결된 것이다. 실패하면서 `windows sandbox: spawn setup refresh`가 나오면 아직 VS Code/Codex 호스트가 비관리자 권한으로 떠 있는 상태다.

## 현재 Git 상태

- 브랜치: `master`
- 원격 최신 커밋은 `git log -1 --oneline origin/master` 또는 `git status -sb`로 확인한다.
- 이번 세션 기준 완료 slice: `N2-PACE-10` opening objective interrupt telemetry.
- GitHub 저장소: <https://github.com/Kyulhee/battle-capsule>
- 안정 릴리즈: <https://github.com/Kyulhee/battle-capsule/releases/tag/v2.0.0-pre-expansion>
- 안정 태그: `v2.0.0-pre-expansion`
- 안정 빌드 기준 커밋: `41339a9`
- Windows/macOS 빌드는 GitHub Release에 업로드 완료.
- README와 RELEASE 문서는 한글 중심으로 갱신 후 push 완료.

## 자율 작업 루틴

사용자가 당분간 직접 확인하기 어렵다고 명시했다. 새 세션도 아래 루틴을 따른다.

1. 계획 확인: `HANDOFF`, `MASTERPLAN`, `TESTING`에서 현재 slice와 gate를 확인한다.
2. 작업: 기본 맵/기본 99인 승격, release, bot full flashlight/fear/battery 같은 큰 결정은 보류한다.
3. 검증: 단발 smoke와 완료 gate를 분리한다. `target_99_probe` 완료 판정은 최소 3-run + `check_scale_telemetry.py --min-runs 3`이다.
4. 푸쉬: 검증된 slice는 커밋하고 push한다. 로컬 전용 자료는 staging하지 않는다.
5. 중단 조건: 같은 blocker가 3회 이상 반복되고, 이후 작업에도 계속 문제가 될 때만 사용자 확인을 기다린다.

실패 판정:

- 단발 `no first upgrade`: 바로 튜닝하지 말고 3-run으로 재확인한다.
- `stuck > 60/run`: gate를 낮추지 말고 맵/nav/night range-dwell 보정을 수정한다.
- spawn fallback, zero damage/shot/plan sentinel, AI budget 초과: 구조 회귀로 보고 다음 작업으로 넘기지 않는다.

## 남아 있는 로컬 자료

아래 항목은 로컬에 남겨도 된다. 새 세션에서 자동 revert하지 않는다.

```text
 M .gitignore
?? asset_generator/
?? docs/ASSET_GENERATION_PROMPTS.md
?? plan_report/
```

주의:

- `.gitignore`, `asset_generator/`, `docs/ASSET_GENERATION_PROMPTS.md`, `plan_report/`는 기존 로컬/참고 자료다. 사용자가 명시하기 전까지 커밋하지 않는다.
- `N2-AI-01`, `N2-PACE-01`, `N2-PACE-02`, `N2-PACE-03`, `N2-PACE-04`, `N2-MISSION-01`, `N2-PACE-05`, `N2-PACE-06`, `N2-PACE-07`, `N2-PACE-08`, `N2-PACE-09`, `N2-PACE-10`은 검증 완료 slice다.
- 강한 상수는 `target_99_probe` stuck 96.0/run으로 실패했다. 완화 후 단발 1-run은 no first upgrade로 scale checker를 실패했지만, 3-run 구조 smoke는 통과했다.

## 다음 작업

현재 완료한 본 작업은 `N2-PACE-10` opening objective interrupt telemetry다. `zone.initial_radius` 문제는 `N2-PACE-09`에서 해결됐고, `N2-PACE-10`은 남은 `objective_interrupt / CHASE` 첫 접촉이 어떤 loot objective에서 끊기는지 기록한다. fresh 3-run 기준 첫 interrupt는 idle_loot heal/armor objective가 combat_low_ammo need로 잡힌 뒤 7-8m enemy에 끊긴다.

통과한 단위 검증:

```powershell
.\Godot_v4.6.2-stable_win64_console.exe --headless --path . --script res://tools/verify_mission_health_rules.gd
.\Godot_v4.6.2-stable_win64_console.exe --headless --path . --script res://tools/verify_artifact_balance.gd
.\Godot_v4.6.2-stable_win64_console.exe --headless --path . --script res://tools/verify_artifact_runtime.gd
.\Godot_v4.6.2-stable_win64_console.exe --headless --path . --script res://tools/verify_player_night_readability.gd
.\Godot_v4.6.2-stable_win64_console.exe --headless --path . --script res://tools/verify_pacing_telemetry.gd
.\Godot_v4.6.2-stable_win64_console.exe --headless --path . --script res://tools/verify_bot_night_awareness.gd
.\Godot_v4.6.2-stable_win64_console.exe --headless --path . --script res://tools/verify_ai_lod_perception.gd
.\Godot_v4.6.2-stable_win64_console.exe --headless --path . --script res://tools/verify_bush_interaction.gd
python -m py_compile tools\summarize_pacing_baseline.py tools\analyze_results.py tools\check_scale_telemetry.py tools\simulate_matches.py
python tools\simulate_matches.py 1 map_spec_path=res://data/mapSpec_night_forest_candidate.json scale_preset=target_99_probe out_dir=C:\tmp\game_dev_pacing_time_scale_v1
python tools\analyze_results.py C:\tmp\game_dev_pacing_time_scale_v1
python tools\summarize_pacing_baseline.py C:\tmp\game_dev_pacing_time_scale_v1
python tools\check_scale_telemetry.py C:\tmp\game_dev_pacing_time_scale_v1 --min-runs 1
python tools\simulate_matches.py 3 map_spec_path=res://data/mapSpec_night_forest_candidate.json scale_preset=target_99_probe out_dir=C:\tmp\game_dev_pacing_game_time_v2_3run
python tools\analyze_results.py C:\tmp\game_dev_pacing_game_time_v2_3run
python tools\summarize_pacing_baseline.py C:\tmp\game_dev_pacing_game_time_v2_3run
python tools\check_scale_telemetry.py C:\tmp\game_dev_pacing_game_time_v2_3run --min-runs 3
python -m json.tool data\mapSpec_night_forest_candidate.json
.\Godot_v4.6.2-stable_win64_console.exe --headless --path . --script res://tools/verify_playable_pacing_preset.gd
.\Godot_v4.6.2-stable_win64_console.exe --headless --path . --script res://tools/verify_night_forest_candidate.gd
.\Godot_v4.6.2-stable_win64_console.exe --headless --path . --quit -- map_spec_path=res://data/mapSpec_night_forest_candidate.json scale_preset=playable_pacing_v1
python tools\simulate_matches.py 3 map_spec_path=res://data/mapSpec_night_forest_candidate.json scale_preset=playable_pacing_v1 out_dir=C:\tmp\game_dev_playable_pacing_v1_3run_v2
python tools\analyze_results.py C:\tmp\game_dev_playable_pacing_v1_3run_v2
python tools\summarize_pacing_baseline.py C:\tmp\game_dev_playable_pacing_v1_3run_v2
python tools\check_scale_telemetry.py C:\tmp\game_dev_playable_pacing_v1_3run_v2 --min-runs 3
python -m py_compile tools\summarize_pacing_baseline.py
python tools\summarize_pacing_baseline.py C:\tmp\game_dev_playable_pacing_v1_3run_v2
.\Godot_v4.6.2-stable_win64_console.exe --headless --path . --script res://tools/verify_pacing_telemetry.gd
python -m py_compile tools\analyze_results.py tools\summarize_pacing_baseline.py tools\check_scale_telemetry.py tools\simulate_matches.py
python tools\simulate_matches.py 3 map_spec_path=res://data/mapSpec_night_forest_candidate.json scale_preset=playable_pacing_v1 out_dir=C:\tmp\game_dev_opening_acq_v1_3run
python tools\analyze_results.py C:\tmp\game_dev_opening_acq_v1_3run
python tools\summarize_pacing_baseline.py C:\tmp\game_dev_opening_acq_v1_3run
python tools\check_scale_telemetry.py C:\tmp\game_dev_opening_acq_v1_3run --min-runs 3
.\Godot_v4.6.2-stable_win64_console.exe --headless --path . --script res://tools/verify_zone_initial_radius_tuning.gd
python tools\simulate_matches.py 3 map_spec_path=res://data/mapSpec_night_forest_candidate.json scale_preset=playable_pacing_v1 out_dir=C:\tmp\game_dev_zone_initial_radius_v1_3run
python tools\analyze_results.py C:\tmp\game_dev_zone_initial_radius_v1_3run
python tools\summarize_pacing_baseline.py C:\tmp\game_dev_zone_initial_radius_v1_3run
python tools\check_scale_telemetry.py C:\tmp\game_dev_zone_initial_radius_v1_3run --min-runs 3
python tools\check_scale_telemetry.py C:\tmp\game_dev_pacing_game_time_v2_3run --min-runs 3
python tools\analyze_results.py C:\tmp\game_dev_zone_initial_radius_v1_3run
python tools\summarize_pacing_baseline.py C:\tmp\game_dev_zone_initial_radius_v1_3run
python tools\simulate_matches.py 3 map_spec_path=res://data/mapSpec_night_forest_candidate.json scale_preset=playable_pacing_v1 out_dir=C:\tmp\game_dev_objective_interrupt_v1_3run
python tools\analyze_results.py C:\tmp\game_dev_objective_interrupt_v1_3run
python tools\summarize_pacing_baseline.py C:\tmp\game_dev_objective_interrupt_v1_3run
python tools\check_scale_telemetry.py C:\tmp\game_dev_objective_interrupt_v1_3run --min-runs 3
git diff --check
```

완화 후 99 검증:

```powershell
python tools\simulate_matches.py 1 map_spec_path=res://data/mapSpec_night_forest_candidate.json scale_preset=target_99_probe out_dir=C:\tmp\game_dev_bot_night_awareness_target99_v2
python tools\analyze_results.py C:\tmp\game_dev_bot_night_awareness_target99_v2
python tools\check_scale_telemetry.py C:\tmp\game_dev_bot_night_awareness_target99_v2 --min-runs 1

python tools\simulate_matches.py 3 map_spec_path=res://data/mapSpec_night_forest_candidate.json scale_preset=target_99_probe out_dir=C:\tmp\game_dev_bot_night_awareness_target99_v2_3run
python tools\analyze_results.py C:\tmp\game_dev_bot_night_awareness_target99_v2_3run
python tools\check_scale_telemetry.py C:\tmp\game_dev_bot_night_awareness_target99_v2_3run --min-runs 3
```

판정:

- `C:\tmp\game_dev_bot_night_awareness_target99_v2` 1-run: duration 107.8s, fallback 0.0/run, zone deaths 1, stuck 45.0/run, AI avg 539.5us, sentinel clear. Scale checker는 no first upgrade 때문에 실패했다.
- `C:\tmp\game_dev_bot_night_awareness_target99_v2_3run` 3-run: avg duration 149.7s, first upgrade 23.0s, fallback 0.0/run, zone deaths 1.3/run, stuck 55.7/run, disengage 111.7/run, AI avg 511.6us, sentinel clear. `check_scale_telemetry.py --min-runs 3` 통과.
- 이 결과로 `N2-AI-01`은 구조 gate 완료로 본다. 단발 no first upgrade는 변동성 기록으로만 남기고 gate 기준은 낮추지 않는다.
- `N2-PACE-01` 1차는 `Telemetry.gd`의 `pacing` milestone 그룹, `tools/analyze_results.py` pacing 출력, `tools/verify_pacing_telemetry.gd`로 구성한다. route/POI dwell은 기존 doctrine telemetry를 analyzer에서 재사용한다.
- `N2-PACE-01` 최종 구조 gate:
  - output: `C:\tmp\game_dev_pacing_map_clearance_v2_3run`
  - avg duration 143.6s, first upgrade 27.3s, fallback 0.0/run, zone deaths 0.3/run, stuck 20.3/run
  - AI update avg 661.2us, max 28729us, regression sentinel clear
  - `check_scale_telemetry.py --min-runs 3` 통과.
- `N2-PACE-02` 기준선 해석:
  - 명령: `python tools\summarize_pacing_baseline.py C:\tmp\game_dev_pacing_map_clearance_v2_3run`
  - avg duration 143.6s는 10분 바닥까지 4.18x, 12.5분 midpoint까지 5.22x 짧은 구조 smoke다.
  - 이 run의 pacing milestone 값은 N2-PACE-04 이전 wall-clock 기준이라 phase 해석에는 더 쓰지 않는다.
- `N2-PACE-03` 조정안 초안:
  - `target_99_probe`는 구조 gate로 유지한다.
  - 본편 체감 tuning은 별도 비기본 playable pacing 후보에서 검증한다.
  - 초안 watch band는 first contact 45-150s, first upgrade 120-300s, stage 2 240-420s, stage 3/late compression 540-720s, match end 600-900s다.
  - 조정 순서는 자기장 schedule, loot/economy spacing, POI rotation, combat/AI 순서다.
- `N2-PACE-04` 정규화 후 fresh 1-run:
  - output: `C:\tmp\game_dev_pacing_time_scale_v1`
  - duration 150.9s, first upgrade 25.1s, stage2 121.3s
  - fallback 0.0/run, stuck 25.0/run, zone deaths 0, AI avg 540.9us, sentinel clear
  - `check_scale_telemetry.py --min-runs 1` 통과.
- `N2-MISSION-01` mission health rule fix:
  - `CLEAN WIN`은 현재 HP / 현재 max HP 비율이 50% 이상이면 통과한다.
  - Hell 시작 HP 1과 Zone Battery 같은 `heal_mult=0` artifact는 `apply_health_capacity_lock(1.0)`으로 current/max HP를 모두 1로 잠근다.
  - `verify_mission_health_rules.gd`, artifact balance/runtime, player night readability, pacing telemetry smoke가 통과했다.
- `N2-PACE-05` fresh game-time 3-run:
  - output: `C:\tmp\game_dev_pacing_game_time_v2_3run`
  - avg duration 163.1s, first contact 1.4s, first kill 17.5s, first upgrade 27.4s, stage2 130.2s
  - fallback 0.0/run, zone deaths 0, stuck 16.7/run, AI avg 628.9us, sentinel clear
  - `check_scale_telemetry.py --min-runs 3` 통과. `summarize_pacing_baseline.py`는 10분 바닥까지 3.68x, 12.5분 midpoint까지 4.60x 부족한 compressed structural smoke로 판정했다.
- `N2-PACE-06` playable_pacing_v1:
  - `data/mapSpec_night_forest_candidate.json`에 비기본 `playable_pacing_v1`을 추가했다. 99 bots/spawn radius/safe spawn attempts는 `target_99_probe`와 같고, loot/economy는 target보다 낮게 유지한다.
  - 첫 낮은 economy 후보는 3-run에서 `no first upgrade`가 재현되어 폐기했다. 최종 v1은 loot_count 210, hotspot 1.04, rare 1.15, stage wave 0.045/0.055 x6이며 `verify_playable_pacing_preset.gd`가 이 하한을 검증한다.
  - output: `C:\tmp\game_dev_playable_pacing_v1_3run_v2`
  - avg duration 294.0s, first contact 1.2s, first kill 15.0s, first upgrade 36.6s, stage2 268.5s
  - fallback 0.0/run, zone deaths 0.7/run, stuck 16.7/run, AI avg 529.0us, sentinel clear
  - `check_scale_telemetry.py --min-runs 3` 통과. gap report는 10분 바닥까지 2.04x, 12.5분 midpoint까지 2.55x 부족하다고 판정했다.
- `N2-PACE-07` opening pressure report:
  - `summarize_pacing_baseline.py`에 spawn fallback, min/avg nearest, saturation, attempts, sub-5s first contact 해석을 추가했다.
  - `C:\tmp\game_dev_playable_pacing_v1_3run_v2` 기준 spawn fallback 0.0/run, min nearest 3.5m, avg-min 3.7m, avg-nearest 7.4m, saturation 0.20, attempts 1.3/5 max다.
  - 로컬 5m spacing smoke는 fallback 0.0/run과 min nearest 5.0m를 만들었지만 first contact가 1.4s로 거의 안 움직였고 no first upgrade가 나와 폐기했다. 해당 data/verifier 변경은 커밋하지 않았다.
- `N2-PACE-08` opening acquisition telemetry:
  - output: `C:\tmp\game_dev_opening_acq_v1_3run`
  - avg duration 347.9s, first acquisition 0.6s, first contact 1.0s, first upgrade 53.7s, stage2 262.0s
  - first acquisition distance 5.2m, source/state는 retreat_counteraction / ZONE_ESCAPE, acquisition-to-contact gap은 0.4s
  - fallback 0.0/run, stuck 23.0/run, AI avg 474.0us, sentinel clear, `check_scale_telemetry.py --min-runs 3` 통과
- `N2-PACE-09` opening zone radius tuning:
  - `ZoneController`는 `configure_initial_zone()`과 optional `generate_next(next_radius_override)`를 지원한다. `Main`/`MatchBootstrap`이 `zone.initial_radius`를 전달한다.
  - `playable_pacing_v1`은 `initial_radius: 86.0`으로 시작한다. `verify_zone_initial_radius_tuning.gd`와 `verify_playable_pacing_preset.gd`가 spawn ring이 opening ZONE_ESCAPE로 시작하지 않도록 검증한다.
  - output: `C:\tmp\game_dev_zone_initial_radius_v1_3run`
  - avg duration 389.3s, first acquisition 1.7s, first contact 2.6s, first upgrade 32.6s, stage2 275.2s
  - first acquisition distance 14.2m, source/state는 objective_interrupt / CHASE, acquisition-to-contact gap은 0.8s
  - fallback 0.0/run, zone deaths 0, stuck 41.0/run, AI avg 509.0us, sentinel clear
  - `check_scale_telemetry.py --min-runs 3` 통과. 300초 이상 playable run은 stuck/disengage를 spawned entity/minute로 본다. 짧은 구조 smoke는 기존 raw gate를 유지한다.
- `N2-PACE-10` opening objective interrupt telemetry:
  - `Telemetry.gd` pacing row에 first objective interrupt time, enemy/objective distance, objective source/kind/need/match/detail, objective/enemy bands를 추가했다.
  - output: `C:\tmp\game_dev_objective_interrupt_v1_3run`
  - avg duration 441.0s, first acquisition 1.6s, first contact 2.4s, first upgrade 56.5s, stage2 278.0s, stage3 519.8s
  - first objective interrupt는 enemy 7.5m, objective 13.4m, source idle_loot, kind heal/armor, need combat_low_ammo
  - fallback 0.0/run, zone deaths 0, stuck 46.3/run, AI avg 474.5us, sentinel clear, long-run scale gate 통과
- 다음 우선순위는 opening loot objective selection과 objective interrupt rule을 확인하는 것이다. 바로 combat damage, AI aggression, night awareness 상수를 건드리지 않는다.

## 설계 가드레일

- 99인 후보를 기본 맵/기본 프리셋으로 승격하지 않는다.
- 봇에게 손전등, 배터리, 공포, 정전, cone-vs-cone 시뮬레이션을 아직 넣지 않는다.
- 현재 단계의 night awareness는 봇 viewer에만 적용되는 거리/확신도 기반 추상 인지 보정이어야 한다.
- `target_99_probe` telemetry는 최종 밸런스가 아니라 구조 안전성 게이트다.
- 수동 화면 검토는 `visual_review` 프리셋을 사용한다. `xlarge_60`/`target_99_probe`는 구조 부하 검증용이다.
- `plan_report/`는 참고용 로컬 디렉토리다. 사용자가 명시하기 전까지 커밋하지 않는다.
