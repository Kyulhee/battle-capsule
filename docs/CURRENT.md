# 현재 트래커

> 최종 업데이트: 2026-08-10. 작업 시작 전 이 문서를 먼저 읽는다.

## 큰 틀

| 트랙 | 상태 | 목표 |
|---|---|---|
| M0 운영 기반 | 지원 중 | 1인 개발에 맞게 문서·검증·빌드·푸쉬 루틴을 가볍게 유지 |
| M1 첫 플레이 가능한 Night BR | 종료 판정 중 | `night_br_m1_60` 10-15분 루프의 수동 체감·성능 승격 |
| M2 릴리즈 버티컬 슬라이스 | 다음 | 캐릭터·전투·야간·HUD·오디오·온보딩이 한 판에서 설득력 있게 동작 |
| M3 Windows 공개 데모 RC | 계획 | 패키지·저장·호환성·외부 테스트 gate를 통과한 무료 데모 |
| M4 오프라인 유료 EA 판단 | 이후 | 데모 반응 뒤 콘텐츠 반복성·운영·업데이트 범위를 결정 |

## 현재 작업면

| 항목 | 값 |
|---|---|
| 현재 단위 | behavior-unchanged kill-context 기준선은 초기 사망 22건 중 생존 상태 피해자 19건·최근 보복 19건으로 교전 종료 실패 가설을 지지했다. 이를 직접 겨냥한 ceasefire 1-run은 재획득·정체·이탈을 악화시켜 방향 gate를 실패했고 폐기·완전 revert 완료 |
| 바로 다음 단위 | 새 gameplay 후보를 정하기 전에 release→같은 대상 재획득과 이동 정체를 분리한다. 새 단일 후보도 1-run에서 생존 방향·D-004·fallback·정체/이탈을 함께 통과할 때만 5-run, 그 뒤에만 packaged 수동 3판으로 진행 |
| 최신 검증 개발 단위 | 현재 worktree `unit_smoke` 79.6초, Windows PCK exact `44 assets/3 JSON/124 runtime/20 probes`, Vulkan HUD·전체 지도, 근접 종료 race source `10+3`회·packaged 3회와 exported EXE quick/full boot clean 통과 |
| 최신 검증 게임플레이 단위 | 최종 clean packaged 자동 1-run은 652.8초·alive `55/38/30/27/24/17`·T50/T10 `35.1/333.0초`·fallback 0으로 실행 계약만 통과했다. 기존 5-run과 함께 생존 gate는 계속 FAIL이며 gameplay PASS가 아님 |
| 첫 공개 범위 | Windows x64, 오프라인 싱글플레이, 한국어, 키보드/마우스, `night_br_m1_60` 한 맵, 무료 데모 |
| 목표 창 | 폐쇄 알파 2026-08 중·하순, 공개 데모 후보 2026-10 말~11월, 유료 EA Go/No-Go 2027 Q1 말 |
| 브랜치 메모 | `master`는 원격과 동기화되어야 한다. 사용자 지시가 바뀌기 전까지 푸쉬 허용 |
| 로컬 메모 | `.gitignore`, `asset_generator/`, `plan_report/` 등 기존 로컬 산출물은 작업 범위 밖이면 건드리지 않는다. 재개 정보는 이 문서에만 둔다 |

## 제품 방향

- 텔레메트리만 통과하는 시뮬레이션이 아니라, 외부 사용자가 설명 없이 한 판을 설치·완주·재시작할 수 있는 Night BR을 만든다.
- M1 개발 기준은 `data/mapSpec_night_forest_expanded_candidate.json`의 `night_br_m1_60`이다. 일반 실행·수동 플레이·후보 페이싱 검증이 같은 표면을 쓴다.
- M1 수동 승격 전 공개 배포는 금지하지만 저장·패키징·브랜딩·릴리즈 검증 기반은 지금부터 병행한다.
- 99명 기본값, macOS 공개 지원, 온라인 기능, 완전한 flashlight/fear/battery, 신규 장비·장소 확장은 공개 데모 이후 증거가 생길 때까지 보류한다.
- 수치 검증은 구조 안전망이다. M1/M2 승격에는 수동 플레이·가독성·첫 사용자 기록이 필요하다.

## 다음 작업 큐

| 우선순위 | 작업 | 종료 조건 |
|---|---|---|
| P0 | `N2-PLAY-11` M1 실패 수정·재판정 | 교전 종료·재획득·이동 정체를 분리한 새 단일 후보가 1-run 방향 gate를 통과할 때만 5-run으로 확대하고, 생존 곡선·D-004 통과 뒤 packaged 수동 3판을 승인 |
| P1 | `N2-REL-01` Windows 릴리즈 기반 마감 | 통과한 clean PCK inventory·PE identity·전체 headless simulation·checksum/manifest/reboot 근거를 보존하고, 사람이 조작하는 전체 루프·정상 기록/배지 저장·cold PCK byte 재현성을 확인 |
| P2 | `N2-M2-VIS-01` 대표 교전 슬라이스 | 수관 가림·야간 명도·캡슐 방향/무기/피격/사망·핵심 효과음·HUD/지도 위계를 한 구간에서 수동 통과 |
| P3 | `N2-M2-UX-01` 첫 사용자 경험 | 밝기·감도·해상도/창 모드·UI 배율, 입력 안내, 언어 일관성, 메뉴→매치→결과→재시작 흐름을 무설명 테스터가 완주 |
| P4 | `N2-REL-02` 공개 데모 RC | clean artifact 재현, 전체 매치/반복 재시작 soak, 다중 해상도·하드웨어, 외부 20회 이상 완주, P0/P1 0, 고지·지원·릴리즈 노트 완료 |
| P5 | M4 EA 판단 | 데모 피드백 뒤에만 진행·콘텐츠 2축, 저장 migration/rollback, 영어·controller·접근성, 서명·업데이트 채널 범위를 결정 |

## 리스크 보드

| 리스크 | 신호 | 대응 |
|---|---|---|
| M1 생존 페이싱 실패 | 5-run alive@30/60/120 `52/35/22`; kill-context 기준선은 60초 내 사망 22건 중 생존 상태 피해자·최근 보복 각 19건. ceasefire는 사망을 16건으로 줄였지만 1초 내 재획득 26.1%, stuck 6→53, disengage 384→823 | ceasefire는 완전 revert하고 5-run 금지. 새 후보는 생존 증가뿐 아니라 재획득·정체·이탈 비회귀를 같은 1-run에서 증명 |
| 화면이 프로토타입으로 보임 | 겹친 수관, procedural capsule, 평면적 야간 재질, HUD 정보 경쟁 | 신규 콘텐츠보다 P2 대표 슬라이스를 우선하고 캡슐을 의도된 제품 정체성으로 승격 |
| 기록·저장 무결성 | packaged smoke에서 legacy settings schema v1 migration·backup·재실행 멱등성과 simulation 중 기존 기록·배지 불변 확인 | 사람이 정상 매치 기록·배지 생성/재실행과 corrupt/empty/future-schema 화면 동작을 확인 |
| 패키지 오염·식별 불일치 | clean PCK의 catalog 자산 44개·JSON 3개·runtime 경로 124개·payload closure exact, Windows x64 GUI identity, internal archive hash/extract/reboot 통과 | 독립 clean export의 EXE는 동일하지만 PCK hash/크기가 달라 byte 재현성 미해결. LICENSES/CREDITS·지원·unsigned 정책 전 공개 승격 금지 |
| 60봇 성능 | 재측정 3회 p95/p99 통과에 더해 packaged headless 전체 simulation 651.038초, spawn 60/60·fallback 0·오류 0 통과 | 수동 끊김·사람 플레이 전체 매치·restart soak·다중 해상도는 P0/P4에서 별도 확인 |
| 99봇 구조 여유 | 고정 입력 5-run은 통과했지만 disengage 0.44가 한계 0.45에 가까움 | 99봇은 gameplay로 승격하지 않고 규모 민감 변경마다 구조 profile을 다시 실행 |
| 첫 사용자·호환성 공백 | exported binary 자동 부팅·전체 simulation은 통과했지만 UI·입력·가독성·정상 저장 생성은 사람이 확인하지 않음 | P3/P4에서 무설명 완주와 Win10/11·한글 경로·읽기 전용 설치·해상도/하드웨어 matrix를 gate로 유지 |
| 범위 팽창 | 온라인·99봇·macOS·신규 콘텐츠가 공개 데모 critical path와 경쟁 | 첫 공개 범위 밖 기능은 M4 Go/No-Go 전까지 보류 |
| 작업 트리 노이즈 | Godot UID가 일부만 추적되어 상태 출력에 100개 이상 노출 | 별도 운영 단위에서 UID 정책을 통일하고 gameplay 커밋과 섞지 않음 |

## 세션 규칙

새 구현 단위를 시작할 때는 현재 마일스톤, 현재 리스크, 종료 조건을 1-2문장으로 재진술한다.
