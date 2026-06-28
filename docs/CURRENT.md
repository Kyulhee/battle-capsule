# Current Tracker

> Last updated: 2026-06-29. This is the default planning surface. Keep it short enough to read before every work slice.

## Big Frame

| Track | State | Goal |
|---|---|---|
| M0 Ops Reset | Supporting | Make the solo-dev workflow fast enough for larger feature decisions |
| M1 First Playable Night BR | Active | A full match loop that feels readable, tense, and playable before final balance |
| M2 Vertical Slice | Planned | One representative Night BR slice with map, night readability, loot, combat, zone, and UI working together |
| M3 Content Stabilization | Later | Tune, polish, and expand after the core loop proves itself |

## Current Slice

| Item | Value |
|---|---|
| Active slice | N2-PACE-31 manual read + opening pressure follow-up |
| Latest verified gameplay slice | N2-PACE-30 initial non-pistol pool candidate |
| Current branch note | Local `master` may have unrelated generated/doc files; check `git status -sb`. Push is approved unless the user revokes it |
| Execution note | Use elevated shell commands when local sandbox fails with `CreateProcessAsUserW failed: 1312` |

## Product Direction

- Build toward a 10-15 minute Night BR prototype, not a pure telemetry exercise.
- Candidate surface remains `data/mapSpec_night_forest_candidate.json` with non-default playable pacing presets.
- Do not promote 99-player defaults, release builds, or full bot flashlight/fear/battery systems without an explicit milestone decision.
- Treat telemetry as structural safety and diagnosis; manual play/readability still decides whether the slice feels like a game.

## Next Work Queue

| Priority | Work | Exit |
|---|---|---|
| P0 | Finish N2-OPS-01 doc routing | Done: tracker docs are the default reading path |
| P1 | Add verification profiles | Done: `tools/run_verify.py --profile ...` covers docs/tooling/unit/pacing/scale/visual gates |
| P2 | Design first-upgrade candidate | Done: N2-PACE-28 `playable_pacing_v3` role multiplier candidate passed, but is diagnostic only |
| P3 | Isolate next upgrade source | Done: N2-PACE-29 source read is initial_loot 66.7% / stage_wave 33.3%, not bot drops |
| P4 | Tune initial/wave non-pistol access | Done: `playable_pacing_v4` 3-run first upgrade 294.9s, missing 0, stage2/stage3 in band |
| P5 | Run manual visual/playtest pass | Done: `visual_review` passed and `PLAYTEST.md` records v4 as needs-iteration for manual promotion |
| P6 | Follow opening pressure | Automated read still has v4 3-run first contact 14.1s / hard-bump 3/3; 1-run visual first contact 10.1s / hard-bump 0/1 |

## Risk Board

| Risk | Signal | Response |
|---|---|---|
| Documentation drag | Active docs exceed their own budgets | Move detail to `EXPERIMENTS` or archive, keep `CURRENT` short |
| Telemetry tunnel vision | Numeric PASS but unclear game feel | Add PLAYTEST notes before accepting major pacing decisions |
| Large-file ownership | `Bot.gd`, `Telemetry.gd`, `Main.gd`, `Player.gd` remain large | Extract only when a slice touches that domain |
| Experiment repetition | Rejected candidates reappear | Check `EXPERIMENTS.md` before new tuning |
| Opening pressure | Pacing v4 fixed upgrade timing but first contact is still early | Do not move zone/economy to solve contact; inspect hard-bump/opening acquisition |
| Asset import noise | Local source pools live under project root | Keep source pools untracked; add `.gdignore` where needed |

## Session Rule

Before starting a new implementation slice, restate this tracker in one or two lines: active milestone, current risk, next exit condition.
