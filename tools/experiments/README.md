# 실험 재현 코드

재현에 필요한 실행 코드·입력 설명을 추적하는 위치다. 원시 로그·캡처·대용량 결과는 `builds/verification/<실험>/`에 두고 커밋하지 않는다.
테스트 verifier의 기존 `tools/verify_*` 경로와 과거 결과는 유지한다. 기존 runner는 다시 사용할 때 입력·출력 경로를 명시적으로 받게 이전하며, 보관된 원본을 덮어쓰지 않는다.

## 첫 이전: E079 초기 기하 분석

`inspect_initial_geometry.py`는 기존 `builds/verification/E079_first_upgrade/inspect_geometry.py`를 읽기 전용 CLI로 이전했다. 원본은 보존한다.
입력은 보관된 E078 대조/후보의 `flow.json`, `results/run_1.json`이다. 두 초기 snapshot 동일·비권총 초기 거리 2.5m 밖·첫 upgrade 0초라는 E079 전제를 검사하며 일반 후보 합격 판정기로 쓰지 않는다.

```powershell
python tools/experiments/inspect_initial_geometry.py --input-dir builds/verification/E078_recovery_patrol
```

결과는 stdout JSON으로만 출력한다. Godot/매치를 실행하거나 원시 결과·수동 저장을 수정하지 않는다. 보관된 `E079_first_upgrade/geometry.json`과 동일한 결과를 재현할 수 있다.
입력은 Git에 포함되지 않으므로 새 checkout에서는 해당 원시 자료가 별도로 필요하다. 현재 코드만으로 E078 매치가 결정적으로 재현된다는 의미는 아니다.

다음 실험부터는 실행 명령, 소스 commit/변경 여부, 입력 경로·해시, 설정/seed, 실패를 포함한 종료 코드, 결과 위치를 함께 남긴다. 승격 판정은 기존 TESTING 기준을 사용한다.
