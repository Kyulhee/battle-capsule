# Next Chat Handoff

> Last updated: 2026-05-30. This note is intentionally short and only covers context that is easy to miss from `CLAUDE.md`, `DOCS_INDEX.md`, `MASTERPLAN.md`, and `DEVLOG.md`.

## Current State

- Branch: `master`.
- Current roadmap line: `v1.12-dev` Complex Artifacts, starting with bounded player-runtime effects.
- Latest completed slice: `v1.12.10 — Bush prop asset integration`.
- Next structural slice: `v1.12.11 — Additional prop asset breadth pass`.
- Release remains paused. Continue version-to-version development without GitHub releases unless the user explicitly asks for a release.
- `asset_generator/` is an external-agent workspace and must remain untracked unless the user explicitly asks to integrate selected files.
- `docs/ASSET_GENERATION_PROMPTS.md` is local-only prompt scratch material and must remain untracked unless the user explicitly asks otherwise.
- Expected warning during Godot startup: `AssetCatalog: 7 configured asset paths are missing; fallbacks remain active.`

## Exact Git State At Handoff

After the v1.12.10 push, expected local status is only the external-generation scratch area:

```text
?? asset_generator/
?? docs/ASSET_GENERATION_PROMPTS.md
```

Do not stage `asset_generator/` or `docs/ASSET_GENERATION_PROMPTS.md` unless the user explicitly asks to integrate selected files.

## Recent Completed Commits

- `5365ebf refactor: close pressure snapshot boundary` — closed v1.11 structurally.
- `6f71fc5 docs: plan complex artifact runtime boundary` — opened v1.12 and selected Emergency Shell as the first implementation candidate.
- `1579ff3 feat: add emergency shell artifact` — implemented Emergency Shell, artifact runtime helper, artifact telemetry, and smoke verification.
- `9fb91d2 test: add artifact selection layout smoke` — verified the five-card artifact selection row and shortlisted Ghost Grass next.
- `8cb41a7 feat: add ghost grass artifact` — added Ghost Grass, bush-exit runtime state, telemetry, docs, and smoke coverage.
- `65e0956 feat: add artifact visual identities` — added `PlayerArtifactVisuals.gd`, `visual_id` catalog ids, all six first-pass artifact visuals, and visual smoke coverage.
- `5de2a26 tune artifact visual readability` — added artifact visual gallery capture and tuned Silent Core/Ghost Grass readability.
- `0368d99 integrate artifact icon display` — normalized `artifact.<id>` icon lookup, added artifact images to selection cards, and replaced the in-game artifact text marker with an icon.
- `06feaf2 tune artifact balance penalties` — renamed Emergency Shell presentation to Escape Capsule, added ammo purge, Red Trigger reveal duration, Armor Sponge dynamic speed/capped heal conversion, Silent Core first-shot miss, and Ghost Grass cooldown/risk tuning.
- `ede1b76 compact artifact selection UI` — compacted artifact selection into circular icon options plus one stable detail card.
- `51c4bdd center artifact selection icons` — centered circular artifact option icons with embedded `TextureRect`s; generated source icons currently exist only for Red Trigger, Armor Sponge, Silent Core, and Zone Battery.
- `6b34660 load artifact png icons without import metadata` — added raw PNG fallback loading to `ArtifactIconResolver.gd` and verified four generated artifact icons load as runtime textures.
- `bb05503 feat: integrate bush prop assets` — promoted selected bush GLBs into runtime assets, wired `forest.bush*` catalog paths, added raw GLB loading through `GLTFDocument`, and verified default-map bush visual replacement.

Older v1.11 slice detail is in `docs/devlog/v1.11.md` and the full snapshots under `docs/devlog/`.

## Current Discussion

The user agreed to continue after v1.11 closure. v1.12.1 selected Emergency Shell as the first Complex Artifact. v1.12.2 implemented it. v1.12.3 verified the five-card selection row fits the default viewport and shortlisted Ghost Grass next. v1.12.4 implemented Ghost Grass as a bounded player-runtime artifact. v1.12.5 added artifact visual identity via a separate player visual helper. v1.12.6 added a visual gallery capture tool and tuned Silent Core/Ghost Grass readability. v1.12.7 integrated artifact icons into selection/HUD through `artifact.<id>` catalog lookup. v1.12.8 completed the requested balance pass. v1.12.9 compacted artifact selection into circular icon options with one-line summaries and one stable detail card, patched option icon centering after screenshot review, and then fixed raw PNG loading so the four existing generated artifact images are actually used. v1.12.10 promoted selected bush GLBs into runtime assets and wired them as catalog-driven Bush visuals while preserving Bush Area3D gameplay/collision.

Recommended next slice:

- `v1.12.11 — Additional prop asset breadth pass`
  - Review generated tree, rock, log, and landmark candidates.
  - Integrate only selected runtime assets through `assets/` and `data/asset_catalog.json`.
  - Keep gameplay collision/cover authority explicit instead of trusting imported mesh collision.
  - Keep generated source workspaces untracked.

## Tooling Note

The current Windows shell sandbox has repeatedly failed direct shell execution with:

```text
CreateProcessAsUserW failed: 1312
```

Because of that, even simple reads/status checks have needed `sandbox_permissions: "require_escalated"`. Automatic approval review sometimes times out, especially for parallel escalated calls. Use sequential shell commands, not parallel shell batches, until the session/runner is restarted or the sandbox issue clears.

Good command pattern:

- Run one shell command at a time.
- Prefer simple prefixes: `git status`, `git diff`, `git add`, `git commit`, `git push`, `rg`, `python tools\simulate_matches.py`, Godot headless.
- If an approval review times out, retry the same simple command once before changing approach.

## User Preferences To Preserve

- Use Korean for progress updates and summaries.
- Continue small, verified slices: plan -> edit -> verify -> commit/push -> devlog.
- Prioritize expansion readiness and data/algorithm boundaries before large new gameplay features.
- Keep `Main.gd` as orchestrator and state owner unless there is a dedicated migration plan.
- Avoid duplicated gameplay numbers in UI/descriptions; prefer shared tuning/catalog/formatter boundaries.
- Do not commit local external-generation scratch files unless explicitly requested.

## Good Next Candidates

- `v1.12.11 — Additional prop asset breadth pass`
  - Review generated tree/rock/log/landmark candidates and promote only selected runtime files.
  - Missing artifact PNGs remain `artifact.ghost_grass` and `artifact.emergency_shell`; generate/select them later under the same `artifact.<id>` convention.
- Narrow v1.10.x item/asset readability polish
  - Only visual/readability patches; do not change expansion architecture.
- Later v1.11 candidates:
  - Reopen only for concrete boundary bugs or stale doc routes.
  - Avoid large JSON/resource migration until new mission/content expansion requires it.
