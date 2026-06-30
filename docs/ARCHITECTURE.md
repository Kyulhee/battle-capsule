# 아키텍처 개요

> 최종 업데이트: 2026-06-30. 구조 변경 전 읽는 한글 요약 문서다. 세부 구현은 코드와 git history를 우선한다.

## 전체 구조

```text
Main.gd
  match orchestration, scene wiring, UI 연결, runtime controller 소유

Entity layer
  Entity.gd
  Player.gd
  Bot.gd
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
| Zone | `ZoneController.gd` | Main이 인스턴스를 소유, Bot/UI는 읽기 중심 |
| Loot | `LootSpawner.gd`, `LootSpawnDirector.gd`, `Pickup.gd` | spawn 계산과 pickup runtime 분리 |
| Combat AI | `Bot.gd`, `BotDoctrine.gd`, `BotTuning.gd` | opening guard와 doctrine 변경은 검증 필수 |
| Player inventory | `Player.gd`, `WeaponSlotManager.gd` | 외부는 Player wrapper를 통해 접근 |
| Mission | `MissionTracker.gd`, mission format/evaluator helpers | HUD 문자열과 판정 분리 |
| Telemetry | `Telemetry.gd`, `tools/analyze_results.py` | gameplay 판단을 위한 구조화된 출력 |
| Assets | `AssetCatalog.gd`, `data/asset_catalog.json` | missing path는 fallback으로 처리 |
| UI | panel/menu builder들 | 실제 screenshot 기반 리뷰 필요 |

## MapDefinition

`MapDefinition.gd`는 기존 `MapSpec` JSON 위에 scale preset과 runtime query를 얹는 compatibility layer다.

- `mapSpec_night_forest_candidate.json`은 현재 Night BR 후보 표면이다.
- `target_99_probe`는 구조 gate다.
- `playable_pacing_v4`는 현재 자동 페이싱 후보이며 default promotion이 아니다.

## 자산 구조

런타임 lookup은 `AssetCatalog.gd`가 `data/asset_catalog.json`을 읽어 처리한다.

- path가 있으면 실제 파일 사용.
- path가 비면 fallback primitive/sound/silence 사용.
- `asset_generator/expected_output/`은 원본 풀이고, 런타임 자산이 아니다.

Bush는 예외적으로 GLB visual replacement가 통합되어 있다. 단, concealment gameplay authority는 여전히 `Bush.tscn`의 Area3D가 가진다.

## 변경 시 주의

- shared `Resource`는 런타임에서 오염될 수 있으므로 필요한 곳에서 `.duplicate()`를 사용한다.
- Bot opening/loot/zone behavior 변경은 `verify_bot_opening_loot_rules.gd`와 pacing profile을 같이 본다.
- UI 변경은 `UI_DESIGN.md` 체크리스트와 screenshot을 사용한다.
- asset path 추가는 Godot headless quit과 최소 1-run sim으로 확인한다.
