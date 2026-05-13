# Battle Capsule — Agent Onboarding

Godot 4.6.2 / GDScript quarter-view battle royale prototype.

Repository: `https://github.com/Kyulhee/battle-capsule`

## Current State

| Item | Status |
|---|---|
| Last public release baseline | v1.7.3.1 — main menu / How to Play hotfix |
| Current development line | v1.10-dev — Main slimdown + UI/catalog boundaries |
| Current stabilization add-on | v1.10.x — Item/Asset Readability Polish |
| Release policy | Paused. Do not create GitHub releases unless explicitly requested. |
| External asset workspace | `asset_generator/` stays untracked unless explicitly integrated. |

v1.10 is infrastructure work, not a content expansion. Keep changes incremental, preserve current gameplay state ownership in `Main.gd`, and avoid starting v1.11 Complex Artifacts until item/asset readability and document routing are stable.

## Default Reading Path

Read only the documents needed for the task. Do not load archived long documents by default.

| Order | Document | Read When |
|---|---|---|
| 1 | [HANDOFF.md](docs/HANDOFF.md) | Every new session or context resume |
| 2 | [DOCS_INDEX.md](docs/DOCS_INDEX.md) | To choose the right source document |
| 3 | [MASTERPLAN.md](docs/MASTERPLAN.md) | Current roadmap, scope, non-goals |
| 4 | [IMPACT_MAP.md](docs/IMPACT_MAP.md) | Before code changes that touch game state, entities, UI, map, or telemetry |
| 5 | [ARCHITECTURE.md](docs/ARCHITECTURE.md) | Before structural refactors or module boundary changes |
| 6 | [TESTING.md](docs/TESTING.md) | Before/after verification |

Task-specific documents:

| Document | Use |
|---|---|
| [DEVLOG.md](docs/DEVLOG.md) | Short active log only. Historical details are indexed under `docs/devlog/`. |
| [ASSET_BRIEF.md](docs/ASSET_BRIEF.md) | Stable style/file-format reference for assets |
| [UI_DESIGN.md](docs/UI_DESIGN.md) | Screenshot-driven UI visual review guidance |
| [RELEASE.md](docs/RELEASE.md) | Release work only |

Excluded from default context:

- `docs/archive/**` — legacy plans and full historical documents.
- `docs/devlog/DEVLOG_full_2026-05-13.md` — preserved full old devlog; open only for historical detail.
- `docs/ASSET_GENERATION_PROMPTS.md` — local-only copy-ready prompt scratch file; intentionally not tracked unless requested.
- `asset_generator/**` — external generator workspace; inspect only for asset tasks, do not commit unless requested.

## Update Rules

| Event | Update |
|---|---|
| Current scope/roadmap changes | `docs/MASTERPLAN.md` |
| Completed verified work | `docs/DEVLOG.md` |
| New/changed architecture boundary | `docs/ARCHITECTURE.md` and, if impact changes, `docs/IMPACT_MAP.md` |
| New telemetry or validation rule | `docs/TESTING.md` |
| External asset generation request changes | local `docs/ASSET_GENERATION_PROMPTS.md` scratch file and, if stable style/format changes, `docs/ASSET_BRIEF.md` |
| Session handoff-sensitive context | `docs/HANDOFF.md` |

## Key Files

```text
src/Main.gd                         — orchestration, game loop, spawns, UI wiring
src/entities/player/Player.gd       — player input, weapon slots, HUD
src/entities/bot/Bot.gd             — AI state machine and combat execution
src/entities/pickup/Pickup.gd       — pickup visibility, label, icon decal, collect logic
src/entities/Entity.gd              — shared HP, shield, movement, perception
src/core/ZoneController.gd          — zone lifecycle and damage
src/core/MissionTracker.gd          — bonus/pressure mission state
src/core/Telemetry.gd               — match metrics; preserve JSON schema unless planned
src/core/AssetCatalog.gd            — audio/icon/prop/cosmetic ID lookup and fallback
src/core/LootSpawner.gd             — loot hotspot and position calculations
src/core/SupplyDropController.gd    — supply drop timing/position calculations
src/ui/MenuIconFactory.gd           — procedural menu/records/help icons
```

## Verification Rhythm

For narrow v1.10 refactors and readability polish, normally run:

```powershell
git diff --check
.\Godot_v4.6.2-stable_win64_console.exe --path . --headless --quit
python tools\simulate_matches.py 1
```

Expected warning while audio assets are missing:

```text
AssetCatalog: 7 configured asset paths are missing; fallbacks remain active.
```

Repeated simulation batches are not required for small UI/catalog/pickup display changes unless gameplay paths change.

## Godot Notes

- Control preset: `PRESET_CENTER_BOTTOM`, not `PRESET_BOTTOM_CENTER`.
- Bottom-anchored Control nodes need `grow_vertical = GROW_DIRECTION_BEGIN`.
- macOS export key: `application/bundle_identifier`.
- Headless export requires `textures/vram_compression/import_etc2_astc=true` in `project.godot`.
- For new `class_name` scripts created outside the editor, prefer `preload()` usage from `Main.gd` to avoid headless parse timing issues.
