# Battle Capsule — Agent Onboarding

Godot 4.6.2 / GDScript quarter-view battle royale prototype.

Repository: `https://github.com/Kyulhee/battle-capsule`

## Current State

| Item | Status |
|---|---|
| Current development line | v2-dev — Night BR candidate, 99-player structural gates, playable pacing |
| Current operating tracker | [CURRENT.md](docs/CURRENT.md) |
| Latest verified gameplay slice | N2-PACE-27 first-upgrade context telemetry/report |
| Current ops slice | N2-OPS-01 workflow tracker reset |
| Release policy | Paused. Do not create GitHub releases unless explicitly requested. |
| External source pools | `asset_generator/`, `plan_report/`, and local prompt scratch files stay untracked unless explicitly integrated. |

The project is no longer in a small one-feature-at-a-time cleanup phase. Work from the milestone tracker first, then pick the smallest slice that advances the active milestone without losing sight of playability.

## Default Reading Path

Read only the documents needed for the task. Do not load archived long documents by default.

| Order | Document | Read When |
|---|---|---|
| 1 | [CURRENT.md](docs/CURRENT.md) | Every session; use it as the active tracker |
| 2 | [HANDOFF.md](docs/HANDOFF.md) | Context resume, git state, local execution notes |
| 3 | [DECISIONS.md](docs/DECISIONS.md) | Before reopening blocked/default/pacing decisions |
| 4 | [EXPERIMENTS.md](docs/EXPERIMENTS.md) | Before new tuning candidates, to avoid repeating rejected paths |
| 5 | [DOCS_INDEX.md](docs/DOCS_INDEX.md) | To choose task-specific references |
| 6 | [IMPACT_MAP.md](docs/IMPACT_MAP.md) | Before code changes that touch game state, entities, UI, map, or telemetry |

Task-specific documents:

| Document | Use |
|---|---|
| [PLAYTEST.md](docs/PLAYTEST.md) | Manual feel/readability notes; telemetry cannot replace this |
| [MASTERPLAN.md](docs/MASTERPLAN.md) | Broader roadmap and historical context; do not treat it as the active tracker |
| [DEVLOG.md](docs/DEVLOG.md) | Short active log only. Historical details are indexed under `docs/devlog/`. |
| [TESTING.md](docs/TESTING.md) | Verification commands and gate interpretation |
| [ARCHITECTURE.md](docs/ARCHITECTURE.md) | Structural refactors or module boundary changes |
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
| Active tracker, next work, major risk changes | `docs/CURRENT.md` |
| Stable project decision changes | `docs/DECISIONS.md` |
| Accepted/rejected experiment outcome | `docs/EXPERIMENTS.md` |
| Manual feel/readability result | `docs/PLAYTEST.md` |
| Completed verified work | `docs/DEVLOG.md` as a short summary only |
| Larger roadmap changes | `docs/MASTERPLAN.md` |
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
src/systems/zone/ZoneController.gd  — zone lifecycle and damage
src/systems/mission/MissionTracker.gd — bonus/pressure mission state
src/core/Telemetry.gd               — match metrics; preserve JSON schema unless planned
src/core/AssetCatalog.gd            — audio/icon/prop/cosmetic ID lookup and fallback
src/systems/loot/LootSpawner.gd     — loot hotspot and position calculations
src/systems/loot/SupplyDropController.gd — supply drop timing/position calculations
src/ui/MenuIconFactory.gd           — procedural menu/records/help icons
```

## Verification Rhythm

For narrow docs/tooling changes, normally run:

```powershell
git diff --check
```

For gameplay, AI, map, telemetry, or pacing changes, select the relevant gate from [TESTING.md](docs/TESTING.md). Do not rely on a telemetry pass alone for major feel decisions; add a [PLAYTEST.md](docs/PLAYTEST.md) note when the user-facing experience changes.

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
