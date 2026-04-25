# 릴리즈 가이드

> 배틀캡슐 빌드 & GitHub 릴리즈 전체 절차

---

## 릴리즈 이력 패턴

| 버전 | 태그 | Windows | macOS | 비고 |
|---|---|---|---|---|
| v0.1.0 | `v0.1.0` | `.exe` + `.pck` (별도) | — | Pre-release |
| v0.2.0~v0.2.1 | `v0.2.x` | `_vX.Y.Z_win64.zip` | — | zip 전환 |
| v0.3.1 | `v0.3.1` | `_vX.Y.Z_win64.zip` | — | — |
| v0.3.2~ | `v0.3.2` | `_vX.Y.Z_win64.zip` | `_mac.zip` | 한국어 릴리즈노트, 배지 방식 README |

**파일명 규칙**
- Windows: `BattleRoyalePrototype_vX.Y.Z_win64.zip`
- macOS: `BattleRoyalePrototype_mac.zip` ← 버전 미포함 (태그 경로로 구분됨)

---

## 릴리즈 절차

### 1. 빌드 전 체크

```bash
# 헤드리스 시뮬레이션으로 AI/밸런스 이상 없는지 확인
./Godot_v4.6.2-stable_win64_console.exe --headless -- autostart=true
cat "$APPDATA/Godot/app_userdata/BattleRoyalePrototype/sim_result_latest.json"
```

TESTING.md의 체크리스트를 통과했는지 확인한다.

### 2. export_presets.cfg 버전 업데이트

```
# preset.0.options (Windows)
application/file_version="0.4.0.0"
application/product_version="0.4.0.0"

# preset.1.options (macOS)
application/short_version="0.4.0"
application/version="0.4.0"
```

### 3. Godot 헤드리스 빌드

```bash
VER="v0.4.0"

# Windows
./Godot_v4.6.2-stable_win64.exe --headless \
  --export-release "Windows Desktop" \
  "builds/BattleRoyalePrototype_${VER}_win64.zip"

# macOS (Universal)
./Godot_v4.6.2-stable_win64.exe --headless \
  --export-release "macOS" \
  "builds/BattleRoyalePrototype_mac.zip"
```

> macOS 빌드 주의:
> - `project.godot`에 `textures/vram_compression/import_etc2_astc=true` 필요
> - `export_presets.cfg`의 macOS 키는 `application/bundle_identifier` (not `application/identifier`)

### 4. git 태그 & 푸시

```bash
VER="v0.4.0"

git add -A
git commit -m "chore: bump version to $VER"
git tag $VER
git push origin master
git push origin $VER
```

### 5. GitHub 릴리즈 생성

```bash
VER="v0.4.0"
WIN_ZIP="builds/BattleRoyalePrototype_${VER}_win64.zip"
MAC_ZIP="builds/BattleRoyalePrototype_mac.zip"

gh release create $VER \
  --title "배틀캡슐 $VER — 봇 AI 개선" \
  --notes "$(cat <<'EOF'
## 주요 변경 사항

변경 내용을 여기에 작성 (한국어).

### 무기 밸런스 등 표가 있으면 추가

**다운로드**: 위 Assets에서 Windows / macOS 선택
EOF
)" \
  "$WIN_ZIP" \
  "$MAC_ZIP"
```

릴리즈 노트 작성 기준 (v0.3.2 이후 한국어):
- 제목: `배틀캡슐 vX.Y.Z — 한줄요약`
- 본문: 주요 변경 사항 위주, 표 필요 시 Markdown 테이블

### 6. README 배지 업데이트

[README.md](README.md) 상단 다운로드 섹션에서 버전 2곳 수정:

```markdown
## 다운로드 (v0.4.0)

[![Windows](https://img.shields.io/badge/Windows-0078D4?style=for-the-badge&logo=windows&logoColor=white)](https://github.com/Kyulhee/battle-capsule/releases/download/v0.4.0/BattleRoyalePrototype_v0.4.0_win64.zip)
[![macOS](https://img.shields.io/badge/macOS-000000?style=for-the-badge&logo=apple&logoColor=white)](https://github.com/Kyulhee/battle-capsule/releases/download/v0.4.0/BattleRoyalePrototype_mac.zip)
```

수정 후 커밋·푸시:

```bash
git add README.md
git commit -m "docs: update download links to vX.Y.Z"
git push origin master
```

---

## v0.4.0 릴리즈 시 체크리스트

```
[ ] 헤드리스 시뮬레이션 통과 (TESTING.md 봇 AI 체크리스트)
[ ] export_presets.cfg 버전 번호 업데이트
[ ] Windows 빌드 생성 및 로컬 실행 확인
[ ] macOS 빌드 생성 (bundle_identifier 키 확인)
[ ] git tag + push
[ ] gh release create (Windows + macOS 첨부)
[ ] README 배지 URL 업데이트 + push
[ ] gh release view vX.Y.Z 로 asset 업로드 확인
```

---

## 참고: 릴리즈 노트 예시 (v0.3.2)

```
title: 배틀캡슐 v0.3.2 — 탄약 시스템 개편
tag:   v0.3.2
assets: BattleRoyalePrototype_v0.3.2_win64.zip
        BattleRoyalePrototype_mac.zip
```

릴리즈 본문은 DEVLOG.md 해당 버전 섹션을 요약해서 작성한다.
