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

## E080 실제 첫 수집 순서

`run_first_collection.py`는 기존 loot-flow probe의 시작 경로를 재사용한다. OFF 초기 배치를 과거 원시 actor ID까지 비교한 뒤, 대조/회복 순찰 후보 각각 1x/5x의 짧은 구간을 실행한다. 첫 수집 뒤 시계 갱신을 관측하거나 canonical 10초에 종료하며 전체 매치 결과를 만들지 않는다.

```powershell
python tools/experiments/run_first_collection.py --reference-flow builds/verification/E078_recovery_patrol/control/flow.json --out-dir builds/verification/E080_repeat_natural
python tools/experiments/run_first_collection.py --reference-flow builds/verification/E078_recovery_patrol/control/flow.json --out-dir builds/verification/E080_repeat_delayed --start-delay-ms 100
```

출력 폴더는 새 경로여야 한다. 기존 폴더는 덮어쓰지 않는다. 입력 SHA/seed, 소스 파일 SHA/기준 commit, 엔진 SHA, 실제 명령, 종료 코드/timeout, 수동 결과·소스 불변 여부와 요약을 저장한다. 기준 commit 이후 변경은 파일 SHA로 구분하며 commit만으로 실행 소스가 같다고 해석하지 않는다.

probe 전용 `first_collection_scale=1|5`는 초기 비권총 pickup에만 성공 callback을 붙인다. callback은 실제 장비 적용 성공 뒤 호출하고 최대 8건의 actor/pickup ID·source·장착 무기·거리·canonical 시각·physics/process frame을 기록한다. process 경계는 처음 16개와 종료 경계를 남기므로 긴 전체 프레임 이력은 아니다. 기록 객체는 봇 생성 뒤 준비하며 기본 OFF는 추가 시계/검색/진단 객체를 만들지 않는다.

`first_collection_start_delay_ms=100`은 이 진단에서만 허용하는 명시적 시작 지연이다. 자연 스케줄링·성능·승격 결과와 섞지 않는다. 다른 trace/튜닝 혼합은 거부하고 E078 순찰 후보만 별도 대조한다. 초기 ID 일치는 계측 중 전체 물리 결정성을 보증하지 않는다.

현재 보관 자료는 `E080_first_collection`(초기 자연 관측), `E080_start_delay`(100ms 지연), `E080_natural_final`(지연 실험과 같은 소스의 자연 대조)이다. 입력은 Git에 포함되지 않는다. 판정은 DEVLOG에서 관리하며 E078 당시 프레임 이력이 없다는 한계를 유지한다.
