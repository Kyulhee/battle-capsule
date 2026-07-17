# 테스트와 검증 가이드

> 최종 업데이트: 2026-07-18. 기준값을 낮춰 통과시키지 않는다. threshold 변경은 별도 결정이 필요하다.

## 원칙

- 가장 작은 검증 profile을 먼저 고른다.
- gameplay 변경은 단발 smoke만으로 닫지 않는다.
- structural gate 실패는 gate를 낮추지 말고 원인을 고친다.
- 모든 pacing 초 단위는 `Main.match_timer` 기준이다.
- N2-PACE-34 이전 시뮬레이션의 초 단위 결과는 현재 기준선으로 사용하지 않는다.
- headless player는 simulation 참가자가 아니라 observer다. alive/spawn/target 집계는 bot만 포함한다.
- `target_99_probe`는 체감 목표가 아니라 구조 안전망이다.

## 검증 프로필 진입점

```powershell
python tools\run_verify.py --profile docs_only
python tools\run_verify.py --profile tooling
python tools\run_verify.py --profile unit_smoke
python tools\run_verify.py --profile ai_test_arena
python tools\run_verify.py --profile pacing_v2
python tools\run_verify.py --profile pacing_v3
python tools\run_verify.py --profile pacing_candidate --pacing-preset playable_pacing_v4 --runs 5 --out-root C:\tmp\run_name
python tools\run_verify.py --profile pacing_candidate --pacing-preset playable_pacing_v5 --runs 5 --out-root C:\tmp\run_name
python tools\run_verify.py --profile scale_99 --runs 5
python tools\run_verify.py --profile visual_review
```

| 프로필 | 사용 시점 | 최소 판정 |
|---|---|---|
| `docs_only` | 문서/계획만 변경 | `git diff --check` |
| `tooling` | Python 분석/검증 도구 변경 | diff check + `py_compile` |
| `unit_smoke` | GDScript verifier 또는 작은 로직 변경 | 핵심 `tools/verify_*.gd`, Night/확장 map 구조 |
| `ai_test_arena` | AI 정책·테스트 맵·고정 스폰·격리 옵션 변경 | 결정/이동 정책 + 5개 preset + 실제 duel 공격 + squad 표적 기억·접촉률 |
| `pacing_v2` | v2 late-zone 기준 재확인 | 3-run + analyze/summarize + scale gate |
| `pacing_v3` | v3 first-upgrade 진단 후보 | 3-run + gate |
| `pacing_candidate` | 현재 후보 승격/회귀 판단 | unit smoke + 최소 5-run + duration/upgrade gate |
| `scale_99` | 99명 구조 변경 | 확장 Night 후보 `target_99_probe` 최소 5-run + scale gate |
| `visual_review` | UI/가독성/체감 변경 | Night/player, 전체맵/미니맵 capture + 1-run + `PLAYTEST.md` 기록 |

## 현재 pacing candidate gate

`pacing_candidate`는 다음을 요구한다.

- 최소 run 수: 5
- avg duration: 540초 이상
- avg first upgrade: 120초 이상
- missing first-upgrade run: 0
- scale sentinel PASS

현재 canonical 기준선:

- v5 bot-only 5-run: 평균 duration 434.7초, 범위 271.0-655.5초, first upgrade 222.8초, stage2 220.1초, stage3 590.1초.
- spawn 99/99와 ATTACK 최대 16.0초는 통과했지만 duration과 normalized stuck 0.21은 실패했다.

N2-PACE-34 이전 결과와 N2-PACE-35 player 참가 결과는 weapon/source 맥락만 참고하고 현재 duration/stuck 기준선으로 사용하지 않는다.

`playable_pacing_v5`는 N2-PACE-33의 비기본 duration 가설이다. profile 최소 gate와 별도로 제품 판정은 평균 600-900초와 개별 run 분산을 함께 본다.

- 판정: bot-only damage 동작 가설은 유지하지만 canonical duration gate 실패로 기본 승격을 보류한다.

좁은 구조 수정은 해당 구조 gate가 개선되고 회귀 검증을 통과하면 채택할 수 있다. 이때 unrelated pacing gate 실패를 숨기지 않으며 전체 후보는 승격하지 않는다.

고정 seed는 결과 재현 보장이 아니다. `simulate_matches.py`는 seed를 JSON에 남겨 입력을 추적하지만 physics/timer 순서가 달라질 수 있으므로 최소 5-run 분포로 판단한다. `seed_base=41000`처럼 실행 입력을 명시할 수 있다.

## 자주 쓰는 직접 검증

```powershell
git diff --check
python -m py_compile tools\analyze_results.py tools\summarize_pacing_baseline.py tools\check_scale_telemetry.py tools\simulate_matches.py tools\run_verify.py
.\Godot_v4.6.2-stable_win64_console.exe --headless --path . --script res://tools/verify_pacing_telemetry.gd
.\Godot_v4.6.2-stable_win64_console.exe --headless --path . --script res://tools/verify_playable_pacing_preset.gd
.\Godot_v4.6.2-stable_win64_console.exe --headless --path . --script res://tools/verify_zone_initial_radius_tuning.gd
.\Godot_v4.6.2-stable_win64_console.exe --headless --path . --script res://tools/verify_bot_opening_loot_rules.gd
.\Godot_v4.6.2-stable_win64_console.exe --headless --path . --script res://tools/verify_bot_decision_policy.gd
.\Godot_v4.6.2-stable_win64_console.exe --headless --path . --script res://tools/verify_bot_movement_policy.gd
.\Godot_v4.6.2-stable_win64_console.exe --headless --path . --script res://tools/verify_ai_test_arena.gd
.\Godot_v4.6.2-stable_win64_console.exe --headless --path . --script res://tools/verify_mission_health_rules.gd
```

AI 오류를 짧게 재현할 때는 제품 맵 대신 72m 전용 표면을 먼저 쓴다.

```powershell
.\Godot_v4.6.2-stable_win64_console.exe --path . -- map_spec_path=res://data/mapSpec_ai_test_arena.json scale_preset=duel_1 debug_flags=ai,perception,nav
```

`duel_1`은 4.5m 고정 1대1과 초기 loot 격리, `squad_4`는 다중 위협, `systems_8`은 loot 포함 8봇 상태 전이, `random_8`은 고정 스폰 의존성 비교용이다. Arena 통과는 재현·회귀 근거이며 Night gameplay 승격 근거가 아니다.

`ai_test_arena` profile은 실제 `Main.tscn`도 실행한다. `duel_1` 봇이 3초 안에 플레이어를 획득하고 피해를 주지 못하면 실패한다.

`squad_4`는 자연 행동을 2초 계측한 뒤 교차 피해, peripheral switch, combat-loot, sniper 최소 사거리를 강제 구간에서만 격리한다. 강제 구간은 두 봇을 1.1m 간격에 두고 같은 strafe 계획을 준다. 0.75초 안에 1.5m 밖으로 분리되고 이후 근접 쌍 샘플이 2% 이하이며, 3초 동안 player 표적 유지와 최소 세 봇 공격이 함께 통과해야 한다. 자연 다자전 수치는 진단 출력이며 Night gameplay 승격 근거가 아니다.

## 시뮬레이션 분석

```powershell
python tools\simulate_matches.py 5 map_spec_path=res://data/mapSpec_night_forest_candidate.json scale_preset=playable_pacing_v4 seed_base=41000 out_dir=C:\tmp\manual_run
python tools\analyze_results.py C:\tmp\manual_run
python tools\analyze_map_structure.py data\mapSpec_night_forest_candidate.json --preset visual_review
python tools\analyze_map_structure.py data\mapSpec_night_forest_expanded_candidate.json --preset target_99_probe
python tools\summarize_pacing_baseline.py C:\tmp\manual_run
python tools\check_scale_telemetry.py C:\tmp\manual_run --min-runs 5 --min-avg-duration 540 --min-run-duration 300 --max-run-duration 1200 --min-avg-first-upgrade 120 --max-missing-first-upgrade 0
```

## 회귀 신호

- zero total damage / zero weapon damage / zero shot / zero combat plan.
- spawn fallback 발생.
- stuck/disengage per spawned entity/min 급증.
- AI update budget 과도한 상승.
- no first upgrade가 5-run에서 반복.
- stage3가 사라지거나 avg duration이 gate 아래로 떨어짐.
- `attack_max_continuous` 단일 run 이상치와 최종 생존 수 정체.
- `deaths_by_stage`가 stage1에 과도하게 집중.

## 시각 검증

`visual_review`는 화면 상태 후보를 위한 profile이다.

```powershell
python tools\run_verify.py --profile visual_review --out-root C:\tmp\visual_review_run
```

캡처는 `C:\tmp\player_night_readability.png`, `C:\tmp\full_map_orientation.png`, `C:\tmp\minimap_orientation.png`에 생성된다. 결과는 `PLAYTEST.md`에 짧게 남긴다.

이 profile의 8봇 simulation은 화면 상태 확인용이며 encounter 빈도나 99봇 gameplay 판정에 사용하지 않는다.

확장 후보의 지도와 실제 런타임 화면은 별도로 캡처할 수 있다.

```powershell
.\Godot_v4.6.2-stable_win64_console.exe --path . --script res://tools/capture_map_orientation.gd -- map_spec_path=res://data/mapSpec_night_forest_expanded_candidate.json scale_preset=xlarge_60 output_tag=expanded_candidate
.\Godot_v4.6.2-stable_win64_console.exe --path . --script res://tools/capture_runtime_candidate.gd -- map_spec_path=res://data/mapSpec_night_forest_expanded_candidate.json scale_preset=xlarge_60 capture_output=C:/tmp/runtime_expanded_candidate.png
```
