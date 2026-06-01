# Battle Capsule Master Plan

> Last updated: 2026-06-01 (v2.0.6 large_40 scale preset smoke)

This is the active roadmap. Full pre-compression details are preserved in [archive/MASTERPLAN_full_2026-05-26.md](archive/MASTERPLAN_full_2026-05-26.md). Older historical plans live under `docs/archive/`.

## Current Status

| Item | Status |
|---|---|
| Current line | v2.0-dev: MapDefinition + player scale foundation |
| Latest completed slice | v2.0.6: conservative 40-bot scale preset smoke |
| Next structural slice | v2.0.7: MapDefinition position query compatibility |
| v1.10 status | Structurally closed for Main-owned data/catalog/presentation cleanup |
| Release status | Paused; continue version-to-version development unless a release is explicitly requested |
| External assets | `asset_generator/` and local prompt scratch files stay untracked unless explicitly integrated |

Expected Godot startup warning while missing generated assets remain unresolved:

```text
AssetCatalog: 7 configured asset paths are missing; fallbacks remain active.
```

## Active Principles

- Keep `Main.gd` as the orchestrator and match-global state owner.
- Preserve single-source state ownership in `Main.gd` for `zone`, `mission_tracker`, `player_ref`, `alive_count`, game-over flow, pressure trigger flags, and Telemetry hook calls until a dedicated migration plan exists.
- Prefer small catalog, tuning, formatter, evaluator, controller, director, planner, and store boundaries over broad gameplay rewrites.
- Gameplay numbers shown in UI/descriptions should come from the same data/tuning used by logic whenever practical.
- Do not start 99-player scale, new maps, mission map theming, bot artifacts, or artifact upgrade trees without an explicit migration plan.
- Active docs should stay compact. Raw/full details belong in `docs/archive/` or `docs/devlog/` snapshots.

## Active Docs

| Document | Purpose |
|---|---|
| [../CLAUDE.md](../CLAUDE.md) | Session onboarding and default reading path |
| [HANDOFF.md](HANDOFF.md) | Short next-session context |
| [DOCS_INDEX.md](DOCS_INDEX.md) | Documentation routing and active-doc budgets |
| [DEVLOG.md](DEVLOG.md) | Compressed recent verified work |
| [IMPACT_MAP.md](IMPACT_MAP.md) | Ownership and change-impact checks |
| [ARCHITECTURE.md](ARCHITECTURE.md) | Module boundaries; open for structural changes |
| [TESTING.md](TESTING.md) | Verification criteria |
| [ASSET_BRIEF.md](ASSET_BRIEF.md) | Stable external asset style and format brief |
| [ASSET_STATUS.md](ASSET_STATUS.md) | Current asset integration state and deferred asset decisions |

## Boundary Role Rules

| Role | Owns | Must not own |
|---|---|---|
| `Main.gd` | Match-global state, scene wiring, lifecycle orchestration, Telemetry hooks | Static catalogs, formatting tables, reusable tuning defaults |
| `*Tuning.gd` | Numeric thresholds, fallback values, label helpers for those values | Runtime counters, scene lookups, mutation, policy orchestration |
| `*Catalog.gd` / `*Data.gd` | Static ids, descriptor construction, resource/data lookup | Runtime progress, evaluation side effects, scene state |
| `*Formatter.gd` / `*Builder.gd` / `*Resolver.gd` | Text, display specs, node construction, icon/visual lookup | Gameplay decisions, hidden duplicated thresholds |
| `*Evaluator.gd` | Pure condition checks from explicit context and descriptor data | Counters, timers, file I/O, reward/penalty execution |
| `*Controller.gd` / `*Director.gd` / `*Planner.gd` | Bounded runtime process, placement, or planning inside one domain | Match-global ownership that should remain in `Main.gd` |
| `*Store.gd` | File persistence and schema compatibility for one concern | Gameplay timing, UI formatting, evaluation rules |

## Structural State

### v1.10 Main Slimdown

Complete enough for v1.11:

- Main-owned item/resource pools, runtime match tuning, UI panel builders, match bootstrap helpers, pressure effect execution, bot spawn planning, loot/supply creation, and world/menu presentation defaults have first-pass boundaries.
- Routine edits to item display, resources, menu/help/records/result/pause/artifact/Hell announcement UI, and Main runtime tuning no longer require reading unrelated `Main.gd` systems.
- Intentionally retained in `Main.gd`: scene callbacks, exported scene/count defaults, current match state, zone, mission tracker, player reference, alive count, game-over flow, pressure trigger/effect flow, and Telemetry hook calls.
- Remaining v1.10.x item/asset readability polish can continue as narrow visual patches, but it does not block v1.11.

### v1.11 Subsystem Boundaries

Current audit result: direction is coherent enough to continue. The main risk was documentation and repeated slice drift, not a specific broken runtime authority.

| Domain | Current state |
|---|---|
| Hell | `HellEventController.gd` under `src/systems/hell/`; `HellTuning.gd` owns config-backed event tuning. Main still selects modifiers and wires announcements. |
| Zone | `ZoneController.gd` under `src/systems/zone/`; Main still owns `zone`, while Bot/Player/Minimap read through Main-owned references. |
| Loot/Supply | `LootSpawner`, `SupplyDropController`, and `LootSpawnDirector` live under `src/systems/loot/`; Main keeps supply minimap state and Telemetry hooks. |
| Mission | Catalog, HUD formatting, bonus evaluation, pressure condition evaluation, badge storage, description formatting, and tuning now have separate owners. `MissionTracker.gd` keeps active state, counters, hooks, public wrappers, pressure descriptor snapshots, and context assembly. |
| Player | HUD builders/renderers, weapon icon resolver, tuning constants, occluder fader, artifact runtime state, and artifact visuals are split. `Player.gd` keeps movement, combat, heal, artifact application, pickup, HUD update, zone warning, Sfx, and Telemetry runtime behavior. |
| Bot | Tuning, debug label construction, marker formatting, visual kit, and skin controller are split. `Bot.gd` intentionally keeps AI state machine, perception, navigation, loot/supply decisions, combat, death/drop behavior, and Main-owned state reads. |
| Entity/Pickup | Weapon slot tuning, pickup presentation, and pickup icon resolution are split. `Pickup.gd` keeps runtime nodes, focus/LOS, item collection side effects, Telemetry, and lifecycle. |
| Mission numeric text | Bonus and pressure mission descriptions now generate from mission/condition data plus shared tuning where practical. Pressure feasibility cutoffs live in `MissionTuning.gd`. |
| Docs | v1.11.35 snapshots full active docs and compresses default-session docs. |

## Recent Slices

| Slice | Result |
|---|---|
| v1.11.31 | Bonus mission descriptions/HUD/evaluation thresholds now read from `MissionData` and `MissionTuning`. |
| v1.11.32 | Pressure mission descriptions generate from `conditions[]`. |
| v1.11.33 | Pressure feasibility cutoffs moved to `MissionTuning.gd`. |
| v1.11.34 | Boundary role rules and active-document budgets defined. |
| v1.11.35 | Full docs snapshotted; active roadmap/devlog/version summary compressed. |
| v1.11.36 | `Main.gd` no longer reads MissionTracker private pressure descriptor state; v1.11 marked structurally closed. |

Full slice history is preserved in [devlog/v1.11_full_2026-05-26.md](devlog/v1.11_full_2026-05-26.md) and [devlog/DEVLOG_full_2026-05-26.md](devlog/DEVLOG_full_2026-05-26.md).

## v1.12 Complex Artifacts

**Goal**: Add replay-changing artifacts without undoing v1.10-v1.11 boundaries. First-pass complex artifacts should be player-owned runtime effects with explicit catalog data and small hooks.

**v1.12.1 decision**

- First candidate: **Emergency Shell**.
- Reason: one-shot low-HP shield is a bounded player-runtime effect with clear state (`unused/triggered`), visible shield-bar feedback, and limited balance impact.
- Rejected as first candidates:
  - Glass Capsule: too close to existing passive stat modifiers; it would not prove the complex-artifact runtime boundary.
  - Ghost Grass / Pulse Scanner / Marked King / Overheat Barrel: more interesting, but each touches perception, enemy reveal, minimap/HUD, kill rewards, or sustained-fire tuning before the runtime boundary is proven.

**Emergency Shell boundary contract**

| Owner | Responsibility |
|---|---|
| `ArtifactCatalog.gd` | Selection descriptor, id, label, color, description text, numeric effect data. |
| `PlayerArtifactRuntime.gd` | One-match trigger state and pure trigger decision from explicit player health/shield context. |
| `Player.gd` | Own helper instance, call it from damage flow, apply returned shield update, update HUD/Sfx/Telemetry hooks. |
| `Telemetry.gd` | Record selected artifact id and trigger count without changing existing score schema. |
| `Main.gd` | Keep selection/apply orchestration only; no artifact effect logic. |

**First implementation guardrails**

- Trigger only once per match.
- Trigger after a non-lethal hit or tick leaves player HP at or below the configured threshold. Do not intercept lethal damage in the first pass.
- Use catalog-owned numbers for threshold and shield amount; visible description must be generated from those values.
- Preserve existing artifacts and simulations.
- Do not add bot artifacts, map-themed artifacts, or artifact upgrade trees in v1.12.2.

**v1.12.2 result**

- Added Emergency Shell as a starting artifact.
- Added `PlayerArtifactRuntime.gd` for one-match player artifact trigger state.
- Emergency Shell triggers once after non-lethal damage leaves HP at or below the configured threshold, then grants the configured shield amount up to current max shield.
- Added artifact Telemetry metrics and `tools/verify_artifact_runtime.gd` smoke coverage.

**v1.12.3 result**

- Added `tools/verify_artifact_selection_layout.gd` to check artifact card count, required text, Emergency Shell presence, and default 1280px row fit.
- Verified the five-card selection row is 796px wide, so no immediate card layout change is needed.
- Kept Emergency Shell values unchanged for now.
- Shortlisted **Ghost Grass** as the next candidate because bush-exit stealth grace is bounded player runtime state and does not require minimap/HUD direction UI.

**v1.12.4 result**

- Added **Ghost Grass** as a starting artifact.
- Catalog-owned values: 2.0s bush-exit grace, 0.45 visual stealth multiplier, 0.6 footstep radius multiplier.
- `PlayerArtifactRuntime.gd` now owns both Emergency Shell one-shot state and Ghost Grass timer state.
- `Player.gd` only reports bush transitions, applies returned runtime effects, and keeps reveal/fire behavior authoritative through `reveal_timer`.
- Telemetry records `ghost_grass_started`; selection layout smoke now verifies six cards at 958px row width.

**v1.12.5 result**

- Added `PlayerArtifactVisuals.gd` as the owner for player-attached artifact visual nodes.
- `ArtifactCatalog.gd` now gives every starting artifact a `visual_id`.
- First-pass primitive visuals:
  - Red Trigger: shotgun-only red glow.
  - Armor Sponge: shield-ratio armor plates.
  - Silent Core: running afterimages.
  - Zone Battery: blue plasma near the zone edge.
  - Emergency Shell: back pack that ruptures on trigger.
  - Ghost Grass: short green wake while active.
- Gameplay state stays in `PlayerArtifactRuntime.gd`; visual nodes only read `Player.gd` context snapshots and artifact events.

**v1.12.6 result**

- Added `tools/capture_artifact_visual_gallery.gd` to render all current artifact visual states into `C:/tmp/artifact_visual_gallery.png`.
- Reviewed the generated gallery and tuned the first-pass visuals for readability.
- Silent Core now trails opposite movement direction instead of stacking directly over the body.
- Ghost Grass now uses a brighter lime/yellow-green wake with stronger blades so it does not blend into the default player tint.

**v1.12.7 result**

- Added `ArtifactIconResolver.gd` and normalized artifact icon ids as `artifact.<id>`.
- Artifact selection UI gained artifact icon images.
- The in-game artifact HUD indicator now uses an icon instead of text.
- Existing runtime artifact PNGs cover Red Trigger, Armor Sponge, Silent Core, and Zone Battery; Ghost Grass and Escape Capsule use catalog fallback icons until generated PNGs are selected.
- `tools/verify_artifact_selection_layout.gd` gained icon coverage.

**v1.12.8 result**

- Renamed Emergency Shell presentation to **Escape Capsule** while keeping the stable internal id `emergency_shell`.
- Escape Capsule now purges all ammo after its one-shot shield trigger.
- Red Trigger now increases ranged firing reveal duration to 3.0s.
- Armor Sponge now scales movement speed from normal at 0 shield to the previous 0.75 floor at max shield; heal conversion is capped at 50 shield and uses 50% of heal value.
- Silent Core no longer halves max HP/shield; instead, the first unrevealed non-knife shot is forced to miss.
- Ghost Grass is now a short-risk stealth: 1.25s after bush exit, 5.0s cooldown, and 1.5x gun damage plus immediate break if shot while active.
- Zone Battery remains unchanged.

**v1.12.9 result**

- Artifact selection now uses fixed circular icon options with one-line summaries instead of six long cards.
- Selecting an option updates one stable detail card with the full generated `line1`/`line2` description and choose button.
- `ArtifactCatalog.gd` now provides catalog-owned `summary` text per artifact, keeping short option text near the detailed artifact data.
- Added `tools/capture_artifact_selection_ui.gd`, which renders `C:/tmp/artifact_selection_ui.png` for screenshot review.
- `tools/verify_artifact_selection_layout.gd` now checks option count, button icons, default detail state, detail update on option press, and 1280px row fit.
- Follow-up patch centers option icons with embedded `TextureRect`s instead of `Button.icon`; generated source icons currently exist only for Red Trigger, Armor Sponge, Silent Core, and Zone Battery.
- `ArtifactIconResolver.gd` now falls back to raw PNG `Image.load()` when Godot import metadata is absent, so the four existing runtime artifact PNGs load before procedural fallback icons.

**v1.12.10 result**

- Promoted selected generated bush GLBs into runtime assets: `assets/props/forest/bush_dense.glb` and `assets/props/forest/bush_low.glb`.
- Added `forest.bush`, `forest.bush.low`, and `forest.bush.dense` paths under `data/asset_catalog.json`.
- `Main.gd` now passes `asset_catalog` into `WorldBuilder.generate_world()`.
- `WorldBuilder` keeps `Bush.tscn` Area3D gameplay/collision as the authority, attaches catalog GLB visuals when available, disables imported visual collision nodes, and hides the old cylinder mesh only after a catalog visual loads.
- Raw `.glb` files load through `GLTFDocument` when Godot import metadata is absent.
- Added `tools/verify_bush_prop_assets.gd` to verify catalog paths, raw GLB mesh counts, and default-map bush replacement.
- Follow-up patch tracks bush occupancy by Area instance, restores same-bush visibility semantics, keeps outside bush concealment strict by default, reuses the old cylinder mesh as player-entry dark tint, and adds rustle feedback on enter/exit/movement.
- Added `tools/verify_bush_interaction.gd` to pin same-bush visibility, outside concealment, reveal override, entry/exit state, tint visibility, and rustle feedback.
- Follow-up patch animates only the nearest GLB bush clumps instead of swaying the whole catalog visual.

**v1.12.11 result**

- Promoted generated Escape Capsule and Ghost Grass artifact PNGs into normalized runtime icons.
- Added catalog paths for all six starting artifact icons.
- `tools/verify_artifact_selection_layout.gd` now checks that each starting artifact has a real catalog icon file path, not just a procedural fallback texture.

## Next Work

1. **v2.0 MapDefinition + player scale** — primary priority.
   - Design MapDefinition resource and Full Map UI foundation.
   - Expand map size and player count toward real playable scale.
   - Requires AI LOD, spawn/loot density rescale, zone/pathing rescale before 99-player target.
2. **v1.10.x Item/Asset Readability Polish**
   - Only narrow visual/readability patches.
   - Keep generated source assets untracked unless selected files are integrated into runtime assets.
3. **Optional v1.11 reopen**
   - Only for a concrete boundary bug or stale doc route.
   - Avoid new helper extraction based on line count alone.

## v2.0 MapDefinition Plan

**Goal**: make map scale, match scale, spawn/loot density, zone profile, minimap/full-map metadata, and selected visual props an explicit definition layer before increasing player count.

**Boundary contract**

| Owner | Responsibility |
|---|---|
| `MapDefinition` | Static map id/name, world size, POIs, obstacles, routes, scale presets, spawn/loot/zone profile ids or overrides. |
| `WorldBuilder.gd` | Build world geometry and visual prop overlays from a definition; keep collision/gameplay authority explicit. |
| `Main.gd` | Continue owning match-global state and orchestration; consume sanitized definition data instead of scattering map-scale defaults. |
| `Minimap.gd` / future Full Map UI | Render definition features, current/next zone, player/supply markers, and selected POI metadata; no match logic. |
| Runtime tuning helpers | Clamp and merge scale preset values; do not discover scenes or mutate match state. |

**First slices**

1. Add a compatibility loader so current `MapSpec` JSON can be wrapped as the first `MapDefinition`. Done in v2.0.1.
2. Move map-specific spawn radius, loot count/density, and zone radius profile into definition-owned or preset-owned data while preserving `game_config.json` fallback behavior. Done in v2.0.2.
3. Add validation tooling for world bounds, POI radii, obstacle bounds, spawn radius, loot hotspot coverage, and zone radius sanity. Done in v2.0.4.
4. Build a Full Map UI foundation from the same minimap feature data; keep it read-only at first. Done in v2.0.3.
5. Scale bots by presets before 99-player work: 11 -> 24 -> 40 -> 60 -> 99, with AI LOD and telemetry checks at each step.

**Non-goals for the first v2.0 pass**

- Do not add new maps, mission map theming, bot artifacts, artifact upgrade trees, fire spread, or interior/landmark gameplay.
- Do not redesign landmark collision until a feature needs precise interiors or climbable structures.
- Do not bulk-promote generated GLBs; keep prop upgrades tied to visual or gameplay needs.

**v2.0.1 result**

- Added `MapDefinition.gd` as a compatibility wrapper around current `MapSpec` JSON.
- The wrapper exposes map id/name, map spec, match/runtime/zone overrides, scale presets, validation, and summary data without changing runtime call sites.
- Added `tools/verify_map_definition.gd` to validate legacy MapSpec wrapping and wrapper-format overrides.

**v2.0.2 result**

- `data/mapSpec_example.json` now carries definition-owned baseline match/runtime/zone values plus `baseline` and `medium_24` scale presets.
- `Main.gd` loads MapDefinition before world generation and applies the selected scale preset while preserving command-line tuning overrides.
- `MatchRuntimeTuning.gd` and `LootSpawner.gd` now support `hotspot_density_mult` so loot density can scale independently from loot count.
- `scale_preset=medium_24` is available for smoke scale runs without changing the default baseline behavior.

**v2.0.3 result**

- Added a read-only Full Map overlay toggled from `Main.gd` during active matches.
- The overlay renders world bounds, POIs, generated obstacle footprints, current/next zone, player facing, and supply marker state from `MapDefinition` / `MapSpec` / `WorldBuilder.get_minimap_features()`.
- Added `tools/verify_full_map_overlay.gd` for projection, layout bounds, generated feature ingestion, and runtime marker smoke coverage.

**v2.0.4 result**

- Expanded `MapDefinition.validate()` to catch POI density/bias issues, oversized POI radii, rotated obstacle footprint bounds, spawn/runtime clearance conflicts, loot density gaps, and implicit zone radius sanity.
- `tools/verify_map_definition.gd` now includes negative validation probes so the new checks are pinned.
- Preset compatibility now supports flat match keys as a fallback while nested `match` sections remain preferred.

**v2.0.5 result**

- Added `SettingsManager.gd` so settings file persistence, master volume application, fullscreen state, and clamping are no longer implemented directly in `Main.gd`.
- `Main.gd` keeps settings panel callbacks as scene wiring only.
- Added `tools/verify_settings_manager.gd` to pin load/save/clamp/missing-file behavior.

**v2.0.6 result**

- Added the `large_40` scale preset with 40 bots, 104 loot, 56m spawn radius, 1.12 hotspot density multiplier, and slightly longer zone timings.
- Extended `verify_map_definition.gd` so the new preset's match/runtime/zone overrides are pinned.
- Smoked `scale_preset=large_40` through one normal simulation before any 60/99-player work.

## Deferred Asset Upgrades

Recorded for future reference. Do not pursue until the relevant gameplay feature is being implemented.

| Upgrade | Trigger condition |
|---|---|
| Bush B direction — cell-based Area3D per leaf clump, `bush_cell.glb` single-clump asset, map spec as cell coordinate arrays | When fire spread or per-cell vision events (flare, illumination) are implemented |
| GLB visual replacement pass — rocks, trees, fallen tree, log pile, landmarks as `CatalogPropVisual` over existing procedural collision | When map visual upgrade is prioritized; purely cosmetic, no gameplay impact |
| Tier 1 dynamic props — barrel_cluster, fire_pit, log_pile as event-capable objects | When fire/explosion events are implemented alongside Bush B |
| Landmark collision redesign — cabin, watchtower with hand-crafted CollisionShape3D matching GLB geometry | When interior entry or precise landmark interaction is planned |

Current bush GLB integration (v1.12.10) is kept as-is. `asset_generator/` remains untracked.

## Completion Gates

### v1.11 Gate

- Status: structurally closed as of v1.11.36.
- Directory moves must preserve class names, preload paths, scene references, runtime behavior, and Telemetry schema.
- New boundaries must match the role rules in this file.
- Formatters/builders must not hide gameplay thresholds unless those values are passed from data/tuning owners.
- Evaluators should receive explicit context and avoid side effects.
- Controllers/directors may be stateful only inside one bounded domain.
- Docs-only slices verify with `git diff --check`; code slices verify with `git diff --check`, Godot headless quit, and at least one relevant simulation.

### Phase 2 Guardrails

| Future Area | Guardrail |
|---|---|
| v2.0 MapDefinition + Full Map UI | Requires config/debug foundation, v1.10 Main slimdown, and v1.11 subsystem closure |
| Forest 2.0 / City Map | Requires MapDefinition and large navigation stability checks |
| 99-player or large-map scale | Requires AI LOD, spawn/loot density rescale, zone/pathing rescale, and performance validation |

## Compact History

| Version | Summary |
|---|---|
| v1.11-dev | Subsystem directory and non-Main data/algorithm boundaries |
| v1.10-dev | Main slimdown, UI catalogs, supply/loot calculation boundaries |
| v1.9-dev | AssetCatalog hooks, audio/cosmetic IDs, debug logging hooks, scale-test CLI overrides |
| v1.8-dev | GameConfig, DebugFlags, DebugOverlay, AssetCatalog, runtime core icon pass |
| v1.7.x | AI doctrine, archetype readability, minimap/world footprint alignment |
| v1.6.x and earlier | Core battle royale prototype, missions, artifacts, telemetry, release foundation |

## Next Agent Checklist

- Read [HANDOFF.md](HANDOFF.md), [DOCS_INDEX.md](DOCS_INDEX.md), and this file before work.
- Before code changes, check [IMPACT_MAP.md](IMPACT_MAP.md) for ownership and cascade effects.
- Keep `asset_generator/` and `docs/ASSET_GENERATION_PROMPTS.md` untracked unless explicitly asked to integrate them.
- For asset generation, keep stable style/format rules in [ASSET_BRIEF.md](ASSET_BRIEF.md) and local prompt scratch out of commits.
- For docs-only work, verify with `git diff --check`; for code work, add Godot/simulation checks based on risk.
