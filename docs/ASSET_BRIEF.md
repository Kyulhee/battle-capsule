# Battle Capsule Asset Production Brief

> Last updated: 2026-05-13
> Purpose: stable style and file-format reference for v1.8+ asset pipeline work.

Copy-ready external generator prompts may be kept in local `docs/ASSET_GENERATION_PROMPTS.md`, which is intentionally untracked unless the user asks to publish it. This file is the tracked reference for style, formats, IDs, and handoff checks.

Generated master files may stay in the separate `asset_generator/expected_output/` workspace; runtime-ready files are selected into `assets/` and then connected through `data/asset_catalog.json`.

---

## 1. Style Target

**Game**: Battle Capsule, a quarter-view tactical roguelite battle royale prototype in Godot.

**Visual language**

- Low-poly, readable, tactical, restrained.
- Quarter-view / top-down readability is more important than close-up detail.
- Forest map palette: dark green ground, muted foliage, gray rock/building masses, warm loot accents.
- Silhouettes must read at small HUD/minimap scale.
- Avoid photorealism, glossy high-detail textures, cute/cartoon exaggeration, noisy pattern fills, text baked into images, and complex logos.
- UI icons should be simple filled silhouettes with a small accent shape, transparent background, no text.
- 3D props should use simple shapes, low vertex count, clean material slots, and strong top-down footprint readability.

**Audio language**

- Short, dry, responsive, game-readable.
- Avoid cinematic reverb, long tails, vocal sounds, music stings, or overly realistic firearm recordings.
- Sounds should sit under a small arcade tactical game, not a military simulator.

**Reference screenshots to provide to external agents**

Use 3 to 5 current screenshots if possible:

1. `ref_gameplay_quarter_view.png` - active match with player, terrain, HUD.
2. `ref_minimap_forest_layers.png` - minimap visible with forest/rock/building layers.
3. `ref_player_bot_close.png` - close-up of capsule player/bot silhouettes.
4. `ref_main_menu.png` - title/menu mood and palette.
5. `ref_forest_open_area.png` - open loot area plus surrounding cover.

Recommended reference note:

```text
Use these screenshots only for style, palette, camera angle, and readability. Do not recreate the exact screenshot composition. Generate reusable game assets.
```

---

## 2. Output Rules

**Audio**

- Format: `.wav`
- Sample rate: `44100 Hz`
- Bit depth: `16-bit PCM`
- Channels: mono
- Loudness: normalized but not clipped
- File length:
  - weapon shots: `0.08s` to `0.35s`
  - reload: `0.25s` to `0.7s`
  - footsteps: `0.05s` to `0.18s`
  - UI/item sounds: `0.08s` to `0.5s`
- If using stock libraries, use CC0 or explicitly commercial-safe licenses.

**Icons**

- Format: `.png`
- Master size: `1024x1024` preferred, `256x256` acceptable.
- Runtime size: normalized to `64x64` in `assets/icons/` for current HUD and pickup decals.
- Background: transparent
- Safe area: icon should fit within the center 80% of the canvas, e.g. about 832x832 on a 1024 master or 208x208 on a 256 master.
- Style: flat or minimally shaded, thick silhouette, 1 to 2 accent colors.
- No text, no tiny details, no drop shadows that disappear on dark UI.
- After generation, run `powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\sync_generated_icons.ps1` from the repo root to crop transparent padding and downsample selected icons.

**3D props**

- Preferred format: `.glb`
- Scale: 1 Godot unit = 1 meter.
- Origin: bottom center for upright props; center for rocks/crates.
- Materials: 1 to 3 simple PBR materials, no high-res texture dependency unless necessary.
- Geometry: low-poly, clean normals, no animation required for first pass.
- Every prop should be readable from above.

**Concept sheets**

- If the external agent cannot output `.glb`, generate orthographic concept PNGs first.
- Preferred views: top, quarter, front.
- Transparent or neutral flat background.

---

## 3. Current Catalog Targets

These IDs already exist in `data/asset_catalog.json`. Prefer generating these first.

### A. Audio - Weapon And Combat

| Catalog ID | Target Path | Notes |
|---|---|---|
| `shoot.pistol` | `assets/sfx/weapons/pistol_shoot.wav` | short compact pop, light sidearm |
| `shoot.ar` | `assets/sfx/weapons/ar_shoot.wav` | sharper automatic rifle single shot |
| `shoot.shotgun` | `assets/sfx/weapons/shotgun_shoot.wav` | wider punch, not too long |
| `shoot.railgun` | `assets/sfx/weapons/railgun_shoot.wav` | rare energy snap, bright but not sci-fi overkill |
| `reload` | `assets/sfx/reload.wav` | compact mechanical click/slide |
| `dry_fire` | `assets/sfx/dry_fire.wav` | tiny empty click |
| `hit` | `assets/sfx/hit.wav` | body hit thump |
| `impact_wall` | `assets/sfx/impact_wall.wav` | dry rock/metal impact |
| `hurt` | `assets/sfx/hurt.wav` | player damage thud, non-vocal |
| `death` | `assets/sfx/death.wav` | short capsule shutdown/break sound |
| `melee` | `assets/sfx/melee.wav` | quick knife swipe/hit |

Prompt:

```text
Create short mono WAV sound effects for a low-poly quarter-view tactical battle royale game. The tone is dry, readable, compact, and arcade-tactical. Avoid cinematic reverb, long tails, vocals, realistic military loudness, and distortion. Each sound must be immediately recognizable in a busy match.
```

### B. Audio - Items, Zone, Footsteps

| Catalog ID | Target Path | Notes |
|---|---|---|
| `pickup` | `assets/sfx/pickup.wav` | short item collect ping |
| `heal` | `assets/sfx/heal.wav` | warm quick recovery cue |
| `zone_warning` | `assets/sfx/zone_warning.wav` | two-pulse warning, not harsh |
| `footstep.grass` | `assets/sfx/footsteps/grass_01.wav` | soft grass step |
| `footstep.dirt` | `assets/sfx/footsteps/dirt_01.wav` | dry ground step |
| `footstep.stone` | `assets/sfx/footsteps/stone_01.wav` | muted stone/rock step |

Prompt:

```text
Create compact movement and item WAV sounds for a low-poly forest battle royale. Footsteps should be subtle and soft because they repeat often. Item sounds should be clear but not musical. Zone warning should be urgent but short.
```

### C. UI Icons - Weapons And Items

| Catalog ID | Suggested Path | Notes |
|---|---|---|
| `weapon.knife` | `assets/icons/weapons/knife.png` | simple blade silhouette |
| `weapon.pistol` | `assets/icons/weapons/pistol.png` | compact sidearm |
| `weapon.ar` | `assets/icons/weapons/ar.png` | rifle silhouette |
| `weapon.shotgun` | `assets/icons/weapons/shotgun.png` | longer barrel, warm accent |
| `weapon.railgun` | `assets/icons/weapons/railgun.png` | rare angular energy rifle |
| `item.heal` | `assets/icons/items/heal.png` | medical cross or bandage mark |
| `item.armor` | `assets/icons/items/armor.png` | shield/vest silhouette |
| `artifact.red_trigger` | `assets/icons/artifacts/red_trigger.png` | red trigger mark, aggressive |

Prompt:

```text
Create square transparent PNG HUD icon masters for a low-poly tactical battle royale. 1024x1024 is preferred, 256x256 is acceptable. Use thick readable silhouettes, minimal flat shading, no text, no background, no photorealism. Icons must remain clear after downsampling to 64x64 and at 24x24 pixels on a dark green/black UI. Palette should match muted forest gameplay with small blue/orange/red/cyan accents.
```

### D. 3D Props - Forest And Landmarks

| Catalog ID | Suggested Path | Notes |
|---|---|---|
| `forest.tree` | `assets/props/forest/tree_cluster.glb` | small cluster, blocks sight, top-down clear |
| `forest.bush` | `assets/props/forest/bush_patch.glb` | low stealth cover, readable green mass |
| `forest.rock` | `assets/props/forest/rock_large.glb` | gray cover rock, simple footprint |
| `landmark.cabin` | `assets/props/landmarks/cabin.glb` | one small forest cabin, major loot landmark |
| `landmark.wall` | `assets/props/landmarks/ruined_wall.glb` | gray ruin/wall segment |

Prompt:

```text
Create low-poly GLB props for a quarter-view forest battle royale game. Assets should use simple geometry, muted forest colors, strong top-down footprints, and low detail. They should read clearly from a high quarter-view camera. No photoreal textures, no complex interiors, no text. Each prop should have a clean origin and be usable in Godot.
```

---

## 4. Recommended Expansion IDs

These IDs are not all in the catalog yet. Generate them after the current catalog targets, then add them to `data/asset_catalog.json`.

### Icons

| New ID | Suggested Path | Notes |
|---|---|---|
| `ammo.pistol` | `assets/icons/ammo/pistol.png` | small magazine or bullet stack |
| `ammo.ar` | `assets/icons/ammo/ar.png` | rifle ammo |
| `ammo.shotgun` | `assets/icons/ammo/shotgun.png` | shells |
| `ammo.railgun` | `assets/icons/ammo/railgun.png` | energy cell |
| `item.medkit` | `assets/icons/items/medkit.png` | stronger heal than bandage |
| `artifact.ghost_grass` | `assets/icons/artifacts/ghost_grass.png` | stealth/grass motif |
| `artifact.pulse_scanner` | `assets/icons/artifacts/pulse_scanner.png` | circular scan pulse |
| `artifact.zone_battery` | `assets/icons/artifacts/zone_battery.png` | battery plus zone ring |

### Props

| New ID | Suggested Path | Notes |
|---|---|---|
| `forest.tree.small` | `assets/props/forest/tree_small.glb` | single small tree |
| `forest.tree.cluster` | `assets/props/forest/tree_cluster.glb` | 3 to 5 trees |
| `forest.bush.low` | `assets/props/forest/bush_low.glb` | low stealth cover |
| `forest.bush.dense` | `assets/props/forest/bush_dense.glb` | denser stealth cover |
| `forest.rock.small` | `assets/props/forest/rock_small.glb` | small cover/readability prop |
| `forest.rock.large` | `assets/props/forest/rock_large.glb` | large cover prop |
| `landmark.camp.crate` | `assets/props/landmarks/camp_crate.glb` | loot camp prop |
| `landmark.camp.tarp` | `assets/props/landmarks/camp_tarp.glb` | small camp landmark |

### Cosmetics

| New ID | Suggested Path | Notes |
|---|---|---|
| `cosmetic.face.alert` | `assets/icons/cosmetics/face_alert.png` | simple alert mark |
| `cosmetic.face.hidden` | `assets/icons/cosmetics/face_hidden.png` | stealth mark |
| `cosmetic.accessory.visor` | `assets/props/cosmetics/visor.glb` | capsule head accessory |
| `cosmetic.accessory.band` | `assets/props/cosmetics/band.glb` | simple colored band |

---

## 5. Priority Order

**Batch 1 - Immediate usefulness**

1. Weapon sounds: `shoot.pistol`, `shoot.ar`, `shoot.shotgun`, `shoot.railgun`.
2. Footsteps: `footstep.grass`, `footstep.dirt`, `footstep.stone`.
3. Core UI icons: `weapon.knife`, `weapon.pistol`, `weapon.ar`, `weapon.shotgun`, `weapon.railgun`, `item.heal`, `item.armor`.

**Batch 2 - Map identity**

1. `forest.tree`
2. `forest.bush`
3. `forest.rock`
4. `landmark.cabin`
5. `landmark.wall`

**Batch 3 - Roguelite identity**

1. Artifact icons.
2. Bot/player cosmetic marks.
3. Additional camp/loot props.

---

## 6. Handoff Checklist

When generated assets are returned:

- [ ] File names match the suggested paths.
- [ ] Audio is mono 44100 Hz 16-bit PCM WAV.
- [ ] PNG icons have transparent backgrounds.
- [ ] GLB props open in Godot without missing texture errors.
- [ ] No generated asset includes text, watermarks, or external brand marks.
- [ ] License is recorded if a stock source was used.
- [ ] Run `powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\sync_generated_icons.ps1` if icon masters came from `asset_generator/expected_output/`.
- [ ] `data/asset_catalog.json` path fields are updated.
- [ ] Run `.\Godot_v4.6.2-stable_win64_console.exe --path . --headless --quit`.
- [ ] Run `python tools\simulate_matches.py 1`.

---

## 7. Catalog Update Example

After adding an icon:

```json
"weapon.ar": {
  "path": "res://assets/icons/weapons/ar.png",
  "fallback_shape": "ar",
  "color": [0.42, 0.72, 1.0, 1.0]
}
```

After adding a prop:

```json
"forest.tree.cluster": {
  "path": "res://assets/props/forest/tree_cluster.glb",
  "fallback_shape": "tree_cluster",
  "tags": ["forest", "cover", "los_blocker"]
}
```

After adding a sound:

```json
"shoot.ar": {
  "path": "res://assets/sfx/weapons/ar_shoot.wav",
  "fallback": "shoot",
  "tags": ["weapon", "ar"]
}
```
