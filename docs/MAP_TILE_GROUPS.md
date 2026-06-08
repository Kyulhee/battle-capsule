# 99-Player Map Tile Group Brief

> Last updated: 2026-06-08. Planning document for external map ideation and future map-spec authoring.

This document defines reusable placement groups for 99-player map planning. It is not a runtime tile compiler yet. Current maps are still authored as explicit `mapSpec` data with POIs, routes, obstacles, scale presets, and zone settings.

## Current Reality

The project already uses a hybrid procedural approach:

- `mapSpec` explicitly defines `pois`, `routes`, `obstacles`, `scale_presets`, and `zone`.
- `WorldBuilder.gd` expands obstacle descriptors into procedural details:
  - deterministic obstacle `jitter` and `rot_jitter`;
  - generated `rock_cluster` pieces from one descriptor;
  - visual bush replacement while keeping `Bush.tscn` as gameplay authority.
- `LootSpawner.gd` treats POIs as weighted loot hotspots:
  - `item_density` controls hotspot weight and initial consumable count;
  - `rare_bias` controls weapon/rare pressure;
  - runtime presets can apply `hotspot_density_mult` and `rare_bias_mult`.
- Spawn is procedural inside an annulus and guarded by clearance checks.

So the next useful abstraction is not "fully random maps." It is a catalog of hand-designed placement groups that can be mixed, mirrored, rotated, then expanded into regular `mapSpec` entries.

## Design Goal

For 99 players, each placement group must answer four questions:

- Why does a player or bot move through this area?
- What positional advantage is available?
- What is the cost of taking the direct route?
- What is the slower or safer alternative?

Groups should create battle-royale pressure: looting, rotating, recovering, and holding terrain should naturally collide. Do not tune for a fixed CHASE-combat percentage.

## Hard Constraints

Use these constraints when proposing external layouts.

| Constraint | Target |
|---|---|
| World size | 180m preferred for `target_99_probe` |
| Spawn radius | 78m preferred |
| Entity clearance | 3.5m |
| Spawn fallback | Must remain 0 in repeated gates |
| POI roles | At least 3 `loot_hub`, 4 `transit_choke`, 2 `recovery_pocket`, 4 `concealment_field` |
| Route roles | At least 2 `primary_choke`, 2 `flank`, 1 `loot_flow`, 1 `recovery_exit` |
| Primary chokes | Multi-point route, width about 12.5m, valid `alternate_route_id` |
| Central route | Should not be so wide that it absorbs side-gate pressure |
| Hard cover | Use sparingly; heavy clutter raises stuck risk |
| Bushes | Gameplay authority remains `Bush.tscn`; visuals are cosmetic |

## Placement Group Schema

External planners can propose groups in this shape:

```json
{
  "group_id": "west_ridge_gate_A",
  "role": "primary_choke_gate",
  "footprint": [36, 44],
  "transform": {
    "pos": [-44, 10],
    "rot": 0,
    "mirror": false
  },
  "anchors": {
    "entry": [-70, -54],
    "pressure_point": [-34, 16],
    "exit": [-48, 50],
    "alternate_hint": [-18, 62]
  },
  "poi_slots": [
    { "role": "transit_choke", "offset": [0, 0], "radius": 13, "density": 0.68, "rare_bias": 0.20 },
    { "role": "recovery_pocket", "offset": [-14, 18], "radius": 14, "density": 0.46, "rare_bias": 0.12 }
  ],
  "route_segments": [
    { "role": "primary_choke", "width": 12.5, "strategic_value": "edge_cutoff" },
    { "role": "flank", "width": 12.5, "strategic_value": "choke_bypass" }
  ],
  "obstacle_motif": "ridge_rocks_light_cover",
  "loot_policy": "moderate_weapon_pressure",
  "risk": "exposed_crossfire",
  "reward": "high-ground route control"
}
```

The schema is intentionally higher level than `mapSpec`. A later conversion pass can expand it into exact POIs, routes, and obstacle descriptors.

## Core Group Types

### 1. Primary Choke Gate

Purpose: force rotation conflict on a valuable direct route.

Use when:

- two outer regions need a fast connection;
- a team or bot can hold the route;
- a flank route exists but costs time or loot.

Recommended contents:

- 1-2 `transit_choke` POIs;
- one multi-point `primary_choke` route;
- one linked `flank` route as `alternate_route_id`;
- 2-4 hard cover pieces, offset rather than centered;
- light loot, with enough rare pressure to justify contesting.

Avoid:

- walling both sides tightly;
- placing hard cover directly on every route point;
- making the alternate route equally fast and equally rewarding.

### 2. Loot Hub Cross

Purpose: create early loot attraction and mid-game rotation pressure.

Use when:

- several routes should meet, but not all combat should happen there;
- the hub should be valuable, exposed, and temporary.

Recommended contents:

- 1 central `loot_hub`;
- 3-4 route connections;
- medium `item_density`, moderate `rare_bias`;
- low hard cover, with bushes or logs for partial movement breaks.

Avoid:

- oversized central radius;
- too much hard cover;
- making the central route wider than side gates.

### 3. Recovery Pocket Exit

Purpose: let wounded actors recover, then force a risky re-entry.

Use when:

- bots need a place to leave combat without vanishing from the match;
- a recovery route should lead back into a contested gate or hub.

Recommended contents:

- 1 `recovery_pocket`;
- 1 `recovery_exit` route;
- low-to-medium loot density;
- heal/ammo access, but limited rare weapon pressure;
- soft cover and one readable exit angle.

Avoid:

- making the pocket too safe;
- placing too much ammo directly on the exit;
- adding hard clutter that causes stuck or line-of-sight traps.

### 4. Concealment Field

Purpose: create stealth, ambush, and scouting decisions.

Use when:

- the route should be traversable but uncertain;
- players should choose between open speed and concealed risk.

Recommended contents:

- 2-5 `bush_patch` descriptors;
- one `concealment_field` POI;
- low `item_density`;
- route overlap near the edge, not through the exact center every time.

Avoid:

- making concealment the safest route by default;
- placing high-value loot deep inside every bush field;
- overlapping every bush into one huge blob.

### 5. Flank Arc

Purpose: provide a slower bypass around a primary choke.

Use when:

- a direct gate would otherwise become mandatory;
- rotation should offer a tactical but time-costly alternative.

Recommended contents:

- one `flank` route;
- sparse cover, mostly soft or low;
- low loot density;
- clear connection back to a primary route or loot hub.

Avoid:

- making the flank more rewarding than the choke;
- hiding the entire flank in concealment;
- placing it so far out that zone pressure makes it irrelevant.

### 6. Edge Spawn Band

Purpose: support 99-player opening distribution without creating isolated dead zones.

Use when:

- spawn annulus needs local cover and orientation;
- early movement should funnel toward hubs, gates, or flanks.

Recommended contents:

- small cover clusters near but not on spawn positions;
- low-value loot breadcrumbs;
- at least one clear route toward a meaningful objective;
- no hard choke immediately at spawn.

Avoid:

- rare loot directly at spawn edge;
- safe loops that never reconnect to main routes;
- dense obstacle rings that break spawn clearance.

### 7. Power Position Overlook

Purpose: create a temporary strong position that can be contested or bypassed.

Use when:

- a route needs a reason to fight before the final zone;
- elevation or hard cover should matter without becoming a fortress.

Recommended contents:

- one high `rock_cluster` or ridge motif;
- one exposed approach;
- one slower covered approach;
- moderate rare bias nearby, not directly on top.

Avoid:

- adding multiple high hard-cover clusters close together;
- giving full sight control over every route;
- placing recovery pockets immediately behind it.

## Example Composition Recipes

### Balanced 99 Forest

Use as the neutral reference shape. It is no longer the only current implementation target; the first concrete 99-player candidate should be compared against the Night Artificial Forest direction below.

- 1 `loot_hub_cross` in the inner third.
- 2 mirrored `primary_choke_gate` groups east/west.
- 2 `flank_arc` groups north/south.
- 2 `recovery_pocket_exit` groups, each feeding back toward a gate.
- 4 `concealment_field` groups, two inner and two outer.
- 4-6 `edge_spawn_band` groups around the spawn annulus.
- 1 optional `power_position_overlook` near one gate, mirrored only if telemetry supports it.

Expected telemetry intent:

- primary-choke damage is material, but not dominant;
- target acquisition remains route-bound;
- loot/recover CHASE does not detach from analyzable POI/route pressure;
- spawn fallback remains 0.

### High-Conflict Gate Map

Use for a stronger contested-terrain candidate.

- 2 large `primary_choke_gate` groups.
- 1 smaller `loot_hub_cross`.
- 2 short `flank_arc` groups.
- 2 `recovery_pocket_exit` groups that re-enter near the gates.
- Fewer concealment fields, placed near route edges.

Risk:

- can overproduce enemy interrupts;
- can lower combat target soft-POI if gates are too narrow or cover pulls actors off route.

### Wide Rotation Map

Use for slower, more tactical rotations.

- 3 smaller `loot_hub_cross` groups instead of one large center.
- 2 `primary_choke_gate` groups.
- 3 `flank_arc` groups.
- 3 `recovery_pocket_exit` groups.
- More edge spawn bands with breadcrumb loot.

Risk:

- can dilute combat throughput at 99;
- needs stricter checks for CHASE combat share and target acquisition soft POI.

## Current Candidate: Night Artificial Forest

The current preferred 99-player concept is a night artificial forest coliseum, using the local `plan_report/` directory as reference material. That directory is a planning source, not a committed runtime asset source.

First structural runtime candidate:

- `data/mapSpec_night_forest_candidate.json`
- `tools/verify_night_forest_candidate.gd`
- non-default only; do not promote it to the default map or default scale preset yet.

First POI-level probe:

- `data/mapSpec_poi_sluice_crossing_probe.json`
- `tools/verify_poi_sluice_crossing_probe.gd`
- compact 72m direct-crossing test with north/south flanks and pump re-entry.

Second POI-level probe:

- `data/mapSpec_poi_wire_maze_probe.json`
- `tools/verify_poi_wire_maze_probe.gd`
- compact 76m sparse-maze test with direct lane, north/south flanks, and shed re-entry.

Main shift from Balanced 99 Forest:

- do not rely on a universal center loot hub as the primary collision engine;
- use a diagonal river or sluice line to force crossing decisions;
- make `Sluice Crossing` the main rotation conflict, with real alternate routes;
- keep `Black Ridge` as a strong but contestable power position;
- use `False Clinic` as a recovery/story pocket that must feed actors back into risk;
- treat flashlight, darkness, and visibility as future pacing systems, not as assumptions for the first structural `mapSpec`.

### POI Role Mapping

| Concept POI | Primary role | Secondary role | First-pass caution |
|---|---|---|---|
| Supply Flats | `loot_hub` | edge-to-mid loot flow | Open loot should be valuable but exposed. Do not over-cover it into a safe armory. |
| Ammunition Pockets | loot support | `edge_spawn_band` breadcrumb | Keep pockets small and distributed so they do not become safe loops outside pressure. |
| Cabin Row | `concealment_field` | close-quarters transit | Avoid dense interiors in the first pass; use readable cover and soft concealment. |
| False Clinic | `recovery_pocket` | `recovery_exit` anchor | Recovery must lead back toward a contested route, not away from the match. |
| Wire Maze | `transit_choke` | objective compound | Highest stuck/LOS risk. Start with sparse fence segments and wide gates. |
| Broadcast Fence | `transit_choke` | future light/surveillance objective | Good for later flashlight/searchlight logic; first pass should stay structural. |
| Black Ridge | `power_position_overlook` | `transit_choke` pressure | Strong sight advantage needs one exposed approach and one slower covered approach. |
| Sluice Crossing | `primary_choke` | river crossing / map identity | Must have alternate routes with real time cost; avoid one mandatory kill bridge. |

### Route Shape

Recommended route groups:

- `sluice_direct_crossing`: `primary_choke`, multi-point, width about 12.5m, connects opposite river banks.
- `north_service_flank`: `flank`, slower bypass through Cabin Row or outer forest.
- `south_drainage_flank`: `flank`, lower loot but safer rotation along water/ditch edge.
- `clinic_reentry`: `recovery_exit`, from False Clinic back toward Sluice Crossing or Broadcast Fence.
- `ridge_pressure_route`: `primary_choke` or `transit_choke`, passes near Black Ridge without putting all traffic on top of it.
- `supply_to_broadcast_flow`: `loot_flow`, pulls early looters toward a mid-game compound.

### First Candidate Constraints

- Keep world size at 180m and spawn radius around 78m unless the envelope is explicitly revised.
- Keep spawn fallback at 0 in repeated gates.
- Keep Wire Maze and Black Ridge obstacle density conservative in the first `mapSpec`.
- Use bushes as gameplay `Bush.tscn` authority; any night/forest visuals stay cosmetic.
- Do not tune for final 10-15 minute match length until the structural candidate passes.
- Do not give every bot full flashlight/battery/fear behavior in the first candidate.

## External Planning Deliverable

When returning an external map idea, provide one of these:

1. Placement group plan:

```json
{
  "map_id": "forest_99_candidate_B",
  "world_size": 180,
  "groups": [
    { "group_id": "west_gate_A", "type": "primary_choke_gate", "pos": [-44, 10], "rot": 0 },
    { "group_id": "east_gate_A", "type": "primary_choke_gate", "pos": [44, -8], "rot": 180, "mirror": true }
  ],
  "notes": [
    "West gate should be faster but more exposed.",
    "South flank is safer but has low loot."
  ]
}
```

2. Direct `mapSpec` proposal:

- `metadata`;
- `pois`;
- `routes`;
- `obstacles`;
- optional scale preset overrides.

The placement group plan is preferred for early ideation. Direct `mapSpec` is preferred only when the layout is already stable.

## Conversion Checklist

Before a placement plan becomes a candidate `mapSpec`:

- Expand every group into named POIs with roles, radii, `item_density`, and `rare_bias`.
- Expand route segments into route ids, points, width, `connects`, and `alternate_route_id`.
- Keep obstacle descriptors explicit and sparse enough to avoid stuck.
- Confirm route points stay inside world bounds.
- Confirm POI roles and route roles satisfy the hard constraints.
- Confirm spawn radius, clearance, and boundary margin remain valid.
- Run:
  - `verify_strategic_flow_map.gd`;
  - `verify_candidate_99_probe.gd`;
  - fresh 5-run `xlarge_60`;
  - fresh 5-run `target_99_probe`;
  - `compare_scale_profiles.py`.

## Current Next Questions

Use external planning to answer these before more behavior tuning:

- Are non-pistol weapon opportunities too scarce, or just too far from common pistol ammo routes?
- Do recovery exits lead actors back into meaningful pressure, or into repeated loot/recover loops?
- Do primary gates create readable power positions without overproducing stuck or enemy-interrupt churn?
- Does target acquisition start near POIs but drift during CHASE because route geometry lacks intermediate pressure points?
- Which groups should be mirrored, and which should remain asymmetric to create strategic identity?
