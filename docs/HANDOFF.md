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
- 이번 세션 기준 푸쉬 대상 slice: `N2-AI-01` 봇 추상 야간 인지 1차.
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
- `N2-AI-01` 코드와 관련 문서는 검증 완료 slice이며 커밋/푸쉬 대상이다.
- 강한 상수는 `target_99_probe` stuck 96.0/run으로 실패했다. 완화 후 단발 1-run은 no first upgrade로 scale checker를 실패했지만, 3-run 구조 smoke는 통과했다.

## 다음 작업

현재 완료한 본 작업은 `N2-AI-01` 봇 추상 야간 인지 재검증이다. 다음 구현 후보는 `N2-PACE-01` 10-15분 pacing telemetry 초안이다.

통과한 단위 검증:

```powershell
.\Godot_v4.6.2-stable_win64_console.exe --headless --path . --script res://tools/verify_bot_night_awareness.gd
.\Godot_v4.6.2-stable_win64_console.exe --headless --path . --script res://tools/verify_ai_lod_perception.gd
.\Godot_v4.6.2-stable_win64_console.exe --headless --path . --script res://tools/verify_bush_interaction.gd
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
- 다음은 `N2-PACE-01`: match duration, first contact, first non-pistol upgrade, crossing usage, POI dwell, final-zone timing 같은 10-15분 pacing telemetry row를 추가한다.

## 설계 가드레일

- 99인 후보를 기본 맵/기본 프리셋으로 승격하지 않는다.
- 봇에게 손전등, 배터리, 공포, 정전, cone-vs-cone 시뮬레이션을 아직 넣지 않는다.
- 현재 단계의 night awareness는 봇 viewer에만 적용되는 거리/확신도 기반 추상 인지 보정이어야 한다.
- `target_99_probe` telemetry는 최종 밸런스가 아니라 구조 안전성 게이트다.
- 수동 화면 검토는 `visual_review` 프리셋을 사용한다. `xlarge_60`/`target_99_probe`는 구조 부하 검증용이다.
- `plan_report/`는 참고용 로컬 디렉토리다. 사용자가 명시하기 전까지 커밋하지 않는다.
