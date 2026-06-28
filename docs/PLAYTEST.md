# Playtest Notes

> Last updated: 2026-06-29. This file catches what telemetry cannot. Keep entries short and actionable.

## Current Manual Test Target

| Item | Value |
|---|---|
| Build surface | `mapSpec_night_forest_candidate.json` |
| Preferred preset | `visual_review` for manual feel; `playable_pacing_v4` for automated pacing |
| Current focus | Night readability, opening pressure, v4 non-pistol upgrade window, stage2-to-stage3 transition |

## Manual Pass Checklist

Use this checklist before accepting a major pacing or readability change:

- Can the player read self position, nearby threats, pickups, and zone direction without UI overload?
- Does the first minute feel tense rather than random or instantly lethal?
- Does the first non-pistol pickup feel earned, visible, and risky?
- Does the map create route decisions rather than only scattered bot collisions?
- Does stage2 create rotation pressure without making stage3 impossible to reach?
- Are deaths understandable from the player's perspective?
- Does performance stay playable in the visual review preset?

## Entry Template

```text
Date:
Surface:
Change under test:
Result: accept / reject / needs iteration
Feel notes:
Action:
```

## Recent Entries

### 2026-06-29 - N2-PACE-31 v4 visual review

Date: 2026-06-29
Surface: `tools/run_verify.py --profile visual_review --out-root C:\tmp\game_dev_N2_PACE_31_visual_review`; capture `C:\tmp\player_night_readability.png`; pacing reference `playable_pacing_v4`.
Change under test: N2-PACE-30 v4 candidate, with initial non-pistol weapons removed from initial loot and stage/supply sources carrying the first upgrade window.
Result: needs iteration.
Feel notes: Player silhouette, pickup labels, and pickup glow are readable in the capture. Nearby bush/terrain silhouettes are still very dark, so route/cover reading likely needs an explicit visual pass before promotion. The 1-run visual sim had first contact 10.1s, first kill 23.4s, first upgrade none, and hard-bump acquisition 0/1; this is not enough to reject v4, but it confirms opening pressure still needs design work.
Action: Keep `playable_pacing_v4` as the automated pacing candidate. Do not promote it as a manual/game-feel baseline until opening pressure is addressed without repeating hard-bump-threshold-only, zone, or broad economy changes.

## Notes

- Do not use `xlarge_60` or `target_99_probe` for visual feel. Those are structural load tests.
- A telemetry PASS is not a playtest PASS.
- `playable_pacing_v4` is the current automated pacing candidate, not a promoted manual baseline.
- A single manual note can override a numeric candidate if the game feel is clearly worse.
