# Battle Capsule — Asset Status

> Created: 2026-05-30. Updated after artifact icon completion. For agent handoff. Describes the current state of all asset types,
> what is integrated, what is generated but not yet integrated, and what decisions were deferred.

---

## How Assets Are Wired (Integration Pattern)

All runtime asset lookup goes through `src/core/AssetCatalog.gd`, which reads `data/asset_catalog.json`.
The JSON maps a stable string id to a `res://` path plus fallback id and tags.

```
data/asset_catalog.json
  └── category (audio / icons / props / cosmetics)
        └── id → { "path": "res://...", "fallback": "...", "tags": [...] }
```

`AssetCatalog.get_path(category, id, fallback)` returns the path or empty string if missing.
A missing path is not an error — it silently falls back to a procedural primitive or a default.

**Expected startup warning while asset paths remain empty:**
```
AssetCatalog: 7 configured asset paths are missing; fallbacks remain active.
```
This is intentional and harmless. Do not suppress it.

---

## Asset Catalog — Current Status

### Audio (`audio`)

| ID | Status | File |
|---|---|---|
| `shoot.pistol` | ✅ integrated | `res://assets/sfx/weapons/pistol_shoot.wav` |
| `shoot.ar` | ✅ integrated | `res://assets/sfx/weapons/ar_shoot.wav` |
| `shoot.shotgun` | ✅ integrated | `res://assets/sfx/weapons/shotgun_shoot.wav` |
| `shoot.railgun` | ✅ integrated | `res://assets/sfx/weapons/railgun_shoot.wav` |
| `footstep.grass` | ✅ integrated | `res://assets/sfx/footsteps/grass_01.wav` |
| `footstep.dirt` | ✅ integrated | `res://assets/sfx/footsteps/dirt_01.wav` |
| `footstep.stone` | ✅ integrated | `res://assets/sfx/footsteps/stone_01.wav` |
| `reload`, `dry_fire`, `hit`, `impact_wall`, `hurt`, `death`, `pickup`, `heal`, `melee`, `zone_warning`, `footstep`, `shoot` | ❌ path empty | Falls back to procedural sound or silence |

Generated procedural WAVs exist in `asset_generator/expected_output/assets/sfx/` but have not been promoted to `res://assets/sfx/`. The Kenney CC0 pack fetcher (`scripts/fetch_kenney_audio.py`) also exists and produces higher quality replacements. Neither has been integrated.

---

### Icons (`icons`)

| ID | Status | Notes |
|---|---|---|
| `weapon.*` (knife, pistol, ar, shotgun, railgun) | ✅ integrated | `res://assets/icons/weapons/` |
| `ammo.*` (pistol, ar, shotgun, railgun) | ✅ integrated | `res://assets/icons/ammo/` |
| `item.heal`, `item.medkit`, `item.armor` | ✅ integrated | `res://assets/icons/items/` |
| `artifact.red_trigger` | ✅ integrated | `res://assets/icons/artifacts/red_trigger.png` |
| `artifact.armor_sponge` | ✅ integrated | `res://assets/icons/artifacts/armor_sponge.png` |
| `artifact.silent_core` | ✅ integrated | `res://assets/icons/artifacts/silent_core.png` |
| `artifact.zone_battery` | ✅ integrated | `res://assets/icons/artifacts/zone_battery.png` |
| `artifact.emergency_shell` | ✅ integrated | `res://assets/icons/artifacts/emergency_shell.png` |
| `artifact.ghost_grass` | ✅ integrated | `res://assets/icons/artifacts/ghost_grass.png` |

All six starting artifact icons now have runtime PNG paths in `data/asset_catalog.json`. `ArtifactIconResolver.gd` still handles missing import metadata via raw `Image.load()`, so no `.import` file is required.

---

### Props (`props`)

| ID | Status | Notes |
|---|---|---|
| `forest.bush` | ✅ integrated | `res://assets/props/forest/bush_dense.glb` |
| `forest.bush.low` | ✅ integrated | `res://assets/props/forest/bush_low.glb` |
| `forest.bush.dense` | ✅ integrated | `res://assets/props/forest/bush_dense.glb` |
| `forest.tree`, `forest.rock`, `landmark.cabin`, `landmark.wall` | ❌ path empty | Catalog entries exist, paths are empty |

**Remaining generated GLBs** (14 unintegrated out of 16 generated prop GLBs) exist only in `asset_generator/expected_output/assets/props/` and are not promoted to `res://assets/props/`. Full list:

```
forest/  tree_small.glb, tree_cluster.glb, rock_small.glb, rock_cluster.glb,
         rock_large.glb, log_pile.glb, fallen_tree.glb
         (bush_low.glb and bush_dense.glb already integrated)

landmarks/  ruined_wall.glb, cabin.glb, camp_crate.glb, camp_tarp.glb,
            watchtower.glb, barrel_cluster.glb, fire_pit.glb
```

---

### Cosmetics (`cosmetics`)

All entries (`player.default`, `bot.*`) have empty paths. Procedural geometry is used for all characters. No generated cosmetic assets exist yet.

---

## Bush Integration Detail (v1.12.10)

Bush is the only prop category with a full integration pipeline. Understanding this is important before touching `WorldBuilder.gd` or `Bush.gd`.

**How it works:**

1. `WorldBuilder._build_bush_patch()` instantiates `Bush.tscn` (Area3D + CylinderShape3D r=1.5).
2. `_apply_catalog_visual()` loads the GLB via `GLTFDocument` (no Godot import metadata needed), names the root node `CatalogPropVisual`, disables imported collision nodes, and calls `bush.set_catalog_visual_active(true)`.
3. `Bush.gd` detects `CatalogPropVisual`, registers each `MeshInstance3D` in the GLB as a `_rustle_chunk`, replaces the original cylinder mesh with a thin floor-tint disc, and overrides materials with a normalized olive-green semi-transparent `StandardMaterial3D`.
4. On body enter/exit/movement, the nearest chunks animate with sway/lift + wave delay.

**Gameplay authority stays in `Bush.tscn`**: the Area3D cylinder is the concealment boundary, not the GLB mesh. The GLB is purely visual.

The chunk-rustle follow-up is committed: GLB bush visuals animate only the nearest mesh clumps instead of swaying the whole catalog visual.

---

## Deferred Asset Upgrade Decisions

The following were discussed and explicitly deferred. **Do not implement these without a dedicated plan.**

### Bush B Direction — Cell-based Area3D
- **What**: Replace single `bush_patch` (one Area3D) with arrays of individual bush cell positions. Each cell = its own `Bush.tscn` + single-clump `bush_cell.glb`. The composite `bush_dense/low.glb` would no longer be used.
- **Why deferred**: Required by fire spread and per-cell vision events (flare/illumination). Those features are far from current priority.
- **Trigger**: Implement when fire spread or per-cell vision events are being built.

### GLB Visual Replacement Pass (Tier 2/0)
- **What**: Attach generated rock, tree, fallen tree, log pile, and landmark GLBs as `CatalogPropVisual` over existing procedural collision shapes in `WorldBuilder`.
- **Why deferred**: Purely cosmetic. No gameplay impact. Not blocking map/player scale work.
- **Trigger**: When visual upgrade is prioritized; straightforward to implement.

### Landmark Collision Redesign (Tier 3)
- **What**: Cabin, watchtower, camp_tarp, camp_crate need hand-crafted `CollisionShape3D` to match their GLB geometry for enterable/climbable gameplay.
- **Why deferred**: High implementation cost, requires design decisions about interior access.
- **Trigger**: When interior entry or precise landmark interaction is planned.

### Dynamic Event Props (Tier 1)
- **What**: `barrel_cluster`, `fire_pit`, `log_pile` as event-capable objects (explosions, fire spread).
- **Why deferred**: Depends on fire/explosion event system which does not exist yet.
- **Trigger**: Implement alongside Bush B direction and the fire event system.

---

## Asset Generator Workspace

`asset_generator/` is **intentionally untracked**. Do not `git add` it unless explicitly asked.

The workspace contains:
- `scripts/generate_prop.py` — procedural GLB generator (trimesh). Generates all 16 props.
- `scripts/generate_icon.py` — OpenAI image API icon generator. Requires `OPENAI_API_KEY`.
- `scripts/generate_audio.py` — procedural WAV synthesizer (numpy/scipy).
- `scripts/fetch_kenney_audio.py` — Kenney CC0 audio pack downloader + OGG→WAV converter.
- `scripts/render_prop_preview.py` — software rasterizer for GLB contact sheets.
- `expected_output/` — all generated files (GLBs, PNGs, WAVs, JSON manifests).

To promote an asset to the game: copy the file to `res://assets/...`, add its path to `data/asset_catalog.json`, and verify via Godot headless quit (no new error beyond the known AssetCatalog warning).
