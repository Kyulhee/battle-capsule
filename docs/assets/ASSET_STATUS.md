# Battle Capsule 자산 상태

> 최종 업데이트: 2026-07-21. 현재 통합/보류/미연결 자산 상태를 요약한다.

## 연결 방식

런타임 자산 조회는 `src/core/AssetCatalog.gd`가 담당하고, 데이터는 `data/asset_catalog.json`에서 읽는다.

```text
data/asset_catalog.json
  category(audio/icons/materials/props/cosmetics)
    id -> { "path": "res://...", "fallback": "...", "tags": [...] }
```

`AssetCatalog.get_path(category, id, fallback)`은 경로를 반환하거나 없으면 빈 문자열을 반환한다. 빈 경로는 오류가 아니라 procedural fallback 또는 기본 표시로 이어진다.

현재 path가 설정된 항목은 audio 11, icons 18, materials 3, props 14개이며 모두 실제 파일과 연결되어 `AssetCatalog.missing_count()`가 0이다. path가 비어 있는 항목은 의도된 procedural fallback이며 누락 경고 대상이 아니다.

## 현재 catalog 상태

### 오디오

| ID | 상태 | 파일 |
|---|---|---|
| `shoot.pistol` | 교체 후보 | CC0 실사 `cz.wav` 단발 |
| `shoot.ar` | 교체 후보 | CC0 실사 `sks.wav` 단발 |
| `shoot.shotgun` | 교체 후보 | CC0 실사 `shotty.wav` 단발 |
| `shoot.railgun` | 교체 후보 | CC0 실사 `mosin.wav` 단발 |
| `footstep.grass` | 수동 채택 | `res://assets/sfx/footsteps/grass_01.wav` |
| `footstep.dirt` | 수동 채택 | `res://assets/sfx/footsteps/dirt_01.wav` |
| `footstep.stone` | 수동 채택 | `res://assets/sfx/footsteps/stone_01.wav` |
| `melee.swing` 1-3 | 교체 후보 | CC0 Foley `swish-1/4/7.wav` |
| `melee.hit` | 교체 후보 | CC0 `qubodupImpactMeat01.ogg` |
| `reload`, `dry_fire`, `hit`, `impact_wall`, `hurt`, `death`, `pickup`, `heal`, `zone_warning`, fallback IDs | path 비어 있음 | procedural sound 또는 silence fallback |

발걸음은 Kenney CC0 원본을 유지한다. 첫 무기음 4종은 OpenGameArt `Gunshot Sounds` CC0 실사 녹음이다. 칼은 OpenGameArt CC0 휘두름 3종과 살점 피격음을 분리했다. 세부 출처와 가공 범위는 `assets/sfx/README.txt`에 둔다. `SoundManager`는 성공 스트림을 ID별로 캐시하며 권총은 AR보다 작게, 앉기 발걸음은 -10 dB로 재생한다.

### 아이콘

| ID | 상태 | 메모 |
|---|---|---|
| `weapon.*` | 통합됨 | `res://assets/icons/weapons/` |
| `ammo.*` | 통합됨 | `res://assets/icons/ammo/` |
| `item.heal`, `item.medkit`, `item.armor` | 통합됨 | `res://assets/icons/items/` |
| 시작 artifact 6종 | 통합됨 | `red_trigger`, `armor_sponge`, `silent_core`, `zone_battery`, `emergency_shell`, `ghost_grass` |

`ArtifactIconResolver.gd`는 import metadata가 없어도 raw `Image.load()` fallback을 처리하므로 `.import` 파일이 없어도 된다.

### 3D prop

| ID | 상태 | 메모 |
|---|---|---|
| `forest.bush`, `forest.bush.low`, `forest.bush.dense` | 통합됨 | `res://assets/props/forest/bush_*.glb` |
| `forest.tree` | 후보 통합 | Cabin Row 외곽 수목 6개 |
| `landmark.cabin`, `landmark.wall` | 후보 통합 | Cabin Row 건물 3동·경계벽 2개 |
| `landmark.crate`, `landmark.barrels`, `landmark.fire_pit` | 후보 통합 | 마당 보급·생활 프롭 |
| `landmark.watchtower`, `landmark.camp.tarp` | 후보 통합 | West Ridge 감시 실루엣·screen cover |
| `forest.rock.large`, `forest.log.pile`, `forest.fallen.tree` | 후보 통합 | West Ridge 능선·벌목 hard cover |
| `forest.rock` | path 비어 있음 | 기존 procedural rock 유지 |

아직 런타임에 연결하지 않은 GLB는 `asset_generator/expected_output/assets/props/`에 남아 있다. 주요 목록:

```text
forest/tree_small.glb
forest/rock_small.glb
forest/rock_cluster.glb
```

### 지면 material

`ground.forest_dirt`, `ground.forest_grass`, `ground.path_dirt`를 연결했다. `surface_zones` 10개가 실제 지면, 발걸음 surface ID, 미니맵·전체 지도를 같은 데이터로 사용한다.

### 캐릭터 cosmetic

`player.default`, `bot.*` 경로는 비어 있다. 현재 모든 캐릭터는 procedural geometry를 사용한다.

## 월드 프롭 통합 방식

1. `WorldBuilder._build_bush_patch()`가 `Bush.tscn`을 만든다.
2. `_apply_catalog_visual()`이 GLB를 `CatalogPropVisual`로 붙인다.
3. `Bush.gd`가 GLB mesh chunk를 rustle 대상에 등록하고, gameplay boundary는 기존 `Area3D` cylinder가 계속 담당한다.
4. 진입/이동 시 가까운 chunk만 sway/lift 애니메이션을 한다.

중요: GLB는 순수 시각 자산이다. 은신 판정은 `Bush.tscn`의 Area3D가 권한을 가진다.

Tree와 landmark도 기존 충돌 proxy 위에 시각 GLB를 붙인다. 정적 GLB는 재질별로 메시를 합치고, 세밀한 cabin interior collision은 아직 제공하지 않는다.

## 보류된 자산 결정

| 항목 | 내용 | 재개 조건 |
|---|---|---|
| Bush B cell-based Area3D | bush patch를 개별 cell로 나누는 구조 | fire spread 또는 per-cell vision event 구현 시 |
| 나머지 지역 GLB pass | Cabin Row 문법을 다른 POI에 맞게 변형 | N2-PLAY-06에서 첫 지역 묶음 채택 시 |
| Landmark collision redesign | cabin/watchtower/tarp/crate 정밀 collision | interior/climbable gameplay 결정 후 |
| Dynamic event behavior | 연결된 barrel/fire 시각물과 미연결 log에 상호작용 추가 | fire/explosion 시스템과 함께 |

## 생성 워크스페이스

`asset_generator/`는 의도적으로 untracked다. 명시 요청 없이 `git add`하지 않는다.

포함 내용:

- `scripts/generate_prop.py`
- `scripts/generate_icon.py`
- `scripts/generate_audio.py`
- `scripts/fetch_kenney_audio.py`
- `scripts/render_prop_preview.py`
- `expected_output/`

런타임 승격 절차:

1. 생성 파일과 report를 확인한다.
2. 필요한 파일만 `assets/`로 복사한다.
3. `data/asset_catalog.json` path를 추가한다.
4. fallback 동작을 유지한다.
5. `verify_audio_catalog_assets.gd`, `unit_smoke`, 60봇 Forward+ 2회로 확인한다.
