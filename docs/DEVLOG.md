# Battle Capsule Active Devlog

> Last updated: 2026-05-28. This is the compressed active log. Full pre-compression history is preserved in [devlog/DEVLOG_full_2026-05-26.md](devlog/DEVLOG_full_2026-05-26.md); older full history remains in [devlog/DEVLOG_full_2026-05-13.md](devlog/DEVLOG_full_2026-05-13.md).

Do not load full devlog snapshots by default. Use [devlog/INDEX.md](devlog/INDEX.md) and per-version summaries unless exact historical detail is needed.

---

## v1.12.9-dev — 2026-05-28

**Artifact selection compact UI**

**src/ui/panels/ArtifactSelectionPanelBuilder.gd / src/core/ArtifactCatalog.gd / tools / docs**

- Replaced the six long artifact cards with fixed circular icon options plus one-line catalog summaries.
- Added catalog-owned `summary` text for each starting artifact.
- Selecting an artifact option now updates one stable detail card with the full `line1`/`line2` description and choose button.
- Added `tools/capture_artifact_selection_ui.gd` for screenshot review at `C:/tmp/artifact_selection_ui.png`.
- Updated artifact selection layout smoke to verify option count, button icons, default detail content, detail update after pressing an option, and 1280px row fit.
- Follow-up patch centers circular option icons with embedded `TextureRect`s instead of `Button.icon`; generated artifact source icons currently exist for four artifacts only.
- `ArtifactIconResolver.gd` now loads raw PNG files via `Image.load()` when Godot import metadata is absent, matching the weapon icon resolver behavior.
- Added `tools/verify_artifact_icon_loading.gd` to prove the four generated artifact icons load as runtime PNG textures while Ghost Grass and Escape Capsule remain fallback-only.

**검증 결과**

- `git diff --check` 통과.
- `.\Godot_v4.6.2-stable_win64_console.exe --headless --script tools/verify_artifact_icon_loading.gd` 통과: 4 generated PNG icons loaded as 64x64 textures; 2 missing icons used 54x54 fallback textures.
- `.\Godot_v4.6.2-stable_win64_console.exe --headless --script tools/verify_artifact_selection_layout.gd` 통과: 6 options, 936px row width.
- `.\Godot_v4.6.2-stable_win64_console.exe --path . --script res://tools/capture_artifact_selection_ui.gd` 통과: `C:/tmp/artifact_selection_ui.png` 생성 및 중앙 정렬 확인.
- `.\Godot_v4.6.2-stable_win64_console.exe --headless --quit` 통과. Expected AssetCatalog missing-path warning only.

---

## v1.12.8-dev — 2026-05-28

**Artifact balance and penalty pass**

**src/core/ArtifactCatalog.gd / src/entities/player/Player.gd / src/entities/player/PlayerArtifactRuntime.gd / tools / docs**

- Renamed Emergency Shell presentation to **Escape Capsule** while keeping the internal id `emergency_shell`; its trigger now purges all ammo after granting the one-shot shield.
- Red Trigger now increases ranged firing reveal duration to 3.0s.
- Armor Sponge now scales movement speed from normal at 0 shield to 0.75 at max shield; heal-to-shield conversion is 50% of heal value and capped at 50 shield.
- Silent Core no longer reduces max HP/shield; instead, the first unrevealed non-knife shot is forced to miss.
- Ghost Grass now has 1.25s bush-exit stealth, 5.0s cooldown, and 1.5x gun damage plus immediate break if shot while active.
- Added `tools/verify_artifact_balance.gd` and extended artifact runtime smoke coverage.

**검증 결과**

- `git diff --check` 통과.
- `.\Godot_v4.6.2-stable_win64_console.exe --headless --script tools/verify_artifact_runtime.gd` 통과.
- `.\Godot_v4.6.2-stable_win64_console.exe --headless --script tools/verify_artifact_balance.gd` 통과.
- `.\Godot_v4.6.2-stable_win64_console.exe --headless --script tools/verify_artifact_selection_layout.gd` 통과: 6 cards, 6 icons, 958px row width.
- `.\Godot_v4.6.2-stable_win64_console.exe --headless --script tools/verify_artifact_visuals.gd` 통과.
- `.\Godot_v4.6.2-stable_win64_console.exe --headless --quit` 통과. Expected AssetCatalog missing-path warning only.
- `python tools\simulate_matches.py 1 normal` 통과: duration=72.7s, stage=3, recover=21, disengage=20.
- `python tools\simulate_matches.py 1 hell` 통과: duration=102.1s, stage=4, recover=65, disengage=22.

---

## v1.12.7-dev — 2026-05-28

**Artifact icon display integration**

**src/ui/ArtifactIconResolver.gd / artifact selection HUD / data/asset_catalog.json / tools**

- Added `ArtifactIconResolver.gd` and normalized artifact icon lookup through `artifact.<id>` catalog ids.
- Artifact selection cards now show small artifact images.
- The in-game artifact indicator now uses an icon instead of the previous text label.
- Runtime PNGs currently cover Red Trigger, Armor Sponge, Silent Core, and Zone Battery; Ghost Grass and Escape Capsule use catalog fallback icons until generated PNGs are promoted.
- Extended artifact selection layout smoke to verify icon TextureRects.

**검증 결과**

- `git diff --check` 통과.
- `.\Godot_v4.6.2-stable_win64_console.exe --headless --script tools/verify_artifact_selection_layout.gd` 통과: 6 cards, 6 icons, 958px row width.
- `.\Godot_v4.6.2-stable_win64_console.exe --headless --quit` 통과. Expected AssetCatalog missing-path warning only.

---

## v1.12.6-dev — 2026-05-28

**Artifact visual readability pass**

**src/entities/player/PlayerArtifactVisuals.gd / src/entities/player/Player.gd / tools / docs**

- Added `tools/capture_artifact_visual_gallery.gd`, which renders all current artifact visual states into `C:/tmp/artifact_visual_gallery.png` for direct inspection.
- Used the generated gallery to review the six first-pass visuals plus Emergency Shell ready/break states.
- Tuned Silent Core so afterimages trail opposite the current movement direction instead of stacking over the player body.
- Tuned Ghost Grass to use a brighter lime/yellow-green wake with stronger grass blades so it separates from the default green player tint.
- Kept gameplay state ownership unchanged: `PlayerArtifactRuntime.gd` still owns trigger/timer state, while `PlayerArtifactVisuals.gd` only owns presentation nodes.

**검증 결과**

- `git diff --check` 통과.
- `.\Godot_v4.6.2-stable_win64_console.exe --headless --path . --script res://tools/verify_artifact_visuals.gd` 통과.
- `.\Godot_v4.6.2-stable_win64_console.exe --path . --script res://tools/capture_artifact_visual_gallery.gd` 통과: `C:/tmp/artifact_visual_gallery.png` 생성.
- `.\Godot_v4.6.2-stable_win64_console.exe --headless --path . --script res://tools/verify_artifact_runtime.gd` 통과.
- `.\Godot_v4.6.2-stable_win64_console.exe --headless --path . --script res://tools/verify_artifact_selection_layout.gd` 통과: 6 cards, 958px row width.
- `.\Godot_v4.6.2-stable_win64_console.exe --path . --headless --quit` 통과. Expected AssetCatalog missing-path warning only.
- `python tools\simulate_matches.py 1 normal` 통과: duration=46.5s, stage=2, recover=32, disengage=15.
- `python tools\simulate_matches.py 1 hell` 통과: duration=47.3s, stage=2, recover=58, disengage=26.

---

## v1.12.5-dev — 2026-05-28

**Artifact visual identity foundation**

**src/entities/player/PlayerArtifactVisuals.gd / src/entities/player/Player.gd / src/core/ArtifactCatalog.gd / docs / tools**

- Added `PlayerArtifactVisuals.gd` to own player-attached artifact visual nodes separately from gameplay trigger state.
- Added `visual_id` to every starting artifact descriptor.
- Wired `Player.gd` so visuals receive current weapon type, shield ratio, movement speed, Zone Battery proximity, Ghost Grass active state, and artifact runtime events.
- Added first-pass primitive visuals for all current starting artifacts: Red Trigger glow, Armor Sponge plates, Silent Core afterimages, Zone Battery plasma, Emergency Shell back pack/rupture, and Ghost Grass wake.
- Added `tools/verify_artifact_visuals.gd` smoke coverage for catalog visual ids and visual state toggles.

**검증 결과**

- `git diff --check` 통과.
- `.\Godot_v4.6.2-stable_win64_console.exe --headless --path . --script res://tools/verify_artifact_visuals.gd` 통과.
- `.\Godot_v4.6.2-stable_win64_console.exe --headless --path . --script res://tools/verify_artifact_runtime.gd` 통과.
- `.\Godot_v4.6.2-stable_win64_console.exe --headless --path . --script res://tools/verify_artifact_selection_layout.gd` 통과: 6 cards, 958px row width.
- `.\Godot_v4.6.2-stable_win64_console.exe --path . --headless --quit` 통과. Expected AssetCatalog missing-path warning only.
- `python tools\simulate_matches.py 1 normal` 통과: duration=83.6s, stage=3, recover=23, disengage=21.
- `python tools\simulate_matches.py 1 hell` 통과: duration=66.6s, stage=2, recover=86, disengage=27.

---

## v1.12.4-dev — 2026-05-28

**Ghost Grass bush-exit stealth runtime**

**src/core/ArtifactCatalog.gd / src/entities/player/PlayerArtifactRuntime.gd / src/entities/player/Player.gd / src/core/Telemetry.gd / docs / tools**

- Added Ghost Grass as a starting artifact with catalog-owned duration, stealth multiplier, and footstep multiplier values.
- Extended `PlayerArtifactRuntime.gd` so player artifact runtime state now covers both Emergency Shell one-shot damage response and Ghost Grass bush-exit timer state.
- Wired `Player.gd` to report bush transitions, apply Ghost Grass stealth while `reveal_timer <= 0`, and reduce footstep radius only while the timer is active.
- Kept reveal/fire behavior authoritative: Ghost Grass does not suppress an active reveal ping.
- Added `ghost_grass_started` Telemetry count and extended artifact runtime smoke coverage.

**검증 결과**

- `git diff --check` 통과.
- `.\Godot_v4.6.2-stable_win64_console.exe --headless --path . --script res://tools/verify_artifact_runtime.gd` 통과.
- `.\Godot_v4.6.2-stable_win64_console.exe --headless --path . --script res://tools/verify_artifact_selection_layout.gd` 통과: 6 cards, 958px row width.
- `.\Godot_v4.6.2-stable_win64_console.exe --path . --headless --quit` 통과. Expected AssetCatalog missing-path warning only.
- `python tools\simulate_matches.py 1 normal` 통과: duration=74.3s, stage=3, recover=21, disengage=13.
- `python tools\simulate_matches.py 1 hell` 통과: duration=77.6s, stage=3, recover=128, disengage=23.

---

## v1.12.3-dev — 2026-05-28

**Emergency Shell readability check and next artifact shortlist**

**tools/verify_artifact_selection_layout.gd / docs**

- Added an artifact selection layout smoke test that builds the current catalog, verifies required card text, confirms Emergency Shell is present, and checks default 1280px row fit.
- Verified the five-card artifact selection row is 796px wide, so no immediate card layout change is needed.
- Left Emergency Shell threshold/shield values unchanged pending actual manual play/screenshot review.
- Shortlisted Ghost Grass as the next artifact candidate because bush-exit stealth grace is bounded player runtime state and avoids first-pass minimap/HUD direction work.

**검증 결과**

- `git diff --check` 통과.
- `.\Godot_v4.6.2-stable_win64_console.exe --headless --path . --script res://tools/verify_artifact_selection_layout.gd` 통과: 5 cards, 796px row width.

---

## v1.12.2-dev — 2026-05-27

**Emergency Shell first implementation**

**src/core/ArtifactCatalog.gd / src/entities/player/PlayerArtifactRuntime.gd / src/entities/player/Player.gd / src/core/Telemetry.gd / docs / tools**

- Added Emergency Shell as a starting artifact with catalog-owned HP threshold and shield amount values.
- Added `PlayerArtifactRuntime.gd` to own one-match runtime trigger state for player artifacts.
- Wired `Player.gd` so Emergency Shell triggers once after non-lethal damage leaves HP at or below the configured threshold, then grants the configured shield amount up to current max shield.
- Added reusable player status flash entry point while preserving the pressure flash wrapper.
- Added artifact Telemetry metrics: selected artifact id, artifact event counts, and Emergency Shell trigger count.
- Added `tools/verify_artifact_runtime.gd` smoke coverage for threshold, shield amount, and one-shot behavior.

**검증 결과**

- `git diff --check` 통과.
- `.\Godot_v4.6.2-stable_win64_console.exe --headless --path . --script res://tools/verify_artifact_runtime.gd` 통과.
- `.\Godot_v4.6.2-stable_win64_console.exe --path . --headless --quit` 통과. Expected AssetCatalog missing-path warning only.
- `python tools\simulate_matches.py 1 normal` 통과: duration=75.0s, stage=3, recover=30, disengage=17.
- `python tools\simulate_matches.py 1 hell` 통과: duration=45.1s, stage=2, recover=68, disengage=15.

---

## v1.12.1-dev — 2026-05-27

**Complex Artifacts scope and first implementation candidate**

**docs/MASTERPLAN.md / docs/devlog/v1.12.md / docs/devlog/INDEX.md**

- Started v1.12 as the Complex Artifacts line after v1.11 structural closure.
- Audited the existing artifact flow: `ArtifactCatalog.gd` owns selection descriptors/modifier data, `Main.gd` owns selection/apply orchestration, and `Player.gd` owns runtime modifier application.
- Chose **Emergency Shell** as the first implementation candidate because a one-shot low-HP shield has bounded player-runtime state and visible feedback without touching bot AI, map systems, or mission logic.
- Deferred Glass Capsule, Ghost Grass, Pulse Scanner, Marked King, and Overheat Barrel until the artifact runtime boundary is proven.
- Defined the v1.12.2 boundary contract: catalog-owned effect data, small player artifact runtime helper, Player-owned wiring/application, optional Telemetry event logging, and no Main-owned effect logic.

**검증 결과**

- `git diff --check` 통과.

---

## v1.11.36-dev — 2026-05-26

**v1.11 closure decision and pressure snapshot boundary**

**src/systems/mission/MissionTracker.gd / src/Main.gd / docs**

- Re-audited the remaining v1.11 owner boundaries against the role rules in `MASTERPLAN.md`.
- Added `MissionTracker.get_active_pressure_snapshot()` so `Main.gd` no longer reads `MissionTracker._active_pressure` directly when applying pressure success/fail reward or penalty effects.
- Updated bot debug snapshot state names in `Main.gd` to read from the Bot enum source instead of a duplicated local name list.
- Marked v1.11 structurally closed; future v1.11 reopen should require a concrete boundary bug or stale doc route, not line count alone.

**검증 결과**

- `git diff --check` 통과. Git emitted the existing line-ending warning for `MissionTracker.gd`, but no whitespace errors.
- `.\Godot_v4.6.2-stable_win64_console.exe --path . --headless --quit` 통과. Expected AssetCatalog missing-path warning only.
- `python tools\simulate_matches.py 1 normal` 통과: duration=99.7s, stage=4, recover=32, disengage=17.
- `python tools\simulate_matches.py 1 hell` 통과: duration=63.9s, stage=2, recover=66, disengage=16.

---

## v1.11.35-dev — 2026-05-26

**Active documentation compression**

**docs/MASTERPLAN.md / docs/DEVLOG.md / docs/devlog/v1.11.md / docs/DOCS_INDEX.md / docs/devlog/INDEX.md / docs/HANDOFF.md**

- Snapshotted full active docs before compression:
  - `docs/archive/MASTERPLAN_full_2026-05-26.md`
  - `docs/devlog/DEVLOG_full_2026-05-26.md`
  - `docs/devlog/v1.11_full_2026-05-26.md`
- Compressed `MASTERPLAN.md` to current status, active principles, boundary role rules, structural state, next work, and gates.
- Compressed `DEVLOG.md` to recent verified work plus links to full snapshots.
- Compressed `docs/devlog/v1.11.md` to grouped slice summaries and current follow-ups.
- Updated doc routing/index files so agents do not load raw/full logs by default.

**검증 결과**

- `git diff --check` 통과.

---

## v1.11.34-dev — 2026-05-26

**Boundary and documentation governance review**

**docs/MASTERPLAN.md / docs/DOCS_INDEX.md / docs/devlog/v1.11.md / docs/HANDOFF.md**

- Audited the v1.10-v1.11 boundary work by role: Main-owned orchestration, tuning, catalog/data, formatter/builder/resolver, evaluator, controller/director/planner, and store.
- Confirmed the current extraction direction is coherent enough to continue; no urgent runtime authority conflict was found.
- Added role rules to `MASTERPLAN.md` so future helpers do not blur data, formatting, evaluation, state, and orchestration ownership.
- Added active-document budgets and archive routing rules to `DOCS_INDEX.md`.
- Scoped v1.11.35 as a docs-only compression pass before more gameplay or broad extraction work.

**검증 결과**

- `git diff --check` 통과.

---

## v1.11.33-dev — 2026-05-25

**Pressure feasibility tuning boundary**

**src/systems/mission/MissionTuning.gd / src/systems/mission/PressureConditionEvaluator.gd / docs**

- Moved pressure feasibility literals for detected-survival minimum bots and late-zone long outside-zone filtering into `MissionTuning.gd`.
- `PressureConditionEvaluator.gd` now reads those values from `MissionTuning` while keeping descriptor feasibility and active condition evaluation algorithms.
- Updated mission docs to mark pressure feasibility cutoffs as tuning-owned rather than evaluator-owned.
- Preserved pressure descriptors, active counters, feasibility outcomes, HUD text, reward/penalty execution, and Telemetry schema.

**검증 결과**

- `git diff --check` 통과.
- `.\Godot_v4.6.2-stable_win64_console.exe --path . --headless --quit` 통과.
- `python tools\simulate_matches.py 1 normal` 통과: duration=64.5s, stage=2.
- `python tools\simulate_matches.py 1 hell` 통과: duration=63.5s, stage=2.

---

## Compact Recent History

| Slice | Summary |
|---|---|
| v1.11.32 | Pressure mission descriptions generate from pressure `conditions[]`. |
| v1.11.31 | Bonus mission descriptions and selected HUD/evaluation thresholds now bind to mission data/tuning. |
| v1.11.30 | Mission numeric description audit selected the bonus-description formatter as the next drift fix. |
| v1.11.29 | Pickup pass closure documented retained pickup runtime/collection responsibilities. |
| v1.11.24 | Bot pass closure documented retained AI/runtime responsibilities. |
| v1.11.19 | Player pass closure documented retained movement/combat/HUD runtime responsibilities. |
| v1.11.12 | Mission subsystem closure documented mission state vs helper ownership. |
| v1.10.20 | Main-owned data/catalog/presentation cleanup marked structurally closed. |

Detailed version summaries are in [devlog/INDEX.md](devlog/INDEX.md).
