# Battle Capsule Active Devlog

> Last updated: 2026-06-03. Compressed recent work log. Full historical detail is preserved in `docs/devlog/` and `docs/archive/`.

Do not load full snapshots by default. Use `docs/devlog/INDEX.md` and per-version summaries unless exact history is needed.

---

## v2.0.26 — CHASE Context / Encounter Spacing Probe

**Scope**

- Added persisted doctrine telemetry `chase_context_time_by_archetype`.
- `Bot.gd` now tags `CHASE` time as `combat`, `loot`, `recover_loot`, or `unknown`.
- Extended `tools/analyze_results.py` and `tools/compare_scale_profiles.py` with CHASE context mix output.
- Ran fresh 5-run candidate sets:
  - `C:\tmp\game_dev_chase_candidate_60`
  - `C:\tmp\game_dev_chase_candidate_99`
- Kept gameplay unchanged; this slice is diagnostics only.

**Verification**

- `python -m py_compile tools\compare_scale_profiles.py tools\simulate_matches.py tools\analyze_results.py tools\check_scale_telemetry.py` passed.
- `git diff --check` passed.
- Both fresh 5-run sets passed `check_scale_telemetry.py`.
- Fresh 99 output: avg duration 141.5s, first upgrade 25.4s, legacy disengage 122.4/run, AI avg 518.6us.
- CHASE context mix:
  - `xlarge_60`: combat 50.0%, loot 29.2%, recover_loot 20.9%.
  - `target_99`: combat 45.2%, loot 30.9%, recover_loot 24.0%.
- Fresh 99 remains throughput-limited: damage/match min +8.6% vs 60 while entities are +64%.

**Decision**

- 99 active coverage is partly leaking into loot/recovery movement; CHASE combat share is lower and loot+recover CHASE is the majority.
- Per-ATTACK efficiency remains intact, so do not tune damage first.
- Next slice should inspect objective interrupts, recovery-loot path length, and pickup spacing before zone pacing or retreat thresholds.

---

## v2.0.25 — 99 Combat Throughput / Engagement Density Diagnosis

**Scope**

- Extended `tools/compare_scale_profiles.py` with engagement-density diagnostics:
  - damage/shots/plans per match minute.
  - damage/shots per `ATTACK` minute.
  - engage samples per spawned entity/minute.
  - combined `ATTACK+CHASE` and `DISENGAGE+ZONE_ESCAPE` state share.
  - `Engagement density decision` summary.
- Extended `tools/analyze_results.py` with the same single-directory engagement-density rows.
- Kept gameplay unchanged; this slice is diagnostics only.

**Verification**

- `python -m py_compile tools\compare_scale_profiles.py tools\simulate_matches.py tools\analyze_results.py tools\check_scale_telemetry.py` passed.
- `git diff --check` passed.
- Compared fresh `xlarge_60` vs adjusted `target_99_loot_v3`:
  - Entities: 61 -> 100 (+64%).
  - Damage/match min: 2238.3 -> 2402.1 (+7%).
  - Shots/match min: 273.3 -> 296.5 (+8%).
  - Plans/match min: 169.5 -> 172.0 (+1%).
  - Damage/ATTACK min: 770.5 -> 819.3.
  - Shots/ATTACK min: 94.1 -> 101.1.
  - `ATTACK+CHASE`: 41.32% -> 37.67%; `RETREAT+ESCAPE`: 44.13% -> 48.79%.

**Decision**

- Combat throughput is not scaling with population, even after the economy fix.
- ATTACK-state efficiency is intact, so the bottleneck is not per-attack lethality.
- Next work should inspect target acquisition, chase routing, and encounter spacing before zone pacing, damage, or bot retreat thresholds.

---

## v2.0.24 — Candidate-Only 99-Probe Loot/Economy Adjustment

**Scope**

- Added runtime loot `rare_bias_mult` support with default `1.0`.
- Wired `rare_bias_mult` into `LootSpawner` so hotspot rare bias can be scaled by runtime preset.
- Applied candidate-only `target_99_probe` economy tuning:
  - `hotspot_density_mult`: 1.12 -> 1.16.
  - `rare_bias_mult`: 1.45.
  - Kept raw `loot_count` at 240 and `stage_wave_count_mult` at 9 after a broader v2 attempt improved pickups but worsened duration/combat throughput.
- Updated `verify_candidate_99_probe.gd` to guard the new economy probe knobs.

**Verification**

- `verify_candidate_99_probe.gd`, `verify_large_map_candidate.gd`, and `verify_map_runtime_path.gd` passed.
- Adjusted 99 v3 5-run set at `C:\tmp\game_dev_candidate_99_loot_v3` passed `check_scale_telemetry.py`.
- v3 vs previous 99: first upgrade 27.4s -> 16.6s, non-pistol pickups/entity/min 0.04 -> 0.07, rare pickups/entity/min 0.06 -> 0.10, DISENGAGE state 21.84% -> 21.16%.
- v3 vs 60: first upgrade gap narrowed to +3.75s, but damage/entity/min (-12.67), shots/entity/min (-1.51), plans/entity/min (-1.06), and duration (+42.7s) remain poor.

**Decision**

- Keep the narrow v3 candidate economy adjustment; it fixes upgrade timing without worsening the scale gate.
- Do not increase raw loot/wave volume broadly yet; the discarded v2 attempt improved pickups but stretched duration and reduced combat throughput.
- Next slice should diagnose 99 combat throughput/engagement density before zone pacing or bot-threshold tuning.

---

## v2.0.23 — 99-Probe Economy/Combat Tempo Diagnosis

**Scope**

- Extended `tools/compare_scale_profiles.py` with economy-normalized tempo rows and a `Tempo decision` summary.
- Extended `tools/analyze_results.py` with economy-normalized per spawned entity/minute output.
- Reused the fresh v2.0.22 candidate sets; no gameplay data was changed.

**Verification**

- `python -m py_compile tools\compare_scale_profiles.py tools\simulate_matches.py tools\analyze_results.py tools\check_scale_telemetry.py` passed.
- `git diff --check` passed.
- `compare_scale_profiles.py` on the fresh 60-vs-99 candidate sets reports:
  - weapon pickups/entity/min 0.54 -> 0.39 (-0.15).
  - non-pistol pickups/entity/min 0.11 -> 0.04 (-0.07).
  - rare pickups/entity/min 0.18 -> 0.06 (-0.12).
  - damage, shots, and plans all fall per entity/min.
- `analyze_results.py` now prints economy-normalized rows for single run directories.

**Decision**

- The 99-probe tempo issue is economy plus combat throughput dilution.
- Raw loot count is not the only target: `target_99_probe` already has 240 loot for 100 entities, close to `xlarge_60` density, but real non-pistol and rare pickup rates are lower.
- Next tuning should be candidate-only and focus on non-pistol/rare access through loot hotspot density, wave mix, or POI distribution before changing zone pacing or bot behavior thresholds.

---

## v2.0.22 — Reason-Aware 60-vs-99 Candidate Comparison

**Scope**

- Ran fresh 5-run candidate-map sets with persisted DISENGAGE reason telemetry:
  - `C:\tmp\game_dev_reason_candidate_60` using `xlarge_60`.
  - `C:\tmp\game_dev_reason_candidate_99` using `target_99_probe`.
- Compared the sets with `tools/compare_scale_profiles.py`.
- Kept gameplay unchanged; this slice is telemetry analysis only.

**Verification**

- `check_scale_telemetry.py` passed on both fresh 5-run sets.
- `xlarge_60`: avg duration 106.3s, first upgrade 12.8s, fallback 0.0/run, min nearest 3.6m, AI avg 361.8us.
- `target_99_probe`: avg duration 148.0s, first upgrade 27.4s, fallback 0.0/run, min nearest 3.6m, AI avg 504.3us.
- 99-vs-60 deltas: duration +41.8s, first upgrade +14.5s, damage/entity/min -11.63, shots/entity/min -1.42, plans/entity/min -0.99, DISENGAGE state +4.25pp.
- Reason-aware deltas: DISENGAGE entries/entity/min -1.20, survival_break -0.97, outnumbered -0.21, `DISENGAGE sec/entry` +0.25.

**Decision**

- DISENGAGE pressure is not caused by higher entry frequency or a single overactive reason.
- The stronger signal is 99-probe tempo dilution: slower first upgrade, lower combat rate, lower plan rate, and longer matches.
- Do not tune DISENGAGE thresholds yet.
- Next slice should diagnose 99-probe economy/combat tempo before changing zone pacing, spawn/POI density, or bot behavior thresholds.

---

## v2.0.21 — Persisted DISENGAGE Reason Telemetry

**Scope**

- Added persisted `tactics.disengage_entries`, `tactics.disengage_reasons`, and `tactics.disengage_reasons_by_archetype`.
- Instrumented DISENGAGE entry reasons: `outnumbered`, `losing_fight`, `reload_retreat`, `sniper_min_range`, `attack_timeout`, and `survival_break`.
- Preserved existing `disengage_triggered` gate semantics as the outnumbered/legacy trigger metric; full entry volume is now reported separately as `disengage_entries`.
- Extended `tools/analyze_results.py` and `tools/compare_scale_profiles.py` with reason-aware output.
- Kept gameplay unchanged; this slice is instrumentation and reporting only.

**Verification**

- `python -m py_compile tools\compare_scale_profiles.py tools\simulate_matches.py tools\analyze_results.py tools\check_scale_telemetry.py` passed.
- 1-run candidate-map smoke passed with `xlarge_60` and wrote persisted DISENGAGE reason data to `C:\tmp\game_dev_disengage_reason_smoke`.
- `python tools\check_scale_telemetry.py C:\tmp\game_dev_disengage_reason_smoke --min-runs 1` passed.
- `compare_scale_profiles.py` prints `disengage entries/entity/min`, `DISENGAGE sec/entry`, and reason rates when reason telemetry is present.

**Decision**

- Do not tune behavior yet.
- Next slice should rerun candidate `xlarge_60` and `target_99_probe` 5-run sets, then compare reason-aware DISENGAGE deltas before changing zone, spawn, or bot thresholds.

---

## v2.0.20 — 99-Probe Pressure Decision

**Scope**

- Extended `tools/compare_scale_profiles.py` with `DISENGAGE sec/trigger` and a pressure-decision summary.
- The comparison now distinguishes spawn/pathing, AI budget, DISENGAGE trigger frequency, DISENGAGE duration/exit pressure, and ZONE_ESCAPE pressure.
- Reviewed current bot state flow: DISENGAGE can be entered by outnumbered scans, losing fights, reload retreats, sniper min-range retreats, attack timeouts, and survival breaks, but current telemetry only persists part of those reasons.
- Kept gameplay unchanged; this slice is a decision/tooling pass.

**Verification**

- `python -m py_compile tools\compare_scale_profiles.py tools\simulate_matches.py tools\analyze_results.py tools\check_scale_telemetry.py` passed.
- `compare_scale_profiles.py` passed on `C:\tmp\game_dev_candidate_60` vs `C:\tmp\game_dev_candidate_99`.
- The pressure decision reports spawn/pathing and AI are not current blockers.
- It classifies 99 DISENGAGE pressure as duration/exit-related rather than trigger-frequency-related, because DISENGAGE state share rose while normalized trigger rate did not.
- It classifies ZONE_ESCAPE as a secondary review item because state share rose mildly without higher normalized zone-fire.

**Decision**

- Do not tune zone timings, spawn density, or outnumbered thresholds yet.
- Next slice should add persisted DISENGAGE reason telemetry so the 99 pressure can be attributed before behavior changes.

---

## v2.0.19 — Normalized 60-vs-99 Candidate Comparison

**Scope**

- Added `out_dir=` / `sim_out_dir=` support to `tools/simulate_matches.py` so scale comparison runs can be kept outside the repo.
- Added `tools/compare_scale_profiles.py` to compare two run directories using normalized per spawned entity/minute rates, spawn distribution, AI update cost, and doctrine state mix.
- Kept gameplay data unchanged; this slice is comparison tooling plus a fresh candidate-map 60-vs-99 telemetry pass.

**Verification**

- `python -m py_compile tools\simulate_matches.py tools\compare_scale_profiles.py tools\analyze_results.py tools\check_scale_telemetry.py` passed.
- Candidate `xlarge_60` 5-run set passed the scale gate from `C:\tmp\game_dev_candidate_60`.
- Candidate `target_99_probe` 5-run set passed the scale gate from `C:\tmp\game_dev_candidate_99`.
- `compare_scale_profiles.py` reported 99 vs 60: duration +7.1s, spawn saturation +0.08, AI avg +123.9us, ZONE_ESCAPE +2.14pp, DISENGAGE +5.32pp.

**Decision**

- Spawn and AI budget still look acceptable for the candidate-only 99 probe.
- The main 99-specific pressure is behavioral density: higher DISENGAGE share and slightly higher ZONE_ESCAPE share.
- Do not tune by lowering gates; next work should inspect whether zone profile, spawn/POI density, or outnumbered behavior is the right adjustment point.

---

## v2.0.18 — 99-Probe Scale-Normalized Analysis

**Scope**

- Extended `tools/analyze_results.py` with scale-normalized rates per spawned entity/minute.
- Added aggregate doctrine state mix reporting so 60/99 bot runs can compare state pressure without relying only on raw event counts.
- Kept this as telemetry analysis only; no gameplay tuning, default map switch, or 99-player global promotion was made.

**Verification**

- `python -m py_compile tools\analyze_results.py` passed.
- `python tools\analyze_results.py tools\sim_runs_current` passed on the current 99-probe run set.
- Current 99-probe normalized output: damage=27.7, shots=3.35, plans=1.83, disengage=0.56, stuck=0.11, zone_fire=1.02, survival=1.24 per spawned entity/min.
- Current 99-probe state mix: ZONE_ESCAPE 26.0%, DISENGAGE 22.0%, CHASE 19.2%, ATTACK 18.9%, IDLE 14.0%.

**Decision**

- The 99-probe pass is not enough to promote the preset; zone escape and disengage state share are now the first explicit review targets.
- The next slice should compare candidate `xlarge_60` and `target_99_probe` with the same normalized analyzer before changing gameplay numbers.

---

## v2.0.17 — Guarded 99-Target Candidate Probe

**Scope**

- Added `target_99_probe` only to `data/mapSpec_large_candidate.json`; the default map still has no 99-player runtime preset.
- Kept `target_99` as a `scale_envelope`, not a runtime `scale_preset`.
- The probe uses 99 bots, 240 loot, 78m spawn radius, 180 safe spawn attempts, and slower early zone pacing on the 180m candidate map.
- Added `tools/verify_candidate_99_probe.gd` to assert the probe is candidate-only, validates against the preferred `target_99` envelope, and is absent from the default map.

**Verification**

- `verify_candidate_99_probe.gd`, `verify_large_map_candidate.gd`, `verify_map_definition.gd`, and `verify_map_runtime_path.gd` passed.
- 5-run candidate-map `target_99_probe` simulation passed: avg duration 129.4s, no runs under 60s, no zero damage/shot/plan sentinels.
- Existing scale gate passed: fallback=0.0/run, min nearest=3.5m, avg nearest=7.7m, saturation=0.20, AI avg=439.9us.

**Decision**

- 99 bots are now technically smokeable on the non-default candidate path.
- Do not promote this to the default map or global 99-player tuning yet; the next slice should analyze 99-probe pacing, zone escape volume, and engagement density before broader promotion.

---

## v2.0.16 — Candidate Map Runtime Loading Smoke

**Scope**

- Added `map_spec_path` as a safe CLI/test override in `Main.gd`; the exported default remains `res://data/mapSpec_example.json`.
- Added `map_spec_path`, `map_spec`, `map_definition_path`, and `map_definition` command-line aliases through `MatchTuning.gd`.
- Preserved raw command-line value casing for resource paths so mixed-case filenames like `mapSpec_large_candidate.json` load reliably.
- Added `tools/verify_map_runtime_path.gd` to pin CLI path parsing, candidate definition loading, and `xlarge_60` preset resolution.

**Verification**

- `verify_map_runtime_path.gd` passed.
- Godot headless load with `map_spec_path=res://data/mapSpec_large_candidate.json scale_preset=xlarge_60` loaded `Mountain Forest Alpha Large Candidate`.
- 5-run candidate-map `xlarge_60` simulation passed: avg duration 99.7s, no runs under 60s, no zero damage/shot/plan sentinels.
- Candidate-map scale gate passed: fallback=0.0/run, min nearest=3.5m, avg nearest=9.6m, saturation=0.12, AI avg=311.8us.

**Decision**

- The larger candidate is now runtime-smokable without becoming the default map.
- The next slice can consider a guarded 99-target probe on the candidate path only; do not switch the default map or promote 99-player tuning globally.

---

## v2.0.15 — Non-Default Large Map Candidate

**Scope**

- Added `data/mapSpec_large_candidate.json` as a separate 180m forest candidate map; `Main.gd` still loads the current default map.
- Kept `target_99` as a `scale_envelope`, not a runtime `scale_preset`; the candidate exposes only `baseline` and `xlarge_60` presets.
- Set the candidate `xlarge_60` test surface to 60 bots, 150 loot, 78m spawn radius, 120 safe spawn attempts, and a slower early zone curve.
- Expanded candidate authored data to 11 POIs and 35 obstacles so target-envelope validation is tied to a concrete map spec instead of only abstract math.
- Added `tools/verify_large_map_candidate.gd` to validate the candidate, verify it satisfies the `target_99` preferred world/spawn envelope, and keep `target_99` out of runtime presets.

**Verification**

- `verify_large_map_candidate.gd` passed: `xlarge_60` world=180m, spawn=78m, boundary margin=8.5m, target_99 preferred saturation=0.20.
- `verify_map_definition.gd` and `verify_scale_envelope.gd` passed.
- Godot headless project load passed with the expected AssetCatalog fallback warning only.
- `git diff --check` passed.

**Decision**

- This is still scale-backbone work, not a playable 99-player expansion.
- The next slice should add a safe candidate-map runtime loading/smoke path before any 99-player preset.

---

## v2.0.14 — Larger-Map Spawn Envelope Prerequisite

**Scope**

- Added definition-owned `scale_envelopes.target_99` as a planning target, not a runtime `scale_preset`.
- Captured 99-bot prerequisites from the 60-bot spawn telemetry: minimum 160m world / 72m spawn radius, preferred 180m world / 78m spawn radius, 8m inner radius, 3.5m entity clearance, and saturation guardrails.
- Added `tools/verify_scale_envelope.gd` to keep `target_99` out of runtime presets and verify the envelope math against current `xlarge_60`.
- Extended `MapDefinition` to load, expose, summarize, and sanity-check `scale_envelopes`.

**Verification**

- `verify_map_definition.gd` passed with `target_99` exposed as an envelope only.
- `verify_scale_envelope.gd` passed: current `xlarge_60` saturation=0.24 / boundary margin=0.5m; `target_99` min=160m world + 72m spawn, preferred=180m world + 78m spawn.

**Decision**

- 99-player tuning remains blocked until a new or rescaled map spec satisfies the `target_99` envelope.
- The next implementation slice should build a non-default larger map candidate or map-rescale prototype before adding a 99-player runtime preset.

---

## v2.0.13 — 60-Bot Spawn Distribution Telemetry

**Scope**

- Added `spawn` telemetry for requested/placed entity count, fallback usage, nearest-spawn distance, average spawn attempts, max attempts, and spawn-annulus saturation.
- `Main.gd` now records fallback spawn positions into `_spawn_positions` so later spawn checks and telemetry include the actual fallback placement.
- Extended `analyze_results.py` and `check_scale_telemetry.py` to report spawn distribution and fail repeated scale runs if fallback spawns appear or nearest spacing drops below the clearance floor.
- Kept this as measurement and gate work; no 99-player preset or larger map was added.

**Verification**

- `python -m py_compile tools\analyze_results.py tools\check_scale_telemetry.py` passed.
- Godot headless project load passed with expected AssetCatalog warning only.
- `python tools\simulate_matches.py 5 normal scale_preset=xlarge_60` passed.
- `python tools\analyze_results.py tools\sim_runs_current` reported avg duration 120.0s, avg zone stage 2.40, no zero damage/shot/plan sentinels, and spawn distribution placed=61/61, fallback=0.0/run, min nearest=3.5m, avg nearest=7.1m, avg attempts=1.5, max attempts=7, saturation=0.24.
- `python tools\check_scale_telemetry.py tools\sim_runs_current` passed with spawn distribution included.

**Decision**

- Current 120m map / 56m spawn radius is technically viable for 60 bots, but minimum spacing is already at the clearance floor.
- Do not add a 99-player preset on the same map envelope; larger scale needs a larger map/spawn envelope plan first.

---

## v2.0.12 — 60-Bot Progressive Zone Pacing

**Scope**

- Made the `xlarge_60` zone curve explicit instead of relying on the baseline stage timings after the first shrink.
- Retuned the 60-bot zone profile so early compression is slower, then stage timings accelerate: first shrink now ends later, stage 2 uses 30s wait / 24s shrink, then later stages step down to 22/18, 14/12, and 10/10.
- Kept this as preset data tuning; no new map size, 99-player preset, or AI LOD behavior was added.

**Verification**

- `verify_map_definition.gd` passed with pinned `xlarge_60` stage overrides.
- `python tools\simulate_matches.py 5 normal scale_preset=xlarge_60` passed.
- `python tools\analyze_results.py tools\sim_runs_current` reported avg duration 103.9s, avg zone stage 2.00, 0 runs under 60s, avg first upgrade 11.8s, no zero damage/shot/plan sentinels, and AI update budget avg=369.8us.
- `python tools\check_scale_telemetry.py tools\sim_runs_current` passed.

---

## v2.0.11 — AI Update Budget Telemetry Probe

**Scope**

- Added sampled bot AI update-budget telemetry: every fourth bot physics update records total elapsed update time by state and archetype.
- Extended saved simulation results with an `ai` group and taught `analyze_results.py` to report aggregate average/max update cost plus the highest-cost states.
- Extended the 60-bot repeated telemetry gate to print AI update budget and fail only on loose guardrail thresholds when AI samples are present.
- Kept this as instrumentation/backbone work; no AI LOD behavior or 99-player preset was added.

**Verification**

- `python -m py_compile tools\analyze_results.py tools\check_scale_telemetry.py` passed.
- Godot headless project load passed with expected AssetCatalog warning only.
- `verify_map_definition.gd` passed.
- `python tools\simulate_matches.py 5 normal scale_preset=xlarge_60` passed.
- `python tools\analyze_results.py tools\sim_runs_current` reported avg duration 97.3s, 0 runs under 60s, avg first upgrade 12.6s, and AI update budget samples=25210, avg=363.3us, max=28459us.
- `python tools\check_scale_telemetry.py tools\sim_runs_current` passed with AI update budget included.

---

## v2.0.10 — 60-Bot Distribution Tuning And Telemetry Gate

**Scope**

- Retuned `xlarge_60` as the active 60-bot test surface: 120 loot, 1.05 hotspot density multiplier, 0.08/0.08 stage loot wave probabilities, 6x stage wave count multiplier, and 30s initial zone timer.
- Added `tools/check_scale_telemetry.py` to fail repeated scale runs on zero combat sentinels, short duration, too-fast/too-slow first upgrade, excessive recover deaths, stuck volume, or disengage volume.
- Kept 99-player tuning blocked; this slice tightens the 60-bot gate instead of adding a larger preset.

**Verification**

- `verify_map_definition.gd` passed.
- `python tools\simulate_matches.py 5 normal scale_preset=xlarge_60` passed.
- `python tools\analyze_results.py tools\sim_runs_current` reported avg duration 100.2s, 0 runs under 60s, avg first upgrade 11.1s, and no zero-damage/shot/plan sentinels.
- `python tools\check_scale_telemetry.py tools\sim_runs_current` passed.
- Godot headless project load passed with expected AssetCatalog warning only.
- `python tools\simulate_matches.py 1 normal` passed.

---

## v2.0.9 — 60-Bot Telemetry Repeat And Scale Decision

**Scope**

- Ran 5 repeated `scale_preset=xlarge_60` normal simulations and analyzed the current telemetry summary.
- Recorded the scale decision: 60 bots has no combat/perception regression sentinel, but 99-player tuning remains blocked until spawn/loot distribution and scale telemetry gates are tightened.

**Telemetry**

- Runs: 5; avg duration 93.2s, min/max 75.2s / 131.6s, avg zone stage 2.60, runs under 60s: 0.
- Regression sentinels: zero damage, zero weapon damage, zero shot, and zero combat plan all `none`.
- Recover success: 230/527 (43.6%); died in RECOVER: 1 total.
- Avg disengage triggers: 100.4; avg stuck triggers: 44.2; avg combat plans cover/reposition/kite: 147.2 / 128.0 / 4.2.
- Avg first upgrade: 9.5s, which is too fast for the current scale target and points to loot/spawn distribution work before 99-player tuning.

**Decision**

- Do not add a 99-player preset yet.
- Next slice should keep `xlarge_60` as the test surface and add distribution/telemetry gates before any larger scale preset.

---

## v2.0.8 — Conservative 60-Bot Scale Feasibility

**Scope**

- Added `xlarge_60` to `data/mapSpec_example.json` as a bounded 60-bot scale preset.
- The preset keeps spawn radius at 56m inside the current 120m world bounds, raises safe spawn attempts to 80, and uses 144 loot with a 1.15 hotspot density multiplier.
- `tools/verify_map_definition.gd` now pins the `xlarge_60` match, runtime spawn/loot, and zone overrides.

**Verification**

- `verify_map_definition.gd` passed.
- Godot headless project load passed with expected AssetCatalog warning only.
- `python tools\simulate_matches.py 1 normal scale_preset=xlarge_60` passed with 60-bot distribution.
- `python tools\simulate_matches.py 1 normal` passed.

---

## v2.0.7 — MapDefinition Position Query Compatibility

**Scope**

- Added `MapDefinition` query helpers for world size/bounds, world-position bounds checks, clamping, bounds UV conversion, and world-distance scaling.
- Added defensive POI and obstacle descriptor accessors so map UI can consume validated definition data without hand-parsing raw `MapSpec` dictionaries.
- `FullMapOverlay` and `Minimap` now accept the active `MapDefinition` and prefer its query/descriptor APIs while preserving `MapSpec` fallback behavior.

**Verification**

- `verify_map_definition.gd` passed with position query and descriptor copy checks.
- `verify_full_map_overlay.gd` passed.
- Godot headless project load passed with expected AssetCatalog warning only.

---

## v2.0.6 — Conservative 40-Bot Scale Preset Smoke

**Scope**

- Added `large_40` to `data/mapSpec_example.json` as the next validated scale preset after `medium_24`.
- The preset keeps spawn radius inside the current world bounds and nudges loot density / zone timing conservatively instead of jumping toward 99-player tuning.
- `tools/verify_map_definition.gd` now pins the `large_40` match, runtime loot, and zone overrides.

**Verification**

- `verify_map_definition.gd` passed.
- Godot headless project load passed with expected AssetCatalog warning only.
- `python tools\simulate_matches.py 1 normal scale_preset=large_40` passed with 40-bot distribution.

---

## v2.0.5 — SettingsManager Boundary Extraction

**Scope**

- Added `src/core/SettingsManager.gd` to own `user://settings.cfg` load/save, master volume application, fullscreen state, clamping, and runtime sync.
- `Main.gd` now keeps only settings panel callbacks and delegates persistence/audio/display mutation to `SettingsManager`.
- Added `tools/verify_settings_manager.gd` for save/load, clamp, fullscreen state, and missing-file fallback smoke coverage.

**Verification**

- `verify_settings_manager.gd` passed.
- Godot headless project load passed with expected AssetCatalog warning only.
- `python tools\simulate_matches.py 1 normal` passed.

---

## v2.0.4 — MapDefinition Validation Expansion

**Scope**

- Expanded `MapDefinition.validate()` for POI item density / rare-bias sanity, oversized POI radii, rotated obstacle footprint bounds, spawn radius versus runtime spawn clearance, loot density coverage, and implicit zone radius sanity.
- `MapDefinition.summary()` now reports loot hotspot count and the resolved zone initial radius.
- Scale presets now accept legacy flat match keys as a compatibility fallback while still preferring nested `match` sections.
- `tools/verify_map_definition.gd` now includes a negative validation probe for POI, obstacle, spawn, and zone profile failures.

**Verification**

- `verify_map_definition.gd` passed.

---

## v2.0.3 — Read-Only Full Map UI Foundation

**Scope**

- Added `src/ui/FullMapOverlay.gd`, a presentation-only full-screen map overlay for world bounds, POIs, generated obstacle footprints, current/next zone, player facing, and supply marker state.
- `Main.gd` now syncs map UI data through `_sync_map_views()` and toggles the Full Map overlay with `M`; `ESC` closes the overlay before pause.
- The overlay reuses `MapDefinition`, wrapped `MapSpec`, and `WorldBuilder.get_minimap_features()` data without owning match decisions.
- Added `tools/verify_full_map_overlay.gd` to pin layout bounds, world-to-map projection, generated feature ingestion, and runtime marker state.

**Verification**

- `verify_full_map_overlay.gd` passed.
- `verify_map_definition.gd` passed.
- Godot headless project load passed with expected AssetCatalog warning only.

---

## v2.0.2 — Definition-Driven Scale Preset Merge

**Scope**

- Added baseline match/runtime/zone values and `baseline` / `medium_24` scale presets to `data/mapSpec_example.json`.
- `Main.gd` now loads `MapDefinition` before world generation and applies the selected scale preset into bot count, loot count, spawn radius, zone timing, zone stages, and runtime tuning.
- `MatchRuntimeTuning.gd` and `LootSpawner.gd` now support `hotspot_density_mult` for preset-driven POI loot density scaling.
- `MatchTuning.gd` accepts `scale_preset` / `map_scale_preset` command-line args for smoke scale runs.
- `tools/verify_map_definition.gd` now verifies preset match overrides and runtime loot density overrides.

**Verification**

- `verify_map_definition.gd` passed.
- Godot headless project load passed with expected AssetCatalog warning only.
- `python tools\simulate_matches.py 1 normal` passed with baseline 11-bot distribution.
- `python tools\simulate_matches.py 1 normal scale_preset=medium_24` passed with 24-bot distribution.

---

## v2.0.1 — MapDefinition Compatibility Loader

**Scope**

- Added `src/core/MapDefinition.gd` as a compatibility wrapper over current MapSpec JSON.
- The wrapper owns map id/name, source path, MapSpec reference, match/runtime/zone overrides, scale presets, summary data, and validation.
- Added `tools/verify_map_definition.gd` to validate legacy MapSpec wrapping and wrapper-format match overrides.
- Updated architecture/impact docs so future map/full-map work checks `MapDefinition` first while runtime call sites still consume `MapSpec`.

**Verification**

- `verify_map_definition.gd` passed: `mountain_forest_alpha`, 7 POIs, 35 obstacles, wrapper bot override 24.
- Godot headless project load passed with expected AssetCatalog warning only.
- `python tools\simulate_matches.py 1 normal` passed.

---

## v1.12.11 — Artifact Icon Completion

**Scope**

- Promoted generated Escape Capsule and Ghost Grass PNGs into normalized runtime artifact icons.
- Added catalog paths for all six starting artifact icons.
- Extended `tools/sync_generated_icons.ps1` with exact-destination filtering for targeted icon promotion.
- Strengthened `tools/verify_artifact_selection_layout.gd` so each starting artifact must have a real catalog icon path, not only a procedural fallback texture.
- GLB bush visuals now animate nearest mesh clumps on enter/exit/movement instead of swaying the entire `CatalogPropVisual` root.
- Added `docs/ASSET_STATUS.md` as the concise asset-state handoff for integrated, generated, and deferred assets.
- Updated roadmap toward `v2.0 MapDefinition + player scale`.

**Verification**

- `git diff --check` passed.
- `verify_artifact_selection_layout.gd` passed: 6 options, 936px row width.
- `verify_bush_interaction.gd` passed.
- `verify_bush_prop_assets.gd` passed.
- Godot headless project load passed with expected AssetCatalog warning only.
- `python tools\simulate_matches.py 1 normal` passed.

---

## v1.12.10 — Bush Asset Integration And Feedback

**Scope**

- Promoted selected generated bush GLBs into runtime assets: `bush_dense.glb` and `bush_low.glb`.
- Added `forest.bush`, `forest.bush.low`, and `forest.bush.dense` prop catalog paths.
- `WorldBuilder` attaches catalog GLB visuals while `Bush.tscn` Area3D remains gameplay/collision authority.
- Raw GLB loading uses `GLTFDocument` when Godot import metadata is absent.
- Restored same-bush visibility semantics and outside-bush concealment behavior.
- Restored player-entry visual feedback through a low-alpha interior tint and per-clump rustle.

**Verification**

- `verify_bush_prop_assets.gd` passed.
- `verify_bush_interaction.gd` passed.
- Godot headless project load passed with expected AssetCatalog warning only.
- Normal match simulation passed.

---

## v1.12.1-v1.12.9 — Complex Artifact Line

- Added Escape Capsule and Ghost Grass as bounded player-runtime artifacts.
- Added `PlayerArtifactRuntime.gd` for one-match trigger/timer state.
- Added artifact Telemetry metrics without changing existing score schema.
- Added `PlayerArtifactVisuals.gd` for player-attached artifact presentation nodes.
- Tuned first-pass visuals for Red Trigger, Armor Sponge, Silent Core, Zone Battery, Escape Capsule, and Ghost Grass.
- Added artifact icon resolution through normalized `artifact.<id>` ids and raw PNG loading.
- Reworked artifact selection into circular options plus one stable detail card.
- Completed balance penalties: Escape Capsule ammo purge, Red Trigger reveal increase, Armor Sponge dynamic speed/heal conversion cap, Silent Core first unrevealed non-knife miss, Ghost Grass cooldown/risk.

Details are in `docs/devlog/v1.12.md`.

---

## v1.11 Closure

- v1.11 is structurally closed as of `v1.11.36`.
- `Main.gd` remains match-global orchestrator and state owner.
- Mission, pressure, loot, supply, Hell, player HUD, bot visual/debug, pickup presentation, and asset/icon lookup now have bounded helper/catalog/tuning owners.
- Future v1.11 reopen should require a concrete boundary bug or stale doc route.

Details are in `docs/devlog/v1.11.md` and `docs/devlog/v1.11_full_2026-05-26.md`.

---

## Next

- `v2.0.11`: add AI update-budget / LOD telemetry at 60-bot scale before any 99-player preset.
- Defer generated tree/rock/log/landmark GLB promotion until map visual upgrade is prioritized.
