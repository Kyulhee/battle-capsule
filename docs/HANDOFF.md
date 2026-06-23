# 다음 세션 핸드오프

> 마지막 업데이트: 2026-06-24 (N2-OPS verification profiles 도입 중). 새 세션은 이 파일보다 [CURRENT.md](CURRENT.md)를 먼저 현재 작업 화면으로 사용한다.

## 먼저 확인할 것

1. VS Code를 **관리자 권한**으로 열고 `C:\test\game_dev`에서 Codex 새 세션을 시작한다.
2. 새 세션 첫 shell 테스트:

```powershell
Get-Location
```

권한 상승 없이 성공하면 Windows sandbox 문제가 해결된 것이다. 실패하면서 `windows sandbox: spawn setup refresh`가 나오면 아직 VS Code/Codex 호스트가 비관리자 권한으로 떠 있는 상태다.
현재 세션에서는 권한 상승 없는 shell이 `CreateProcessAsUserW failed: 1312`로 실패했지만, `sandbox_permissions: "require_escalated"` 명시 실행은 정상 동작했다. shell/git/Godot/Python 검증이 필요하면 권한 상승 명시를 우선 사용한다.

## 현재 Git 상태

- 브랜치: `master`
- 원격 최신 커밋은 `git log -1 --oneline origin/master` 또는 `git status -sb`로 확인한다.
- 이번 세션 기준 완료 gameplay slice: `N2-PACE-27` first-upgrade context telemetry/report.
- 현재 ops slice: `N2-OPS-02` verification profile runner.
- 현재 로컬은 `7e3c3f8 report first upgrade context` 때문에 `origin/master`보다 1 commit ahead일 수 있다. push는 명시 승인 필요.
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
- `N2-AI-01`, `N2-PACE-01`, `N2-PACE-02`, `N2-PACE-03`, `N2-PACE-04`, `N2-MISSION-01`, `N2-PACE-05`, `N2-PACE-06`, `N2-PACE-07`, `N2-PACE-08`, `N2-PACE-09`, `N2-PACE-10`, `N2-PACE-11`, `N2-PACE-12`, `N2-PACE-13`, `N2-PACE-14`, `N2-PACE-15`, `N2-PACE-16`, `N2-PACE-17`, `N2-PACE-18`, `N2-PACE-19`, `N2-PACE-20`, `N2-PACE-21`, `N2-PACE-22`, `N2-PACE-23`, `N2-PACE-24`, `N2-PACE-25`, `N2-PACE-26`은 검증 완료 slice다.
- 강한 상수는 `target_99_probe` stuck 96.0/run으로 실패했다. 완화 후 단발 1-run은 no first upgrade로 scale checker를 실패했지만, 3-run 구조 smoke는 통과했다.

## 다음 작업

현재 완료한 본 작업은 `N2-PACE-27` first-upgrade context telemetry/report다. `N2-PACE-25`는 stage2 entry timing은 유지한 채 stage2 이후 compression만 늘리는 비기본 `playable_pacing_v2`를 추가했다. `N2-PACE-26`은 v2 위에 단순 loot_count/hotspot/rare 축소 후보를 로컬로 검증했고, late-zone 결과가 후퇴해 폐기했다.

검증 profile 진입점:

- `python tools\run_verify.py --profile docs_only`
- `python tools\run_verify.py --profile tooling`
- `python tools\run_verify.py --profile unit_smoke`
- `python tools\run_verify.py --profile pacing_v2`
- `python tools\run_verify.py --profile scale_99`
- `python tools\run_verify.py --profile visual_review`

`N2-PACE-27` 완료 범위:

- `src/core/Telemetry.gd`: first upgrade context fields 추가, pickup call-order 방어.
- `tools/verify_pacing_telemetry.gd`: synthetic pickup context assertion 추가.
- `tools/analyze_results.py`: `First upgrade context` aggregate 출력 추가.
- `tools/summarize_pacing_baseline.py`: `First upgrade context` report section 추가.

`N2-PACE-27` 검증 결과:

- `verify_pacing_telemetry.gd`, `py_compile`, `playable_pacing_v2` 3-run, analyzer, summarizer, scale gate 통과.
- 출력: `C:\tmp\game_dev_first_upgrade_context_v1_3run`
- 결과: avg duration 345.2s, first contact 19.2s, first kill 26.5s, first upgrade 40.5s, stage2 293.7s, stage3 none, scale gate PASS.
- first upgrade는 shotgun 100%, context는 concealment_field 66.7% / loot_hub 33.3%, on-route 100%.
- 다음 후보는 shotgun/non-pistol access를 context별로 늦추는 작은 변경이다. 단순 global loot_count/hotspot/rare 축소는 반복하지 않는다.

폐기한 로컬 v3 후보는 커밋하지 않았다:

- loot_count 210 -> 205
- hotspot_density_mult 1.04 -> 1.02
- rare_bias_mult 1.15 -> 1.08
- v2 late-zone timing은 유지

폐기 후보 `C:\tmp\game_dev_playable_pacing_v3_economy_v1_3run` 결과:

- avg duration 454.1s, min/max 272.7s / 639.4s
- first contact 12.9s, first kill 16.6s, first upgrade 56.0s
- stage2 270.3s, stage3 none
- scale gate는 통과: fallback 0.0/run, stuck 0.15/entity/min, disengage 0.24/entity/min, AI avg 409.4us, sentinel clear.
- 판정: first upgrade는 v2의 19.4s보다 늦어졌지만, avg duration은 533.3s -> 454.1s로 후퇴했고 stage3가 다시 사라졌다. no-first-upgrade starvation은 없었지만 채택하지 않는다.

`playable_pacing_v2` 설계:

- v1과 같은 99 bots / loot_count 210 / spawn_radius 78 / safe_spawn_attempts 260 / entity_clearance 5m / loot economy.
- initial_radius 86, initial_timer 160, base wait/shrink 150/70은 v1과 같게 유지해 stage2 entry timing을 보존한다.
- stage2 이후만 확장한다: stage2 260/110s dps 1.5, stage3 220/95s dps 3.0, stage4 160/80s dps 6.0, stage5 110/65s dps 10.0.

`playable_pacing_v2` 3-run `C:\tmp\game_dev_playable_pacing_v2_late_zone_v1_3run` 결과:

- avg duration 533.3s, min/max 265.9s / 672.8s
- first contact 13.5s, first kill 20.3s, first upgrade 19.4s
- stage2 268.1s, stage3 638.4s
- phase gap: stage2 and stage3 are in band; match end is still 66.7s short; first upgrade is still 100.6s early.
- scale gate 통과: fallback 0.0/run, stuck 0.09/entity/min, disengage 0.20/entity/min, AI avg 418.9us, sentinel clear.

`playable_pacing_v1` 3-run `C:\tmp\game_dev_playable_pacing_v1_3run_v2` phase gap:

- avg duration 294.0s, first contact 1.2s, first kill 15.0s, first upgrade 36.6s, stage2 268.5s, stage3 none
- first contact: 1.2s vs 45-150s -> early by 43.8s
- first kill: 15.0s vs 60-210s -> early by 45.0s
- first non-pistol upgrade: 36.6s vs 120-300s -> early by 83.4s
- stage 2: 268.5s vs 240-420s -> in band
- stage 3: none vs 540-720s -> missing
- match end: 294.0s vs 600-900s -> early by 306.0s
- read: stage2는 이미 band 안이므로 다음 gameplay 후보는 stage2를 움직이기보다 late-zone compression과 stage3/match-end gap을 먼저 본다.
- read: first upgrade는 아직 너무 빠르지만, 폐기했던 no-first-upgrade starvation을 되살리지 않도록 조심스럽게 늦춘다.

fresh 3-run `C:\tmp\game_dev_opening_zone_edge_guard_v1_3run` 결과:

- avg duration 342.1s, first acquisition 12.9s, first contact/damage 17.3s, first kill 23.9s, first upgrade 18.7s, stage2 275.9s
- first acquisition은 idle_reaction 66.7% / objective_interrupt 33.3%, `retreat_counteraction / ZONE_ESCAPE` first acquisition은 0%
- run 1: 16.0s idle_reaction / IDLE / 1.0m hard bump, contact 16.5s, gap 0.5s
- run 2: 17.6s idle_reaction / IDLE / 1.0m hard bump, contact 18.0s, gap 0.5s
- run 3: 5.1s objective_interrupt / CHASE / 1.0m hard bump, contact 17.3s, gap 12.2s
- hard-bump acquisition impact: 3/3 runs, avg contact gap 4.4s, delayed 5s+ 1, read=contact-gap-not-acquisition-only
- scale gate 통과: fallback 0.0/run, stuck 0.08/entity/min, disengage 0.26/entity/min, AI avg 474.6us, sentinel clear

다음 우선순위는 `playable_pacing_v2`를 기준으로 first-upgrade source/weapon/route context를 먼저 진단하는 것이다. 단순 global loot_count/hotspot/rare 축소는 v3에서 폐기했으므로 반복하지 않는다. 다음 후보는 non-pistol upgrade timing을 직접 겨냥하되 stage2/stage3 band를 깨지 않는 작은 변경이어야 한다.

N2-PACE-26 통과/폐기 검증:

- local v3 JSON parse, `verify_playable_pacing_preset.gd`, `verify_night_forest_candidate.gd`, runtime load 통과
- `python tools\simulate_matches.py 3 map_spec_path=res://data/mapSpec_night_forest_candidate.json scale_preset=playable_pacing_v3 out_dir=C:\tmp\game_dev_playable_pacing_v3_economy_v1_3run`
- `python tools\analyze_results.py C:\tmp\game_dev_playable_pacing_v3_economy_v1_3run`
- `python tools\summarize_pacing_baseline.py C:\tmp\game_dev_playable_pacing_v3_economy_v1_3run`
- `python tools\check_scale_telemetry.py C:\tmp\game_dev_playable_pacing_v3_economy_v1_3run --min-runs 3`

N2-PACE-25 통과 검증:

- `python -m json.tool data\mapSpec_night_forest_candidate.json`
- `.\Godot_v4.6.2-stable_win64_console.exe --headless --path . --script res://tools/verify_playable_pacing_preset.gd`
- `.\Godot_v4.6.2-stable_win64_console.exe --headless --path . --script res://tools/verify_night_forest_candidate.gd`
- `.\Godot_v4.6.2-stable_win64_console.exe --headless --path . --script res://tools/verify_zone_initial_radius_tuning.gd`
- `.\Godot_v4.6.2-stable_win64_console.exe --headless --path . --quit -- map_spec_path=res://data/mapSpec_night_forest_candidate.json scale_preset=playable_pacing_v2`
- `python tools\simulate_matches.py 3 map_spec_path=res://data/mapSpec_night_forest_candidate.json scale_preset=playable_pacing_v2 out_dir=C:\tmp\game_dev_playable_pacing_v2_late_zone_v1_3run`
- `python tools\analyze_results.py C:\tmp\game_dev_playable_pacing_v2_late_zone_v1_3run`
- `python tools\summarize_pacing_baseline.py C:\tmp\game_dev_playable_pacing_v2_late_zone_v1_3run`
- `python tools\check_scale_telemetry.py C:\tmp\game_dev_playable_pacing_v2_late_zone_v1_3run --min-runs 3`

N2-PACE-24 통과 검증:

- `python -m py_compile tools\summarize_pacing_baseline.py`
- `python tools\summarize_pacing_baseline.py C:\tmp\game_dev_playable_pacing_v1_3run_v2`
- `python tools\summarize_pacing_baseline.py C:\tmp\game_dev_opening_zone_edge_guard_v1_3run`

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
.\Godot_v4.6.2-stable_win64_console.exe --headless --path . --script res://tools/verify_bot_opening_loot_rules.gd
python tools\simulate_matches.py 3 map_spec_path=res://data/mapSpec_night_forest_candidate.json scale_preset=playable_pacing_v1 out_dir=C:\tmp\game_dev_opening_loot_rules_v1_3run
python tools\analyze_results.py C:\tmp\game_dev_opening_loot_rules_v1_3run
python tools\summarize_pacing_baseline.py C:\tmp\game_dev_opening_loot_rules_v1_3run
python tools\check_scale_telemetry.py C:\tmp\game_dev_opening_loot_rules_v1_3run --min-runs 3
python tools\simulate_matches.py 3 map_spec_path=res://data/mapSpec_night_forest_candidate.json scale_preset=playable_pacing_v1 out_dir=C:\tmp\game_dev_idle_loot_priority_v2_3run
python tools\analyze_results.py C:\tmp\game_dev_idle_loot_priority_v2_3run
python tools\summarize_pacing_baseline.py C:\tmp\game_dev_idle_loot_priority_v2_3run
python tools\check_scale_telemetry.py C:\tmp\game_dev_idle_loot_priority_v2_3run --min-runs 3
python tools\simulate_matches.py 3 map_spec_path=res://data/mapSpec_night_forest_candidate.json scale_preset=playable_pacing_v1 out_dir=C:\tmp\game_dev_playable_spawn_clearance_v1_3run
python tools\simulate_matches.py 3 map_spec_path=res://data/mapSpec_night_forest_candidate.json scale_preset=playable_pacing_v1 out_dir=C:\tmp\game_dev_opening_proximity_guard_v1_3run
python tools\analyze_results.py C:\tmp\game_dev_opening_proximity_guard_v1_3run
python tools\summarize_pacing_baseline.py C:\tmp\game_dev_opening_proximity_guard_v1_3run
python tools\check_scale_telemetry.py C:\tmp\game_dev_opening_proximity_guard_v1_3run --min-runs 3
python tools\simulate_matches.py 3 map_spec_path=res://data/mapSpec_night_forest_candidate.json scale_preset=playable_pacing_v1 out_dir=C:\tmp\game_dev_opening_idle_reaction_grace_v1_3run
python tools\analyze_results.py C:\tmp\game_dev_opening_idle_reaction_grace_v1_3run
python tools\summarize_pacing_baseline.py C:\tmp\game_dev_opening_idle_reaction_grace_v1_3run
python tools\check_scale_telemetry.py C:\tmp\game_dev_opening_idle_reaction_grace_v1_3run --min-runs 3
python tools\simulate_matches.py 3 map_spec_path=res://data/mapSpec_night_forest_candidate.json scale_preset=playable_pacing_v1 out_dir=C:\tmp\game_dev_opening_loot_safety_v1_3run
python tools\simulate_matches.py 3 map_spec_path=res://data/mapSpec_night_forest_candidate.json scale_preset=playable_pacing_v1 out_dir=C:\tmp\game_dev_opening_loot_safety_v2_3run
python tools\analyze_results.py C:\tmp\game_dev_opening_loot_safety_v2_3run
python tools\summarize_pacing_baseline.py C:\tmp\game_dev_opening_loot_safety_v2_3run
python tools\check_scale_telemetry.py C:\tmp\game_dev_opening_loot_safety_v2_3run --min-runs 3
python tools\simulate_matches.py 3 map_spec_path=res://data/mapSpec_night_forest_candidate.json scale_preset=playable_pacing_v1 out_dir=C:\tmp\game_dev_opening_bump_spacing_v1_3run
python tools\simulate_matches.py 3 map_spec_path=res://data/mapSpec_night_forest_candidate.json scale_preset=playable_pacing_v1 out_dir=C:\tmp\game_dev_opening_bump_reveal_guard_v1_3run
python tools\analyze_results.py C:\tmp\game_dev_opening_bump_reveal_guard_v1_3run
python tools\summarize_pacing_baseline.py C:\tmp\game_dev_opening_bump_reveal_guard_v1_3run
python tools\check_scale_telemetry.py C:\tmp\game_dev_opening_bump_reveal_guard_v1_3run --min-runs 3
python tools\simulate_matches.py 3 map_spec_path=res://data/mapSpec_night_forest_candidate.json scale_preset=playable_pacing_v1 out_dir=C:\tmp\game_dev_opening_objective_interrupt_window_v1_3run
python tools\analyze_results.py C:\tmp\game_dev_opening_objective_interrupt_window_v1_3run
python tools\summarize_pacing_baseline.py C:\tmp\game_dev_opening_objective_interrupt_window_v1_3run
python tools\check_scale_telemetry.py C:\tmp\game_dev_opening_objective_interrupt_window_v1_3run --min-runs 3
python tools\simulate_matches.py 3 map_spec_path=res://data/mapSpec_night_forest_candidate.json scale_preset=playable_pacing_v1 out_dir=C:\tmp\game_dev_opening_idle_reaction_window_v1_3run
python tools\analyze_results.py C:\tmp\game_dev_opening_idle_reaction_window_v1_3run
python tools\summarize_pacing_baseline.py C:\tmp\game_dev_opening_idle_reaction_window_v1_3run
python tools\check_scale_telemetry.py C:\tmp\game_dev_opening_idle_reaction_window_v1_3run --min-runs 3
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
- `N2-PACE-11` opening loot rule guard:
  - idle_loot objective는 2초 grace 동안 6m 초과 enemy interrupt를 미루고, 6m 이내 enemy는 즉시 interrupt한다.
  - ammo가 combat loot threshold와 정확히 같으면 `combat_low_ammo`가 아니라 `ammo_low`로 분류한다.
  - output: `C:\tmp\game_dev_opening_loot_rules_v1_3run`
  - avg duration 450.5s, first acquisition 1.5s, first contact 2.2s, first upgrade 36.6s, stage2 268.3s, stage3 509.5s
  - first objective interrupt는 enemy 4.8m, objective 8.4m, source idle_loot, kind heal/armor, need ammo_low 66.7% / combat_low_ammo 33.3%
  - fallback 0.0/run, zone deaths 0, stuck 62.0/run, AI avg 468.7us, sentinel clear, long-run scale gate 통과
- `N2-PACE-12` opening loot target quality guard:
  - healthy heal은 same-weapon ammo보다 낮게 보고, wounded bot은 heal 우선순위를 유지한다.
  - immediate-value 검색에서는 pistol -> non-pistol upgrade 보너스를 끈다.
  - 폐기 후보 `C:\tmp\game_dev_idle_loot_priority_v1_3run`은 first upgrade 2.7s로 scale gate 실패했다.
  - 채택 후보 output: `C:\tmp\game_dev_idle_loot_priority_v2_3run`
  - avg duration 414.8s, first acquisition 1.5s, first contact 2.1s, first upgrade 54.5s, stage2 269.7s, stage3 510.4s
  - first objective interrupt는 enemy 4.5m, objective 21.8m, source idle_loot, kind armor/heal
  - fallback 0.0/run, zone deaths 0, stuck 53.7/run, AI avg 441.1us, sentinel clear, long-run scale gate 통과
- `N2-PACE-13` opening proximity guard:
  - `playable_pacing_v1`은 safe spawn attempts 260, entity clearance 5.0m를 사용한다.
  - idle_loot close interrupt cutoff는 6m에서 5m로 낮췄다.
  - spawn-only 후보 `C:\tmp\game_dev_playable_spawn_clearance_v1_3run`은 min nearest 5.0m를 만들었지만 enemy 5.6m objective_interrupt 100%라서 close cutoff까지 같이 조정했다.
  - 채택 후보 output: `C:\tmp\game_dev_opening_proximity_guard_v1_3run`
  - avg duration 360.7s, first acquisition 1.8s, first contact 2.6s, first damage 2.8s, first upgrade 29.4s, stage2 269.9s
  - first acquisition source는 objective_interrupt 66.7% / idle_reaction 33.3%
  - spawn fallback 0.0/run, min nearest 5.0m, avg-nearest 8.6m, saturation 0.42
  - zone deaths 0.3/run, stuck 0.11/entity/min, disengage 0.27/entity/min, AI avg 466.3us, sentinel clear, long-run scale gate 통과
- `N2-PACE-14` opening idle reaction grace:
  - IDLE 봇은 spawn 후 3초 동안 2m 밖 visible enemy acquisition을 미룬다.
  - 2m bump, 피격, 총성, recovery melee, objective interrupt 경로는 그대로 둔다.
  - 채택 후보 output: `C:\tmp\game_dev_opening_idle_reaction_grace_v1_3run`
  - avg duration 328.2s, first acquisition 2.6s, first contact 3.4s, first damage 3.4s, first upgrade 38.3s, stage2 280.5s
  - first acquisition source는 objective_interrupt 100.0%, idle_reaction 0.0%
  - first objective interrupt는 enemy 4.8m, objective 21.2m, source idle_loot, kind heal/armor, need ammo_low
  - spawn fallback 0.0/run, min nearest 5.0m, avg-nearest 8.6m, saturation 0.42
  - zone deaths 0, stuck 0.08/entity/min, disengage 0.29/entity/min, AI avg 531.6us, sentinel clear, long-run scale gate 통과
- `N2-PACE-15` opening loot safety guard:
  - spawn 후 3초 동안 5m 안 actor가 있으면 먼 idle-loot objective 시작을 미룬다.
  - 같은 opening window에서 idle-loot objective interrupt도 2m bump 밖이면 미룬다.
  - v1 `C:\tmp\game_dev_opening_loot_safety_v1_3run`은 first objective interrupt가 2.1s/enemy 4.8m로 남아 폐기했다.
  - 채택 후보 output: `C:\tmp\game_dev_opening_loot_safety_v2_3run`
  - avg duration 393.8s, first acquisition 5.9s, first contact 6.5s, first damage 6.5s, first upgrade 20.2s, stage2 280.9s, stage3 520.6s
  - first acquisition source는 idle_reaction 100.0%, distance 1.1m
  - first objective interrupt는 9.8s, enemy 8.3m, objective 14.1m, source idle_loot, kind armor/heal
  - spawn fallback 0.0/run, min nearest 5.0m, avg-nearest 8.8m, saturation 0.42
  - zone deaths 0.3/run, stuck 0.10/entity/min, disengage 0.26/entity/min, AI avg 514.7us, sentinel clear, long-run scale gate 통과
- `N2-PACE-16` opening bump reveal guard:
  - spawn clearance 5.7m / attempts 340 후보 `C:\tmp\game_dev_opening_bump_spacing_v1_3run`은 fallback 0이었지만 stuck/entity/min 0.16으로 scale gate를 실패해서 폐기했다.
  - IDLE 봇은 spawn 후 7초 동안 1-2m near-bump forced reveal을 미룬다. 1m hard bump, 피격, 총성, non-IDLE close reveal은 유지한다.
  - 채택 후보 output: `C:\tmp\game_dev_opening_bump_reveal_guard_v1_3run`
  - avg duration 458.8s, first acquisition 5.4s, first contact 6.0s, first damage 6.0s, first kill 16.9s, first upgrade 19.0s, stage2 270.6s, stage3 511.7s
  - first acquisition source는 objective_interrupt 100.0%, distance 2.9m
  - first objective interrupt는 5.4s, enemy 2.9m, objective 15.9m, source idle_loot, kind armor/weapon, need ammo_low
  - spawn fallback 0.0/run, min nearest 5.1m, avg-nearest 8.4m, saturation 0.42
  - zone deaths 0, stuck 0.06/entity/min, disengage 0.21/entity/min, AI avg 462.5us, sentinel clear, long-run scale gate 통과
- `N2-PACE-17` opening objective interrupt window:
  - idle-loot objective start safety는 3초로 유지하고, idle-loot objective interrupt safety만 7초 / 1m hard bump 기준으로 분리했다.
  - 채택 후보 output: `C:\tmp\game_dev_opening_objective_interrupt_window_v1_3run`
  - avg duration 345.6s, first acquisition 8.6s, first contact 9.2s, first damage 9.2s, first kill 18.6s, first upgrade 54.9s, stage2 268.4s
  - first acquisition source는 idle_reaction 100.0%, distance 5.4m
  - first objective interrupt는 28.6s, enemy 8.5m, objective 7.2m, source post_kill_loot/loot_retarget/idle_loot
  - spawn fallback 0.0/run, min nearest 5.0m, avg-nearest 8.6m, saturation 0.42
  - zone deaths 0.3/run, stuck 0.09/entity/min, disengage 0.27/entity/min, AI avg 420.0us, sentinel clear, long-run scale gate 통과
- `N2-PACE-18` opening idle reaction visual window:
  - 2m 밖 visible enemy에 대한 IDLE opening reaction window를 3초에서 10초로 늘렸다.
  - 1m hard bump, 1-2m near-bump 7초 guard, idle-loot interrupt 7초/1m guard, damage/gunshot/non-IDLE 경로는 유지한다.
  - 채택 후보 output: `C:\tmp\game_dev_opening_idle_reaction_window_v1_3run`
  - avg duration 577.1s, first acquisition 13.9s, first contact 14.3s, first damage 14.5s, first kill 26.0s, first upgrade 38.1s, stage2 281.3s, stage3 524.3s
  - first acquisition source는 objective_interrupt / idle_reaction / retreat_counteraction이 각각 33.3%, distance 4.1m
  - first objective interrupt는 27.4s, enemy 1.9m, objective 11.0m, source idle_loot
  - spawn fallback 0.0/run, min nearest 5.0m, avg-nearest 8.5m, saturation 0.42
  - zone deaths 0, stuck 0.07/entity/min, disengage 0.21/entity/min, AI avg 462.3us, sentinel clear, long-run scale gate 통과
- 다음 우선순위는 mixed opening acquisition context를 확인하는 것이다. 바로 combat damage, AI aggression, zone pacing, global perception 상수를 건드리지 않는다.

## 설계 가드레일

- 99인 후보를 기본 맵/기본 프리셋으로 승격하지 않는다.
- 봇에게 손전등, 배터리, 공포, 정전, cone-vs-cone 시뮬레이션을 아직 넣지 않는다.
- 현재 단계의 night awareness는 봇 viewer에만 적용되는 거리/확신도 기반 추상 인지 보정이어야 한다.
- `target_99_probe` telemetry는 최종 밸런스가 아니라 구조 안전성 게이트다.
- 수동 화면 검토는 `visual_review` 프리셋을 사용한다. `xlarge_60`/`target_99_probe`는 구조 부하 검증용이다.
- `plan_report/`는 참고용 로컬 디렉토리다. 사용자가 명시하기 전까지 커밋하지 않는다.
