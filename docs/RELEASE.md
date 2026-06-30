# 릴리즈 가이드

> 최종 업데이트: 2026-06-30. 릴리즈는 사용자가 명시적으로 요청할 때만 진행한다.

## 현재 기준

- 현재 안정 태그: `v2.0.0-pre-expansion`
- GitHub 저장소: `https://github.com/Kyulhee/battle-capsule`
- 파일명 규칙:
  - Windows: `BattleRoyalePrototype_${VER}_win64.zip`
  - macOS: `BattleRoyalePrototype_${VER}_macos.zip`

## 릴리즈 전 조건

- 사용자가 릴리즈/빌드를 명시 요청했다.
- `TESTING.md`의 관련 smoke와 simulation gate가 통과했다.
- release note에 들어갈 변경 요약이 `DEVLOG.md` 또는 버전 로그에 있다.
- default promotion, build target, tag 이름을 확인했다.

## 절차

### 1. 검증

```powershell
python tools\run_verify.py --profile unit_smoke
python tools\simulate_matches.py 5
python tools\analyze_results.py
```

릴리즈 성격에 따라 `scale_99`, `visual_review`, 수동 실행을 추가한다.

### 2. 버전 갱신

`export_presets.cfg`의 Windows/macOS 버전을 갱신한다.

### 3. 빌드

```powershell
$VER="vX.Y.Z"

.\Godot_v4.6.2-stable_win64.exe --headless --export-release "Windows Desktop" "builds/BattleRoyalePrototype_${VER}_win64.zip"
.\Godot_v4.6.2-stable_win64.exe --headless --export-release "macOS" "builds/BattleRoyalePrototype_${VER}_macos.zip"
```

macOS 주의:

- `project.godot`에 `textures/vram_compression/import_etc2_astc=true` 필요.
- `export_presets.cfg` key는 `application/bundle_identifier`.

### 4. 커밋, 태그, 푸쉬

```powershell
$VER="vX.Y.Z"

git add export_presets.cfg README.md docs\RELEASE.md
git commit -m "chore: prepare release $VER"
git tag $VER
git push origin master
git push origin $VER
```

### 5. GitHub 릴리즈

```powershell
$VER="vX.Y.Z"
gh release create $VER `
  --title "배틀캡슐 $VER - 한줄 요약" `
  --notes-file release_notes.md `
  "builds/BattleRoyalePrototype_${VER}_win64.zip" `
  "builds/BattleRoyalePrototype_${VER}_macos.zip"
```

### 6. README 다운로드 링크 갱신

릴리즈 asset URL이 맞는지 확인하고 README 배지를 갱신한다.

## 체크리스트

```text
[ ] 릴리즈 요청 확인
[ ] 검증 profile 통과
[ ] export preset 버전 갱신
[ ] Windows 빌드 생성/실행 확인
[ ] macOS 빌드 생성
[ ] git tag + push
[ ] GitHub release 생성
[ ] asset 업로드 확인
[ ] README 다운로드 링크 갱신
[ ] DEVLOG/MASTERPLAN 상태 갱신
```
