# 다음 세션 핸드오프

> 마지막 업데이트: 2026-06-11. 기존 긴 handoff는 제거했고, 새 관리자 권한 Codex 세션이 이어받는 데 필요한 내용만 남긴다.

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
- 이번 세션 기준 완료 slice: `N2-PACE-04` pacing game-time 정규화.
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
- `N2-AI-01`, `N2-PACE-01`, `N2-PACE-02`, `N2-PACE-03`, `N2-PACE-04`는 검증 완료 slice다.
- 강한 상수는 `target_99_probe` stuck 96.0/run으로 실패했다. 완화 후 단발 1-run은 no first upgrade로 scale checker를 실패했지만, 3-run 구조 smoke는 통과했다.

## 다음 작업

현재 완료한 본 작업은 `N2-PACE-04` pacing game-time 정규화다. `N2-PACE-02`와 `N2-PACE-03`에서 gameplay tuning은 적용하지 않았고, 이번 slice도 tuning 없이 milestone seconds가 `core.duration`과 같은 game-time 축을 쓰도록 고쳤다.

통과한 단위 검증:

```powershell
.\Godot_v4.6.2-stable_win64_console.exe --headless --path . --script res://tools/verify_pacing_telemetry.gd
.\Godot_v4.6.2-stable_win64_console.exe --headless --path . --script res://tools/verify_bot_night_awareness.gd
.\Godot_v4.6.2-stable_win64_console.exe --headless --path . --script res://tools/verify_ai_lod_perception.gd
.\Godot_v4.6.2-stable_win64_console.exe --headless --path . --script res://tools/verify_bush_interaction.gd
python -m py_compile tools\summarize_pacing_baseline.py tools\analyze_results.py tools\check_scale_telemetry.py tools\simulate_matches.py
python tools\simulate_matches.py 1 map_spec_path=res://data/mapSpec_night_forest_candidate.json scale_preset=target_99_probe out_dir=C:\tmp\game_dev_pacing_time_scale_v1
python tools\analyze_results.py C:\tmp\game_dev_pacing_time_scale_v1
python tools\summarize_pacing_baseline.py C:\tmp\game_dev_pacing_time_scale_v1
python tools\check_scale_telemetry.py C:\tmp\game_dev_pacing_time_scale_v1 --min-runs 1
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
- 다음 우선순위는 fresh game-time 3-run 기준선을 만든 뒤 Night 후보 전용 비기본 playable pacing preset 또는 zone/economy override를 설계하는 것이다. 바로 combat damage, AI aggression, night awareness 상수를 건드리지 않는다.

## 설계 가드레일

- 99인 후보를 기본 맵/기본 프리셋으로 승격하지 않는다.
- 봇에게 손전등, 배터리, 공포, 정전, cone-vs-cone 시뮬레이션을 아직 넣지 않는다.
- 현재 단계의 night awareness는 봇 viewer에만 적용되는 거리/확신도 기반 추상 인지 보정이어야 한다.
- `target_99_probe` telemetry는 최종 밸런스가 아니라 구조 안전성 게이트다.
- 수동 화면 검토는 `visual_review` 프리셋을 사용한다. `xlarge_60`/`target_99_probe`는 구조 부하 검증용이다.
- `plan_report/`는 참고용 로컬 디렉토리다. 사용자가 명시하기 전까지 커밋하지 않는다.
