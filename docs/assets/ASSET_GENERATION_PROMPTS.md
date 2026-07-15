# 외부 자산 생성 프롬프트

> 최종 업데이트: 2026-06-30. 이미지/오디오/3D 생성기에 그대로 전달할 수 있는 작업 문서다.

## 현재 상태

생성 원본 풀:

```text
asset_generator/expected_output/
```

현재 런타임에 승격된 자산:

```text
assets/icons/weapons/*.png
assets/icons/ammo/*.png
assets/icons/items/*.png
assets/icons/artifacts/*.png
assets/props/forest/bush_*.glb
assets/sfx/weapons/*.wav
assets/sfx/footsteps/*.wav
```

보류 중인 생성 아이콘 풀:

```text
asset_generator/expected_output/assets/icons/action/*.png
asset_generator/expected_output/assets/icons/status/*.png
asset_generator/expected_output/assets/icons/map/*.png
asset_generator/expected_output/assets/icons/ui/*.png
```

시각 결함이 발견되지 않는 한 action/status/map/ui 아이콘은 재생성하지 않는다. 런타임 통합은 별도 repo 작업이다.

## 공통 요구사항

- 게임: Battle Capsule, low-poly quarter-view tactical roguelite battle royale.
- 우선순위: close-up detail보다 quarter-view/top-down 가독성.
- 스타일: 단순, 절제, 전술적, low-noise.
- 금지: 포토리얼, military sim realism, 귀여운 cartoon 과장, 텍스트, watermark, 외부 브랜드, 복잡한 패턴.
- 결과물은 `asset_generator/expected_output/` 아래에 둔다.
- `assets/`, `data/asset_catalog.json`, Godot scene 연결은 별도 통합 작업이다.
- 각 batch에는 `report.json`을 포함한다: 파일 경로, 크기/길이, 형식, 라이선스/source note.

## Batch A - 숲/랜드마크 GLB prop

### 출력 경로

```text
asset_generator/expected_output/assets/props/forest/tree_small.glb
asset_generator/expected_output/assets/props/forest/tree_cluster.glb
asset_generator/expected_output/assets/props/forest/bush_low.glb
asset_generator/expected_output/assets/props/forest/bush_dense.glb
asset_generator/expected_output/assets/props/forest/rock_small.glb
asset_generator/expected_output/assets/props/forest/rock_large.glb
asset_generator/expected_output/assets/props/landmarks/cabin.glb
asset_generator/expected_output/assets/props/landmarks/ruined_wall.glb
asset_generator/expected_output/assets/props/landmarks/camp_crate.glb
asset_generator/expected_output/assets/props/landmarks/camp_tarp.glb
asset_generator/expected_output/reports/report_batch_props_forest_01.json
asset_generator/expected_output/sheets/sheet_batch_props_forest_01.png
```

### Prop 기준

| ID | 파일 | footprint 목표 | 역할 |
|---|---|---|---|
| `forest.tree.small` | `tree_small.glb` | 폭 1.0-1.4m | 단일 LOS blocker/filler |
| `forest.tree.cluster` | `tree_cluster.glb` | 폭 2.5-4.0m | tree cover cluster |
| `forest.bush.low` | `bush_low.glb` | 폭 1.5-2.2m | 낮은 stealth cover |
| `forest.bush.dense` | `bush_dense.glb` | 폭 2.5-3.5m | 큰 stealth patch |
| `forest.rock.small` | `rock_small.glb` | 폭 1.0-1.8m | 작은 cover/filler |
| `forest.rock.large` | `rock_large.glb` | 폭 2.4-3.8m | 주요 cover object |
| `landmark.cabin` | `cabin.glb` | 폭 5-7m | loot landmark, interior 없음 |
| `landmark.wall` | `ruined_wall.glb` | 길이 3-6m | cover wall segment |
| `landmark.camp.crate` | `camp_crate.glb` | 폭 1-1.5m | loot camp prop |
| `landmark.camp.tarp` | `camp_tarp.glb` | 폭 3-5m | camp landmark silhouette |

### 복사용 프롬프트

```text
Create a batch of low-poly GLB props for Battle Capsule, a quarter-view tactical roguelite battle royale game in Godot 4.

The assets must be readable from a high quarter-view/top-down camera, not close-up. Use simple geometry, muted forest colors, clean material slots, and strong silhouettes. The forest map palette is dark green ground, muted foliage, gray rocks/buildings, and restrained warm loot-camp accents.

Generate these GLB files with exact filenames:
- assets/props/forest/tree_small.glb
- assets/props/forest/tree_cluster.glb
- assets/props/forest/bush_low.glb
- assets/props/forest/bush_dense.glb
- assets/props/forest/rock_small.glb
- assets/props/forest/rock_large.glb
- assets/props/landmarks/cabin.glb
- assets/props/landmarks/ruined_wall.glb
- assets/props/landmarks/camp_crate.glb
- assets/props/landmarks/camp_tarp.glb

Use 1 Godot unit = 1 meter. Put origins at ground level: bottom center for upright props, footprint center for rocks/crates/tarps. Keep all props low-poly, static, unanimated, and usable in Godot without missing texture errors. Prefer embedded simple materials over external texture files.

Avoid photorealism, dense texture noise, complex interiors, text, signs, logos, brands, cute/cartoon exaggeration, and high-detail hero assets. These are repeated gameplay props, so clarity and low visual noise matter more than detail.

Also create:
- one contact sheet PNG showing all props from an isometric/quarter-view angle
- a report JSON listing each file path, approximate footprint size, material count, and any license/source notes
```

## Batch B - Gameplay Audio WAV

### 출력 경로

```text
asset_generator/expected_output/assets/sfx/weapons/pistol_shoot.wav
asset_generator/expected_output/assets/sfx/weapons/ar_shoot.wav
asset_generator/expected_output/assets/sfx/weapons/shotgun_shoot.wav
asset_generator/expected_output/assets/sfx/weapons/railgun_shoot.wav
asset_generator/expected_output/assets/sfx/footsteps/grass_01.wav
asset_generator/expected_output/assets/sfx/footsteps/dirt_01.wav
asset_generator/expected_output/assets/sfx/footsteps/stone_01.wav
asset_generator/expected_output/assets/sfx/pickup.wav
asset_generator/expected_output/assets/sfx/heal.wav
asset_generator/expected_output/assets/sfx/zone_warning.wav
asset_generator/expected_output/reports/report_batch_audio_01.json
```

### 오디오 기준

| ID | 파일 | 길이 목표 | 메모 |
|---|---|---|---|
| `shoot.pistol` | `pistol_shoot.wav` | 0.08-0.18초 | compact sidearm pop |
| `shoot.ar` | `ar_shoot.wav` | 0.07-0.14초 | 반복 가능한 rifle shot |
| `shoot.shotgun` | `shotgun_shoot.wav` | 0.14-0.30초 | 넓은 thump, cinematic 금지 |
| `shoot.railgun` | `railgun_shoot.wav` | 0.18-0.35초 | rare energy snap |
| `footstep.grass` | `grass_01.wav` | 0.05-0.15초 | soft, repeat-safe |
| `footstep.dirt` | `dirt_01.wav` | 0.05-0.15초 | dry muted step |
| `footstep.stone` | `stone_01.wav` | 0.05-0.16초 | muted stone tap |
| `pickup` | `pickup.wav` | 0.08-0.25초 | item collect ping |
| `heal` | `heal.wav` | 0.15-0.45초 | warm recovery cue |
| `zone_warning` | `zone_warning.wav` | 0.25-0.55초 | urgent two-pulse warning |

### 복사용 프롬프트

```text
Create compact mono WAV sound effects for Battle Capsule, a low-poly quarter-view tactical roguelite battle royale.

The tone should be dry, readable, compact, and arcade-tactical. These are not military-sim sounds. Avoid cinematic reverb, long tails, vocals, distortion, excessive bass, realistic firearm loudness, and music stingers.

Generate exactly these files:
- assets/sfx/weapons/pistol_shoot.wav
- assets/sfx/weapons/ar_shoot.wav
- assets/sfx/weapons/shotgun_shoot.wav
- assets/sfx/weapons/railgun_shoot.wav
- assets/sfx/footsteps/grass_01.wav
- assets/sfx/footsteps/dirt_01.wav
- assets/sfx/footsteps/stone_01.wav
- assets/sfx/pickup.wav
- assets/sfx/heal.wav
- assets/sfx/zone_warning.wav

All files must be mono 44.1 kHz 16-bit PCM WAV.

Length targets:
- weapon shots: 0.08s to 0.35s
- footsteps: 0.05s to 0.16s
- pickup/heal/UI warning: 0.08s to 0.55s

Footsteps must be subtle and repeat-safe. AR and pistol shots must be short enough for repeated combat. Shotgun should feel wider but still compact. Railgun should read as rare/energy-based but should not have a long sci-fi tail. Zone warning should be urgent and recognizable, ideally a short two-pulse cue.

Also create a report JSON listing each file path, duration, sample rate, bit depth, and license/source notes.
```

## 수용 체크

- GLB는 Godot 4에서 missing texture 없이 열린다.
- footprint가 작은 화면에서도 읽힌다.
- 오디오는 mono 44.1 kHz 16-bit PCM WAV다.
- clipping, 긴 reverb tail, vocal이 없다.
- report에 라이선스/source note가 있다.

## Repo 통합 메모

생성 자산이 돌아오면 별도 작업으로 처리한다.

1. 생성 파일과 report를 확인한다.
2. 런타임에 필요한 파일만 선택한다.
3. 선택 파일을 `assets/`로 복사한다.
4. `data/asset_catalog.json`에 path를 등록한다.
5. fallback 동작을 유지한다.
6. 검증:

```powershell
git diff --check
.\Godot_v4.6.2-stable_win64_console.exe --path . --headless --quit
python tools\simulate_matches.py 1
```

아이콘 master를 승격할 때만:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\sync_generated_icons.ps1
```
