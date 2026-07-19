# Battle Capsule 자산 상태

> 최종 업데이트: 2026-07-19. 현재 통합/보류/미연결 자산 상태를 요약한다.

## 연결 방식

런타임 자산 조회는 `src/core/AssetCatalog.gd`가 담당하고, 데이터는 `data/asset_catalog.json`에서 읽는다.

```text
data/asset_catalog.json
  category(audio/icons/props/cosmetics)
    id -> { "path": "res://...", "fallback": "...", "tags": [...] }
```

`AssetCatalog.get_path(category, id, fallback)`은 경로를 반환하거나 없으면 빈 문자열을 반환한다. 빈 경로는 오류가 아니라 procedural fallback 또는 기본 표시로 이어진다.

현재 path가 설정된 7개 항목은 모두 실제 파일과 연결되어 `AssetCatalog.missing_count()`가 0이다. path가 비어 있는 항목은 의도된 procedural fallback이며 누락 경고 대상이 아니다.

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
| `reload`, `dry_fire`, `hit`, `impact_wall`, `hurt`, `death`, `pickup`, `heal`, `melee`, `zone_warning`, fallback IDs | path 비어 있음 | procedural sound 또는 silence fallback |

발걸음은 Kenney CC0 원본을 유지한다. 첫 무기음 4종은 Kenney laser proxy여서 수동 폐기했고, OpenGameArt `Gunshot Sounds` CC0 실사 녹음으로 교체했다. 세부 출처와 가공 범위는 `assets/sfx/README.txt`에 둔다. `SoundManager`는 성공 스트림을 ID별로 캐시하고 무기별 볼륨과 ±2% 피치 변화를 적용한다.

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
| `forest.tree`, `forest.rock`, `landmark.cabin`, `landmark.wall` | path 비어 있음 | catalog entry만 있음 |

통합되지 않은 GLB는 `asset_generator/expected_output/assets/props/`에 남아 있다. 주요 목록:

```text
forest/tree_small.glb
forest/tree_cluster.glb
forest/rock_small.glb
forest/rock_cluster.glb
forest/rock_large.glb
forest/log_pile.glb
forest/fallen_tree.glb
landmarks/ruined_wall.glb
landmarks/cabin.glb
landmarks/camp_crate.glb
landmarks/camp_tarp.glb
landmarks/watchtower.glb
landmarks/barrel_cluster.glb
landmarks/fire_pit.glb
```

### 캐릭터 cosmetic

`player.default`, `bot.*` 경로는 비어 있다. 현재 모든 캐릭터는 procedural geometry를 사용한다.

## Bush 통합 방식

Bush는 현재 prop 중 유일하게 전체 통합 흐름을 가진다.

1. `WorldBuilder._build_bush_patch()`가 `Bush.tscn`을 만든다.
2. `_apply_catalog_visual()`이 GLB를 `CatalogPropVisual`로 붙인다.
3. `Bush.gd`가 GLB mesh chunk를 rustle 대상에 등록하고, gameplay boundary는 기존 `Area3D` cylinder가 계속 담당한다.
4. 진입/이동 시 가까운 chunk만 sway/lift 애니메이션을 한다.

중요: GLB는 순수 시각 자산이다. 은신 판정은 `Bush.tscn`의 Area3D가 권한을 가진다.

## 보류된 자산 결정

| 항목 | 내용 | 재개 조건 |
|---|---|---|
| Bush B cell-based Area3D | bush patch를 개별 cell로 나누는 구조 | fire spread 또는 per-cell vision event 구현 시 |
| GLB visual replacement pass | tree/rock/landmark GLB를 procedural collision 위에 붙임 | 시각 업그레이드가 우선순위가 될 때 |
| Landmark collision redesign | cabin/watchtower/tarp/crate 정밀 collision | interior/climbable gameplay 결정 후 |
| Dynamic event props | barrel/fire/log 등 event prop | fire/explosion 시스템과 함께 |

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
