# UI Visual Review Guide

> Last updated: 2026-05-13. This replaces the old ASCII/mockup approval process with a screenshot-driven review workflow.

Use this document when a change affects HUD, menus, pickup labels, minimap, result screens, settings, or any visible UI state.

## Goal

UI review should answer concrete visual questions:

- Is anything overlapping?
- Is important information readable against the real game background?
- Does text fit in its container?
- Does dynamic state change layout size or position?
- Does the UI still work at the project baseline viewport and likely smaller/wider viewports?

Do not rely on intended layout from code alone. Review actual screenshots whenever the change is visual.

## Current Capture Support

The game currently supports manual screenshot capture:

```text
F12 -> debug_screenshot_manual.png
```

Implementation reference:

- `src/Main.gd` handles `KEY_F12`.
- `_take_screenshot("debug_screenshot_manual.png")` first saves to `res://`, then falls back to `user://` if project write fails.

Current baseline viewport:

```text
project.godot
window/size/viewport_width=1280
window/size/viewport_height=720
```

There is not yet a dedicated command-line screenshot capture mode. If a UI task needs repeatable visual verification, adding a small non-gameplay capture mode is preferred over temporary mockup branches.

## Default Review Workflow

1. Run the game normally and capture the relevant screen with `F12`.
2. Inspect the screenshot directly, preferably with the image viewer available to the agent.
3. Run the normal non-visual checks:

```powershell
git diff --check
.\Godot_v4.6.2-stable_win64_console.exe --path . --headless --quit
python tools\simulate_matches.py 1
```

For pure documentation or copy changes, screenshots and simulations are not required.

## Required Screenshots By Change Type

| Change Type | Screenshots To Capture |
|---|---|
| HUD status, health, shield, missions | active match with normal state, damaged/low state if relevant |
| Zone timer / warnings | normal `ZONE Ns`, `ZONE CLOSING` |
| Pickup labels/icons/glow | sparse pickup area, dense pickup cluster, focused pickup candidate |
| Weapon slot HUD | empty slots, full inventory, reload/low ammo if relevant |
| Records/settings/help/menu | each changed panel at default viewport |
| Minimap/full-map work | normal map, zone closing, supply/loot marker state if relevant |
| Result screen | win and loss if the change touches result text/layout |

Do not capture every possible state for small changes. Capture the states that could plausibly break.

## Visual Review Checklist

### Layout

- No overlapping UI text, icons, panels, minimap, or labels.
- Text stays inside buttons, panels, slot boxes, and labels.
- Dynamic values do not resize the whole layout unexpectedly.
- Top-left HUD, center zone text, killfeed, minimap, and bottom slot bar do not fight for the same screen space.
- Pickup labels do not flood the center of the screen when loot is clustered.

### Readability

- HP, shield, alive count, zone state, active weapon, and focused pickup are readable first.
- Secondary information is visibly lower priority.
- Text outline/shadow is enough on dark terrain, buildings, zone overlay, and glow effects.
- Icons remain recognizable at their actual in-game size, not just in source sheets.
- Color is functional: danger, rare, armor, heal, ammo, and common loot are distinguishable.

### Motion And State

- `ZONE Ns` and `ZONE CLOSING` transitions do not jump or occlude other UI.
- Killfeed accumulation does not spill into unrelated HUD areas.
- Pickup focus changes are clear but not debug-like.
- Reload/low ammo indicators update without layout jitter.
- Pause, settings, help, records, and result panels return to the correct previous screen.

### Asset-Specific Checks

- Catalog icons render when present.
- Fallback primitive/icon display still works when an asset is missing.
- Common weapon/ammo glow does not overpower rare/purple, legendary/orange, armor/cyan, or zone warning cues.
- New generated source files under `asset_generator/expected_output/` are not accidentally treated as runtime assets.

## Automated Review Direction

For future UI work, prefer adding a small deterministic capture path instead of temporary mockups.

Recommended command shape:

```powershell
.\Godot_v4.6.2-stable_win64_console.exe --path . -- ui_capture=true ui_state=pickup_dense screenshot=ui_pickup_dense_1280x720.png
```

Suggested capture states:

| State ID | Purpose |
|---|---|
| `hud_normal` | baseline gameplay HUD |
| `hud_zone_closing` | zone warning layout |
| `pickup_sparse` | one or two visible pickups |
| `pickup_dense` | clustered loot readability |
| `inventory_full` | weapon slot stress state |
| `menu_main` | main menu layout |
| `panel_help` | How to Play panel |
| `panel_records` | records list and difficulty tabs |
| `panel_settings` | settings controls |
| `result_win` | result screen layout |

Suggested viewport matrix:

```text
1280x720   baseline
1600x900   wider desktop
960x540    small 16:9
```

This capture mode should:

- Avoid changing gameplay simulation logic.
- Build only the requested UI state or start a deterministic short match setup.
- Save screenshots to a known path.
- Exit automatically after capture.
- Be excluded from release-facing UI unless explicitly enabled by command-line args.

## Agent Review Expectations

When screenshots are available, the agent should inspect them as images and report concrete findings:

- file reviewed,
- viewport/state,
- visible overlaps,
- unreadable text,
- label/icon clutter,
- container overflow,
- suspicious regressions.

Good review result:

```text
Reviewed ui_pickup_dense_1280x720.png.
Findings:
- Pickup labels overlap above the lower-left loot cluster.
- Blue ammo glow is stronger than armor/cyan and should be reduced.
- Focus candidate is not distinguishable from non-focused pickups.
```

Bad review result:

```text
Looks fine.
```

## When To Update This Document

Update this document when:

- a screenshot capture command is actually implemented,
- a new recurring UI state needs review,
- viewport support changes,
- a visual issue repeats often enough to become a checklist item.

Do not add large design proposals here. Put roadmap/scope in [MASTERPLAN.md](MASTERPLAN.md), completed work in [DEVLOG.md](DEVLOG.md), and stable asset style/format rules in [ASSET_BRIEF.md](ASSET_BRIEF.md).
