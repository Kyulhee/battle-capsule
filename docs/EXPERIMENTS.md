# Experiments

> Last updated: 2026-06-24. Use this as the repetition guard. Keep each row short.

## Active Reads

| ID | Question | Latest Evidence | Decision |
|---|---|---|---|
| E-001 | Can `playable_pacing_v2` support late-zone pacing? | N2-PACE-25: avg 533.3s, stage2 268.1s, stage3 638.4s, scale gate PASS | Keep v2 as current late-zone candidate |
| E-002 | Can simple global economy cuts delay first upgrade safely? | N2-PACE-26: first upgrade 56.0s, but avg duration 454.1s and stage3 disappeared | Rejected as next lever |
| E-003 | Where does first upgrade happen under v2? | N2-PACE-27: shotgun 100%, concealment_field 66.7% / loot_hub 33.3%, on-route 100% | Target shotgun/non-pistol access in context |
| E-004 | Is hard-bump acquisition immediate combat pressure? | N2-PACE-23 policy: read contact gap, not acquisition alone | Keep exception unless redesigning opening collision |

## Rejected Patterns

| Pattern | Rejection Signal | Do Not Repeat Until |
|---|---|---|
| Global loot_count/hotspot/rare reduction | Delayed first upgrade but regressed duration and stage3 | A targeted context candidate is tested |
| Spawn-spacing-only opening fix | Improved distance but did not solve contact and risked no-upgrade/stuck regressions | A map/nav reason is proven |
| Moving stage2 earlier/later to solve match length | Stage2 is already inside the watch band in playable samples | Late-zone and match-end gap are isolated |
| Lowering structural gates to pass | Gates caught real fallback/stuck/sentinel risks | A new gate definition is approved |

## Experiment Format

When adding a row, use this shape:

```text
E-XXX | question | output path + 3 key metrics | accepted/rejected/needs rerun
```

Do not paste analyzer output here. Keep raw outputs in `C:\tmp` or an archive only when they are intentionally preserved.
