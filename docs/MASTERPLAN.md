# Battle Capsule Master Plan

> Last updated: 2026-05-13 (HelpPanelBuilder split)

This is the active roadmap. Historical long-form planning was moved to [archive/MASTERPLAN_full_2026-05-13.md](archive/MASTERPLAN_full_2026-05-13.md).

## Current Status

**Current line**: v1.10-dev — Main slimdown and UI/catalog boundaries.

**Current stabilization add-on**: v1.10.x — Item/Asset Readability Polish.

**v1.10 completion status**: not complete. Completed slices below are incremental boundaries, not a finished Main slimdown release.

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

**Status**: in progress. `Main.gd` still owns substantial UI orchestration, match bootstrapping, event flow, and state wiring. The goal is not line-count reduction by itself; the goal is that routine config, catalog, asset, and display edits no longer require reading unrelated `Main.gd` systems.

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
- `HelpPanelBuilder`: How to Play panel rendering from HelpCatalog rows.

**Good next candidates**

1. `MenuController`: main menu, records, help, settings orchestration.
2. `MatchBootstrap`: config load, difficulty setup, seed/map bootstrapping.
3. Small UI/helper/catalog splits that remove isolated static data from `Main.gd`.

**Boundary rules**

- Controllers/helpers should not discover each other through the scene tree. `Main.gd` wires them.
- Do not move zone, mission, player, alive count, or Telemetry ownership out of `Main.gd` yet.
- Preserve Telemetry event names and JSON schema unless a dedicated migration is planned.

**Completion gate before v1.11**

- Finish the v1.10.x item/asset readability stabilization work or explicitly defer remaining visual-only items.
- Move at least one remaining large isolated responsibility out of `Main.gd`, preferably `MenuController` first or `MatchBootstrap` if bootstrapping becomes the lower-risk slice.
- Keep pressure mission effects, zone state, player reference, alive count, and Telemetry ownership in `Main.gd` unless a separate migration plan exists.
- Confirm that simple item display, UI catalog, and balance/config edits can be made through data/catalog/helper files without touching unrelated `Main.gd` sections.

### v1.10.x — Item/Asset Readability Polish `S`

**Summary**: Improve readability and consistency of already connected item/icon assets without adding new items, weapons, artifacts, or gameplay content.

This is a stabilization step before v1.11 Complex Artifacts. It covers pickup display, item label noise, focus clarity, glow intensity, and asset fallback/export checks.

**Patch numbering guidance**

- Use `v1.10.1`-style slices for localized presentation tuning that does not change asset pipeline rules. Example: weakening an over-visible pickup focus marker after screenshot review.
- Use `v1.10.2`-style slices for small asset-pipeline rule changes that can affect multiple runtime files. Example: changing generated icon post-processing scale rules and re-syncing runtime weapon icons.
- Keep all `v1.10.x` slices inside the existing v1.10 stabilization scope. These are not v1.11 content features.

**Scope**

- Existing weapon, ammo, heal, armor, and artifact pickup display only.
- Existing runtime core icons under `assets/icons/` only unless a specific generated icon is selected.
- No new item, weapon, artifact, mission, or map content.
- No `Main.gd` game-state ownership changes.
- No Telemetry JSON schema changes.
- `asset_generator/expected_output/` remains an external source pool; do not commit or integrate the whole folder.

**Priorities**

1. Item label LOD — first pass complete
   - Hide labels for distant pickups.
   - At pickup range, show name only.
   - For the current focus/pickup candidate, show name plus quantity/ammo details.
   - When same-kind pickups are clustered, avoid showing every label at once.
2. Focus marker tone-down — v1.10.1 first pass complete
   - Current filled floor highlight read too heavy in real screenshots.
   - Reduced alpha, emission, and radius while preserving current focus logic.
   - Focus should be secondary to pickup shape/icon and detailed label.
   - No collection logic, Telemetry, or asset file changes.
3. Drop display naming consistency — v1.10.1 first pass complete
   - Initial map loot and supply drops use `ItemData` templates from `src/items/*.tres`, so their labels are already Korean and data-driven.
   - Player/bot death drops create `ItemData` at runtime and now share `DropDisplayCatalog` for Korean weapon/ammo/heal names and death-drop weapon colors.
   - This was fixed as a generation-path consistency issue, not as label text patching in `Pickup.gd`.
   - Preserve drop quantities, item types, Telemetry schema, and collection behavior.
4. Glow intensity
   - Reduce common/blue weapon and ammo glow.
   - Preserve rare/purple, legendary/orange, and armor/cyan readability.
   - Keep glow values in catalog/helper-style visual parameters rather than adding scattered item hardcoding.
5. Pickup focus
   - The current interactable target must be visually clear.
   - Focus should feel like game UI, not debug text.
6. Weapon icon optical sizing — v1.10.2 first pass complete
   - Generated weapon masters are square canvases, so short/thick weapons such as pistol can appear optically larger than long weapons such as shotgun/rifle in HUD slots.
   - Prefer post-processing rules over manual PNG edits so future sync runs stay consistent.
   - `tools/sync_generated_icons.ps1` now supports per-icon `VisualScale` overrides and `-OnlyCategory weapons`.
   - Runtime `assets/icons/weapons/*.png` were re-synced with pistol/knife reduced and long weapons slightly expanded.
   - Keep HUD slot rendering unchanged unless post-processing cannot solve the mismatch.
   - Do not bulk-sync held action/status/map/ui icons as part of this work.
7. AssetCatalog/fallback
   - Missing assets must keep using primitive/icon fallback without runtime errors.
   - New runtime assets must be registered through `data/asset_catalog.json`.
   - Export should include selected runtime assets and exclude generated source/master files.
8. Verification
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
