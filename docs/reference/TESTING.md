# 테스트와 검증 가이드

> 최종 업데이트: 2026-08-09. 기준값을 낮춰 통과시키지 않는다. threshold 변경은 별도 결정이 필요하다.

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
python tools\run_verify.py --profile pacing_candidate --map-spec-path res://data/mapSpec_night_forest_expanded_candidate.json --pacing-preset night_br_m1_60 --runs 5 --out-root C:\tmp\run_name
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
| `scale_99` | 99명 구조 변경 | 확장 Night `target_99_probe`, 입력 41000-41004 최소 5-run + 개체·분 scale gate |
| `visual_review` | UI/가독성/체감 변경 | Night/player, 전체맵/미니맵 capture + 1-run + `PLAYTEST.md` 기록 |

## 현재 pacing candidate gate

`pacing_candidate`는 다음을 요구한다.

- 명시적 `--map-spec-path`: 후보와 다른 기본 맵으로 실행되는 일을 금지
- 최소 run 수: 5
- avg duration: 600-900초
- 개별 duration: 480-960초
- avg first upgrade: 2-30초
- missing first-upgrade run: 0
- scale sentinel PASS

과거 비교 기준선:

- v5 bot-only 5-run: 평균 duration 434.7초, 범위 271.0-655.5초, first upgrade 222.8초, stage2 220.1초, stage3 590.1초.
- spawn 99/99와 ATTACK 최대 16.0초는 통과했지만 duration과 normalized stuck 0.21은 실패했다.

N2-PACE-34 이전 결과와 N2-PACE-35 player 참가 결과는 weapon/source 맥락만 참고하고 현재 duration/stuck 기준선으로 사용하지 않는다.

현재 canonical 표면은 `night_br_m1_60`이다. N2-MAP-17 최종 5-run은 평균 787.2초, 범위 688.1-855.1초, first upgrade 4.9초, 정체/이탈 0.01/0.18 per spawned entity/min, AI 평균 322.3µs로 gate를 통과했다. 이 자동 분포는 수동 장소·전투 체감이나 `target_99_probe` 승격을 대신하지 않는다.

`scale_99`는 입력 추적값 41000-41004를 사용하고 match 길이와 무관하게 stuck/disengage를 spawned entity/min 0.15/0.45로 판정한다. raw count는 진단값이다. 이는 threshold 완화가 아니라 300초 경계의 단위 불연속 제거이며, 과거 확장 후보 0.47은 실패하고 현재 후보 0.44는 통과한다. 최신 5-run은 평균 239.1초, spawn 99/99·fallback 0, stuck/disengage 0.01/0.44, AI 평균 519.6µs로 구조 gate를 통과했다.

좁은 구조 수정은 해당 구조 gate가 개선되고 회귀 검증을 통과하면 채택할 수 있다. 이때 unrelated pacing gate 실패를 숨기지 않으며 전체 후보는 승격하지 않는다.

고정 seed는 결과 재현 보장이 아니다. `simulate_matches.py`는 seed를 JSON에 남겨 입력을 추적하지만 physics/timer 순서가 달라질 수 있으므로 최소 5-run 분포로 판단한다. `seed_base=41000`처럼 실행 입력을 명시할 수 있다.

## 자주 쓰는 직접 검증

```powershell
git diff --check
python -m py_compile tools\analyze_results.py tools\summarize_pacing_baseline.py tools\check_scale_telemetry.py tools\simulate_matches.py tools\run_verify.py
.\Godot_v4.6.2-stable_win64_console.exe --headless --path . --script res://tools/verify_pacing_telemetry.gd
.\Godot_v4.6.2-stable_win64_console.exe --headless --path . --script res://tools/verify_release_identity.gd
.\Godot_v4.6.2-stable_win64_console.exe --headless --path . --script res://tools/verify_release_persistence.gd
.\Godot_v4.6.2-stable_win64_console.exe --headless --path . --script res://tools/verify_settings_manager.gd
.\Godot_v4.6.2-stable_win64_console.exe --headless --path . --script res://tools/verify_playable_pacing_preset.gd
.\Godot_v4.6.2-stable_win64_console.exe --headless --path . --script res://tools/verify_zone_initial_radius_tuning.gd
.\Godot_v4.6.2-stable_win64_console.exe --headless --path . --script res://tools/verify_bot_opening_loot_rules.gd
.\Godot_v4.6.2-stable_win64_console.exe --headless --path . --script res://tools/verify_bot_decision_policy.gd
.\Godot_v4.6.2-stable_win64_console.exe --headless --path . --script res://tools/verify_bot_movement_policy.gd
.\Godot_v4.6.2-stable_win64_console.exe --headless --path . --script res://tools/verify_ai_test_arena.gd
.\Godot_v4.6.2-stable_win64_console.exe --headless --path . --script res://tools/verify_audio_catalog_assets.gd
.\Godot_v4.6.2-stable_win64_console.exe --headless --path . --script res://tools/verify_mission_health_rules.gd
```

## 패키지 경계 검증

export된 PCK는 workspace와 분리된 빈 host directory에 mount해 검사한다.

```powershell
$ProbePath = "C:\tmp\empty_release_probe"
$VerifierPath = (Resolve-Path "tools\verify_release_package.gd").Path
$PckPath = (Resolve-Path "C:\tmp\release\BattleCapsule.pck").Path
New-Item -ItemType Directory -Force -Path $ProbePath | Out-Null
.\Godot_v4.6.2-stable_win64_console.exe --headless --path $ProbePath --script $VerifierPath -- "pck_path=$PckPath"
```

`verify_release_package.gd`는 catalog 자산 44개(20 PNG·11 audio·13 GLB), 검토된 JSON 3개, runtime 논리 경로 124개, 핵심 load probe 20개가 PCK에서 실제 load되고 import/remap generated payload closure가 exact인지 검사한다. test/probe/tool/doc 경로도 없어야 한다. packaged headless 전체 simulation 통과는 UI·입력·가독성·정상 기록 생성·OS/해상도 matrix를 대신하지 않는다.

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

`verify_night_west_ridge_nav.gd`는 West Ridge의 노출 도로와 숲 우회가 감시탑 옆 AI 목표까지 각각 연결되는지 검사한다.

`verify_night_micro_compound_nav.gd`는 활성 맵의 Brush Camp·Survey Camp 앵커 ID를 직접 읽고, 목표와 6개 진입 앵커의 중심, 실제 AI가 쓰는 jitter 반경 35/65/95%, 선언 경계 100%를 각 12방향으로 실제 NavMesh에 대조한다. 각 샘플 snap은 0.35m 이하, 경로 우회비는 2.2 이하이어야 하며 Brush Camp 서쪽 진입은 실제 1봇이 8초 안에 목표 3m 안으로 도착하고 stuck 0이어야 한다.

`verify_bot_strategic_movement_policy.gd`는 비전투 봇이 현재 POI와 존 밖 후보를 제외하고, POI 점유가 높으면 다른 지역으로 분산하며 성향별 objective/entry/outer 앵커를 고르는지 검사한다. 실제 확장 맵 `nav_hotspot_1`은 존 탈출 뒤 전략 POI 목적지도 생성해야 한다. 유효한 목적지는 도착하거나 존 밖이 될 때까지 유지하며 전역 pickup/actor 재탐색을 추가하지 않는다.

`verify_bot_engagement_saturation_runtime.gd`는 이미 포화된 표적에서 먼 방어형 봇은 합류를 보류하고, 그 표적이 자신을 추적하면 즉시 대응하는지 3봇 소형 런타임에서 검사한다. `squad_4`는 10m 안 근접 조우와 강제 표적에서 4봇 모두 플레이어 대응을 유지해야 한다.

미니맵은 Main HUD가 하나만 소유한다. 상시 지도는 플레이어 중심 120m를 280px에 표시하고, 768px 정적 캐시는 `UPDATE_ONCE`여야 한다. `M` 전체 지도는 전역 방향·존 판단을 유지한다.

## 시뮬레이션 분석

초기 유효 보급은 `audit_initial_loot_runtime.gd`에 명시적 M1 맵/preset, `simulation_seed=41000`, 새 `audit_output=C:/test/game_dev/builds/verification/loot_audit/run.json`을 전달해 검사한다. 실제 `Main.start_game()` 직후 physics 이전의 총·탄종·발 수·POI/3m 호환 여부를 출력한다. 같은 묶음이 여러 총의 존재 지표에 포함될 수 있으며 경로 접근성/고갈 시간/생존을 뜻하지 않는다. 강제 player 수집/업그레이드 재현은 자연 플레이 빈도와 분리하고 최신 수동 결과를 저장하지 않는다. `verify_loot_flow_audit.gd`와 `verify_player_ammo_retention.gd`는 `unit_smoke`에 포함된다.

`probe_loot_flow_runtime.gd`는 같은 Main을 bot-only로 시작해 0/120/260초 재고·보유 탄약·위치·점유/전략 목적지를 저장하고 매치를 끝까지 실행한다. `autostart=true`는 전달하지 않는다. M1 맵/preset·seed와 서로 다른 새 절대 경로 `flow_output=.../flow/run_1.json`, `result_output=.../results/run_1.json`이 필수다. Telemetry 출력 경로를 바꾸므로 최신 수동 결과를 덮어쓰지 않는다. `initial_only=true`는 초기 배치만, `loot_match_candidate=true`는 Central Meadow/Survey Camp의 호환 탄약 후보만 켠다. 제품 맵 기본 플래그는 없다.

첫 probe는 대조/후보 순차 실행으로 방향만 본다. 승격 검증은 각각 별도 5-run의 같은 입력 41000-41004를 쓰고 완료·누락 checkpoint·실제 관측 시각·인원 일치를 확인한다. `results/`만 기존 pacing/scale 분석기에 전달한다. flow의 `ammo_without_initial_weapon`은 집계기 재사용으로 **해당 시점 필드 총**의 부재를 뜻하며 보유 총의 탄약 사용 가능성과는 다르다. `no_long_gun`은 무장 해제가 아니라 권총 이하를 포함하고, `low_loaded_no_reserve`는 `no_ammo`와 중첩한다. 위치 표본은 이동 거리/체류 시간 적분이나 사람 부족 시간의 근거가 아니다.

flow schema v2(E-069)는 현재/다음 존, 계획한 존 stage·목표 거리, `holding_preposition_geometry`, HP 비율·사후 탐색 여부, 가장 가까운 필드 호환 탄약 거리를 추가한다. 기존 계획/위치만 읽으며 새 AI 판단·LOS/nav query는 호출하지 않는다. 호환 탄약 부재는 거리 `null`로 쓰고, 거리는 2D 직선이지 가시성/안전/경로 도달의 증거가 아니다. 도착 기하가 참이어도 적 반응 등 앞선 분기가 실행될 수 있어 실제 대기 분기나 체류 시간으로 집계하지 않는다. v1 반복 결과와 v2 단발 sanity는 별도 분포로 유지한다.

schema v3(E-070)의 `trace_progress=true progress_window_only=true`는 **실시간 260초 진단 창**이다. 같은 필수 맵/preset/seed/별도 출력 경로를 전달하며 상태 episode·회복 하위 상태·아이템 목표/캐시·전략 목표/위치를 1초 간격으로 읽는다. 창 종료 시 flow만 저장하고 매치를 중단하므로 result 파일은 생성하지 않으며 pacing/scale run 수에 포함하지 않는다. `initial_only`와 동시 사용은 거부한다. `trace_progress=true` 단독은 기존 5배 가속 전체 매치지만 초반 관측 지연이 반복되어 정밀 진행 근거로 사용하지 않는다.

E-071 `loot_progress_candidate=true`는 같은 probe에서만 봇의 진행 기반 추적 제한을 켠다. E-068 `loot_match_candidate=true`와 혼합은 거부한다. 제품 기본값은 기존 5초이며 후보는 최단 목표 거리 0.5m 개선 때 정체 시계를 갱신하고, 5초간 진전 없음 또는 총15초 초과 시 기존 재탐색/포기 분기를 사용한다. 수집 반경2.5m 안은 수집을 우선한다. 직선 거리 기준이라 길게 멀어지는 우회는 여전히 포기할 수 있다. 추가 전역 탐색·LOS·nav query는 없다.

`verify_bot_loot_progress.gd`는 실제 chase/start/finish/수집 분기에 결정적 이동·지각 fixture를 연결해 30m 대조 포기/후보 수집, 정체·미세 왕복·총시간 상한·도착·목표 교체·목표 삭제·적 반응 우선순위를 검사하며 `unit_smoke`에 포함된다. 이동 fixture 통과는 NavMesh/안전한 수집 증명이 아니므로 실제 M1 실행을 별도로 확인한다. 기본 승격은 대조/후보 각각 5-run과 수동 판정 뒤에만 한다.

E-072 `trace_ai_phases=true`는 같은 probe의 선택적 성능 진단이다. 기존 4회당1회 AI 계측에서 준비·상태 override/stuck·감지/label·상태 handler·Entity 이동/감지·시각·보고 구간을 나눈다. 전체와 같은 종료 시각을 쓰고, 5ms 이상 표본 수·50ms 초과 수·가장 느린32개를 기록한다. sink 저장 비용은 AI timer 밖에 있으므로 계측 실행을 비계측 pacing 승격 run으로 세지 않는다. 시작/handler 진입/종료 상태는 구분하며 `entity_movement`에는 Entity의 perception 갱신도 포함된다. CPU 작업과 OS 스케줄링/중단을 이 값만으로 구분할 수 없다.

`python tools/analyze_ai_phases.py <flow.json> <result.json>`은 완료·전체 표본 수·최대 시간·구간 합계·32개 상한/누락 수·시각/상태/후보 맥락을 검증한다. 정상 JSON 출력을 성능 PASS로 읽지 않는다. `max_gate_pass`와 별도 `check_scale_telemetry.py`의 기존50ms 기준을 유지하고 이전 실패를 제외하지 않는다. 합성6ms handler 지연 배선 검증은 `verify_ai_phase_runtime.gd`, 저장 상한은 `verify_ai_phase_audit.gd`, 파일 분석 검증은 tooling에 포함된다.

E-074부터 진단 OFF에서는 `AiPhaseAudit` 스크립트를 로드하거나 객체를 만들지 않으며 ON에서도 봇 생성 뒤에만 로드한다. ID 기반 조향/엄폐 선택 때문에 초기 비교에서 actor ID를 제거하면 안 된다. `verify_ai_phase_probe.py --godot <console.exe>`는 실제 probe의 OFF/ON/loot 후보 초기 스냅샷을 ID까지 exact 비교하고 OFF의 미로드·미생성을 검사한다(`unit_smoke` 포함). 부모 소스와의 비교는 별도 사전 검증한다. 초기 일치는 전체 매치의 결정적 재현이나 계측 ON의 실행 중 중립성을 보장하지 않는다. E-073의 오염된4+4는 보존하되 승격 근거에서 제외한다.

재고 비교는 관측 지연뿐 아니라 양군의 `zone_stage`/`zone_shrinking`도 일치해야 한다. E-074의260초는 대조4판만 stage2 wave 생성 이후를 읽어184~186개 추가 아이템이 섞였다. 0.25초 이내 시각 검사를 통과해도 이러한 재고 평균을 직접 비교하지 않는다. 같은 시각의 생존 관측, 동일 phase의 재고, 전체 매치 gate를 별도 판정하고 경계 불일치 원시 자료를 버리거나 phase가 맞는 한 쌍만5-run 근거로 쓰지 않는다.

`python tools/analyze_loot_progress.py <flow.json>`은 0-260초 261개 표본, 시각 순서/0.25초 이내 관측 지연, 인원/ID 중복, 기존 0/120/260초 checkpoint를 검사한다. 상태별 빈 탄약 표본·재무장 관측·같은 목표/episode 내 직선 접근량·동일 아이템 재추적을 출력하며 지연/누락은 실패시킨다. 인접 표본 사이 재무장/재소진이나 빠른 상태 전환은 놓칠 수 있다. 상태 체류 시간·실제 경로 길이·추적 중단 이유·가시성으로 단정하지 않는다. `tooling`과 `unit_smoke`에 불변성/회복/목표 교체/누락/지연/중복 fixture를 포함한다.

```powershell
python tools\simulate_matches.py 5 map_spec_path=res://data/mapSpec_night_forest_expanded_candidate.json scale_preset=night_br_m1_60 seed_base=41000 out_dir=C:\tmp\manual_run
python tools\analyze_results.py C:\tmp\manual_run
python tools\analyze_map_structure.py data\mapSpec_night_forest_expanded_candidate.json --preset night_br_m1_60
python tools\analyze_map_structure.py data\mapSpec_night_forest_expanded_candidate.json --preset target_99_probe
python tools\check_scale_telemetry.py C:\tmp\release_scale_99 --min-runs 5 --long-run-normalized-after 0
python tools\summarize_pacing_baseline.py C:\tmp\manual_run
python tools\check_scale_telemetry.py C:\tmp\manual_run --min-runs 5 --min-avg-duration 600 --max-avg-duration 900 --min-run-duration 480 --max-run-duration 960 --min-avg-first-upgrade 2 --max-avg-first-upgrade 30 --max-missing-first-upgrade 0
python tools\compare_scale_profiles.py C:\tmp\parent_control C:\tmp\candidate --baseline-label parent --target-label candidate
.\Godot_v4.6.2-stable_win64_console.exe --path . --script res://tools/profile_runtime_performance.gd -- map_spec_path=res://data/mapSpec_night_forest_expanded_candidate.json scale_preset=night_br_m1_60 perf_warmup_seconds=5 perf_sample_seconds=20 perf_output=C:/tmp/runtime_performance.json
```

AI 이동처럼 규모에 민감한 변경은 부모 커밋 worktree와 현재 후보를 같은 맵·preset·seed base로 각각 최소 5회 실행한다. seed별 결과 일치를 기대하지 않고 종료 분포, 개체·분 기준 stuck/disengage, AI 평균·최대 비용을 함께 비교한다.

`profile_runtime_performance.gd`는 Main이 저장 설정을 적용한 뒤 다시 windowed 1280×720으로 고정하고, headless가 아닌 Forward+ 실행에서 frame/process/physics/navigation, draw call, collision pair, pipeline compile, AI 비용을 JSON으로 남긴다. 같은 조건을 최소 3회 반복하며 `perf_hide_minimap=true`는 UI 병목 대조에만 쓴다. 최신 3회 p95/p99는 15.429/19.948, 15.059/17.641, 15.197/17.924ms이고 p95 20ms 초과는 0/3이다. 초과 run은 제외하지 않고 원시값과 추가 재현 결과를 함께 기록하며, 반복되면 승격을 중단한다.

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
.\Godot_v4.6.2-stable_win64_console.exe --path . --script res://tools/capture_map_orientation.gd -- map_spec_path=res://data/mapSpec_night_forest_expanded_candidate.json scale_preset=night_br_m1_60 output_tag=m1_candidate
.\Godot_v4.6.2-stable_win64_console.exe --path . --script res://tools/capture_runtime_candidate.gd -- map_spec_path=res://data/mapSpec_night_forest_expanded_candidate.json scale_preset=night_br_m1_60 capture_output=C:/tmp/runtime_m1_candidate.png
```
