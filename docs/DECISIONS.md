# Decisions

> Last updated: 2026-06-24. Stable project decisions live here. Do not turn this into a devlog.

## Locked Until Reopened

| ID | Decision | Reason | Reopen Only If |
|---|---|---|---|
| D-001 | Release work is paused | Current work is v2-dev prototype direction, not packaging | User explicitly requests release/build work |
| D-002 | 99-player default promotion is blocked | Candidate map/pacing still uses non-default test surfaces | M1 First Playable Night BR gate passes |
| D-003 | `target_99_probe` is a structural gate, not a game-feel target | It checks scale safety and regression sentinels | A replacement structural profile exists |
| D-004 | `playable_pacing_v2` is the current late-zone candidate | Stage2/stage3 band improved versus v1 | A new candidate preserves stage2/stage3 and improves match end or upgrade timing |
| D-005 | Simple global loot/hotspot/rare cuts are rejected as the next lever | N2-PACE-26 delayed upgrades but regressed duration/stage3 | A targeted first-upgrade design proves global economy is still the bottleneck |
| D-006 | 1m hard-bump exception remains allowed | It is treated as collision/readability, judged by contact gap | A dedicated opening collision redesign is planned |
| D-007 | Generated source pools stay untracked | `asset_generator/` and `plan_report/` are input/reference pools, not runtime content | User asks to integrate selected assets |
| D-008 | Active docs must optimize next action, not history | Long logs already slowed development | A historical audit explicitly needs full detail |
| D-009 | Role-specific initial weapon multipliers are allowed only as non-default pacing experiments | N2-PACE-28 targeted first-upgrade context without repeating global economy cuts | A promoted candidate needs manual playtest and pacing evidence |
| D-010 | First-upgrade telemetry is game-time, not wall-clock time | N2-PACE-29 found economy first_upgrade used real seconds while other pacing milestones used game seconds | A new canonical time basis is approved |

## Current Design Bias

- Prefer milestone-level decisions over endless micro-slices.
- Prefer a playable vertical loop over more diagnostic fields unless the next decision cannot be made without data.
- Prefer small targeted gameplay candidates over broad global tuning when previous broad tuning regressed another milestone.
- Keep `playable_pacing_v2` as the late-zone reference until a candidate beats it on both pacing evidence and feel.
- Treat old first-upgrade seconds before N2-PACE-29 as suspect for timing, though their weapon/POI/route context can still inform diagnosis.
