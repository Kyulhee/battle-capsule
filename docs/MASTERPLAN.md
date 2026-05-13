# Battle Capsule Master Plan

> Last updated: 2026-05-13 (document routing + asset readability planning)

This is the active roadmap. Historical long-form planning was moved to [archive/MASTERPLAN_full_2026-05-13.md](archive/MASTERPLAN_full_2026-05-13.md).

## Current Status

**Current line**: v1.10-dev — Main slimdown and UI/catalog boundaries.

**Current stabilization add-on**: v1.10.x — Item/Asset Readability Polish.

**Release status**: paused. Continue version-to-version development without GitHub releases unless explicitly requested.

**External assets**: `asset_generator/expected_output/` contains generated icon source files. Runtime-ready files are selected into `assets/` and registered through `data/asset_catalog.json`.

## Active Principles

- Keep `Main.gd` as the orchestrator while reducing the amount of code that must be read for simple config/UI/asset edits.
- Preserve single-source game state ownership in `Main.gd`: `zone`, `mission_tracker`, `player_ref`, `alive_count`, and Telemetry hooks stay there for now.
- Prefer catalog/helper/controller boundaries over broad gameplay rewrites.
- Treat already connected item/icon assets as readability polish, not new content expansion.
- Do not start 99-player scale, new maps, mission map theming, or v1.11 complex artifact logic until v1.10 stabilization is complete.

## Active Docs

| Document | Purpose |
|---|---|
| [../CLAUDE.md](../CLAUDE.md) | Session onboarding and default reading path |
| [DOCS_INDEX.md](DOCS_INDEX.md) | Documentation routing |
| [DEVLOG.md](DEVLOG.md) | Short active work log |
| [IMPACT_MAP.md](IMPACT_MAP.md) | Ownership and change-impact checks |
| [ARCHITECTURE.md](ARCHITECTURE.md) | Module boundaries |
| [TESTING.md](TESTING.md) | Verification criteria |
| [ASSET_BRIEF.md](ASSET_BRIEF.md) | Stable external asset style and format brief |

## v1.10 — Main Slimdown + UI Controllers `M`

**Summary**: Keep `Main.gd` as the orchestration root, but move isolated screen/config/spawn/asset responsibilities behind small boundaries.

**Already split**

- `GameConfig`: match, zone, difficulty, Hell timing JSON loader.
- `DebugFlags` / `DebugOverlay`: runtime debug flags and simple overlay.
- `AssetCatalog`: audio/icon/prop/cosmetic ID lookup with fallback and missing-path summary.
- `LootSpawner`: POI/density-based loot hotspot and position calculations.
- `SupplyDropController`: supply drop timing, position roll, and cluster calculations.
- `ArtifactCatalog`: starting artifact choices and stat modifiers.
- `DifficultyCatalog`: difficulty label/description/color UI data.
- `HelpCatalog`: How to Play section/row data.
- `MenuIconFactory`: procedural menu/records/help icon generation.

**Good next candidates**

1. `MenuController`: main menu, records, help, settings orchestration.
2. `MatchBootstrap`: config load, difficulty setup, seed/map bootstrapping.
3. Small UI/helper/catalog splits that remove isolated static data from `Main.gd`.

**Boundary rules**

- Controllers/helpers should not discover each other through the scene tree. `Main.gd` wires them.
- Do not move zone, mission, player, alive count, or Telemetry ownership out of `Main.gd` yet.
- Preserve Telemetry event names and JSON schema unless a dedicated migration is planned.

### v1.10.x — Item/Asset Readability Polish `S`

**Summary**: Improve readability and consistency of already connected item/icon assets without adding new items, weapons, artifacts, or gameplay content.

This is a stabilization step before v1.11 Complex Artifacts. It covers pickup display, item label noise, focus clarity, glow intensity, and asset fallback/export checks.

**Scope**

- Existing weapon, ammo, heal, armor, and artifact pickup display only.
- Existing runtime core icons under `assets/icons/` only unless a specific generated icon is selected.
- No new item, weapon, artifact, mission, or map content.
- No `Main.gd` game-state ownership changes.
- No Telemetry JSON schema changes.
- `asset_generator/expected_output/` remains an external source pool; do not commit or integrate the whole folder.

**Priorities**

1. Item label LOD
   - Hide labels for distant pickups.
   - At pickup range, show name only.
   - For the current focus/pickup candidate, show name plus quantity/ammo details.
   - When same-kind pickups are clustered, avoid showing every label at once.
2. Glow intensity
   - Reduce common/blue weapon and ammo glow.
   - Preserve rare/purple, legendary/orange, and armor/cyan readability.
   - Keep glow values in catalog/helper-style visual parameters rather than adding scattered item hardcoding.
3. Pickup focus
   - The current interactable target must be visually clear.
   - Focus should feel like game UI, not debug text.
4. AssetCatalog/fallback
   - Missing assets must keep using primitive/icon fallback without runtime errors.
   - New runtime assets must be registered through `data/asset_catalog.json`.
   - Export should include selected runtime assets and exclude generated source/master files.
5. Verification
   - `git diff --check`
   - `.\Godot_v4.6.2-stable_win64_console.exe --path . --headless --quit`
   - `python tools\simulate_matches.py 1`
   - Confirm Telemetry hook names and JSON schema are unchanged.

**Explicit exclusions**

- Screenshot saving is not mandatory verification.
- Do not touch v2.0 MapDefinition, v2.1 Forest 2.0, or v2.2 AI LOD work.
- Do not start 99-player expansion, new maps, mission map theming, or new artifact implementation.

## v1.11 — Complex Artifacts `M`

**Summary**: After v1.10 stabilization, add second-pass artifacts that create replay variation through bounded gameplay logic.

Candidate artifacts:

- Emergency Shell: once per match, shield at low HP.
- Ghost Grass: stealth grace after leaving bushes.
- Pulse Scanner: periodic nearby bot direction HUD cue.
- Marked King: kill reward plus temporary exposure.
- Glass Capsule: low max HP, high outgoing damage.
- Overheat Barrel: sustained-fire damage/spread tradeoff.

Do not begin until v1.10 Main boundaries and pickup/asset readability are stable.

## Phase 2 Guardrails

Phase 2 remains blocked until v1.10 and v1.11 foundations are stable.

| Future Area | Guardrail |
|---|---|
| v2.0 MapDefinition + Full Map UI | Requires config/debug foundation and v1.10 Main slimdown |
| Forest 2.0 / City Map | Requires MapDefinition and large navigation stability checks |
| 99-player or large-map scale | Requires AI LOD, spawn/loot density rescale, zone/pathing rescale, and performance validation |

## Compact History

| Version | Summary |
|---|---|
| v1.10-dev | Main slimdown, UI catalogs, supply/loot calculation boundaries |
| v1.9-dev | AssetCatalog hooks, audio/cosmetic IDs, debug logging hooks, scale-test CLI overrides |
| v1.8-dev | GameConfig, DebugFlags, DebugOverlay, AssetCatalog, runtime core icon pass |
| v1.7.3.1 | Main menu and How to Play hotfix |
| v1.7.x | AI doctrine, archetype readability, minimap/world footprint alignment |
| v1.6.x and earlier | Core battle royale prototype, missions, artifacts, telemetry, release foundation |

Detailed historical notes are indexed in [devlog/INDEX.md](devlog/INDEX.md); full pre-reset documents are in `docs/archive/` and `docs/devlog/`.

## Next Agent Checklist

- Read [HANDOFF.md](HANDOFF.md), [DOCS_INDEX.md](DOCS_INDEX.md), and this file before work.
- Before code changes, check [IMPACT_MAP.md](IMPACT_MAP.md) for ownership and cascade effects.
- Keep `asset_generator/` untracked unless explicitly asked to integrate selected files.
- For asset generation instructions, use local `docs/ASSET_GENERATION_PROMPTS.md` if present, and keep stable style/format rules in [ASSET_BRIEF.md](ASSET_BRIEF.md).
- For narrow v1.10 work, verify with `git diff --check`, Godot headless quit, and one simulation.
