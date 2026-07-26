# 릴리즈 가이드

> 최종 업데이트: 2026-07-26. 릴리즈 준비는 활성 작업이지만 실제 tag·GitHub Release 공개는 사용자 명시 지시 뒤에만 진행한다.

## 현재 범위

- 저장소: `https://github.com/Kyulhee/battle-capsule`
- 현재 공개 안정 태그: `v2.0.0-pre-expansion`
- 첫 공개 목표: Windows x64, 오프라인 싱글플레이, 한국어, 키보드/마우스, `night_br_m1_60` 한 맵 무료 데모
- macOS는 실제 Mac 실행·서명·notarization을 통과하기 전 R0/R1 지원 대상에서 제외
- `target_99_probe`는 구조 회귀이며 출시 gameplay 규모가 아님
- 공개 archive 이름: `BattleCapsule_${ReleaseVersion}_win64.zip`

## 릴리즈 단계

| 단계 | 제품 gate | 목표 |
|---|---|---|
| R0 폐쇄 알파 후보 | M1 + `N2-REL-01` | 제한을 명시한 Windows 내부 RC와 외부 테스트 시작 |
| R1 공개 데모 후보 | M2 + M3 | 공개 페이지·지원 경로·재현 가능한 artifact를 갖춘 무료 데모 |
| R2 유료 EA 판단 | M4 | 데모 결과를 근거로 콘텐츠·플랫폼·운영 투자 결정 |

단계별 상세 gate와 목표 창은 `MASTERPLAN.md`가 소유한다. 이 문서는 검증·패키징·공개 절차만 소유한다.

## N2-REL-01 종료 조건

- 미션 보너스와 Result/Records 점수가 일치하고 simulation은 사용자 기록을 남기지 않음
- `settings.cfg`, `match_history.json`, `achievements.json`에 schema version, 원자적 교체, backup, corrupt fallback이 있음
- `asset_generator/**`, `plan_report/**`, debug·test·tool 원본이 export에 들어가지 않음
- 제품명, 실행 파일, 아이콘, 메뉴 버전, Windows metadata, archive/manifest release identifier가 `Battle Capsule`과 한 버전을 공유하고, tag를 만들 경우 같은 버전에 매핑
- clean source에서 만든 EXE/PCK가 첫 실행→한 판→결과→재시작→재실행 저장 확인을 통과
- archive 파일 목록·크기, SHA-256, source commit, Godot 버전, known issues를 manifest에 기록

이 단계의 산출물은 공개판이 아니라 `v2.1.0-demo-dev` 내부 build다.

현재 자동 완료 범위는 점수/기록 일치, simulation 격리, 세 save의 schema v1·원자 교체·backup/corrupt/legacy fixture, 현재 공개판 rollback bridge와 future-schema 보존, `Battle Capsule`·`v2.1.0-demo-dev` identity와 명시적 export 경계다. `unit_smoke`, Forward+ 3-run, 고정 입력 `target_99_probe` 5-run도 통과했다. workspace export의 PE metadata/headless boot는 사전 smoke일 뿐이며 `.godot` cache가 없는 clean tracked PCK inventory·전체 루프·manifest가 잔여 gate다. 사람이 직접 하는 재시작/재실행, LICENSES/CREDITS·회사/저작권 정책·지원 경로도 공개 전 필요하고 signing은 현재 꺼져 있다.

## 1. 소스 검증

R0/R1 후보는 아래 명령을 현재 M1 map·preset과 별도 출력 경로로 실행한다.

```powershell
python tools\run_verify.py --profile unit_smoke
python tools\run_verify.py --profile pacing_candidate --map-spec-path res://data/mapSpec_night_forest_expanded_candidate.json --pacing-preset night_br_m1_60 --runs 5 --out-root C:\tmp\release_pacing
python tools\run_verify.py --profile scale_99 --runs 5 --out-root C:\tmp\release_scale_99
python tools\run_verify.py --profile visual_review --out-root C:\tmp\release_visual
```

Forward+는 같은 조건을 최소 3회 재며 p95 20ms 초과 run을 제외하지 않는다. 초과가 반복되면 승격을 중단한다.

```powershell
.\Godot_v4.6.2-stable_win64_console.exe --path . --script res://tools/profile_runtime_performance.gd -- map_spec_path=res://data/mapSpec_night_forest_expanded_candidate.json scale_preset=night_br_m1_60 perf_warmup_seconds=5 perf_sample_seconds=20 perf_output=C:/tmp/release_performance.json
```

R1에는 짧은 profile 외에 실제 10-15분 전체 매치, 반복 재시작, 장시간 soak 결과가 필요하다.

## 2. clean build source

- 현재 작업 디렉터리가 아니라 clean clone 또는 release 전용 clean worktree에서 빌드한다.
- `git status --porcelain`이 비어 있지 않으면 release build를 중단한다.
- source commit과 tag 후보를 manifest에 먼저 기록한다.
- export preset은 runtime resource만 포함하고 로컬 생성 원본·테스트·도구·문서·debug screenshot·console wrapper를 제외한다.
- 같은 commit을 두 번 export했을 때 archive 내용과 예상 크기가 허용 범위 안에서 같아야 한다.

## 3. 버전·브랜드

`src/core/BuildInfo.gd`가 제품명·제품 버전·채널·표시 버전·Windows 버전·실행 파일명 계약을 소유한다. Godot export preset 자체를 생성하지는 않으므로 release identity verifier가 다음 중복 위치의 불일치를 막는다. archive/manifest/tag 매핑은 패키징 단계에서 별도로 검증한다.

- `project.godot`의 application name
- `export_presets.cfg`의 file/product version, product/company/description/copyright, icon
- `BuildVersionLabel.gd`가 그리는 메뉴 표시 버전
- EXE/PCK 이름, archive 이름, manifest, release note, Git tag

공개 이름은 `Battle Capsule`, 실행 파일은 `BattleCapsule.exe`를 사용한다.

## 4. Windows export와 archive

Godot export 대상은 `.zip`이 아니라 staging의 `.exe`다. 생성된 EXE/PCK를 검증한 뒤 별도로 압축한다.

```powershell
$ReleaseVersion = "vX.Y.Z"
$StagePath = "builds\staging\$ReleaseVersion\windows"
$ArchivePath = "builds\BattleCapsule_${ReleaseVersion}_win64.zip"

New-Item -ItemType Directory -Force -Path $StagePath | Out-Null
.\Godot_v4.6.2-stable_win64_console.exe --headless --path . --export-release "Windows Desktop" "$StagePath\BattleCapsule.exe"
Compress-Archive -Path "$StagePath\*" -DestinationPath $ArchivePath
Get-FileHash -Algorithm SHA256 $ArchivePath
```

archive에는 EXE/PCK, `README`, `KNOWN_ISSUES`, `LICENSES/CREDITS`, build manifest만 둔다. 원본 프로젝트·도구·텔레메트리 결과는 넣지 않는다.

## 5. packaged artifact 승인

압축을 새 경로에 풀고 다음을 실제 binary로 확인한다.

- Windows 10/11 표준 사용자, 한글 경로, 읽기 전용 설치 경로에서 첫 실행
- 깨끗한 user profile에서 메뉴→설정→매치→결과→재시작→종료
- 재실행 뒤 설정·정상 기록·배지가 보존되고 simulation 기록은 없음
- 이전 정상 save, 손상 save, 빈 save에서 crash·데이터 전체 유실이 없음
- 지원 해상도에서 HUD·미니맵·결과가 잘리지 않음
- 전체 매치와 반복 재시작에서 crash, softlock, 지속적인 p95 20ms 초과가 없음
- package manifest의 파일·크기·hash가 실제 archive와 일치

R1 공개 후보는 외부 20회 이상 완주와 P0/P1 결함 0을 추가로 요구한다.

## 6. 고지와 지원

- Godot와 모든 제3자 자산의 라이선스·출처를 `LICENSES/CREDITS`에 포함한다.
- 로컬 저장 데이터 종류, 삭제 방법, 외부 전송 없음과 향후 원격 수집 시 opt-in 원칙을 밝힌다.
- 버전·commit·OS·renderer·최근 로그를 묶는 진단 정보와 버그 신고 URL 또는 이메일을 제공한다.
- 무료 데모가 unsigned라면 경고 가능성을 공개한다. 유료 직접 배포 또는 스토어 확대 전에는 코드 서명을 R2 gate로 승격한다.

## 7. tag와 공개

사용자가 최종 공개를 지시하고 candidate commit·artifact가 고정된 뒤에만 수행한다.

```powershell
$ReleaseVersion = "vX.Y.Z"

git tag $ReleaseVersion
git push origin master
git push origin $ReleaseVersion
gh release create $ReleaseVersion `
  --title "Battle Capsule $ReleaseVersion" `
  --notes-file release_notes.md `
  "builds\BattleCapsule_${ReleaseVersion}_win64.zip"
```

업로드된 asset의 SHA-256과 실행 smoke를 다시 확인한 뒤 README 다운로드 링크와 안정판 배지를 갱신한다.

## 최종 체크리스트

```text
[ ] 공개 승인과 대상 단계 확인
[ ] M1/M2/M3 해당 gate와 수동 기록 통과
[ ] clean source와 candidate commit 고정
[ ] 저장·기록·migration/corrupt fixture 통과
[ ] 제품명·버전·아이콘·metadata 일치
[ ] 명시적 export 경계와 clean PCK/archive 내용 검사
[ ] packaged EXE 전체 루프·재실행·호환성 확인
[ ] 전체 매치·restart soak·외부 테스트 통과
[ ] LICENSES/CREDITS·로컬 데이터·지원 경로 포함
[ ] manifest·SHA-256·known issues·release note 생성
[ ] tag·GitHub Release·업로드 hash 확인
[ ] README·CURRENT·MASTERPLAN·DEVLOG 갱신
```
