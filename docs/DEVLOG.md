# Battle Capsule Active Devlog

> Last updated: 2026-05-13. Keep this file short. Add only recent verified work and link older details through [devlog/INDEX.md](devlog/INDEX.md).

The previous full devlog was preserved at [devlog/DEVLOG_full_2026-05-13.md](devlog/DEVLOG_full_2026-05-13.md). Do not load it by default.

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
