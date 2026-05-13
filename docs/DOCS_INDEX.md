# Documentation Index

> Last updated: 2026-05-13. This file defines the default reading path so agents and humans do not need to load every long document.

## Read First

| Document | Role | Default? |
|---|---|---|
| [../CLAUDE.md](../CLAUDE.md) | Session onboarding and current operating rules | Yes |
| [HANDOFF.md](HANDOFF.md) | Short next-session context and local git notes | Yes |
| [MASTERPLAN.md](MASTERPLAN.md) | Current roadmap, scope, non-goals, next candidates | Yes |
| [DEVLOG.md](DEVLOG.md) | Short active log for recent verified work | Yes, after work |
| [IMPACT_MAP.md](IMPACT_MAP.md) | Ownership and change-impact map | Yes, before code changes |
| [ARCHITECTURE.md](ARCHITECTURE.md) | Module boundaries and dependency structure | Structural changes only |
| [TESTING.md](TESTING.md) | Verification commands and interpretation | Verification only |

## Asset Work

| Document | Role |
|---|---|
| [ASSET_BRIEF.md](ASSET_BRIEF.md) | Stable visual/audio style and file-format reference |

The generated workspace [../asset_generator/expected_output](../asset_generator/expected_output) is a source pool, not runtime content. Only selected files should be normalized into `assets/` and registered through `data/asset_catalog.json`.

`docs/ASSET_GENERATION_PROMPTS.md` may exist locally as a copy-ready prompt scratch file, but it is intentionally untracked unless the user asks to publish it.

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
| [archive/IDEA_PLAN_legacy.md](archive/IDEA_PLAN_legacy.md) | Old idea pool and roadmap draft |
| [devlog/DEVLOG_full_2026-05-13.md](devlog/DEVLOG_full_2026-05-13.md) | Previous full devlog |
| [devlog/INDEX.md](devlog/INDEX.md) | Compact version history index |

Open archived documents only when a task requires historical detail that is not present in the active log or current roadmap.
