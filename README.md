# 배틀 캡슐

<p align="center">
  <img src="assets/icons/artifacts/red_trigger.png" width="72" alt="레드 트리거">
  <img src="assets/icons/artifacts/ghost_grass.png" width="72" alt="고스트 그래스">
  <img src="assets/icons/artifacts/zone_battery.png" width="72" alt="존 배터리">
</p>

<p align="center">
  <strong>쿼터뷰 배틀로얄 프로토타입</strong><br>
  루팅, 은신, 자기장 압박, 아티팩트 선택이 짧은 생존전 안에서 충돌하는 Godot 게임입니다.
</p>

<p align="center">
  <a href="https://godotengine.org/"><img alt="Godot 4.6.2" src="https://img.shields.io/badge/Godot-4.6.2-478CBF?style=for-the-badge&logo=godot-engine&logoColor=white"></a>
  <a href="https://github.com/Kyulhee/battle-capsule/releases/tag/v2.0.0-pre-expansion"><img alt="안정 빌드" src="https://img.shields.io/badge/안정판-v2.0.0_pre--expansion-2EA043?style=for-the-badge"></a>
  <a href="https://github.com/Kyulhee/battle-capsule/releases"><img alt="다운로드" src="https://img.shields.io/badge/다운로드-Windows%20%7C%20macOS-111111?style=for-the-badge"></a>
</p>

---

## 다운로드

현재 안정 빌드: **v2.0.0-pre-expansion**

| 플랫폼 | 다운로드 | 비고 |
|---|---|---|
| Windows | [BattleRoyalePrototype_v2.0.0-pre-expansion_win64.zip](https://github.com/Kyulhee/battle-capsule/releases/download/v2.0.0-pre-expansion/BattleRoyalePrototype_v2.0.0-pre-expansion_win64.zip) | 로컬 최소 실행 검증 완료 |
| macOS | [BattleRoyalePrototype_v2.0.0-pre-expansion_macos.zip](https://github.com/Kyulhee/battle-capsule/releases/download/v2.0.0-pre-expansion/BattleRoyalePrototype_v2.0.0-pre-expansion_macos.zip) | Windows에서 교차 내보내기. 첫 실행 시 개인정보 보호 및 보안 허용이 필요할 수 있음 |

> 이 빌드는 대규모 확장 전 안정 스냅샷입니다. 99인/야간 맵 작업은 아직 개발용 probe 단계이며 기본 게임 모드로 승격하지 않았습니다.

## 게임 요약

배틀 캡슐은 플레이어 1명이 숲 형태의 전장에 진입해 봇들과 싸우는 작은 배틀로얄 프로토타입입니다. 무기와 보급품을 줍고, 아티팩트 하나를 선택한 뒤, 점점 좁아지는 자기장 안에서 마지막까지 살아남아야 합니다.

| 핵심 축 | 현재 구현 |
|---|---|
| 생존 압박 | 파란 자기장이 좁아지며 이동과 후반 교전을 강제 |
| 루팅 경로 | 무기, 탄약, 회복, 방어구, 보급 캡슐이 위험/보상 선택을 만듦 |
| 은신과 가독성 | 부쉬, 웅크리기, 시야, 야간 가독성을 주요 설계 축으로 유지 |
| 아티팩트 개성 | 강한 장점과 그에 맞는 패널티를 함께 부여 |
| AI 확장 준비 | 더 큰 매치 실험을 위해 인식/감각 LOD를 정리 중 |

## 아티팩트

| 아티팩트 | 역할 |
|---|---|
| <img src="assets/icons/artifacts/red_trigger.png" width="32" alt=""> **레드 트리거** | 강한 샷건 압박과 더 긴 노출 위험 |
| <img src="assets/icons/artifacts/armor_sponge.png" width="32" alt=""> **아머 스펀지** | 회복을 실드로 전환하지만 실드가 늘수록 느려짐 |
| <img src="assets/icons/artifacts/silent_core.png" width="32" alt=""> **사일런트 코어** | 조용한 이동 정체성과 첫 사격 제약 |
| <img src="assets/icons/artifacts/zone_battery.png" width="32" alt=""> **존 배터리** | 자기장 근처 플레이와 파란 플라즈마 피드백 |
| <img src="assets/icons/artifacts/emergency_shell.png" width="32" alt=""> **탈출 캡슐** | 긴급 회복을 제공하지만 후속 비용이 큼 |
| <img src="assets/icons/artifacts/ghost_grass.png" width="32" alt=""> **고스트 그래스** | 부쉬 기반 은신과 취약 시간 설계 |

## 현재 개발 방향

프로젝트는 짧은 프로토타입에서 **10-15분 야간 배틀로얄** 구조로 확장하는 중입니다. 다만 한 번에 99인 완성판으로 올리지 않고, 아래 순서로 안전하게 검증합니다.

1. 대규모 확장 전 안정 빌드를 유지합니다.
2. 전체 맵을 매번 완성 체감으로 검증하지 않고, POI 단위 probe와 구조 telemetry를 병행합니다.
3. 야간 가독성, 손전등, 배터리, 봇 야간 인지를 단계적으로 추가합니다.
4. scale telemetry는 최종 밸런스 지표가 아니라 구조 안전성 게이트로 사용합니다.

현재 로드맵은 [docs/MASTERPLAN.md](docs/MASTERPLAN.md), 야간 배틀로얄 페이싱 계획은 [docs/NIGHT_BR_PACING_PLAN.md](docs/NIGHT_BR_PACING_PLAN.md)에 정리되어 있습니다.

## 조작법

<details>
<summary>조작법 펼치기</summary>

| 키 | 동작 |
|---|---|
| `WASD` | 이동 |
| 마우스 | 조준 |
| 좌클릭 | 사격 또는 근접 공격 |
| `F` | 근처 아이템 줍기 |
| `Q` | 회복 아이템 사용 |
| `C` | 웅크리기 토글 |
| `R` | 예비 탄약으로 재장전 |
| `` ` `` | 칼 슬롯 |
| `1`-`4` | 무기 슬롯 |
| `Space` | 점프 |
| `Esc` | 일시정지/메뉴 |

</details>

## 무기와 아이템

<details>
<summary>장비 표 펼치기</summary>

| 무기 | 탄창 | 예비 탄약 | 역할 |
|---|---:|---:|---|
| 칼 | - | - | 항상 사용 가능한 최후 수단 |
| 피스톨 | 15 | 30 | 기본 지급 무기 |
| 돌격소총 | 30 | 60 | 안정적인 지속 화력 |
| 샷건 | 6 | 12 | 근거리 폭발력 |
| 레일건 | 2 | 4 | 느리지만 강한 정밀 사격 |

| 아이템 | 효과 |
|---|---|
| 회복 아이템 | HP 회복 |
| 고급 회복 아이템 | 더 큰 회복량 |
| 방어구 | 실드 추가 |
| 탄약 | 해당 무기의 예비 탄약 추가 |
| 보급 캡슐 | 자기장 진행 후 희귀 전투 옵션 제공 |

</details>

## 프로젝트 문서

| 문서 | 용도 |
|---|---|
| [docs/DOCS_INDEX.md](docs/DOCS_INDEX.md) | 처음 읽을 문서 안내 |
| [docs/MASTERPLAN.md](docs/MASTERPLAN.md) | 현재 로드맵과 작업 범위 |
| [docs/DEVLOG.md](docs/DEVLOG.md) | 최근 검증 작업 로그 |
| [docs/TESTING.md](docs/TESTING.md) | 검증 명령과 telemetry 해석 |
| [docs/ASSET_STATUS.md](docs/ASSET_STATUS.md) | 통합/보류 에셋 상태 |
| [docs/RELEASE.md](docs/RELEASE.md) | 빌드와 릴리즈 절차 |

## 개발

필요 환경:

- Godot **4.6.2**
- Windows 내보내기가 우선 최소 실행 검증 대상입니다.
- macOS 내보내기는 Godot에서 생성하며, 공개 배포 전 실제 Mac에서 한 번 더 실행 확인이 필요합니다.

자주 쓰는 로컬 검증:

```powershell
.\Godot_v4.6.2-stable_win64_console.exe --headless --script res://tools/verify_ai_lod_perception.gd
.\Godot_v4.6.2-stable_win64_console.exe --headless --script res://tools/verify_pickup_light_lod.gd
.\Godot_v4.6.2-stable_win64_console.exe --headless --script res://tools/verify_player_night_readability.gd
```

## 참고 사항

- 일부 생성 에셋 경로가 로컬 빌드에서 없을 수 있지만 대체 표시가 활성화되어 있습니다.
- 현재 작업 브랜치에는 기본 승격 전의 99인/야간 맵 probe가 포함될 수 있습니다.
- 최신 공개 안정 기준점은 GitHub 태그 `v2.0.0-pre-expansion`입니다.
