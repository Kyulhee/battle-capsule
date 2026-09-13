# Battle Capsule 작업 지침

Godot 4.6.2 / GDScript, Windows PowerShell 작업 환경이다. 설명은 한글, 식별자·명령·원문 인용은 원문을 쓴다.

## 진행 범위

- 사용자가 요청한 구현은 관련 검증과 발견된 회귀 수정까지 이어간다. 일반 로컬 작업마다 재승인을 요청하지 않는다.
- 완료 조건은 사용자에게 전달할 결과로 잡는다. 진단이 필요하면 확인할 가설과 그 결과로 내릴 결정을 정하고, 무관한 계측·튜닝으로 범위를 넓히지 않는다.
- 제품 범위 변경, 파괴적 작업, 공개 tag/Release는 명시적 지시가 필요하다. 푸시는 승인된 대상·범위 안에서만 한다. 도구의 권한 정책은 그대로 따른다.
- 기존 사용자 변경과 `asset_generator/`, `plan_report/` 원본 풀을 보존하고 요청 없이 커밋하지 않는다.

## 필요한 정보 찾기

- 재개·다음 작업 선택: [CURRENT](docs/CURRENT.md). 구체적인 수정에는 관련 코드부터 확인한다.
- 구조/소유 경계: [ARCHITECTURE](docs/reference/ARCHITECTURE.md). 검증 선택/승격: [TESTING](docs/reference/TESTING.md).
- 정책·후보 판단 등 다른 참조와 기록 위치: [DOCS_INDEX](docs/DOCS_INDEX.md). 모든 문서를 매번 읽지 않는다.
- 현재 상태는 CURRENT에만, 검증 결과는 DEVLOG에 한 번 기록한다. 계획·정책·검증 안내는 그 계약이 바뀔 때만 갱신한다.

## 검증

- 문서만 변경: `python tools/run_verify.py --profile docs_only` (공백 검사이며 내용 검증은 아니다).
- 좁은 코드/도구 변경: `python tools/run_verify.py --profile focused --list-tests`로 찾고 `--test <파일명>`으로 관련 검증을 선택한다. 여러 파일은 옵션을 반복한다.
- `unit_smoke`는 넓은 회귀 묶음이다. 통합 영향이 있으면 관련 runtime/profile까지 넓히되, 같은 변경에서 통과한 검증은 새 실패·변경·미해결 우려 없이 반복하지 않는다.
- focused/단발 smoke는 전체 회귀·후보 승격의 증거가 아니다. 게임플레이 변경은 관련 runtime 검증이 필요하며, 기본값 승격의 5-run·수동 체감·릴리즈 gate는 TESTING/RELEASE를 따른다.
- 실패를 숨기거나 통과를 위해 기준값을 낮추지 않는다. 변경과 무관한 기존 실패는 구분해 기록하고 전체 후보를 승격하지 않는다.
- 진단은 최신 수동 결과·설정·기록을 덮어쓰지 않는 격리 경로를 사용한다. 기존 게임·Godot 리소스 경로는 운영 정리만을 위해 옮기지 않는다.
