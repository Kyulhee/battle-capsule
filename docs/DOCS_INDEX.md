# Documentation Index

> Last updated: 2026-06-08. This file defines the default reading path so agents and humans do not need to load every long document.

## Read First

| Document | Role | Default? |
|---|---|---|
| [../CLAUDE.md](../CLAUDE.md) | Session onboarding and current operating rules | Yes |
| [HANDOFF.md](HANDOFF.md) | Short next-session context and local git notes | Yes |
| [MASTERPLAN.md](MASTERPLAN.md) | Current roadmap, scope, non-goals, next candidates | Yes |
| [DEVLOG.md](DEVLOG.md) | Active log for recent verified work | Update after work; do not load full file for onboarding |
| [IMPACT_MAP.md](IMPACT_MAP.md) | Ownership and change-impact map | Yes, before code changes |
| [ARCHITECTURE.md](ARCHITECTURE.md) | Module boundaries and dependency structure | Structural changes only |
| [TESTING.md](TESTING.md) | Verification commands and interpretation | Verification only |
| [ASSET_STATUS.md](ASSET_STATUS.md) | Integrated/generated/deferred asset state | Asset work only |
| [MAP_TILE_GROUPS.md](MAP_TILE_GROUPS.md) | 99-player map placement-group planning brief | Map/scale planning only |
| [NIGHT_BR_PACING_PLAN.md](NIGHT_BR_PACING_PLAN.md) | 10-15 minute night BR pacing and test strategy | Night/99 pacing planning only |

## Active Document Budgets

These are operating limits for default-session docs, not strict CI rules.

| Document | Target |
|---|---|
| [HANDOFF.md](HANDOFF.md) | 100 lines or less |
| [MASTERPLAN.md](MASTERPLAN.md) | 350 lines or less after v1.11.35 |
| [DEVLOG.md](DEVLOG.md) | 200 lines or less after v1.11.35 |
| Per-version devlogs under `docs/devlog/` | 150 lines or less per active version |
| [ARCHITECTURE.md](ARCHITECTURE.md) / [IMPACT_MAP.md](IMPACT_MAP.md) | Keep as reference docs; open only when relevant |

When a default-session document exceeds its budget, snapshot the full raw content under `docs/devlog/` or `docs/archive/`, then leave only compressed current status, rules, and next actions in the active file.

## Asset Work

| Document | Role |
|---|---|
| [ASSET_BRIEF.md](ASSET_BRIEF.md) | Stable visual/audio style and file-format reference |
| [ASSET_STATUS.md](ASSET_STATUS.md) | Current integrated assets, generated-but-held pools, and deferred asset decisions |

The generated workspace [../asset_generator/expected_output](../asset_generator/expected_output) is a source pool, not runtime content. Only selected files should be normalized into `assets/` and registered through `data/asset_catalog.json`.

`docs/ASSET_GENERATION_PROMPTS.md` may exist locally as a copy-ready prompt scratch file, but it is intentionally untracked unless the user asks to publish it.

## Planning References

| Path | Role |
|---|---|
| [../plan_report](../plan_report) | Local external planning reference for Night Artificial Forest; keep untracked unless explicitly requested |

## Conditional Docs

| Document | Use Only When |
|---|---|
| [UI_DESIGN.md](UI_DESIGN.md) | A UI change needs screenshot-driven visual review |
| [RELEASE.md](RELEASE.md) | A release/build/GitHub release is explicitly requested |

## Archives

These files are preserved for history but excluded from default context:

| Path | Contents |
|---|---|
| [archive/MASTERPLAN_full_2026-05-13.md](archive/MASTERPLAN_full_2026-05-13.md) | Previous long-form master plan |
| [archive/MASTERPLAN_full_2026-05-26.md](archive/MASTERPLAN_full_2026-05-26.md) | Full active roadmap before v1.11.35 compression |
| [archive/MASTERPLAN_full_2026-06-08.md](archive/MASTERPLAN_full_2026-06-08.md) | Full active roadmap before Night Artificial Forest planning compression |
| [archive/IDEA_PLAN_legacy.md](archive/IDEA_PLAN_legacy.md) | Old idea pool and roadmap draft |
| [devlog/DEVLOG_full_2026-05-13.md](devlog/DEVLOG_full_2026-05-13.md) | Previous full devlog |
| [devlog/DEVLOG_full_2026-05-26.md](devlog/DEVLOG_full_2026-05-26.md) | Full active devlog before v1.11.35 compression |
| [devlog/DEVLOG_full_2026-06-08.md](devlog/DEVLOG_full_2026-06-08.md) | Full active devlog before Night Artificial Forest compression |
| [devlog/v1.11_full_2026-05-26.md](devlog/v1.11_full_2026-05-26.md) | Full v1.11 slice summary before v1.11.35 compression |
| [devlog/INDEX.md](devlog/INDEX.md) | Compact version history index |

Open archived documents only when a task requires historical detail that is not present in the active log or current roadmap.
