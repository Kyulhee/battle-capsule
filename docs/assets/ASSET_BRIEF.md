# Battle Capsule 자산 제작 브리프

> 최종 업데이트: 2026-06-30. 외부 생성기나 수동 제작자에게 전달할 안정된 스타일/포맷 기준이다.

## 목적

이 문서는 런타임에 통합할 자산의 기준을 정의한다. 복사 가능한 생성 프롬프트는 [ASSET_GENERATION_PROMPTS.md](ASSET_GENERATION_PROMPTS.md)에 둔다. 생성 원본은 `asset_generator/expected_output/`에 보관하고, 실제 사용할 파일만 `assets/`로 승격한 뒤 `data/asset_catalog.json`에 연결한다.

## 스타일 목표

**게임**: Godot 기반 쿼터뷰 전술 roguelite battle royale 프로토타입.

**시각 언어**

- Low-poly, 읽기 쉬움, 전술적, 절제된 톤.
- 클로즈업 디테일보다는 top-down/quarter-view 가독성이 우선.
- 숲 맵 팔레트: 어두운 녹색 지면, muted foliage, 회색 암석/건물, 따뜻한 loot accent.
- 작은 HUD/미니맵 크기에서도 실루엣이 읽혀야 한다.
- 금지: 포토리얼, glossy 고디테일 텍스처, 귀여운 cartoon 과장, 복잡한 로고, 이미지 안의 텍스트, 노이즈 패턴.
- UI 아이콘은 투명 배경, 단순한 filled silhouette, 1-2개 accent 색상.
- 3D prop은 단순 형상, 낮은 정점 수, 깔끔한 material slot, 강한 상단 footprint.

**오디오 언어**

- 짧고 dry하며 즉각적으로 읽혀야 한다.
- 영화적 reverb, 긴 tail, vocal, music sting, 군사 시뮬레이션식 총성은 피한다.
- 작은 arcade tactical game의 믹스 안에 들어갈 정도의 loudness가 적절하다.

## 출력 규칙

### 오디오

- 형식: mono `.wav`
- 샘플레이트: 44100 Hz
- 비트 깊이: 16-bit PCM
- 길이:
  - weapon shot: 0.08-0.35초
  - reload: 0.25-0.7초
  - footstep: 0.05-0.18초
  - UI/item: 0.08-0.5초
- stock source를 쓰면 CC0 또는 상업 사용 가능 라이선스만 사용한다.

### 아이콘

- 형식: `.png`
- master 크기: 1024x1024 선호, 256x256 허용.
- runtime 크기: 현재 HUD/픽업 decal 기준 64x64.
- 배경: 투명.
- safe area: 중앙 80% 안에 들어오게 한다.
- 스타일: flat 또는 최소 shading, 두꺼운 실루엣, 1-2개 accent 색상.
- 텍스트, tiny detail, 어두운 UI에서 사라지는 shadow 금지.
- 생성 후 필요하면 `tools/sync_generated_icons.ps1`로 투명 여백 crop/downsample.

### 3D prop

- 선호 형식: `.glb`
- 스케일: 1 Godot unit = 1m.
- origin: upright prop은 bottom center, rock/crate는 footprint center.
- material: 1-3개 단순 PBR material.
- geometry: low-poly, clean normals, 첫 패스에서는 animation 불필요.
- 모든 prop은 위에서 보아 footprint가 읽혀야 한다.

## 우선 생성 대상

### 오디오

| ID | 경로 | 기준 |
|---|---|---|
| `shoot.pistol` | `assets/sfx/weapons/pistol_shoot.wav` | 짧은 sidearm pop |
| `shoot.ar` | `assets/sfx/weapons/ar_shoot.wav` | 반복 가능한 rifle shot |
| `shoot.shotgun` | `assets/sfx/weapons/shotgun_shoot.wav` | 넓지만 짧은 punch |
| `shoot.railgun` | `assets/sfx/weapons/railgun_shoot.wav` | rare energy snap |
| `footstep.grass` | `assets/sfx/footsteps/grass_01.wav` | 부드러운 grass step |
| `footstep.dirt` | `assets/sfx/footsteps/dirt_01.wav` | dry ground step |
| `footstep.stone` | `assets/sfx/footsteps/stone_01.wav` | muted stone tap |
| `pickup`, `heal`, `zone_warning` | `assets/sfx/...` | 짧고 명확한 item/zone cue |

### 아이콘

| ID | 경로 | 기준 |
|---|---|---|
| `weapon.*` | `assets/icons/weapons/` | knife, pistol, ar, shotgun, railgun |
| `ammo.*` | `assets/icons/ammo/` | weapon별 ammo |
| `item.heal`, `item.medkit`, `item.armor` | `assets/icons/items/` | 회복/방어 판독 |
| `artifact.*` | `assets/icons/artifacts/` | starting artifact 6종 |

### 3D prop

| ID | 경로 | 기준 |
|---|---|---|
| `forest.tree.small` | `assets/props/forest/tree_small.glb` | 작은 LOS blocker |
| `forest.tree.cluster` | `assets/props/forest/tree_cluster.glb` | 읽히는 tree cover cluster |
| `forest.bush.low` | `assets/props/forest/bush_low.glb` | 낮은 stealth cover |
| `forest.bush.dense` | `assets/props/forest/bush_dense.glb` | 큰 stealth patch |
| `forest.rock.*` | `assets/props/forest/` | cover/readability prop |
| `landmark.*` | `assets/props/landmarks/` | cabin, ruined wall, camp prop |

## 수용 체크리스트

- 파일명이 catalog 또는 브리프 경로와 맞는다.
- 오디오는 mono 44100 Hz 16-bit PCM WAV다.
- PNG 아이콘은 투명 배경이다.
- GLB는 Godot에서 missing texture 없이 열린다.
- 텍스트, watermark, 외부 브랜드가 없다.
- stock source를 썼다면 라이선스를 기록했다.
- 선택된 파일만 `assets/`로 승격한다.
- `data/asset_catalog.json` path를 갱신한다.
- 최소 검증:

```powershell
git diff --check
.\Godot_v4.6.2-stable_win64_console.exe --path . --headless --quit
python tools\simulate_matches.py 1
```
