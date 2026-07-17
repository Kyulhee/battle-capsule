# Battle Capsule 에이전트 온보딩

Godot 4.6.2 / GDScript 기반 quarter-view battle royale 프로토타입.

Repository: `https://github.com/Kyulhee/battle-capsule`

## 현재 상태

| 항목 | 상태 |
|---|---|
| 개발 라인 | v2-dev: Night BR 후보, 99명 구조 gate, playable pacing |
| 활성 트래커 | [CURRENT.md](docs/CURRENT.md) |
| 최신 검증 gameplay slice | N2-PACE-43 초기 pickup 3.5m 간격 폐기. first acquisition 유지, stuck 106.0회 |
| 최신 검증 운영 slice | N2-MAP-03 비충돌 world route cue와 역할별 MultiMesh 배치 |
| 현재 운영 slice | N2-ASSET-01 route/POI landmark 자산 후보 audit |
| 릴리즈 정책 | 명시 요청 전까지 릴리즈/빌드 금지 |
| 외부 원본 풀 | `asset_generator/`, `plan_report/`는 통합 요청 전까지 커밋하지 않음 |

이 프로젝트는 더 이상 작은 기능을 하나씩 붙이는 정리 단계가 아니다. 먼저 milestone tracker를 보고, 현재 마일스톤을 전진시키는 가장 작은 검증 가능한 작업 단위를 고른다.

## 기본 읽기 경로

모든 문서를 열지 않는다. 기본은 아래 3개다.

| 순서 | 문서 | 읽는 시점 |
|---|---|---|
| 1 | [CURRENT.md](docs/CURRENT.md) | 매 세션, 매 작업 시작 |
| 2 | [DOCS_INDEX.md](docs/DOCS_INDEX.md) | 추가 문서가 필요할 때 |
| 3 | [DECISIONS.md](docs/DECISIONS.md) / [EXPERIMENTS.md](docs/EXPERIMENTS.md) | 정책 변경 또는 새 튜닝 후보 전 |

작업별 문서는 [DOCS_INDEX.md](docs/DOCS_INDEX.md)의 중요도 순서를 따른다.

## 제외 문서

- 날짜별 전체 문서 사본은 만들지 않는다. 과거 상태는 Git 이력에서 찾는다.
- `asset_generator/**`, `plan_report/**`는 로컬 원본/참고 풀이다. 통합 요청 전까지 커밋하지 않는다.

## 갱신 규칙

| 상황 | 갱신 문서 |
|---|---|
| 현재 작업, 다음 작업, 주요 리스크 | `docs/CURRENT.md` |
| 안정 결정 변경 | `docs/DECISIONS.md` |
| 채택/폐기 실험 | `docs/EXPERIMENTS.md` |
| 수동 체감/가독성 결과 | `docs/PLAYTEST.md` |
| 검증 완료 작업 | `docs/DEVLOG.md`에 짧게 |
| 로드맵 변경 | `docs/MASTERPLAN.md` |
| 구조 경계/변경 영향 | `docs/reference/ARCHITECTURE.md` |
| 검증 rule/profile 변경 | `docs/reference/TESTING.md` |
| 자산 기준/생성 요청 변경 | `docs/assets/ASSET_BRIEF.md`, `docs/assets/ASSET_GENERATION_PROMPTS.md` |

문서 설명은 한글로 쓴다. 영어는 코드 식별자, 명령, 원문 문자열, 생성기 프롬프트에만 사용한다. 새 루트 문서를 만들지 않고 기존 역할에 병합하며, 줄 수 예산은 [DOCS_INDEX.md](docs/DOCS_INDEX.md)를 따른다.

## 핵심 파일

```text
src/Main.gd                           orchestration, game loop, spawn, UI wiring
src/entities/player/Player.gd         player input, weapon slots, HUD
src/entities/bot/Bot.gd               AI state machine, perception, combat
src/entities/pickup/Pickup.gd         pickup visibility/label/icon/collect
src/entities/Entity.gd                shared HP/shield/movement/perception
src/systems/zone/ZoneController.gd    zone lifecycle/damage
src/systems/mission/MissionTracker.gd mission state
src/core/Telemetry.gd                 match metrics and JSON schema
src/core/AssetCatalog.gd              audio/icon/prop/cosmetic lookup
src/systems/loot/LootSpawner.gd       loot hotspot/position calculation
```

## 검증 리듬

문서만 바꾸면 보통:

```powershell
python tools\run_verify.py --profile docs_only
```

gameplay, AI, map, telemetry, pacing 변경은 [TESTING.md](docs/reference/TESTING.md)에서 해당 profile을 고른다. 주요 체감 변경은 텔레메트리 PASS만으로 닫지 말고 [PLAYTEST.md](docs/PLAYTEST.md)에 기록한다.

예상 가능한 asset warning:

```text
AssetCatalog: 7 configured asset paths are missing; fallbacks remain active.
```

## Godot 메모

- Control preset은 `PRESET_CENTER_BOTTOM`, `PRESET_BOTTOM_CENTER`가 아니다.
- Bottom-anchored Control은 `grow_vertical = GROW_DIRECTION_BEGIN`이 필요하다.
- macOS export key는 `application/bundle_identifier`.
- Headless export에는 `project.godot`의 `textures/vram_compression/import_etc2_astc=true`가 필요하다.
- editor 밖에서 새 `class_name` script를 만들면 headless parse timing을 피하기 위해 `Main.gd`에서는 `preload()` 사용을 선호한다.
