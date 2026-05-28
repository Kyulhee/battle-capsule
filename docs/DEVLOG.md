# Battle Capsule Active Devlog

> Last updated: 2026-05-28. This is the compressed active log. Full pre-compression history is preserved in [devlog/DEVLOG_full_2026-05-26.md](devlog/DEVLOG_full_2026-05-26.md); older full history remains in [devlog/DEVLOG_full_2026-05-13.md](devlog/DEVLOG_full_2026-05-13.md).

Do not load full devlog snapshots by default. Use [devlog/INDEX.md](devlog/INDEX.md) and per-version summaries unless exact historical detail is needed.

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
