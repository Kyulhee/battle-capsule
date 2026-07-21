# 테스트와 검증 가이드

> 최종 업데이트: 2026-07-20. 기준값을 낮춰 통과시키지 않는다. threshold 변경은 별도 결정이 필요하다.

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
python tools\run_verify.py --profile pacing_candidate --map-spec-path res://data/mapSpec_night_forest_candidate.json --pacing-preset playable_pacing_v4 --runs 5 --out-root C:\tmp\run_name
python tools\run_verify.py --profile pacing_candidate --map-spec-path res://data/mapSpec_night_forest_candidate.json --pacing-preset playable_pacing_v5 --runs 5 --out-root C:\tmp\run_name
python tools\run_verify.py --profile scale_99 --runs 5
python tools\run_verify.py --profile visual_review
```

| 프로필 | 사용 시점 | 최소 판정 |
|---|---|---|
| `docs_only` | 문서/계획만 변경 | `git diff --check` |
| `tooling` | Python 분석/검증 도구 변경 | diff check + `py_compile` |
| `unit_smoke` | GDScript verifier 또는 작은 로직 변경 | 핵심 `tools/verify_*.gd`, Night/확장 map 구조, catalog 오디오 |
| `ai_test_arena` | AI 정책·테스트 맵·고정 스폰·격리 옵션 변경 | 결정/이동 정책 + 8개 preset + duel/high rock + open/wall 4봇 traffic + squad |
| `pacing_v2` | v2 late-zone 기준 재확인 | 3-run + analyze/summarize + scale gate |
| `pacing_v3` | v3 first-upgrade 진단 후보 | 3-run + gate |
| `pacing_candidate` | 현재 후보 승격/회귀 판단 | unit smoke + 최소 5-run + duration/upgrade gate |
| `scale_99` | 99명 구조 변경 | 확장 Night 후보 `target_99_probe` 최소 5-run + scale gate |
| `visual_review` | UI/가독성/체감 변경 | Night/player, 전체맵/미니맵 capture + 1-run + `PLAYTEST.md` 기록 |

## 현재 pacing candidate gate

`pacing_candidate`는 다음을 요구한다.

- 명시적 `--map-spec-path`: 후보와 다른 기본 맵으로 실행되는 일을 금지
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
.\Godot_v4.6.2-stable_win64_console.exe --headless --path . --script res://tools/verify_audio_catalog_assets.gd
.\Godot_v4.6.2-stable_win64_console.exe --headless --path . --script res://tools/verify_mission_health_rules.gd
```

AI 오류를 짧게 재현할 때는 제품 맵 대신 96m 전용 표면을 먼저 쓴다.

```powershell
.\Godot_v4.6.2-stable_win64_console.exe --path . -- map_spec_path=res://data/mapSpec_ai_test_arena.json scale_preset=duel_1 debug_flags=ai,perception,nav
```

`duel_1`은 4.5m 고정 1대1, `rock_nav_1`은 high rock 양쪽 24m 횡단, `open_traffic_4`/`wall_traffic_4`는 open 기준과 축 정렬 Box 우회의 4봇 비교, `squad_4`는 다중 위협용이다. wall traffic은 플레이어 접근 거리가 아니라 모든 봇이 벽 북쪽 `z=35`를 12초 안에 통과하고 stuck 4 이하인지 본다. Arena 통과는 재현·회귀 근거이며 Night gameplay 승격 근거가 아니다.

`ai_test_arena` profile은 실제 `Main.tscn`도 실행한다. runtime navmesh가 비거나 `duel_1`이 3초 안에 플레이어를 공격하지 못하면 실패한다. `unit_smoke`의 실제 확장 맵 `nav_hotspot_1`은 Minimap 하위 충돌체 0개, 8초 내 ZONE_ESCAPE 종료, stuck 1 이하를 요구한다.

`squad_4`는 자연 행동을 2초 계측한 뒤 교차 피해, peripheral switch, combat-loot, sniper 최소 사거리를 강제 구간에서만 격리한다. 강제 구간은 두 봇을 1.1m 간격에 두고 같은 strafe 계획을 준다. 0.75초 안에 1.5m 밖으로 분리되고 이후 근접 쌍 샘플이 2% 이하이며, 3초 동안 player 표적 유지와 최소 세 봇 공격이 함께 통과해야 한다. 자연 다자전 수치는 진단 출력이며 Night gameplay 승격 근거가 아니다.

`verify_audio_catalog_assets.gd`는 핵심 오디오 11종의 파일 존재, raw WAV/OGG 로딩, ID별 캐시 재사용과 catalog 누락 0을 요구한다. 총성은 0.05-1.0초, 칼 휘두름은 0.35초 미만, 피격음은 0.60초 미만이어야 한다. 권총 -8.5dB가 AR -6dB보다 작고 칼 피격 -4.5dB가 휘두름 -7.5dB보다 분명해야 한다. 평상시 발걸음은 유지하되 앉기 상태만 -10dB를 추가 감쇠한다.

`verify_cover_classes.gd`는 `hard`가 시야·탄도를, `screen`이 시야만, `soft`가 둘 다 막지 않는 물리 계약을 작은 합성 월드에서 검사한다. `verify_world_prop_assets.gd`는 Cabin Row 프롭 수와 실제 cover class/layer, visual-only fire pit collision, 지면 10구역의 지도 feature와 재질별 병합을 검사한다. 지면 렌더 노드는 최대 3개여야 하며 현재 후보는 grass/path 2개다.

`verify_night_cabin_compound_nav.gd`는 실제 Night NavMesh에서 Cabin Row 남·서·동 입구가 중앙 마당까지 연결되고 과도한 우회가 없는지 검사한다.

`verify_bot_strategic_movement_policy.gd`는 비전투 봇이 현재 POI와 존 밖 후보를 제외하고, POI 점유가 높으면 다른 지역으로 분산하며 성향별 objective/entry/outer 앵커를 고르는지 검사한다. 실제 확장 맵 `nav_hotspot_1`은 존 탈출 뒤 전략 POI 목적지도 생성해야 한다. 유효한 목적지는 도착하거나 존 밖이 될 때까지 유지하며 전역 pickup/actor 재탐색을 추가하지 않는다.

`verify_bot_engagement_saturation_runtime.gd`는 이미 포화된 표적에서 먼 방어형 봇은 합류를 보류하고, 그 표적이 자신을 추적하면 즉시 대응하는지 3봇 소형 런타임에서 검사한다. `squad_4`는 10m 안 근접 조우와 강제 표적에서 4봇 모두 플레이어 대응을 유지해야 한다.

미니맵은 Main HUD가 하나만 소유한다. 상시 지도는 플레이어 중심 120m를 280px에 표시하고, 768px 정적 캐시는 `UPDATE_ONCE`여야 한다. `M` 전체 지도는 전역 방향·존 판단을 유지한다.

## 시뮬레이션 분석

```powershell
python tools\simulate_matches.py 5 map_spec_path=res://data/mapSpec_night_forest_candidate.json scale_preset=playable_pacing_v4 seed_base=41000 out_dir=C:\tmp\manual_run
python tools\analyze_results.py C:\tmp\manual_run
python tools\analyze_map_structure.py data\mapSpec_night_forest_candidate.json --preset visual_review
python tools\analyze_map_structure.py data\mapSpec_night_forest_expanded_candidate.json --preset target_99_probe
python tools\summarize_pacing_baseline.py C:\tmp\manual_run
python tools\check_scale_telemetry.py C:\tmp\manual_run --min-runs 5 --min-avg-duration 540 --min-run-duration 300 --max-run-duration 1200 --min-avg-first-upgrade 120 --max-missing-first-upgrade 0
python tools\compare_scale_profiles.py C:\tmp\parent_control C:\tmp\candidate --baseline-label parent --target-label candidate
.\Godot_v4.6.2-stable_win64_console.exe --path . --script res://tools/profile_runtime_performance.gd -- map_spec_path=res://data/mapSpec_night_forest_expanded_candidate.json scale_preset=xlarge_60 perf_warmup_seconds=5 perf_sample_seconds=20 perf_output=C:/tmp/runtime_performance.json
```

AI 이동처럼 규모에 민감한 변경은 부모 커밋 worktree와 현재 후보를 같은 맵·preset·seed base로 각각 최소 5회 실행한다. seed별 결과 일치를 기대하지 않고 종료 분포, 개체·분 기준 stuck/disengage, AI 평균·최대 비용을 함께 비교한다.

`profile_runtime_performance.gd`는 headless가 아닌 Forward+ 실행에서 frame/process/physics/navigation, draw call, collision pair, pipeline compile, AI 비용을 JSON으로 남긴다. 같은 조건을 최소 2회 반복하며 `perf_hide_minimap=true`는 UI 병목 대조에만 쓴다. N2-UI-01까지의 기준은 p95 13.3-14.2ms, p99 16.5-19.2ms, 33ms 초과 0.06-0.15%다.

맵 엄폐 후보는 구조 분석만으로 승격하지 않는다. `analyze_map_structure.py`로 빈 셀·방사 대역·POI 개방률을 확인한 뒤 60/99봇 각 5-run의 spawn fallback, stuck, POI/route 피해와 Forward+ 2회를 비교하고, 고정 좌표 실제 카메라 캡처와 `PLAYTEST.md` 수동 판정을 함께 남긴다.

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
