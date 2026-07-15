# 테스트와 검증 가이드

> 최종 업데이트: 2026-07-16. 기준값을 낮춰 통과시키지 않는다. threshold 변경은 별도 결정이 필요하다.

## 원칙

- 가장 작은 검증 profile을 먼저 고른다.
- gameplay 변경은 단발 smoke만으로 닫지 않는다.
- structural gate 실패는 gate를 낮추지 말고 원인을 고친다.
- `first_upgrade` threshold는 game-time 기준이다.
- `target_99_probe`는 체감 목표가 아니라 구조 안전망이다.

## 검증 프로필 진입점

```powershell
python tools\run_verify.py --profile docs_only
python tools\run_verify.py --profile tooling
python tools\run_verify.py --profile unit_smoke
python tools\run_verify.py --profile pacing_v2
python tools\run_verify.py --profile pacing_v3
python tools\run_verify.py --profile pacing_candidate --pacing-preset playable_pacing_v4 --runs 3 --out-root C:\tmp\run_name
python tools\run_verify.py --profile pacing_candidate --pacing-preset playable_pacing_v5 --runs 3 --out-root C:\tmp\run_name
python tools\run_verify.py --profile scale_99
python tools\run_verify.py --profile visual_review
```

| 프로필 | 사용 시점 | 최소 판정 |
|---|---|---|
| `docs_only` | 문서/계획만 변경 | `git diff --check` |
| `tooling` | Python 분석/검증 도구 변경 | diff check + `py_compile` |
| `unit_smoke` | GDScript verifier 또는 작은 로직 변경 | 핵심 `tools/verify_*.gd` |
| `pacing_v2` | v2 late-zone 기준 재확인 | 3-run + analyze/summarize + scale gate |
| `pacing_v3` | v3 first-upgrade 진단 후보 | 3-run + gate |
| `pacing_candidate` | 현재 후보 승격/회귀 판단 | unit smoke + 3-run + duration/upgrade gate |
| `scale_99` | 99명 구조 변경 | `target_99_probe` 3-run + scale gate |
| `visual_review` | UI/가독성/체감 변경 | capture 또는 1-run + `PLAYTEST.md` 기록 |

## 현재 pacing candidate gate

`pacing_candidate`는 다음을 요구한다.

- 최소 run 수: 3
- avg duration: 540초 이상
- avg first upgrade: 120초 이상
- missing first-upgrade run: 0
- scale sentinel PASS

`playable_pacing_v4` 최신 기준:

- N2-PACE-30: avg duration 599.6초, first upgrade 294.9초, stage3 654.2초.
- N2-PACE-32: avg duration 554.3초, first contact 17.7초, first upgrade 293.9초, stage3 655.7초.

`playable_pacing_v5`는 N2-PACE-33의 비기본 duration 후보다. profile 최소 gate와 별도로 제품 판정은 평균 600-900초와 개별 run 분산을 함께 본다.

- N2-PACE-33: avg duration 689.0초, 범위 336.2-1219.9초, first upgrade 285.5초, stage2 283.4초, stage3 654.2초.
- 판정: 자동 gate PASS, 평균 목표 PASS, 분산 안정화 전 기본 승격 보류.

## 자주 쓰는 직접 검증

```powershell
git diff --check
python -m py_compile tools\analyze_results.py tools\summarize_pacing_baseline.py tools\check_scale_telemetry.py tools\simulate_matches.py tools\run_verify.py
.\Godot_v4.6.2-stable_win64_console.exe --headless --path . --script res://tools/verify_pacing_telemetry.gd
.\Godot_v4.6.2-stable_win64_console.exe --headless --path . --script res://tools/verify_playable_pacing_preset.gd
.\Godot_v4.6.2-stable_win64_console.exe --headless --path . --script res://tools/verify_zone_initial_radius_tuning.gd
.\Godot_v4.6.2-stable_win64_console.exe --headless --path . --script res://tools/verify_bot_opening_loot_rules.gd
.\Godot_v4.6.2-stable_win64_console.exe --headless --path . --script res://tools/verify_mission_health_rules.gd
```

## 시뮬레이션 분석

```powershell
python tools\simulate_matches.py 3 map_spec_path=res://data/mapSpec_night_forest_candidate.json scale_preset=playable_pacing_v4 out_dir=C:\tmp\manual_run
python tools\analyze_results.py C:\tmp\manual_run
python tools\summarize_pacing_baseline.py C:\tmp\manual_run
python tools\check_scale_telemetry.py C:\tmp\manual_run --min-runs 3 --min-avg-duration 540 --min-avg-first-upgrade 120 --max-missing-first-upgrade 0
```

## 회귀 신호

- zero total damage / zero weapon damage / zero shot / zero combat plan.
- spawn fallback 발생.
- stuck/disengage per spawned entity/min 급증.
- AI update budget 과도한 상승.
- no first upgrade가 3-run에서 반복.
- stage3가 사라지거나 avg duration이 gate 아래로 떨어짐.

## 시각 검증

`visual_review`는 수동 체감 후보를 위한 profile이다.

```powershell
python tools\run_verify.py --profile visual_review --out-root C:\tmp\visual_review_run
```

캡처는 보통 `C:\tmp\player_night_readability.png`에 생성된다. 결과는 `PLAYTEST.md`에 짧게 남긴다.
