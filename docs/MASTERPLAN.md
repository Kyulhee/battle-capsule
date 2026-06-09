# 배틀 캡슐 마스터플랜

> 마지막 업데이트: 2026-06-10 (AI perception LOD 1차 완료)

현재 세션에서 기본으로 읽는 압축 로드맵이다. 압축 전 전체 원문은 [archive/MASTERPLAN_full_2026-06-08.md](archive/MASTERPLAN_full_2026-06-08.md)에 보존했다. 더 오래된 기록은 `docs/archive/`에 남아 있다.

## 현재 요약

| 항목 | 상태 |
|---|---|
| 현재 개발 라인 | v2-dev: 구조 안전성 게이트 + 99인 야간 맵 후보 전환 |
| 최신 완료 코드 슬라이스 | AI perception/sensory LOD 1차 |
| 현재 문서 슬라이스 | 99인 후보 구조 부하용 AI LOD 기준선 기록 |
| 다음 구현 후보 | 봇 추상 야간 인지 또는 10-15분 pacing telemetry 초안 |
| 목표 플레이 시간 | 10-15분 본편 매치 |
| 현재 telemetry 역할 | 최종 밸런스가 아니라 구조 안전성 게이트 |
| 99인 런타임 상태 | 기본 맵/기본 프리셋 승격 금지. 후보 맵과 `target_99_probe`에서만 검증 |
| 수동 화면 검토 | `visual_review` 프리셋 사용. `xlarge_60`/`target_99_probe`는 렉이 큰 구조 부하 검증용 |
| 성능 LOD 상태 | 픽업 광원 LOD와 AI perception/sensory tick LOD 1차 적용 |
| 릴리즈 상태 | 일시 중지. 명시 요청 전까지 버전별 개발 지속 |
| 로컬 참고 자료 | `plan_report/`는 참고용 로컬 디렉토리이며 커밋 대상 아님 |
| 외부 에셋 | `asset_generator/`, 로컬 프롬프트 스크래치는 선택 통합 전까지 untracked 유지 |

생성 에셋 일부가 아직 연결되지 않은 상태에서는 Godot 시작 시 다음 경고가 예상된다.

```text
AssetCatalog: 7 configured asset paths are missing; fallbacks remain active.
```

## 현재 결정

- v2.0.40까지의 긴 telemetry 작업은 "99인 완성 밸런스"가 아니라 "맵/스폰/루트/AI 비용이 무너지지 않는지 보는 구조 안전성 백본"으로 격하한다.
- 다음 본편 후보는 기존 Balanced 99 Forest 개념을 그대로 구현하는 대신, `plan_report/`의 **야간 인공 숲 콜로세움** 방향을 우선 검토한다.
- 중앙 만능 허브보다 대각선 강/수문/횡단로가 회전 압력을 만드는 구조가 더 적합하다. `Sluice Crossing`은 중심 충돌축, `Black Ridge`는 제한된 파워 포지션, `False Clinic`은 회복/스토리 루프 역할을 맡긴다.
- 99인 맵은 `data/mapSpec_night_forest_candidate.json`으로 첫 구조 후보를 만들었다. POI 미니맵은 `Sluice Crossing`, `Wire Maze`, `Black Ridge`, `False Clinic`, `Supply Flats`, `Ammunition Pockets`, `Cabin Row`, `Broadcast Fence`까지 분리했고 모두 smoke/runtime과 3-run reference simulation 기준선을 확보했다. 이 결과를 바탕으로 후보 맵은 `0.2-poi-probe-integrated`까지 소폭 반복했다. 완성 체감을 매번 전체 맵으로 검증하지 않고, POI 미니맵과 주요 기능 프록시 시뮬레이션을 병행한다.
- 손전등, 배터리, 공포, 정전은 본편 체감의 핵심 후보지만 첫 단계부터 모든 봇에게 풀 시스템으로 적용하지 않는다. 처음에는 플레이어-facing 시스템과 봇의 추상 야간 인지만 검증한다.
- 수동 화면 확인 렉은 99 AI 포기 신호가 아니라 테스트 계층 혼선과 렌더링/AI 부하가 섞인 신호로 본다. `visual_review`는 화면 검토용, `xlarge_60`/`target_99_probe`는 구조 부하 검증용으로 분리하고, 픽업 광원 LOD부터 적용했다.
- AI LOD 1차는 봇 의사결정/전투/이동을 건너뛰지 않고 perception tick과 footstep/gunshot/close-range all-actor scan 주기만 낮춘다. 99 후보 1-run은 fallback 0과 regression sentinel clear를 유지했다.
- 10-15분 목표는 현재 짧은 scale smoke의 수치와 별도 축이다. 자기장, 루팅, 첫 교전, 중반 이동, 최종 교전 페이싱은 야간 맵 후보 이후 다시 잡는다.

## 활성 문서

| 문서 | 용도 |
|---|---|
| [../CLAUDE.md](../CLAUDE.md) | 세션 온보딩과 기본 작업 규칙 |
| [HANDOFF.md](HANDOFF.md) | 다음 세션용 짧은 상태와 로컬 git 주의점 |
| [DOCS_INDEX.md](DOCS_INDEX.md) | 문서 라우팅과 활성 문서 예산 |
| [DEVLOG.md](DEVLOG.md) | 최근 검증 작업의 압축 로그 |
| [IMPACT_MAP.md](IMPACT_MAP.md) | 소유권과 변경 영향 확인 |
| [ARCHITECTURE.md](ARCHITECTURE.md) | 구조 변경 시 모듈 경계 확인 |
| [TESTING.md](TESTING.md) | 검증 명령과 해석 기준 |
| [ASSET_STATUS.md](ASSET_STATUS.md) | 현재 통합/보류 에셋 상태 |
| [MAP_TILE_GROUPS.md](MAP_TILE_GROUPS.md) | 99인 맵 배치 그룹과 후보 맵 브리프 |
| [NIGHT_BR_PACING_PLAN.md](NIGHT_BR_PACING_PLAN.md) | 10-15분 야간 배틀로얄 페이싱과 테스트 계층 |

## 운영 원칙

- `Main.gd`는 경기 전역 상태, scene wiring, lifecycle orchestration, Telemetry hook의 소유자로 유지한다.
- 정적 데이터, 수치, 표시 문자열, 평가 조건은 catalog, tuning, formatter, evaluator, controller, director, store 경계로 나눈다.
- UI에 표시되는 수치와 실제 로직 수치는 가능하면 같은 data/tuning에서 가져온다.
- 99인 기본 승격, 새 기본 맵, 봇 artifact, artifact upgrade tree, 화재/정전/공포 시스템은 명시된 migration plan 없이 시작하지 않는다.
- 활성 문서는 짧게 유지한다. 긴 원문은 `docs/archive/` 또는 `docs/devlog/` snapshot에 남긴다.
- `plan_report/`는 외부 기획 참고 자료다. 그 안의 이미지/리포트는 분석에 쓰되 사용자가 요청하기 전까지 커밋하지 않는다.

## 경계 규칙

| 역할 | 소유해야 하는 것 | 소유하면 안 되는 것 |
|---|---|---|
| `Main.gd` | 경기 전역 상태, scene wiring, 생명주기 orchestration, Telemetry hook | 정적 catalog, 재사용 tuning 기본값, 표시 테이블 |
| `*Tuning.gd` | 수치 threshold, fallback 값, 해당 수치의 label helper | runtime counter, scene lookup, mutation |
| `*Catalog.gd` / `*Data.gd` | 정적 id, descriptor, resource/data lookup | runtime progress, 평가 side effect |
| `*Formatter.gd` / `*Builder.gd` / `*Resolver.gd` | 텍스트, 표시 spec, node/icon 구성 | gameplay decision, 숨겨진 중복 threshold |
| `*Evaluator.gd` | 명시 context와 descriptor data를 받는 pure check | counter, timer, file I/O, reward/penalty execution |
| `*Controller.gd` / `*Director.gd` / `*Planner.gd` | 한 domain 안의 제한된 runtime process 또는 placement | 경기 전역 소유권 |
| `*Store.gd` | 한 관심사의 파일 persistence와 schema compatibility | gameplay timing, UI formatting, evaluation rule |

## 버전 스레드

### v1.10-v1.11 구조 정리

상태: 구조적으로 종료.

- `Main.gd`에서 item/resource pool, runtime match tuning, UI builder, bootstrap helper, pressure effect execution, bot spawn planning, loot/supply creation, world/menu presentation 기본값을 1차 분리했다.
- Mission, Hell, Zone, Loot/Supply, Player, Bot, Entity/Pickup은 현재 역할 경계가 유지 가능한 수준이다.
- `Main.gd`에 남기는 것: scene callback, exported default, current match state, zone, mission tracker, player reference, alive count, game-over flow, pressure trigger/effect flow, Telemetry hook call.
- v1.11 이후 helper extraction은 줄 수 기준이 아니라 실제 ownership 충돌이 있을 때만 재개한다.

### v1.12 artifact/asset 기반

상태: 1차 완료.

- 시작 artifact: Red Trigger, Armor Sponge, Silent Core, Zone Battery, Escape Capsule, Ghost Grass.
- Artifact runtime state는 `PlayerArtifactRuntime.gd`, 시각 효과는 `PlayerArtifactVisuals.gd`, 아이콘 해석은 `ArtifactIconResolver.gd` 쪽으로 분리되어 있다.
- 6종 artifact icon PNG는 runtime catalog에 통합되어 있다.
- Bush GLB는 visual-only replacement다. `Bush.tscn` Area3D가 gameplay authority다.
- 생성된 tree/rock/log/landmark GLB는 보류다. 충돌/cover 권한을 명확히 유지할 수 있을 때만 선택 통합한다.

### v2.0 MapDefinition/scale 백본

상태: 구조 안전성 백본은 쓸 수 있는 상태. 최종 99인 밸런스는 아님.

- `MapDefinition.gd`가 legacy `mapSpec` JSON을 감싸고 map id/name, POI, obstacle, route, scale preset, spawn/loot/zone profile을 검증한다.
- Full Map overlay는 read-only foundation으로 추가됐다.
- Scale path는 baseline -> medium_24 -> large_40 -> xlarge_60 -> candidate-only `target_99_probe` 순서로 열렸다.
- `target_99` envelope는 preferred 180m world / 78m spawn radius / 3.5m clearance / fallback 0을 기준으로 한다.
- `data/mapSpec_large_candidate.json`는 180m 후보 맵과 route/POI telemetry를 검증하기 위한 비기본 후보로 남긴다.
- `data/mapSpec_night_forest_candidate.json`는 야간 인공 숲 방향의 첫 비기본 구조 후보로 남긴다.
- v2.0.30 이후 primary choke와 transit choke 압력은 telemetry상 읽히기 시작했다. 다만 v2.0.40 기준 60 -> 99에서 `ATTACK+CHASE`와 `CHASE combat` 비중이 여전히 얇다.
- 이제 이 얇은 combat coverage를 최종 목표로 직접 맞추지 않는다. 야간 시야/손전등/맵 구조가 들어오면 수치가 크게 흔들릴 수 있으므로 현재 계층은 구조 안전성 확인에 사용한다.

## 야간 인공 숲 방향

목표: 99인 본편의 첫 후보 맵을 10-15분 야간 배틀로얄로 만든다.

| POI | 1차 역할 | 검증 포인트 |
|---|---|---|
| Supply Flats | `loot_hub` | 열린 보급지. 초반 무기 접근성은 높지만 노출 비용이 커야 한다 |
| Ammunition Pockets | loot support / edge flow | 탄약 경로를 만들되 안전 루프가 되면 안 된다 |
| Cabin Row | `concealment_field` / close quarters | 은폐와 근접전 체감. 과도한 시야 차단과 stuck 위험 확인 |
| False Clinic | `recovery_pocket` | 회복/스토리 루프. 회복 후 재진입 압력이 있어야 한다 |
| Wire Maze | `transit_choke` | 고위험 구조물. 첫 구현은 경량 장애물로 stuck을 줄인다 |
| Broadcast Fence | `transit_choke` / objective compound | 감시/방송 테마와 중반 이동 압력 |
| Black Ridge | `power_position_overlook` | 강한 위치지만 fortress가 되면 안 된다 |
| Sluice Crossing | `primary_choke` | 대각선 강의 핵심 횡단로. 우회로와 시간 비용이 필요하다 |

중앙 구조는 "모두가 모이는 십자 허브"보다 "강 때문에 어쩔 수 없이 선택해야 하는 횡단/우회"에 가깝게 잡는다.

## 다음 작업 순서

1. **문서 정리**
   - `MASTERPLAN`을 한국어 중심 압축본으로 유지한다.
   - [NIGHT_BR_PACING_PLAN.md](NIGHT_BR_PACING_PLAN.md)에 10-15분 pacing, 야간 시스템 단계, 테스트 계층을 기록한다.
   - [MAP_TILE_GROUPS.md](MAP_TILE_GROUPS.md)에 야간 인공 숲 후보와 8개 POI mapping을 반영한다.
2. **99인 후보 mapSpec 초안**
   - 상태: `data/mapSpec_night_forest_candidate.json` 생성 및 0.2 구조 반복 완료.
   - `Sluice Crossing`, `Black Ridge`, `False Clinic`, `Wire Maze`를 우선 축으로 삼은 180m 후보다.
   - `tools/verify_night_forest_candidate.gd`, `xlarge_60` runtime load, `target_99_probe` runtime load는 통과했다.
3. **POI 미니맵/기능 프록시**
   - 상태: 핵심 8개 POI 프로브 생성, smoke/runtime, 3-run reference simulation 통과.
   - 전체 99인 맵만 반복 실행하지 않는다.
   - 후보 맵 1-run 구조 기준선: duration 165.4s, fallback 0.0/run, sentinel clear, primary_choke damage 48.9%, stuck 101.0/run, zone deaths 4.0/run.
4. **야간 시야 1차 prototype**
   - 상태: 플레이어 전용 `VisionSpot`/`ProximityLight` night profile smoke 완료.
   - 봇은 처음부터 배터리/공포/손전등 inventory를 갖지 않는다. 추상 night awareness와 player reveal 반응부터 시작한다.
   - 수동 화면 확인은 `scale_preset=visual_review`로 한다. 8봇/45픽업/느린 자기장 프리셋이며, 더 가볍게 보려면 `bot_count=0 loot_count=24`를 추가한다.
   - 픽업 광원은 거리 기반 LOD로 가까운 아이템만 full light, 중거리 아이템은 dim light, 먼 아이템은 light off로 처리한다.
   - 다음 확인: 수동 화면에서 손전등 프레이밍, 아이템 판독성, 부쉬 판독성, 교전 판독성을 확인한다.
5. **봇 AI LOD/야간 인지 설계**
   - 99 AI 목표는 유지하지만 수동 화면 검토용 프리셋에서 full 99 AI를 돌리지 않는다.
   - AI perception/sensory LOD 1차는 완료했다. 전투/이동/피격/존 탈출은 매 frame 유지하고, perception/sound/proximity scan만 tick rate로 제한했다.
   - 다음 봇 야간 작업은 cone-vs-cone 손전등 시뮬레이션이 아니라 거리/확신도 기반 추상 인지로 제한한다.
6. **10-15분 pacing gate**
   - 첫 교전 시간, 첫 non-pistol upgrade, 첫 횡단, 중반 재진입, 최종 교전, 평균 매치 시간, AI cost를 새 기준으로 수집한다.
   - 현재 100-170초 scale smoke 수치는 구조 확인용으로만 해석한다.

## 장기 작업 단위

사용자가 장기간 확인하기 어려운 동안에는 아래 단위 순서를 따른다. 한 단위는 가능한 한 1-3개 파일 묶음과 명확한 smoke 검증으로 끝낸다. 같은 단위에서 두 번 연속 막히면 범위를 줄이거나 다음 독립 단위로 넘어가고, 기본 맵/기본 99인 승격 같은 큰 결정은 보류한다.

| ID | 단위 | 산출물 | 검증 | 중단/전환 기준 |
|---|---|---|---|---|
| N2-POI-01 | Sluice Crossing 구조 프로브 | `data/mapSpec_poi_sluice_crossing_probe.json`, 전용 verifier | JSON parse, `verify_poi_sluice_crossing_probe.gd`, runtime load | smoke 실패 원인이 route/POI 구조면 즉시 수정. 시뮬레이션 밸런스 튜닝은 다음 단위로 분리 |
| N2-POI-02 | Sluice Crossing 짧은 시뮬레이션 | 1-3 run 결과와 문서 기록 | `simulate_matches.py` + `analyze_results.py`; 기존 scale gate는 참고용만 | stuck/fallback/nav 문제가 나오면 맵 구조 수정. duration/upgrade threshold 튜닝은 금지 |
| N2-POI-03 | Wire Maze 구조 프로브 | 소형 Wire Maze `mapSpec`, verifier | JSON parse, Godot verifier, runtime load | 장애물/시야가 복잡해지면 fence 밀도 축소. full maze 구현 금지 |
| N2-POI-04 | Wire Maze 짧은 시뮬레이션 | 1-3 run 결과와 문서 기록 | `simulate_matches.py` + `analyze_results.py`; 기존 scale gate는 참고용만 | stuck/fallback/nav 문제가 나오면 maze 밀도 축소. combat 비율 튜닝은 금지 |
| N2-POI-05 | Black Ridge 구조 프로브 | 파워 포지션 소형 `mapSpec`, verifier | key position classification, runtime load | ridge가 fortress가 되면 hard cover 축소. climb/interior 구현 금지 |
| N2-POI-06 | False Clinic 회복 재진입 프로브 | recovery pocket + re-entry `mapSpec`, verifier | recovery_exit classification, runtime load | 안전 루프가 되면 회복/loot 밀도 축소 |
| N2-POI-07 | Supply Flats 초반 루팅 프로브 | open loot hub + exposed route `mapSpec`, verifier | loot_hub classification, runtime load | 열린 보급지가 safe armory가 되면 hard cover/rare bias 축소 |
| N2-POI-08 | Ammunition Pockets 탄약 경로 프로브 | low-rare ammo breadcrumb `mapSpec`, verifier | loot_hub limit, runtime load | 안전 탄약 루프가 되면 density/cover 축소 |
| N2-POI-09 | Cabin Row 은폐/근접전 프로브 | concealment field + readable lane `mapSpec`, verifier | concealment classification, runtime load | interior/climb 구현 금지. 시야가 과밀하면 wall/bush 축소 |
| N2-POI-10 | Broadcast Fence 통과/목표지 프로브 | fence gate + flanks `mapSpec`, verifier | transit_choke classification, runtime load | searchlight/전력 시스템 구현 금지. 구조만 검증 |
| N2-SIM-01 | Black/False/Supply/Ammo/Cabin/Broadcast 짧은 시뮬레이션 | 6개 POI 3-run reference 결과와 문서 기록 | `simulate_matches.py`, JSON summary | duration/first upgrade 튜닝 금지. fallback, zone death, stuck, zero sentinel만 hard signal로 본다 |
| N2-MAP-01 | 야간 후보 맵 구조 반복 | `mapSpec_night_forest_candidate.json` 소폭 수정 | `verify_night_forest_candidate.gd`, runtime load, 99인 1-run reference | POI 프로브 결과 없이 전체 맵 수치 튜닝 금지 |
| N2-VIS-01 | 플레이어-facing 손전등 1차 | 플레이어 조명/readability prototype | Godot headless, 필요 시 수동 screenshot | 모든 봇 full flashlight/fear/battery 금지 |
| N2-PERF-01 | 픽업 광원 LOD 1차 | 거리 기반 pickup light full/dim/off | `verify_pickup_light_lod.gd`, `visual_review` runtime load | 봇 AI update cadence와 같은 단위에서 처리 금지 |
| N2-AI-LOD-01 | AI perception/sensory LOD 1차 | 상태별 perception tick, 보조 감지 loop throttle | `verify_ai_lod_perception.gd`, 60/99 1-run smoke | combat/movement/state handler skip 금지 |
| N2-AI-01 | 봇 추상 야간 인지 | 거리/확신도 보정만 있는 작은 AI patch | 1-3 run smoke, AI cost 확인 | cone-vs-cone 고비용 시뮬레이션으로 확장 금지 |
| N2-PACE-01 | 10-15분 pacing telemetry | match duration, first contact, crossing usage 등 row | smoke + analyzer 출력 확인 | 기존 100-170초 smoke 기준을 최종 목표로 오해하지 않기 |

자율 진행 규칙:

- 커밋/푸시는 사용자가 명시적으로 요청했을 때만 한다.
- 기본 맵, 기본 scale preset, release 관련 작업은 명시 요청 전까지 보류한다.
- 새 단위마다 `DEVLOG`와 `HANDOFF`를 짧게 갱신한다.
- `plan_report/`, `asset_generator/`, `docs/ASSET_GENERATION_PROMPTS.md`, 기존 `.gitignore` 로컬 변경은 건드리지 않는다.
- 시뮬레이션 결과가 애매하면 "수치 튜닝"보다 "다음 POI 구조 프로브"를 우선한다.

현재 단위 상태:

- N2-POI-01 완료: Sluice Crossing 프로브 smoke와 runtime load 통과.
- N2-POI-02 완료: 3-run smoke에서 avg duration 69.1s, fallback 0.0/run, zone deaths 0, regression sentinel 없음. 기존 scale gate는 avg duration 69.1s < 70.0s, first upgrade 8.2s < 10.0s로 참고용 FAIL이지만 POI 프로브 hard gate로 보지 않는다.
- N2-POI-03 완료: Wire Maze 프로브 smoke와 runtime load 통과. 장애물은 sparse wall 4개와 low fence/log 위주로 유지했다.
- N2-POI-04 완료: 3-run reference simulation에서 avg duration 66.6s, fallback 0.0/run, zone deaths 0, zero damage/shot/combat-plan sentinel 없음. 전투 피해는 primary_choke 46.0%, flank 27.1%, recovery_exit 17.0%로 경로 압력이 읽힌다. stuck은 8.7/run으로 관찰 대상이지만 이번 단위에서는 maze 밀도 축소가 필요한 hard fail은 아니다. 기존 scale gate는 avg duration 66.6s, 60초 미만 1회, first upgrade 6.9s 때문에 참고용 FAIL이며 POI 프로브 hard gate로 보지 않는다.
- N2-POI-05 완료: Black Ridge 프로브 smoke와 runtime load 통과. 직접 능선 루트는 `primary_choke`, 북쪽 우회와 남쪽 저지대 우회는 `flank`, Field Aid Hollow 재진입은 `recovery_exit`로 분류된다. hard cover는 high ridge wall 3개와 large rock cluster 3개로 제한했다.
- N2-POI-06 완료: False Clinic 프로브 smoke와 runtime load 통과. False Clinic은 낮은 loot/rare의 `recovery_pocket`으로 유지하고, `clinic_reentry`가 `Clinic Doorway`의 `primary_choke` 압력으로 돌아가도록 고정했다. facade wall은 3개, soft cover는 6개로 제한했다.
- N2-POI-07 완료: Supply Flats 프로브 smoke와 runtime load 통과. 열린 `loot_hub` 중심에 sparse cover만 두고, `supply_exposed_lane`과 side flank/reentry를 분리했다.
- N2-POI-08 완료: Ammunition Pockets 프로브 smoke와 runtime load 통과. 낮은 rare와 작은 breadcrumb 구조로 안전 탄약 루프가 되지 않도록 제한했다.
- N2-POI-09 완료: Cabin Row 프로브 smoke와 runtime load 통과. cabin interior는 만들지 않고 facade wall, bush, readable lane만 검증했다.
- N2-POI-10 완료: Broadcast Fence 프로브 smoke와 runtime load 통과. fence/log gate와 flanks, Fuse Shelter reentry만 검증하고 searchlight/전력 시스템은 보류했다.
- N2-SIM-01 완료: Black Ridge, False Clinic, Supply Flats, Ammunition Pockets, Cabin Row, Broadcast Fence 3-run reference simulation 완료. 6개 모두 fallback 0.0/run, zero damage/shot/combat-plan sentinel 0. Cabin Row와 Broadcast Fence는 stuck 관찰 대상이고, Broadcast Fence는 zone death 1회가 있었다.
- N2-MAP-01 완료: `data/mapSpec_night_forest_candidate.json`를 `0.2-poi-probe-integrated`로 갱신했다. Cabin Row와 Broadcast Fence 주변 장애물 밀도를 낮추고 route/POI 분류 좌표는 유지했다. JSON parse, `verify_night_forest_candidate.gd`, `xlarge_60` runtime load, `target_99_probe` runtime load, 99인 1-run reference simulation을 통과했다. 1-run 결과는 duration 165.4s, fallback 0.0/run, sentinel clear, stuck 101.0/run, zone deaths 4.0/run이다.
- N2-VIS-01 1차 완료: `PlayerNightReadability.gd`가 야간 후보 map metadata에서 기존 `VisionSpot`/`ProximityLight`를 손전등 프로필로 전환한다. 기본 맵에서는 기존 조명값을 복원한다. `verify_player_night_readability.gd`, Night 후보 `xlarge_60` runtime load, Night 후보 `xlarge_60` 1-run smoke를 통과했다.
- N2-VIS-01 수동 검토 프리셋 추가: `visual_review`는 8봇, 45픽업, stage loot wave 0, 느린 자기장으로 구성했다. 1-run smoke는 duration 287.2s, fallback 0.0/run, zone deaths 0, sentinel clear, AI update avg 184.4us였다. `xlarge_60`은 60봇/150픽업/다수 pickup light 때문에 수동 검토용으로 쓰지 않는다.
- N2-PERF-01 완료: pickup `OmniLight3D`에 거리 기반 LOD를 적용했다. 감지된 픽업 body/icon은 유지하되, 광원은 가까우면 full, 중거리면 dim, 멀면 off로 처리하고 focus 상태에서는 full로 복원한다. `verify_pickup_light_lod.gd`, `verify_player_night_readability.gd`, Night 후보 `visual_review` runtime load를 통과했다.
- N2-AI-LOD-01 완료: `Entity` perception은 누적 delta tick으로 바꾸고, 봇은 ATTACK 0.05s / 이동계 상태 0.08s / IDLE 0.12s로 perception LOD를 적용했다. footstep/gunshot/close-range 스캔은 0.15s/0.10s/0.05s로 제한했다. `visual_review`, `xlarge_60`, `target_99_probe` 1-run smoke와 60/99 `check_scale_telemetry.py --min-runs 1`을 통과했다. 99 결과는 duration 178.2s, fallback 0.0/run, zone deaths 1, stuck 51.0/run, AI update avg 463.0us, sentinel clear다.
- 다음 우선순위: N2-AI-01 봇 추상 야간 인지 또는 N2-PACE-01 10-15분 pacing telemetry 초안. 기존 POI 프로브를 수동으로 보고 싶다면 `scale_preset=poi_probe`와 각 `map_spec_path`로 실행한다.

## 비목표

- 이번 전환에서 기본 맵이나 기본 scale preset을 99인으로 승격하지 않는다.
- 모든 봇에게 full flashlight/battery/fear state를 바로 넣지 않는다.
- Wire Maze, cabin interior, watchtower climb, fire spread, blackout event를 한 번에 구현하지 않는다.
- 생성 GLB를 대량 승격하지 않는다.
- combat 비율 하나를 목표값으로 잡고 AI aggression, damage, zone speed를 직접 밀어붙이지 않는다.

## 검증 게이트

문서만 바꿀 때:

- `git diff --check`

후보 맵 구조를 소폭 반복할 때:

- `tools/verify_night_forest_candidate.gd`
- runtime load: `map_spec_path=res://data/mapSpec_night_forest_candidate.json scale_preset=xlarge_60`
- runtime load: `map_spec_path=res://data/mapSpec_night_forest_candidate.json scale_preset=target_99_probe`
- 1-run `target_99_probe` reference simulation
- `git diff --check`

후보 맵을 승격/비교 게이트로 올릴 때:

- `tools/verify_strategic_flow_map.gd`
- `tools/verify_candidate_99_probe.gd`
- fresh 5-run `xlarge_60`
- fresh 5-run `target_99_probe`
- `tools/compare_scale_profiles.py`
- `tools/check_scale_telemetry.py`

야간/페이싱을 바꿀 때:

- `tools/verify_ai_lod_perception.gd`
- `tools/verify_pickup_light_lod.gd`
- `tools/verify_player_night_readability.gd`
- 10-15분 목표에 맞춘 별도 telemetry row 추가
- flashlight on ratio, battery depletion, darkness hit/kill, crossing usage, POI dwell, first-contact, first-upgrade, final-zone timing 확인
- 봇 full night system 적용 전 AI cost와 behavior complexity review

## 보존 문서

| 경로 | 내용 |
|---|---|
| [archive/MASTERPLAN_full_2026-06-08.md](archive/MASTERPLAN_full_2026-06-08.md) | 야간 인공 숲 기획 압축 전 전체 로드맵 |
| [archive/MASTERPLAN_full_2026-05-26.md](archive/MASTERPLAN_full_2026-05-26.md) | v1.11.35 압축 전 전체 로드맵 |
| [archive/MASTERPLAN_full_2026-05-13.md](archive/MASTERPLAN_full_2026-05-13.md) | 이전 장문 마스터플랜 |
| [devlog/DEVLOG_full_2026-05-26.md](devlog/DEVLOG_full_2026-05-26.md) | v1.11.35 압축 전 전체 devlog |
| [devlog/v1.11_full_2026-05-26.md](devlog/v1.11_full_2026-05-26.md) | 압축 전 v1.11 슬라이스 요약 |

## 다음 에이전트 체크리스트

- 작업 전 [HANDOFF.md](HANDOFF.md), [DOCS_INDEX.md](DOCS_INDEX.md), 이 파일을 읽는다.
- 코드 변경 전 [IMPACT_MAP.md](IMPACT_MAP.md)에서 소유권과 영향 범위를 확인한다.
- 야간 인공 숲과 야간 시야 시스템이 반영되기 전까지 v2 telemetry는 구조 안전성 지표로 해석한다.
- `plan_report/`, `asset_generator/`, `docs/ASSET_GENERATION_PROMPTS.md`는 명시 요청 전까지 untracked로 둔다.
- 문서만 바꾸면 `git diff --check`로 검증하고, 코드 변경은 위험도에 맞춰 Godot/simulation check를 추가한다.
