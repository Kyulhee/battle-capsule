# 현재 트래커

> 최종 업데이트: 2026-09-05. 작업 시작 전 이 문서를 먼저 읽는다.

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
| 현재 단위 | E-062 수동 실패 뒤 LOS 이탈 exact 계측을 추가했고 E-063 전 표적 사격은 폐기했다. E-064 player-only 마지막 위치 사격은 관련 runtime과 60봇 5-run 보존 gate를 통과했지만 player 실제 표본은 아직 없다 |
| 바로 다음 단위 | 120초 kill context로 자동 alive@120 중앙 27명과 수동 첫 축소 4명의 괴리를 초기 목적지·무장 거점·교전 참가/연쇄 사망으로 분해하고 E-064 player-target 격리 runtime을 만든다. 물리 변경은 그 뒤 Survey Camp↔Central Meadow 대표 슬라이스의 별도 후보로 둔다 |
| 최신 검증 개발 단위 | E-064 LOS exact schema, player-only predictive vector, bot damage 격리, target lifetime·decision policy와 전체 `unit_smoke`가 PASS했다. 전 표적에 적용한 E-063은 즉시 폐기했고 맵·존·HP·피해·확산·기억시간은 바꾸지 않았다 |
| 최신 검증 게임플레이 단위 | E-064 seed 41000-41004는 평균 694.3초(599.2-855.0), alive 중앙 `53/38/32/27/22/17`, first upgrade 3.40초, fallback 0, stuck/disengage 0.020/0.191로 자동 gate를 통과했다. bot LOS 명중률 10.87%로 E-062를 보존했지만 player 표본과 수동 3판은 아직 PASS가 아니다 |
| 첫 공개 범위 | Windows x64, 오프라인 싱글플레이, 한국어, 키보드/마우스, `night_br_m1_60` 한 맵, 무료 데모 |
| 릴리즈 판정 | `v2.1.0-demo-dev`는 제한을 명시한 테스트 프리릴리즈다. 공개 stable은 `v2.0.0-pre-expansion`을 유지하며 packaged/manual·M2/M3 gate 전 공개판을 교체하지 않는다 |
| 목표 창 | 폐쇄 알파 현실 창 2026-09-28~10-09, 공개 데모 RC 현실 창 2026-12-18~2027-01-15, 유료 EA Go/No-Go 2027 Q1 이후. 날짜는 gate 통과 창이지 출시 약속이 아니다 |
| 브랜치 메모 | 로컬 진단 커밋은 원격보다 앞설 수 있다. 새 커밋 푸쉬는 대상 commit을 명시한 사용자 승인을 다시 받은 뒤에만 한다 |
| 로컬 메모 | `.gitignore`, `asset_generator/`, `plan_report/` 등 기존 로컬 산출물은 작업 범위 밖이면 건드리지 않는다. 재개 정보는 이 문서에만 둔다 |

## 제품 방향

- 텔레메트리만 통과하는 시뮬레이션이 아니라, 외부 사용자가 설명 없이 한 판을 설치·완주·재시작할 수 있는 Night BR을 만든다.
- M1 개발 기준은 `data/mapSpec_night_forest_expanded_candidate.json`의 `night_br_m1_60`이다. 일반 실행·수동 플레이·후보 페이싱 검증이 같은 표면을 쓴다.
- M1 수동 승격 전 공개 배포는 금지하지만 저장·패키징·브랜딩·릴리즈 검증 기반은 지금부터 병행한다.
- 99명 기본값, macOS 정식 지원, 온라인 기능, 완전한 flashlight/fear/battery, 신규 장비·장소 확장은 공개 데모 이후 증거가 생길 때까지 보류한다. macOS Universal 2 미서명 교차 빌드는 호환성 피드백용으로만 제공한다.
- 수치 검증은 구조 안전망이다. M1/M2 승격에는 수동 플레이·가독성·첫 사용자 기록이 필요하다.

## 다음 작업 큐

| 우선순위 | 작업 | 종료 조건 |
|---|---|---|
| P0 | `N2-PLAY-11` M1 실패 원인 분리·재판정 | E-064 player-only 이탈 압력을 격리 runtime/수동으로 판정하고, 자동-수동 생존 곡선 괴리와 초기 목적지/교전 수렴을 계측한 뒤 수동 3판에서 첫 축소 생존·이동 이유·엄폐/이탈·완주를 통과 |
| P1 | `N2-REL-01` 테스트 프리릴리즈와 Windows 기반 마감 | clean tracked commit에서 Windows/macOS artifact·PCK inventory·identity·checksum/manifest/고지를 만들고, 사람 전체 루프·정상 기록/배지·cold PCK byte 재현성과 실제 Mac 실행을 후속 확인 |
| P2 | `N2-M2-VIS-01` 대표 교전 슬라이스 | 수관 가림·야간 명도·캡슐 방향/무기/피격/사망·핵심 효과음·HUD/지도 위계를 한 구간에서 수동 통과 |
| P3 | `N2-M2-UX-01` 첫 사용자 경험 | 밝기·감도·해상도/창 모드·UI 배율, 입력 안내, 언어 일관성, 메뉴→매치→결과→재시작 흐름을 무설명 테스터가 완주 |
| P4 | `N2-REL-02` 공개 데모 RC | clean artifact 재현, 전체 매치/반복 재시작 soak, 다중 해상도·하드웨어, 외부 20회 이상 완주, P0/P1 0, 고지·지원·릴리즈 노트 완료 |
| P5 | M4 EA 판단 | 데모 피드백 뒤에만 진행·콘텐츠 2축, 저장 migration/rollback, 영어·controller·접근성, 서명·업데이트 채널 범위를 결정 |

## 리스크 보드

| 리스크 | 신호 | 대응 |
|---|---|---|
| M1 생존·교전 압력 수동 실패 | E-064 자동 중앙 alive@120은 27명이지만 같은 계열의 E-062 수동은 첫 축소 때 4명뿐이라 자동-수동 괴리가 크다. 첫 60초 사망 111건 중 88건이 DISENGAGE였고 83건은 앞선 사망 3초 안에 발생했다. player-only target-position 사격은 bot 5-run을 보존했으나 실제 player LOS 표본은 없다 | 120초 kill context와 player-target 격리 runtime으로 수동/Forward+와 headless의 초기 목적지·무장 거점 수렴·동시 교전 참가·연쇄 사망을 같은 체크포인트로 비교한다. topology는 원인 확인 뒤 한 대표 구간만 바꾼다 |
| 화면이 프로토타입으로 보임 | 겹친 수관, procedural capsule, 평면적 야간 재질, HUD 정보 경쟁 | 신규 콘텐츠보다 P2 대표 슬라이스를 우선하고 캡슐을 의도된 제품 정체성으로 승격 |
| 기록·저장 무결성 | packaged smoke에서 legacy settings schema v1 migration·backup·재실행 멱등성과 simulation 중 기존 기록·배지 불변 확인 | 사람이 정상 매치 기록·배지 생성/재실행과 corrupt/empty/future-schema 화면 동작을 확인 |
| 패키지 오염·식별 불일치 | `2acf965` clean PCK는 catalog 자산 44개·JSON 3개·runtime 경로 124개·payload closure exact, EXE `Battle Capsule`/`2.1.0.0`을 통과했다. packaged 2-run은 평균 661.8초지만 AI max `57.9/28.6ms`로 strict 합산 FAIL이다 | 현재 artifact는 수동 smoke 전용이다. Forward+ 반복·clean 독립 2차 export/PCK byte 재현성·LICENSES/CREDITS·KNOWN_ISSUES·manifest·지원·unsigned 정책을 닫기 전 archive/공개 승격 금지 |
| 60봇 성능 | E-062 5-run은 AI 평균/최대 305.3/35,241us, stuck/disengage 0.02/0.17 per entity/min, spawn fallback 0으로 scale gate를 통과했다 | 계측 성능은 구조 PASS지만 실제 Forward+ 끊김·사람 전체 매치·restart soak·다중 해상도는 새 package에서 별도 확인 |
| 99봇 구조 여유 | 고정 입력 5-run은 통과했지만 disengage 0.44가 한계 0.45에 가까움 | 99봇은 gameplay로 승격하지 않고 규모 민감 변경마다 구조 profile을 다시 실행 |
| 첫 사용자·호환성 공백 | exported binary 자동 부팅·전체 simulation은 통과했지만 UI·입력·가독성·정상 저장 생성은 사람이 확인하지 않음 | P3/P4에서 무설명 완주와 Win10/11·한글 경로·읽기 전용 설치·해상도/하드웨어 matrix를 gate로 유지 |
| 범위 팽창 | 온라인·99봇·macOS·신규 콘텐츠가 공개 데모 critical path와 경쟁 | 첫 공개 범위 밖 기능은 M4 Go/No-Go 전까지 보류 |
| 작업 트리 노이즈 | Godot UID가 일부만 추적되어 상태 출력에 100개 이상 노출 | 별도 운영 단위에서 UID 정책을 통일하고 gameplay 커밋과 섞지 않음 |

## 세션 규칙

새 구현 단위를 시작할 때는 현재 마일스톤, 현재 리스크, 종료 조건을 1-2문장으로 재진술한다.
