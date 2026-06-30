# 변경 영향 맵

> 최종 업데이트: 2026-06-30. 코드 변경 전 영향 범위를 빠르게 확인하기 위한 문서다.

## 빠른 판단표

| 바꾸는 것 | 같이 확인할 것 | 기본 검증 |
|---|---|---|
| `Bot.gd` opening/perception/combat | `BotDoctrine`, `BotTuning`, telemetry, opening tests | `unit_smoke`, 필요 시 `pacing_candidate` |
| `Player.gd` 체력/무기/아티팩트 | `WeaponSlotManager`, artifact runtime/visuals, HUD | 관련 `verify_artifact_*`, 1-run |
| `Main.gd` orchestration | match tuning, zone, loot, UI wiring | `unit_smoke`, 1-run 이상 |
| `Telemetry.gd` | analyzer/summarizer/check scripts | `tooling`, `verify_pacing_telemetry` |
| `data/mapSpec_*` | map verifiers, scale gates, minimap/full map | map verifier + simulation |
| `data/game_config.json` | match/runtime/hell/mission tuning | relevant smoke + sim |
| `data/asset_catalog.json` | `AssetCatalog`, UI/world fallback | Godot headless quit + visual check |
| UI builder | screenshot state, text fit, panel flow | `docs_only` + UI screenshot |
| Docs only | links, markdown whitespace | `docs_only` |

## 큰 파일 정책

| 파일 | 정책 |
|---|---|
| `Main.gd` | orchestration 소유. 한 번에 대규모 분해 금지 |
| `Bot.gd` | slice가 AI behavior를 직접 건드릴 때만 추출 고려 |
| `Player.gd` | artifact/weapon/health 변경 시 wrapper 경계 유지 |
| `Telemetry.gd` | schema 변경 시 Python 분석 도구를 같이 갱신 |

## Gameplay 변경 안전망

- smoke 하나로 닫지 않는다.
- phase gap을 보고 어떤 milestone을 건드렸는지 판단한다.
- first contact, first kill, first upgrade, stage2, stage3, match end를 분리해서 읽는다.
- duration이 짧아졌다면 opening 지연이 좋아 보여도 후보를 의심한다.
- no first upgrade가 나오면 gate를 낮추지 말고 source/economy를 확인한다.

## 문서 변경 안전망

- 기본 문서는 한글로 유지한다.
- 긴 실험 출력은 붙이지 않는다.
- 실패 패턴은 `EXPERIMENTS.md`에 한 줄로 남긴다.
- 다음 행동은 `CURRENT.md`에만 남긴다.
