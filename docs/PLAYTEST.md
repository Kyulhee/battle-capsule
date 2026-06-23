# Playtest Notes

> Last updated: 2026-06-24. This file catches what telemetry cannot. Keep entries short and actionable.

## Current Manual Test Target

| Item | Value |
|---|---|
| Build surface | `mapSpec_night_forest_candidate.json` |
| Preferred preset | `visual_review` for manual feel; `playable_pacing_v2` for automated pacing |
| Current focus | Night readability, opening pressure, first non-pistol access, stage2-to-stage3 transition |

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

## Notes

- Do not use `xlarge_60` or `target_99_probe` for visual feel. Those are structural load tests.
- A telemetry PASS is not a playtest PASS.
- A single manual note can override a numeric candidate if the game feel is clearly worse.
