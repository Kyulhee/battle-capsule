# 아키텍처 개요

> 최종 업데이트: 2026-07-18. 구조 변경 전 읽는 한글 요약 문서다. 세부 구현은 코드와 Git 이력을 우선한다.

## 전체 구조

```text
Main.gd
  match orchestration, scene wiring, UI 연결, runtime controller 소유

Entity layer
  Entity.gd
  Player.gd
  Bot.gd
  BotDecisionPolicy.gd
  BotMovementPolicy.gd
  BotDoctrine.gd
  BotTuning.gd

Runtime systems
  systems/match
  systems/zone
  systems/loot
  systems/mission
  systems/hell

Core data/helpers
  StatsData.gd
  ItemData.gd
  GameConfig.gd
  AssetCatalog.gd
  MapDefinition.gd
  WeaponSlotManager.gd

Presentation/UI
  WorldBuilder.gd
  Minimap.gd
  FullMapOverlay.gd
  menu/panel builders

Data
  data/game_config.json
  data/asset_catalog.json
  data/mapSpec_*.json
```

## 핵심 원칙

- `Main.gd`는 아직 match-global orchestrator다. 무리하게 한 번에 쪼개지 않는다.
- `Bot.gd`, `Player.gd`, `Telemetry.gd`, `Main.gd`는 큰 파일이다. 해당 도메인을 실제로 만질 때만 추출한다.
- data/config는 가능한 한 순수 데이터로 유지한다.
- runtime controller는 명시적으로 받은 참조를 사용하고, 임의 scene lookup을 늘리지 않는다.
- gameplay authority와 visual replacement를 분리한다.
- generated asset은 catalog를 통해 점진 연결하고 fallback을 유지한다.

## 주요 소유 경계

| 영역 | 소유 | 메모 |
|---|---|---|
| Match bootstrap | `Main.gd`, `systems/match/*` | config/preset 해석은 helper, orchestration은 Main |
| Simulation participants | `SimulationParticipants.gd` | headless player는 observer, alive/spawn/target participant는 bot만 계산 |
| Zone | `ZoneController.gd` | Main이 인스턴스를 소유, Bot/UI는 읽기 중심 |
| Loot | `LootSpawner.gd`, `LootSpawnDirector.gd`, `Pickup.gd` | spawn 계산과 pickup runtime 분리 |
| Combat AI | `Bot.gd`, `BotDecisionPolicy.gd`, `BotMovementPolicy.gd`, `BotDoctrine.gd`, `BotTuning.gd` | 정책은 순수 판단·조향, Bot은 관측 수집과 상태 실행 |
| Player inventory | `Player.gd`, `WeaponSlotManager.gd` | 외부는 Player wrapper를 통해 접근 |
| Mission | `MissionTracker.gd`, mission format/evaluator helpers | HUD 문자열과 판정 분리 |
| Telemetry | `Telemetry.gd`, `tools/analyze_results.py` | gameplay 판단을 위한 구조화된 출력 |
| Assets | `AssetCatalog.gd`, `data/asset_catalog.json` | missing path는 fallback으로 처리 |
| 지도 UI | `Minimap.gd`, `MinimapStaticLayer.gd`, `FullMapOverlay.gd` | 같은 45도 투영 사용. 미니맵 정적 지도는 1회 캐시하고 동적 상태만 실시간 표시 |

## 빠른 변경 영향표

| 바꾸는 것 | 같이 확인할 것 | 기본 검증 |
|---|---|---|
| `Bot.gd` opening/perception/combat | `BotDoctrine`, `BotTuning`, telemetry, opening tests | `unit_smoke`, 필요 시 `pacing_candidate` |
| `Player.gd` 체력/무기/아티팩트 | `WeaponSlotManager`, artifact runtime/visuals, HUD | 관련 `verify_artifact_*`, 1-run |
| `Main.gd` orchestration | match tuning, zone, loot, UI wiring | `unit_smoke`, 1-run 이상 |
| simulation participant | alive count, spawn requested/placed, session winner | `verify_simulation_participants`, 5-run pacing |
| `Telemetry.gd` | analyzer/summarizer/check scripts | `tooling`, `verify_pacing_telemetry` |
| `data/mapSpec_*` | map verifiers, scale gates, minimap/full map | map verifier + simulation + map capture |
| `data/game_config.json` | match/runtime/hell/mission tuning | 관련 smoke + simulation |
| `data/asset_catalog.json` | `AssetCatalog`, UI/world fallback | Godot headless quit + 화면 확인 |
| UI builder | screenshot state, text fit, panel flow | `docs_only` + UI screenshot |
| 문서만 변경 | links, markdown whitespace | `docs_only` |

## MapDefinition

`MapDefinition.gd`는 기존 `MapSpec` JSON 위에 scale preset과 runtime query를 얹는 compatibility layer다.

- `mapSpec_night_forest_candidate.json`은 현재 Night BR 후보 표면이다.
- `target_99_probe`는 구조 gate다.
- `playable_pacing_v4`는 현재 자동 페이싱 후보이며 default promotion이 아니다.
- `routes`는 현재 텔레메트리 위치 분류 전용 데이터다. bot 이동은 POI loot, zone, cover가 결정하며 route graph를 직접 소비하지 않으므로 플레이어 지도와 월드에는 표시하지 않는다.
- minimap과 fullmap은 월드 좌표를 45도 회전해 게임 카메라 방향과 맞춘다.
- player-target outnumbered 판정은 현재 표적을 제외하고 자신을 추적 중이거나 최근 5초 안에 공격한 제3자만 센다. bot-only 판정은 기존 페이싱 계약을 유지한다.
- 짧은 LOS 상실 기억은 player 표적 5초, 일반 표적 2.5초다. 이 값은 `BotDecisionPolicy.gd`가 소유하고 `Bot.gd`가 ATTACK 해제 시 소비한다.
- `BotDecisionPolicy.gd`는 scene tree를 조회하지 않는다. 위협·표적·위치 후보의 context를 받아 판단하며 `Bot.gd`가 관측 수집과 실제 이동·상태 전이를 맡는다.
- `Entity.gd`는 하위 타입이 요청할 때만 기존 perception 갱신에서 LOS가 있는 3m 근접 actor 캐시를 만든다. `BotMovementPolicy.gd`는 위치 offset만 받아 분리 방향을 계산하며 scene tree를 조회하지 않는다.
- 봇의 캐시와 분리는 player-target ATTACK과 비loot CHASE에만 적용한다. bot-only 교전, loot CHASE, 현재 표적은 제외해 기존 시뮬레이션 흐름과 직접 교전 거리를 보존한다.
- perception/sensory와 비즉시 AI 검색은 봇별 위상을 분산한다. 표적·후퇴 위협·압력 문맥은 0.10초, 픽업은 0.25초만 재사용하며 피격·상태·장비/체력 변화와 이미 완전 공개된 첫 표적은 즉시 다시 계산한다.
- `NavigationAgent3D.target_position`은 요청점이 0.35m 이상 이동하거나 상태/stuck 복구가 바뀔 때만 갱신한다. `get_next_path_position()`은 이동 중 매 physics frame 소비한다.
- 교리 상태 시간은 매 frame의 delta를 0.25초씩 누적해 Telemetry에 기록한다. 상태 전환과 사망 시 남은 누적값을 먼저 기록한다.
- headless simulation은 player 행동을 흉내 내지 않는다. player는 비참가 observer이고 99봇 중 1명이 남으면 종료한다.

## 자산 구조

런타임 lookup은 `AssetCatalog.gd`가 `data/asset_catalog.json`을 읽어 처리한다.

- path가 있으면 실제 파일 사용.
- path가 비면 fallback primitive/sound/silence 사용.
- `asset_generator/expected_output/`은 원본 풀이고, 런타임 자산이 아니다.

Bush는 예외적으로 GLB visual replacement가 통합되어 있다. 단, concealment gameplay authority는 여전히 `Bush.tscn`의 Area3D가 가진다.

## 변경 시 주의

- shared `Resource`는 런타임에서 오염될 수 있으므로 필요한 곳에서 `.duplicate()`를 사용한다.
- Bot opening/loot/zone behavior 변경은 `verify_bot_opening_loot_rules.gd`와 pacing profile을 같이 본다.
- UI 변경은 [PLAYTEST.md](../PLAYTEST.md)의 화면 리뷰 체크리스트와 screenshot을 사용한다.
- asset path 추가는 Godot headless quit과 최소 1-run sim으로 확인한다.
- smoke 하나로 gameplay 변경을 닫지 않는다. first contact, first kill, first upgrade, stage2, stage3, match end를 분리해서 읽는다.
- duration이 짧아졌다면 opening 수치가 좋아 보여도 후보를 의심한다.
