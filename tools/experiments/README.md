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

## E081 선택적 물리 시계 후보

동일 실행기에 `--clock-candidate`를 주면 E078 순찰 후보 대신 E081 시계 후보를 비교한다. `--full-match`를 함께 주면 진단/지연 없이 기존 시계와 후보를 5배속 한 판씩 끝까지 실행한다. 전체 매치 모드는 `--start-delay-ms 100`과 혼합할 수 없고 승격을 의미하지 않는다.

```powershell
python tools/experiments/run_first_collection.py --reference-flow builds/verification/E078_recovery_patrol/control/flow.json --out-dir builds/verification/E081_repeat_clock --clock-candidate --start-delay-ms 100
python tools/experiments/run_first_collection.py --reference-flow builds/verification/E078_recovery_patrol/control/flow.json --out-dir builds/verification/E081_repeat_full --clock-candidate --full-match
```

probe 전용 `physics_clock_candidate=true`는 Main의 비공개 기본 OFF 플래그를 시작 전에 켠다. 일반 플레이의 process 경로는 유지하고, 후보만 physics priority -100에서 `match_timer`와 기존 존·피해·미션·보급 갱신을 같은 delta로 진행한다. 화면은 process에서 그리며 시간을 두 번 누적하거나 배속을 다시 곱하지 않는다. 수집 시각만 임의 보정하는 방식이 아니다.

물리 tick은 process보다 먼저 실행되며 낮은 priority 값이 먼저 호출된다. delta는 이미 배속을 반영한다. 이 동작을 사용하되 wall-clock이나 전체 매치 결정성을 보장하지 않는다. [Godot 4.6 Node](https://docs.godotengine.org/en/4.6/classes/class_node.html#class-node-private-method-physics-process), [Engine](https://docs.godotengine.org/en/4.6/classes/class_engine.html#class-engine-property-time-scale)

후보의 lifecycle/피해 호출 시점·빈도가 바뀌므로 초기 수집 검증만으로 기본 승격하지 않는다. 전체 매치 pair는 초기 ID·0/120/260초 checkpoint·flow/core 종료 시각·수동 hash를 검사한다. 각 case의 `run_1.json`은 기존 분석기의 입력이며 `case_summary.json`은 매치 결과 목록이 아니다. 최소 5-run, 전체 gate, 수동 성능/체감은 별도다. 새로운 clock의 시간 분포를 기존 process 기준선과 그대로 합산하지 않는다.

시계 후보 식별은 `inputs.json`과 `flow.json`의 `physics_clock_candidate`를 함께 보관해 확인한다. 기존 `run_1.json` 단독으로 시계 종류를 추정하지 않는다.

## E083 물리 시계 반복 비교

기존 전체 매치 pair를 seed 41000-41004에 한 번씩 순차 실행한다. 보관된 `E083_clock_repeat/reference/<seed>.json`은 동일 소스에서 probe의 `initial_only=true`로 생성한 초기 기준이며 전체 경기 수에 넣지 않는다. 이 원시 자료가 없는 새 checkout에서는 같은 맵/preset/seed와 격리 `flow_output`/`result_output`을 지정해 기준을 먼저 생성한다.

```powershell
foreach ($seed in 41000..41004) {
    python tools/experiments/run_first_collection.py --reference-flow "builds/verification/E083_clock_repeat/reference/$seed.json" --out-dir "builds/verification/E083_repeat_new/seed_$seed" --seed $seed --clock-candidate --full-match
    if ($LASTEXITCODE -ne 0) { throw "Clock pair failed: $seed" }
}
```

새 출력 경로만 사용하고 실행 중 소스를 수정하지 않는다. 각 seed의 `control_match/run_1.json`과 `candidate_match/run_1.json`을 별도 군으로 모아 `run_1..5.json`으로 복사할 경우 SHA 일치를 확인한다. 원시 inputs/flow/command/integrity는 그대로 보존한다. 두 군 모두 TESTING의 기존 최소 5-run gate와 `survival_curve`를 적용하며, 단발 pair 요약의 `promotion_eligible=false`는 전체 후보 승격을 뜻하지 않는다는 경계로 유지한다. 시계 모드·추가 trace OFF·초기 ID·체크포인트 인원/시각·수동 hash도 함께 확인한다. 최신 결과는 DEVLOG에만 기록한다.

## E084 화면 성능 비교

```powershell
python tools/experiments/run_clock_performance.py --out-dir builds/verification/E084_repeat_new --seed 41000
```

Windows에서 실제 렌더링 창을 한 개씩 연다. 초기/완료 확인용이 아니라 Forward+ Vulkan·windowed 1280×720·1배속, live player/60봇·5초 준비+20초 표본의 성능 비교다. OFF1/ON1/ON2/OFF2/OFF3/ON3 순서로 동일 입력을 실행하고 모드·초기 ID/배치·GPU/vsync·해상도·draw call·관측 창을 검사한다. 플레이어 HP를 유지하는 기존 성능 프로필이므로 정상 플레이의 생존/전체 매치 판정이 아니다.

새 출력 폴더만 허용한다. 실행 소스/기준 commit/엔진 SHA, 사용자 데이터 루트의 JSON/CFG/backup SHA, 모든 명령/로그/종료·timeout/무결성/profile을 저장한다. 소스/저장 변경, 실행 오류, 조건 불일치 시 중단하고 원시 자료를 유지한다. 완료된 6회 p95가 하나라도 20ms를 넘으면 summary를 보존한 뒤 실패 종료하며 재추첨하지 않는다. 중단된 첫 묶음과 새 재확인은 합산해 통과시키지 않는다. GPU 창을 닫으면 측정이 중단될 수 있으며 종료 요청 로그를 함께 확인한다. 실행 중 소스를 바꾸거나 다른 성능/게임 프로세스를 병행하지 않는다.
