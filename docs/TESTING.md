# 배틀캡슐 테스팅 가이드

> 마지막 업데이트: 2026-06-11 (봇 추상 야간 인지 99 구조 smoke 추가)

> ⚠️ **중요: 체크리스트 기준 변경 금지**
> 이 파일의 체크리스트 기준값(임계치, pass/fail 조건)은 **반드시 개발자와 상의 후에만** 수정한다.
> 버그를 수정하지 않고 기준을 낮춰 통과시키는 것을 방지하기 위함이다.
> AI 에이전트가 단독으로 기준을 조정하는 것은 허용되지 않는다.

---

## 개요

Godot 헤드리스 모드로 게임을 자동 실행하면 `Telemetry.gd`가 지표를 수집하고  
`user://sim_result_latest.json`에 저장합니다. 이 파일을 분석해서 AI 행동, 밸런스,  
버그 여부를 판단합니다.

v1.7.3 이후 맵은 장기적으로 더 넓고 오래 진행되는 방향을 목표로 합니다.
따라서 매치 시간이 늘어나는 것만으로 실패 처리하지 않고, 피해/발사/전투 plan이 0에 고정되거나 zone death가 급증하는 회귀를 우선 확인합니다.
`tools/analyze_results.py`의 `Regression sentinels` 섹션은 `zero total damage`, `zero weapon damage`, `zero shot`, `zero combat plan` run을 별도로 표시합니다.

---

## 빠른 실행

```bash
# 헤드리스로 1판 실행 (5배속, 자동 종료)
./Godot_v4.6.2-stable_win64_console.exe --headless -- autostart=true

# 반복 시뮬레이션 + 요약
python tools/simulate_matches.py 5
python tools/analyze_results.py

# `analyze_results.py` also prints scale-normalized per spawned entity/minute rates and aggregate doctrine state mix.

# 특정 난이도 봇 파라미터로 실행
python tools/simulate_matches.py 5 hell

# 시뮬레이션에 config override 추가 전달
python tools/simulate_matches.py 1 normal bot_count=20 loot_count=80 zone_wait=20 zone_shrink=25

# v1.8 config/debug 진입점 확인
./Godot_v4.6.2-stable_win64_console.exe --path . --headless --quit
./Godot_v4.6.2-stable_win64_console.exe --path . --headless -- autostart=true debug=true debug_flags=zone

# v1.12 artifact runtime smoke: Emergency Shell one-shot + Ghost Grass timer
./Godot_v4.6.2-stable_win64_console.exe --headless --path . --script res://tools/verify_artifact_runtime.gd

# v1.12 artifact selection layout smoke
./Godot_v4.6.2-stable_win64_console.exe --headless --path . --script res://tools/verify_artifact_selection_layout.gd

# v1.12 artifact balance catalog smoke
./Godot_v4.6.2-stable_win64_console.exe --headless --path . --script res://tools/verify_artifact_balance.gd

# v1.12 artifact icon loading smoke
./Godot_v4.6.2-stable_win64_console.exe --headless --path . --script res://tools/verify_artifact_icon_loading.gd

# v1.12 bush prop asset loading smoke
./Godot_v4.6.2-stable_win64_console.exe --headless --path . --script res://tools/verify_bush_prop_assets.gd

# v1.12 bush interaction smoke
./Godot_v4.6.2-stable_win64_console.exe --headless --path . --script res://tools/verify_bush_interaction.gd

# v1.12 artifact selection screenshot capture (requires normal renderer; writes C:/tmp/artifact_selection_ui.png)
./Godot_v4.6.2-stable_win64_console.exe --path . --script res://tools/capture_artifact_selection_ui.gd

# v1.12 artifact visual smoke
./Godot_v4.6.2-stable_win64_console.exe --headless --path . --script res://tools/verify_artifact_visuals.gd

# v1.12 artifact visual gallery capture (requires normal renderer; writes C:/tmp/artifact_visual_gallery.png)
./Godot_v4.6.2-stable_win64_console.exe --path . --script res://tools/capture_artifact_visual_gallery.gd

# v2.0 MapDefinition smoke
./Godot_v4.6.2-stable_win64_console.exe --headless --path . --script res://tools/verify_map_definition.gd

# v2.0 larger-map / 99-target envelope smoke
./Godot_v4.6.2-stable_win64_console.exe --headless --path . --script res://tools/verify_scale_envelope.gd

# v2.0 non-default large map candidate smoke
./Godot_v4.6.2-stable_win64_console.exe --headless --path . --script res://tools/verify_large_map_candidate.gd

# v2.0 candidate strategic flow map smoke
./Godot_v4.6.2-stable_win64_console.exe --headless --path . --script res://tools/verify_strategic_flow_map.gd

# v2.0 candidate map runtime path smoke
./Godot_v4.6.2-stable_win64_console.exe --headless --path . --script res://tools/verify_map_runtime_path.gd
./Godot_v4.6.2-stable_win64_console.exe --headless --path . --quit -- map_spec_path=res://data/mapSpec_large_candidate.json scale_preset=xlarge_60

# v2.0 candidate-only 99-target probe smoke
./Godot_v4.6.2-stable_win64_console.exe --headless --path . --script res://tools/verify_candidate_99_probe.gd

# v2.0 Night Artificial Forest candidate smoke
./Godot_v4.6.2-stable_win64_console.exe --headless --path . --script res://tools/verify_night_forest_candidate.gd
./Godot_v4.6.2-stable_win64_console.exe --headless --path . --quit -- map_spec_path=res://data/mapSpec_night_forest_candidate.json scale_preset=xlarge_60
./Godot_v4.6.2-stable_win64_console.exe --headless --path . --quit -- map_spec_path=res://data/mapSpec_night_forest_candidate.json scale_preset=target_99_probe
python tools/simulate_matches.py 1 map_spec_path=res://data/mapSpec_night_forest_candidate.json scale_preset=target_99_probe out_dir=C:\tmp\game_dev_night_candidate_99_probe_v1
python tools/analyze_results.py C:\tmp\game_dev_night_candidate_99_probe_v1
# The 1-run Night candidate simulation is a structural reference only. Do not treat its duration as the 10-15 minute pacing gate.

# v2.0 player-facing night readability / pickup light LOD / AI LOD smoke
./Godot_v4.6.2-stable_win64_console.exe --headless --path . --script res://tools/verify_bot_night_awareness.gd
./Godot_v4.6.2-stable_win64_console.exe --headless --path . --script res://tools/verify_ai_lod_perception.gd
./Godot_v4.6.2-stable_win64_console.exe --headless --path . --script res://tools/verify_pickup_light_lod.gd
./Godot_v4.6.2-stable_win64_console.exe --headless --path . --script res://tools/verify_player_night_readability.gd
./Godot_v4.6.2-stable_win64_console.exe --path . --script res://tools/capture_player_night_readability.gd
# Capture output: C:\tmp\player_night_readability.png
python tools/simulate_matches.py 1 map_spec_path=res://data/mapSpec_night_forest_candidate.json scale_preset=xlarge_60 out_dir=C:\tmp\game_dev_night_readability_smoke_v1
python tools/analyze_results.py C:\tmp\game_dev_night_readability_smoke_v1

# Manual visual pass: normal renderer, menu start, no autostart time scaling.
# Use visual_review, not xlarge_60/target_99_probe. Those presets are structural load tests and can lag heavily.
./Godot_v4.6.2-stable_win64_console.exe --path . -- map_spec_path=res://data/mapSpec_night_forest_candidate.json scale_preset=visual_review
# If this still lags, use a static low-actor pass:
./Godot_v4.6.2-stable_win64_console.exe --path . -- map_spec_path=res://data/mapSpec_night_forest_candidate.json scale_preset=visual_review bot_count=0 loot_count=24
# Optional visual_review match smoke:
python tools/simulate_matches.py 1 map_spec_path=res://data/mapSpec_night_forest_candidate.json scale_preset=visual_review out_dir=C:\tmp\game_dev_night_visual_review_smoke_v1
python tools/analyze_results.py C:\tmp\game_dev_night_visual_review_smoke_v1

# Optional AI LOD structural smoke:
python tools/simulate_matches.py 1 map_spec_path=res://data/mapSpec_night_forest_candidate.json scale_preset=xlarge_60 out_dir=C:\tmp\game_dev_ai_lod_xlarge60_v1
python tools/analyze_results.py C:\tmp\game_dev_ai_lod_xlarge60_v1
python tools/check_scale_telemetry.py C:\tmp\game_dev_ai_lod_xlarge60_v1 --min-runs 1
python tools/simulate_matches.py 1 map_spec_path=res://data/mapSpec_night_forest_candidate.json scale_preset=target_99_probe out_dir=C:\tmp\game_dev_ai_lod_target99_v1
python tools/analyze_results.py C:\tmp\game_dev_ai_lod_target99_v1
python tools/check_scale_telemetry.py C:\tmp\game_dev_ai_lod_target99_v1 --min-runs 1

# Optional bot abstract night-awareness structural smoke:
python tools/simulate_matches.py 3 map_spec_path=res://data/mapSpec_night_forest_candidate.json scale_preset=target_99_probe out_dir=C:\tmp\game_dev_bot_night_awareness_target99_v2_3run
python tools/analyze_results.py C:\tmp\game_dev_bot_night_awareness_target99_v2_3run
python tools/check_scale_telemetry.py C:\tmp\game_dev_bot_night_awareness_target99_v2_3run --min-runs 3
# A single target_99_probe run may miss first-upgrade economy telemetry; confirm with a small repeated sample before changing code or thresholds.

# v2.0 Sluice Crossing POI probe smoke
./Godot_v4.6.2-stable_win64_console.exe --headless --path . --script res://tools/verify_poi_sluice_crossing_probe.gd
./Godot_v4.6.2-stable_win64_console.exe --headless --path . --quit -- map_spec_path=res://data/mapSpec_poi_sluice_crossing_probe.json scale_preset=poi_probe
# POI probe simulations are structural/readability checks. Existing scale telemetry thresholds are reference-only here.

# v2.0 Wire Maze POI probe smoke
./Godot_v4.6.2-stable_win64_console.exe --headless --path . --script res://tools/verify_poi_wire_maze_probe.gd
./Godot_v4.6.2-stable_win64_console.exe --headless --path . --quit -- map_spec_path=res://data/mapSpec_poi_wire_maze_probe.json scale_preset=poi_probe

# v2.0 Black Ridge POI probe smoke
./Godot_v4.6.2-stable_win64_console.exe --headless --path . --script res://tools/verify_poi_black_ridge_probe.gd
./Godot_v4.6.2-stable_win64_console.exe --headless --path . --quit -- map_spec_path=res://data/mapSpec_poi_black_ridge_probe.json scale_preset=poi_probe

# v2.0 False Clinic POI probe smoke
./Godot_v4.6.2-stable_win64_console.exe --headless --path . --script res://tools/verify_poi_false_clinic_probe.gd
./Godot_v4.6.2-stable_win64_console.exe --headless --path . --quit -- map_spec_path=res://data/mapSpec_poi_false_clinic_probe.json scale_preset=poi_probe

# v2.0 Supply Flats POI probe smoke
./Godot_v4.6.2-stable_win64_console.exe --headless --path . --script res://tools/verify_poi_supply_flats_probe.gd
./Godot_v4.6.2-stable_win64_console.exe --headless --path . --quit -- map_spec_path=res://data/mapSpec_poi_supply_flats_probe.json scale_preset=poi_probe

# v2.0 Ammunition Pockets POI probe smoke
./Godot_v4.6.2-stable_win64_console.exe --headless --path . --script res://tools/verify_poi_ammunition_pockets_probe.gd
./Godot_v4.6.2-stable_win64_console.exe --headless --path . --quit -- map_spec_path=res://data/mapSpec_poi_ammunition_pockets_probe.json scale_preset=poi_probe

# v2.0 Cabin Row POI probe smoke
./Godot_v4.6.2-stable_win64_console.exe --headless --path . --script res://tools/verify_poi_cabin_row_probe.gd
./Godot_v4.6.2-stable_win64_console.exe --headless --path . --quit -- map_spec_path=res://data/mapSpec_poi_cabin_row_probe.json scale_preset=poi_probe

# v2.0 Broadcast Fence POI probe smoke
./Godot_v4.6.2-stable_win64_console.exe --headless --path . --script res://tools/verify_poi_broadcast_fence_probe.gd
./Godot_v4.6.2-stable_win64_console.exe --headless --path . --quit -- map_spec_path=res://data/mapSpec_poi_broadcast_fence_probe.json scale_preset=poi_probe

# v2.0 40-bot scale preset smoke
python tools/simulate_matches.py 1 normal scale_preset=large_40

# v2.0 60-bot scale preset smoke
python tools/simulate_matches.py 1 normal scale_preset=xlarge_60

# v2.0 60-bot repeated telemetry gate
python tools/simulate_matches.py 5 normal scale_preset=xlarge_60
python tools/analyze_results.py tools/sim_runs_current
python tools/check_scale_telemetry.py tools/sim_runs_current

# v2.0 non-default candidate-map repeated telemetry gate
python tools/simulate_matches.py 5 normal map_spec_path=res://data/mapSpec_large_candidate.json scale_preset=xlarge_60
python tools/analyze_results.py tools/sim_runs_current
python tools/check_scale_telemetry.py tools/sim_runs_current

# v2.0 candidate-only 99-target repeated telemetry gate
python tools/simulate_matches.py 5 normal map_spec_path=res://data/mapSpec_large_candidate.json scale_preset=target_99_probe
python tools/analyze_results.py tools/sim_runs_current
python tools/check_scale_telemetry.py tools/sim_runs_current

# v2.0 normalized 60-vs-99 candidate comparison
python tools/simulate_matches.py 5 normal out_dir=C:\tmp\game_dev_candidate_60 map_spec_path=res://data/mapSpec_large_candidate.json scale_preset=xlarge_60
python tools/simulate_matches.py 5 normal out_dir=C:\tmp\game_dev_candidate_99 map_spec_path=res://data/mapSpec_large_candidate.json scale_preset=target_99_probe
python tools/compare_scale_profiles.py C:\tmp\game_dev_candidate_60 C:\tmp\game_dev_candidate_99 --baseline-label xlarge_60 --target-label target_99
# The comparison includes tempo, engagement-density, CHASE-context, route-pressure, and pressure-decision summaries; do not tune by lowering gates.

# v2.0 DISENGAGE reason telemetry smoke
python tools/simulate_matches.py 1 normal out_dir=C:\tmp\game_dev_disengage_reason_smoke map_spec_path=res://data/mapSpec_large_candidate.json scale_preset=xlarge_60
python tools/analyze_results.py C:\tmp\game_dev_disengage_reason_smoke
python tools/check_scale_telemetry.py C:\tmp\game_dev_disengage_reason_smoke --min-runs 1
python tools/compare_scale_profiles.py C:\tmp\game_dev_disengage_reason_smoke C:\tmp\game_dev_disengage_reason_smoke --baseline-label smoke_a --target-label smoke_b

# v2.0 Full Map overlay smoke
./Godot_v4.6.2-stable_win64_console.exe --headless --path . --script res://tools/verify_full_map_overlay.gd

# v2.0 SettingsManager smoke
./Godot_v4.6.2-stable_win64_console.exe --headless --path . --script res://tools/verify_settings_manager.gd

# 결과 파일 위치 (Windows)
# %APPDATA%\Godot\app_userdata\BattleRoyalePrototype\sim_result_latest.json
```

### 99 구조 게이트 반복 실패 방지

`target_99_probe` 단발 run은 빠른 smoke/reference로만 사용합니다. 야간 인지, pacing, scale 구조 변경의 완료 판정은 최소 3-run과 `check_scale_telemetry.py --min-runs 3` 통과를 기준으로 합니다.

실패 분류:

- `stuck > 60/run`: gate를 낮추지 말고 맵 구조, nav 압박, night range/dwell 보정을 수정합니다.
- spawn fallback 또는 placed/requested mismatch: 스폰/맵 envelope 문제로 보고 AI 수치를 건드리지 않습니다.
- zero total damage, zero weapon damage, zero shot, zero combat plan: AI/전투 회귀로 보고 즉시 코드 경로를 확인합니다.
- 1-run `no first upgrade`: economy seed 변동 가능성이 있으므로 3-run으로 재확인합니다. 3-run에서도 실패하면 loot/upgrade 접근성 문제로 분류합니다.
- AI update budget 초과: behavior 튜닝보다 perception/sensory loop cadence를 먼저 확인합니다.

---

## 지표 그룹

`Telemetry.gd`의 `enabled_groups` 딕셔너리로 그룹별 ON/OFF가 가능합니다.  
`start_match()` 호출 전에 `set_groups({...})`를 사용하세요.

### `core` (항상 ON 권장)

| 지표 | 설명 | 이상 판단 기준 |
|---|---|---|
| `duration` | 매치 소요 시간 (초) | < 20s → 즉사/스폰 버그 의심. 장기적으로 10분까지 늘리는 방향이므로 상한 자체는 실패 조건으로 보지 않음 |
| `zone_stage_reached` | 자기장 최대 단계 | 항상 1이면 봇이 너무 빠르게 전멸 |
| `kills` / `assists` | 플레이어 킬/어시스트 | 매번 0이면 전투가 발생 안 함 |
| `deaths_by_stage` | 스테이지별 봇 사망 수 | 1단계에만 몰리면 초반 밸런스 과도 |
| `win` | 플레이어 승리 여부 | — |

### `combat`

| 지표 | 설명 | 이상 판단 기준 |
|---|---|---|
| `shots_fired` | 봇 전체 발사 수 | 0이면 봇이 전투 안 함 |
| `total_damage_dealt` | 게임 내 발생한 총 피해량 | 0이면 피해/사거리/인식 회귀. duration이 급증할 때 가장 먼저 확인 |
| `damage_by_weapon` | 무기별 피해량 | 특정 무기가 0이면 해당 무기 미사용 |
| `kills_by_weapon` | 무기별 킬 수 | — |
| `kill_distances` | 무기별 평균 킬 거리 | 피스톨 > 20m 이상이면 교전 범위 이상 |
| `attack_max_continuous` | 봇의 최장 연속 교전 시간 | > 30s → 봇이 ATTACK 루프에 갇힘 |

### `tactics` (봇 AI 검증 핵심)

| 지표 | 설명 | v1.7.3 기대값 |
|---|---|---|
| `ammo_empty_enter` | 탄약 소진 후 RECOVER 진입 횟수 | > 0 (정상 작동 확인) |
| `reserve_reload` | reserve 있어서 RECOVER 스킵한 횟수 | 탄약 픽업 후 증가해야 함 |
| `recover_bouts` | 실제 RECOVER/전투 루팅 시도 횟수 | > 0, 과도한 급증은 루팅/교전 루프 의심 |
| `recover_success` | RECOVER 중 루팅 성공 횟수 | bouts 대비 20%+ 목표, 50%+면 양호 |
| `died_in_recover` | RECOVER 중 사망 횟수 | `died_in_recover / recover_bouts < 0.5` |
| `stuck_triggered` | stuck 우회 발동 횟수 | > 0이지만 과도하면 맵/이동 문제 |
| `patrol_entered` | 루팅 못 찾고 patrol로 전환된 횟수 | 아이템이 충분하면 낮아야 함 |
| `weapon_drop_spawned` | 봇 사망 시 무기 드롭 생성 수 | 봇 사망 수와 유사해야 함 |
| `disengage_triggered` | 수적 열세(2+ 적) 감지 후 DISENGAGE 진입 횟수 | > 0이면 정상 동작, 0이면 outnumbered 감지 실패 |
| `cover_peek` | 엄폐 피킹 전술 선택 횟수 | 5회 시뮬 평균 0 고정이면 엄폐 탐색 오류 |
| `combat_reposition` | 교전 중 측면 재배치 횟수 | 5회 시뮬 평균 0 고정이면 combat plan 선택 오류 |
| `combat_kite` | 거리 벌리기/카이팅 횟수 | 무기/상황에 따라 낮을 수 있으나 키가 존재해야 함 |
| `survival_break` | 저체력 생존 이탈 횟수 | 0 고정이면 HP override 훅 확인 |

### `doctrine`

| 지표 | 설명 | 이상 판단 기준 |
|---|---|---|
| `profile_counts` | 최종 merge된 아키타입 profile 분포 | 5회 기준 AGGRESSIVE/DEFENSIVE/OPPORTUNIST=15, SNIPER=10 근처 |
| `profile_summaries` | `BotDoctrine.explain_profile()` 결과 | 비어 있으면 configure/log 연결 오류 |
| `combat_plan_counts` | Doctrine이 선택한 문자열 plan 카운트 | `peek_cover/reposition/strafe`가 0에 고정되면 plan 선택 회귀 |
| `plan_by_archetype` | 아키타입별 plan 분포 | AGGRESSIVE/DEFENSIVE/SNIPER/OPPORTUNIST 대표 plan 편향이 모두 같으면 아키타입 체감 약함 |
| `state_time_by_archetype` | 아키타입별 상태 누적 시간 | 특정 상태가 모든 아키타입에서 과도하게 같으면 state transition 튜닝 필요 |
| `engage_range_by_archetype` | 아키타입별 교전거리 avg/min/max 계산용 집계 | SNIPER와 AGGRESSIVE 평균 교전거리가 장기간 동일하면 거리 선호 회귀 의심 |
| `supply_decisions` | profile 기반 보급 관심 결정 | 보급 매치에서 일부 기록 가능, 과도한 증가 시 중앙 군집 의심 |

### `ai`

| 지표 | 설명 | 이상 판단 기준 |
|---|---|---|
| `update_samples` | 샘플링된 봇 physics 업데이트 수. 현재 4프레임마다 1회 기록 | 60봇 반복 런에서 0이면 Bot/Telemetry 연결 오류 |
| `update_total_usec` | 샘플링된 업데이트 시간 합계 | `analyze_results.py`에서 평균 비용 계산용 |
| `update_max_usec` | 단일 샘플 최대 업데이트 시간 | 큰 스파이크가 반복되면 AI LOD 또는 상태별 병목 확인 |
| `update_by_state` | 상태별 샘플/합계/최대 업데이트 시간 | DISENGAGE/ATTACK만 계속 과도하면 해당 상태 로직부터 점검 |
| `update_by_archetype` | 아키타입별 샘플/합계/최대 업데이트 시간 | 특정 아키타입만 비싸면 profile/plan 조건 확인 |

`tools/check_scale_telemetry.py`는 `ai` 그룹이 존재하면 AI update budget을 함께 출력합니다. 현재 기본 guardrail은 v2.0.11 60봇 기준을 깨지 않는 느슨한 방어선이며, 실제 목표 임계치는 반복 데이터가 쌓인 뒤 별도 합의로 조정합니다.

### `spawn`

| 지표 | 설명 | 이상 판단 기준 |
|---|---|---|
| `requested_count` / `placed_count` | 요청한 플레이어+봇 수와 실제 배치 수 | 다르면 스폰 루프/텔레메트리 연결 오류 |
| `fallback_count` | 안전 스폰 실패 후 fallback 범위에 배치한 수 | 60봇 반복 런에서 0이어야 함 |
| `min_nearest_distance` | 가장 가까운 두 스폰 사이 거리 | `entity_clearance`보다 낮으면 스폰 안전거리 회귀 |
| `avg_nearest_distance` | 각 스폰의 최근접 거리 평균 | 낮아질수록 초반 교전/혼잡 압력 증가 |
| `avg_attempts` / `attempt_max` | 안전 위치를 찾는 평균/최대 시도 횟수 | 급증하면 스폰 반경/장애물/맵 크기 압박 |
| `annulus_saturation` | 스폰 annulus 면적 대비 clearance 원 점유 추정치 | 1에 가까워질수록 현재 맵 envelope로 확장 불가 |

`tools/check_scale_telemetry.py`는 `spawn` 그룹이 존재하면 fallback 사용과 최소 최근접 거리를 함께 검사합니다. v2.0.13 기준 `xlarge_60`은 5회 반복에서 placed=61/61, fallback=0.0/run, min nearest=3.5m, avg nearest=7.1m, saturation=0.24였습니다.

### `scale_envelopes`

`scale_envelopes`는 플레이 가능한 `scale_presets`가 아니라 큰 맵/대규모 플레이어 수를 열기 위한 사전 조건입니다.

| 지표 | 설명 | 이상 판단 기준 |
|---|---|---|
| `target_99.world_size_min` | 99봇용 최소 world size | 현재 120m보다 커야 함 |
| `target_99.spawn_radius_min` | 99봇용 최소 spawn radius | 현재 56m보다 커야 함 |
| `target_99.max_annulus_saturation` | 최소 envelope의 허용 spawn 밀도 | 현재 60봇 saturation보다 높으면 99 확장 근거 부족 |
| `target_99.boundary_margin_min` | spawn radius + clearance 이후 경계 여유 | 0에 가까우면 current map처럼 확장 여유 없음 |

`tools/verify_scale_envelope.gd`는 `target_99`가 runtime `scale_preset`으로 노출되지 않고, 최소/선호 envelope가 현재 60봇 envelope보다 느슨한지 확인합니다.

### `economy`

| 지표 | 설명 | 이상 판단 기준 |
|---|---|---|
| `heals_used` | 치료 아이템 사용 횟수 | 0이면 힐 시스템 미작동 |
| `shields_picked` | 방어구 픽업 횟수 | — |
| `rare_pickups` | 희귀 아이템 픽업 횟수 | 보급 캡슐 이후 > 0 기대 |
| `weapon_pickups` | 무기별 픽업 횟수 | 특정 무기만 0이면 스폰 문제 |
| `first_upgrade_time` | 첫 피스톨 외 무기 획득까지 걸린 시간 | > 60s면 아이템 밀도 부족 |

### `supply`

| 지표 | 설명 |
|---|---|
| `telegraphed` | 보급 캡슐 예고 발생 여부 |
| `visits` | 보급 위치 방문 횟수 |
| `preannounce_interest` | 예고 중 봇이 이동 관심 표시 횟수 |
| `contests` | 보급 경합 횟수 |

### `pressure` (Hard opt-in / Hell 전용)

| 지표 | 설명 | 이상 판단 기준 |
|---|---|---|
| `pressure_triggered` | 존 전환마다 압박 미션이 발동된 횟수 | 0이면 트리거 로직 오류 |
| `pressure_cleared` | 미션 기한 내 성공한 횟수 | `triggered` 대비 30%+ 목표 (Hell은 낮아도 정상) |
| `pressure_failed` | 시간 초과 또는 즉시 실패 횟수 | `cleared + failed ≈ triggered` 이어야 함 |

### `artifact`

| 지표 | 설명 | 이상 판단 기준 |
|---|---|---|
| `selected` | 선택된 artifact id | 수동 플레이에서 선택했는데 `none`이면 apply/log 경로 확인 |
| `events` | artifact runtime event counts | 이벤트형 artifact 발동 후 해당 event가 0이면 trigger/log 경로 확인 |
| `emergency_shell_triggered` | Emergency Shell 발동 횟수 | 한 매치에서 0 또는 1이어야 함 |
| `ghost_grass_started` | Ghost Grass bush-exit 발동 횟수 | Ghost Grass 선택 후 부쉬 이탈 시 증가해야 함 |
| `triggered_ids` | 발동된 미션 ID 목록 | 다양한 ID가 섞이는지 확인 (편향 감지) |

---

## 테스팅 시나리오별 그룹 설정

### 봇 AI 행동 검증 (v1.7.3)

```gdscript
Telemetry.set_groups({
    "core":    true,
    "tactics": true,
    "combat":  true,
    "doctrine": true,
    "economy": false,
    "supply":  false,
})
```

**체크리스트**
- [ ] `stuck_triggered` > 0 → 끼임 감지 작동
- [ ] `reserve_reload` ≥ 0 → (v0.6+) 교전 중 ammo 아이템 opportunistic pickup 미구현으로 0 정상
- [ ] `recover_success` / `recover_bouts` > 0 → 회복 시스템 작동 확인 (v0.6+ 빠른 전투로 성공 전 피격 사망 흔함 — 500 HP 테스트에서 21% 확인, 시스템 버그 아님)
- [ ] `died_in_recover` / `recover_bouts` < 0.5 → 회복 중 사망 50% 미만
- [ ] `patrol_entered` < `recover_bouts` → 패트롤은 마지막 수단으로만 사용
- [ ] `attack_max_continuous` < 20.0 → 봇이 ATTACK에 갇히지 않음
- [ ] `weapon_drop_spawned` ≈ 봇 사망 수 (11 - alive_count) → 드롭 정상 작동
- [ ] `disengage_triggered` > 0 → 수적 열세 감지 및 DISENGAGE 상태 작동
- [ ] `cover_peek + combat_reposition + combat_kite` > 0 → 개인 교전 수칙 선택이 발동
- [ ] `python tools/analyze_results.py` 출력에서 `Avg combat plans`가 표시됨
- [ ] `Doctrine profiles`가 아키타입 스폰 분포와 일치
- [ ] `Doctrine plans`가 표시되고 plan 카운트가 0에 고정되지 않음
- [ ] `Doctrine plans by archetype`, `Doctrine state time by archetype`, `Doctrine engage range by archetype` 출력이 표시됨

### 무기 밸런스 검증

```gdscript
Telemetry.set_groups({
    "core":    true,
    "combat":  true,
    "economy": true,
    "tactics": false,
    "supply":  false,
})
```

**체크리스트**
- [ ] `kill_distances["pistol"]` 평균 5~12m 이내
- [ ] `kill_distances["assault_rifle"]` 평균 10~25m
- [ ] `kill_distances["shotgun"]` 평균 3~8m
- [ ] `damage_by_weapon` 비율이 픽업 빈도와 대략 비례
- [ ] `first_upgrade_time` 20~60s 사이 (너무 빠르면 초반 무기 밀도 과도)

### 경제 & 루프 검증

```gdscript
Telemetry.set_groups({
    "core":    true,
    "economy": true,
    "supply":  true,
    "combat":  false,
    "tactics": false,
})
```

**체크리스트**
- [ ] `weapon_pickups` 전 무기 종류에 고르게 분포
- [ ] `rare_pickups` > 0 → 보급 캡슐 정상 작동
- [ ] duration이 갑자기 늘어난 경우 `total_damage_dealt`, `shots_fired`, `cover_peek + combat_reposition + combat_kite`가 0에 고정되지 않음

### 압박 미션 검증 (Hard opt-in / Hell)

```gdscript
Telemetry.set_groups({
    "core":     true,
    "mission":  true,
    "pressure": true,
})
```

**체크리스트** (Hard opt-in 또는 Hell 난이도 실행 시)
- [ ] `pressure_triggered` > 0 → 압박 미션 트리거 작동
- [ ] `pressure_cleared + pressure_failed` == `pressure_triggered` → 미해결 미션 없음
- [ ] `triggered_ids` 목록에 2개 이상의 서로 다른 미션 ID 포함 → 풀 무작위화 작동
- [ ] Hell 모드: `pressure_cleared` ≥ 1 → 극단적 난이도에서도 달성 가능

> 체크리스트를 모두 통과하면 **DEVLOG.md** 업데이트 후 릴리즈를 진행합니다.  
> 단계 전체 기준 → [CLAUDE.md](../CLAUDE.md)

---

## 결과 파일 읽기

`sim_result_latest.json` 예시:

```json
{
  "enabled_groups": { "core": true, "tactics": true, ... },
  "session": { "kills": 3, "assists": 1, "rank": 1, "win": true },
  "core": { "duration": 87.4, "zone_stage_reached": 2, ... },
  "tactics": {
    "ammo_empty_enter": 14,
    "reserve_reload": 6,
    "recover_bouts": 8,
    "recover_success": 5,
    "stuck_triggered": 3,
    "patrol_entered": 2,
    "weapon_drop_spawned": 11
  }
}
```

---

## 추후 추가 예정 지표

| 지표 | 버전 | 용도 |
|---|---|---|
| `log_stealth` 구현 | v0.5 | 풀숲 활용률, 웅크리기 탐지 회피율 |
| `outnumbered_disengage` | v0.5 | 수적 열세 감지 후 후퇴 횟수 |
| `flank_attempts` | v0.6 | 플랭킹 시도 횟수 |
| `cover_claimed` | v0.6 | CoverRegistry 사용 횟수 |
| `shots_on_target` | 미정 | 명중률 계산 (log_shot 활용) |
