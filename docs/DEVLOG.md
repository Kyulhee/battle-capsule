# Battle Capsule Active Devlog

> Last updated: 2026-05-14. Keep this file short. Add only recent verified work and link older details through [devlog/INDEX.md](devlog/INDEX.md).

The previous full devlog was preserved at [devlog/DEVLOG_full_2026-05-13.md](devlog/DEVLOG_full_2026-05-13.md). Do not load it by default.

---

## v1.10.4-dev — 2026-05-14

**Data/Description Value Binding — item display formatter**

**src/core/ItemDisplayFormatter.gd / src/entities/pickup/Pickup.gd / src/entities/player/Player.gd**

- Added a small item display formatter for pickup names/details and weapon/slot ammo strings.
- Focused pickup details now read weapon ammo, ammo amount, heal count, and armor amount from `ItemData` / `StatsData` instead of local string fragments in `Pickup.gd`.
- Player HUD slot ammo and reload-progress ammo text now share the same formatter fed by `WeaponSlotManager` slot state.
- No pickup collection, inventory, balance values, Telemetry hook names, or JSON schema were changed.

**검증 결과**

- `git diff --check` 통과.
- `.\Godot_v4.6.2-stable_win64_console.exe --path . --headless --quit` 통과.
- `python tools\simulate_matches.py 1` 통과: duration=72.6s, stage=3, recover=23, disengage=12.

---

## v1.10.3-dev — 2026-05-14

**Data/Description Value Binding — artifact descriptions**

**src/core/ArtifactCatalog.gd / src/Main.gd / src/entities/player/Player.gd**

- Starting artifact `line1`/`line2` text is now generated from structured `mods` values instead of storing gameplay numbers directly in prose.
- Red Trigger damage/spread values and Armor Sponge heal-to-shield amounts now live in artifact modifier fields that Player combat/healing code also reads.
- Zone Battery difficulty-specific shield regeneration moved from `Main.gd` ad hoc mutation into `ArtifactCatalog.prepare_for_difficulty()`, so selection card text and applied value share the same path.
- No balance values, Telemetry hook names, or JSON schema were changed.

**검증 결과**

- `git diff --check` 통과.
- `.\Godot_v4.6.2-stable_win64_console.exe --path . --headless --quit` 통과.
- `python tools\simulate_matches.py 1` 통과: duration=85.1s, stage=3, recover=26, disengage=16.

---

## v1.10-dev — 2026-05-14

**Bot Objective Awareness — loot movement scan**

**src/entities/bot/Bot.gd**

- Loot/objective chase now keeps navigation toward the pickup while rotating view through an objective-relative scan pattern.
- Footstep and ambient awareness can now set scan alerts during loot chase, so bots can turn their view toward nearby movement without abandoning the pickup route.
- Non-recovery opportunistic loot can still be interrupted by a fully revealed enemy; recovery/combat-loot runs keep their objective unless existing higher-priority damage or loud-gunshot overrides take over.
- Telemetry hook names and JSON schema were not changed.

**검증 결과**

- `git diff --check` 통과.
- `.\Godot_v4.6.2-stable_win64_console.exe --path . --headless --quit` 통과.
- `python tools\simulate_matches.py 1` 통과: duration=104.4s, stage=4, recover=41, disengage=17.

---

## v1.10-dev — 2026-05-13

**RecordsPanelBuilder Boundary — Records rendering split**

**src/ui/RecordsPanelBuilder.gd / src/Main.gd**

- Moved Records difficulty tabs, clear button, history row rendering, and record icon value rows out of `Main.gd`.
- `Main.gd` keeps selected difficulty state and callbacks; `RecordsPanelBuilder` owns UI construction from Telemetry history.
- This continues the low-risk `MenuController`-direction split without moving game state, match flow, or Telemetry schema.
- `Main.gd` is now about 1847 lines after the Help/Records builder splits.

**검증 결과**

- `git diff --check` 통과.
- `.\Godot_v4.6.2-stable_win64_console.exe --path . --headless --quit` 통과.
- `python tools\simulate_matches.py 1` 통과: duration=74.1s, stage=3, recover=30, disengage=17.

---

## v1.10-dev — 2026-05-13

**HelpPanelBuilder Boundary — How to Play rendering split**

**src/ui/HelpPanelBuilder.gd / src/Main.gd**

- Moved How to Play scroll content rendering from `Main.gd` into `HelpPanelBuilder`.
- `Main.gd` now wires the Help panel root and close button styling, while `HelpPanelBuilder` reads `HelpCatalog` rows and uses `MenuIconFactory` for icon rows.
- This is a low-risk `MenuController`-direction slice; gameplay state ownership, Telemetry hooks, and match flow were not changed.
- `Main.gd` dropped the HelpPanel row-builder functions and no longer preloads `HelpCatalog` directly.

**검증 결과**

- `git diff --check` 통과.
- `.\Godot_v4.6.2-stable_win64_console.exe --path . --headless --quit` 통과.
- `python tools\simulate_matches.py 1` 통과: duration=62.3s, stage=2, recover=14, disengage=17.

---

## v1.10.2-dev — 2026-05-13

**Item/Asset Readability Polish — weapon icon optical sizing**

**tools/sync_generated_icons.ps1**

- Added per-icon `VisualScale` overrides so generated square-canvas weapon masters can be optically balanced during sync instead of manually edited after export.
- Added `-OnlyCategory` filtering and used `-OnlyCategory weapons` so this pass only re-synced runtime weapon icons.

**assets/icons/weapons/**

- Re-synced knife, pistol, AR, shotgun, and railgun runtime icons.
- Pistol was reduced from roughly 54x43 alpha bounds to 42x34.
- AR, shotgun, and railgun were expanded horizontally to roughly 57-60px bounds so long weapons do not read as undersized beside pistol.
- HUD rendering and pickup decal code were not changed.

**검증 결과**

- `git diff --check` 통과.
- `.\Godot_v4.6.2-stable_win64_console.exe --path . --headless --quit` 통과.
- `python tools\simulate_matches.py 1` 통과: duration=77.0s, stage=3, recover=14, disengage=20.

---

## v1.10.1-dev — 2026-05-13

**Item/Asset Readability Polish — focus marker and death-drop labels**

**src/entities/pickup/Pickup.gd**

- Reduced focused pickup floor marker radius, alpha, and emission so it reads as a secondary focus cue instead of a heavy ground highlight.
- Pickup focus logic, collection behavior, and Telemetry schema were not changed.

**src/core/DropDisplayCatalog.gd / src/entities/player/Player.gd / src/entities/bot/Bot.gd**

- Added a shared death-drop display catalog for runtime-generated weapon, ammo, and heal pickup names.
- Player death drops now use Korean names consistently with bot death drops and `src/items/*.tres` templates.
- Bot death drops were moved to the same catalog so future death-drop naming changes have one source.

**Docs**

- Clarified that v1.10 is still in progress, not a completed Main slimdown release.
- Updated v1.10 completion gate and impact notes for `DropDisplayCatalog`.

**검증 결과**

- `git diff --check` 통과.
- `.\Godot_v4.6.2-stable_win64_console.exe --path . --headless --quit` 통과.
- `python tools\simulate_matches.py 1` 통과: duration=77.1s, stage=3, recover=20, disengage=21.

---

## v1.10.x-dev — 2026-05-13

**Item/Asset Readability Polish — pickup label LOD and focus**

**src/entities/pickup/Pickup.gd / src/entities/player/Player.gd**

- Pickup labels now use a small LOD policy: distant pickups hide labels, nearby non-focused pickups show name only, and the current interaction focus shows name plus ammo/quantity detail.
- Same-kind pickup clusters suppress duplicate labels so dense loot piles do not flood the screen with repeated text.
- Common/blue weapon and ammo glow intensity was reduced while purple/orange/cyan high-value cues remain stronger.
- The player now tracks the nearest interactable pickup each frame and marks it with a subtle in-world focus disc plus detailed label.
- Collection behavior, item data, and Telemetry JSON schema were not changed.

**docs/IMPACT_MAP.md**

- Updated pickup display ownership notes to reflect label LOD/focus behavior.

**검증 결과**

- `git diff --check` 통과.
- `.\Godot_v4.6.2-stable_win64_console.exe --path . --headless --quit` 통과.
- `python tools\simulate_matches.py 1` 통과: duration=61.7s, stage=2, recover=17, disengage=21.

---

## v1.10-docs — 2026-05-13

**Document Operations Reset + External Asset Prompt Plan**

**Docs**

- Replaced the default documentation flow with a short routing structure:
  - [../CLAUDE.md](../CLAUDE.md)
  - [DOCS_INDEX.md](DOCS_INDEX.md)
  - [MASTERPLAN.md](MASTERPLAN.md)
  - [DEVLOG.md](DEVLOG.md)
- Moved historical long documents out of the default reading path:
  - `docs/archive/MASTERPLAN_full_2026-05-13.md`
  - `docs/archive/IDEA_PLAN_legacy.md`
  - `docs/devlog/DEVLOG_full_2026-05-13.md`
- Added compact per-version devlog summaries under [devlog/INDEX.md](devlog/INDEX.md).
- Added local-only `docs/ASSET_GENERATION_PROMPTS.md` for copy-ready external generator prompts; it remains intentionally untracked.
- Replaced the old ASCII/mockup UI process with screenshot-driven review guidance in [UI_DESIGN.md](UI_DESIGN.md).

**Scope Note**

- No gameplay or runtime code changes.
- `asset_generator/` remains untracked and external.

---

## v1.10-dev — 2026-05-11

**MenuIconFactory Boundary — procedural menu icon split**

- Moved capsule logo and Records/Help pixel icon generation from `Main.gd` into `src/ui/MenuIconFactory.gd`.
- `Main.gd` now asks for icon IDs instead of owning pixel-generation details.
- Verified previously with Godot headless quit, one simulation, and `git diff --check`.

---

## v1.10-dev — 2026-05-11

**HelpCatalog Boundary — How to Play data split**

- Moved How to Play key/icon/text/description data into `src/core/HelpCatalog.gd`.
- `Main.gd` still owns the HelpPanel builder and rendering style.
- Verified previously with Godot headless quit, one simulation, and `git diff --check`.

---

## v1.10-dev — 2026-05-11

**DifficultyCatalog Boundary — difficulty UI data split**

- Moved difficulty labels, descriptions, and colors into `src/core/DifficultyCatalog.gd`.
- Main menu, tooltip, and Records tabs now share the same source.
- Verified previously with Godot headless quit, one simulation, and `git diff --check`.

---

## v1.10-dev — 2026-05-11

**ArtifactCatalog Boundary — starting artifact data split**

- Moved starting artifact ID/label/color/description/modifier data into `src/core/ArtifactCatalog.gd`.
- `Main.gd` keeps selection UI and modifier application flow.
- Verified previously with Godot headless quit, one simulation, and `git diff --check`.

---

## v1.10-dev — 2026-05-11

**SupplyDropController Boundary — supply calculation split**

- Added `src/core/SupplyDropController.gd` for supply telegraph timing, position roll, pillar progress, and cluster calculations.
- `Main.gd` still owns minimap state and actual node creation.
- Verified previously with Godot headless quit, one simulation, and `git diff --check`.
