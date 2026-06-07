# Next Chat Handoff

> Last updated: 2026-06-08. Short context only; read `CLAUDE.md`, `DOCS_INDEX.md`, `MASTERPLAN.md`, and `IMPACT_MAP.md` before code changes.

## Current State

- Branch: `master`.
- Latest pushed code slice: `v2.0.40 — opportunistic loot scoring and pistol upgrade tuning`.
- Current planning pivot: v2 scale telemetry is now treated as a **structural safety gate**, not final 99-player balance.
- Current map direction: build one 99-player **Night Artificial Forest** candidate before more behavior tuning.
- Target match length for the intended main game: 10-15 minutes.
- Default map and default scale preset are still not promoted to 99 players.
- `target_99_probe` remains candidate-only.
- Release remains paused unless the user explicitly asks for a release.
- Expected Godot startup warning remains: `AssetCatalog: 7 configured asset paths are missing; fallbacks remain active.`

## Local/Untracked Notes

- `plan_report/` is local reference material for the Night Artificial Forest concept. Do not commit it unless explicitly requested.
- `asset_generator/` is an external source pool. Keep it untracked unless selected files are promoted into runtime assets.
- `docs/ASSET_GENERATION_PROMPTS.md` is local prompt scratch. Keep it untracked unless the user asks to publish it.
- `.gitignore` may have pre-existing local edits; do not revert or stage them unless the user asks.

## Read First

- [MASTERPLAN.md](MASTERPLAN.md): active Korean-first roadmap and current decisions.
- [NIGHT_BR_PACING_PLAN.md](NIGHT_BR_PACING_PLAN.md): 10-15 minute night BR pacing and test layers.
- [MAP_TILE_GROUPS.md](MAP_TILE_GROUPS.md): placement group brief plus Night Artificial Forest POI mapping.
- [ASSET_STATUS.md](ASSET_STATUS.md): current artifact/bush/generated-asset state.
- [IMPACT_MAP.md](IMPACT_MAP.md): ownership and change-impact checks before code edits.

## Recent Relevant Commits

- `5c2d7b3 docs: add 99 map tile group brief` — added `MAP_TILE_GROUPS.md` and linked it from active docs.
- `8333bd3 tune bot opportunistic loot selection` — latest pushed gameplay tuning slice, v2.0.40.
- `178f505 feat: add loot objective context diagnostics` — diagnostic context before the v2.0.40 tuning pass.

Older v2.0 telemetry detail is in [DEVLOG.md](DEVLOG.md), [archive/MASTERPLAN_full_2026-06-08.md](archive/MASTERPLAN_full_2026-06-08.md), and `docs/devlog/`.

## Next Work

1. Create a first Night Artificial Forest 99-player candidate `mapSpec`.
   - Use `Sluice Crossing` as the primary rotation conflict.
   - Keep `Black Ridge` strong but contestable.
   - Keep `False Clinic` as recovery with risky re-entry.
   - Start `Wire Maze` with sparse obstacles and wide gates to control stuck risk.
2. Run current scale tooling as structural checks only.
   - Do not tune combat/CHASE percentages as final design targets yet.
   - Keep fallback 0, clearance, route/POI coverage, stuck, disengage, zone escape, and AI cost visible.
3. Add POI-level mini probes before trying to judge the whole 99-player experience.
   - Priority probes: `Sluice Crossing`, `Wire Maze`, `Black Ridge`, `Supply Flats`, `False Clinic`.
4. Prototype night vision carefully.
   - Start with player-facing flashlight and reveal/readability.
   - Bots should first use abstract night awareness, not full flashlight/battery/fear state.
5. Build a separate 10-15 minute pacing gate after the map and first night-vision pass exist.

## Verification Reminders

Docs-only work:

- `git diff --check`

Candidate map work:

- `tools/verify_strategic_flow_map.gd`
- `tools/verify_candidate_99_probe.gd`
- fresh 5-run `xlarge_60`
- fresh 5-run `target_99_probe`
- `tools/compare_scale_profiles.py`
- `tools/check_scale_telemetry.py`

## Guardrails

- Do not promote the 99-player candidate to default/global runtime without an explicit decision.
- Do not add full bot flashlight, battery, fear, blackout, fire spread, interior cabin, or watchtower climb systems in the first map candidate.
- Keep `Main.gd` as match-global orchestrator.
- Keep bush gameplay authority in `Bush.tscn`; visual GLB bush replacement is cosmetic.
- For asset generation, keep stable style/format rules in [ASSET_BRIEF.md](ASSET_BRIEF.md) and local prompt scratch out of commits.
