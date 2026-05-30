# Next Chat Handoff

> Last updated: 2026-05-30. Short context only; read `CLAUDE.md`, `DOCS_INDEX.md`, `MASTERPLAN.md`, and `IMPACT_MAP.md` before code changes.

## Current State

- Branch: `master`.
- Latest completed slice: `v2.0.1 — MapDefinition compatibility loader and validation`.
- Next structural slice: `v2.0.2 — Definition-driven scale preset data merge`.
- Release remains paused. Continue version-to-version development unless the user explicitly asks for a release.
- Expected Godot startup warning remains: `AssetCatalog: 7 configured asset paths are missing; fallbacks remain active.`
- `asset_generator/` is an external source pool and must stay untracked unless selected files are promoted into runtime assets.
- `docs/ASSET_GENERATION_PROMPTS.md` is local prompt scratch and should stay untracked unless the user asks to publish it.
- `docs/ASSET_STATUS.md` is now the concise asset-state handoff document.

## Recent Completed Commits

- `a7c23bf feat: promote remaining artifact icons` — Escape Capsule and Ghost Grass PNGs were normalized, cataloged, and verified as real artifact icon paths.
- `d445692 docs: sync asset and v2 handoff` — compacted handoff/devlog docs and added `ASSET_STATUS.md`.
- Current v2.0.1 slice adds `MapDefinition.gd` and `tools/verify_map_definition.gd`.

Earlier v1.12 work added Emergency Shell/Escape Capsule, Ghost Grass, player artifact runtime state, artifact visuals, compact artifact selection UI, raw PNG icon loading, bush GLB visuals, restored bush interaction semantics, and bush visual feedback. Full recent detail is in `DEVLOG.md` and `devlog/v1.12.md`.

## Recommended Next Slice

`v2.0.2 — Definition-driven scale preset data merge`

- Keep `Main.gd` as match-global orchestrator.
- Preserve the new `MapDefinition` compatibility layer and validation.
- Add definition-owned or scale-preset-owned spawn radius, loot count/density, and zone profile selection while preserving `game_config.json` fallbacks.
- Keep runtime behavior equivalent for the default map until validation covers the new merge path.
- Do not start 99-player tuning until the definition and validation path is stable.

## Asset Notes

- All six starting artifact icons are integrated.
- Bush GLBs are integrated and visual-only; `Bush.tscn` Area3D remains gameplay authority.
- Generated tree/rock/log/landmark GLBs remain deferred. Promote them only as selected runtime assets and preserve explicit collision/cover authority.
- Deferred asset decisions are tracked in `ASSET_STATUS.md`.

## Tooling Note

The Windows shell sandbox may fail with `CreateProcessAsUserW failed: 1312`. If so, retry simple commands with `sandbox_permissions: "require_escalated"`.

## User Preferences

- Use Korean.
- Work in small verified slices: plan -> edit -> verify -> commit/push.
- Keep active docs compact; archive raw/full history.
- Prefer data/tuning/catalog boundaries over broad gameplay rewrites.
