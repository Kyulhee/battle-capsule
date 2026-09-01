# 배틀 캡슐

<p align="center">
  <img src="assets/icons/artifacts/red_trigger.png" width="72" alt="레드 트리거">
  <img src="assets/icons/artifacts/ghost_grass.png" width="72" alt="고스트 그래스">
  <img src="assets/icons/artifacts/zone_battery.png" width="72" alt="존 배터리">
</p>

<p align="center">
  <strong>60인 야간 쿼터뷰 배틀로얄</strong><br>
  루팅, 은신, 자기장 압박, 아티팩트 선택이 10-15분 생존전 안에서 충돌하는 Godot 게임입니다.
</p>

<p align="center">
  <a href="https://godotengine.org/"><img alt="Godot 4.6.2" src="https://img.shields.io/badge/Godot-4.6.2-478CBF?style=for-the-badge&logo=godot-engine&logoColor=white"></a>
  <a href="https://github.com/Kyulhee/battle-capsule/releases/tag/v2.1.0-demo-dev"><img alt="테스트 빌드" src="https://img.shields.io/badge/프리릴리즈-v2.1.0_demo--dev-D29922?style=for-the-badge"></a>
  <a href="https://github.com/Kyulhee/battle-capsule/releases/tag/v2.0.0-pre-expansion"><img alt="안정 빌드" src="https://img.shields.io/badge/안정판-v2.0.0_pre--expansion-2EA043?style=for-the-badge"></a>
  <a href="https://github.com/Kyulhee/battle-capsule/releases"><img alt="다운로드" src="https://img.shields.io/badge/다운로드-Windows%20%7C%20macOS-111111?style=for-the-badge"></a>
</p>

---

## 다운로드

현재 테스트 빌드: **v2.1.0-demo-dev**<br>
현재 안정 빌드: **v2.0.0-pre-expansion**

| 플랫폼 | 다운로드 | 비고 |
|---|---|---|
| Windows x64 | [BattleCapsule_v2.1.0-demo-dev_win64.zip](https://github.com/Kyulhee/battle-capsule/releases/download/v2.1.0-demo-dev/BattleCapsule_v2.1.0-demo-dev_win64.zip) | clean package 계약과 자동 전체 매치 검증. 미서명 테스트 빌드 |
| macOS Universal 2 | [BattleCapsule_v2.1.0-demo-dev_macos_universal.zip](https://github.com/Kyulhee/battle-capsule/releases/download/v2.1.0-demo-dev/BattleCapsule_v2.1.0-demo-dev_macos_universal.zip) | Intel/Apple Silicon 교차 내보내기. 미서명·미공증, 실제 Mac 실행 미검증 |

> `v2.1.0-demo-dev`는 현재 60봇 Night BR을 미리 확인하는 **프리릴리즈**입니다. 안정판 교체나 공개 데모 승격이 아니며, 알려진 제한은 [릴리즈 노트](docs/releases/v2.1.0-demo-dev.md)에 정리했습니다. macOS에서 처음 실행할 때 Gatekeeper 경고가 표시될 수 있습니다.

## 게임 요약

배틀 캡슐은 플레이어 1명이 야간 숲 전장에 진입해 60명의 봇과 싸우는 싱글플레이 배틀로얄입니다. 지역별 보급품을 찾아 이동하고, 아티팩트 하나를 선택한 뒤, 점점 좁아지는 자기장 안에서 마지막까지 살아남아야 합니다.

| 핵심 축 | 현재 구현 |
|---|---|
| 생존 압박 | 파란 자기장이 좁아지며 이동과 후반 교전을 강제 |
| 루팅 경로 | 무기, 탄약, 회복, 방어구, 보급 캡슐이 위험/보상 선택을 만듦 |
| 은신과 가독성 | 부쉬, 웅크리기, 시야, 야간 가독성을 주요 설계 축으로 유지 |
| 아티팩트 개성 | 강한 장점과 그에 맞는 패널티를 함께 부여 |
| AI 전장 흐름 | POI, 보급, 엄폐, 자기장 압박을 함께 평가하며 이동·교전 |

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

프로젝트는 **10-15분 60봇 야간 배틀로얄**을 먼저 완성하는 중입니다. 한 번에 99인 완성판으로 올리지 않고, 아래 순서로 검증합니다.

1. 기존 안정 빌드는 유지하고 개발 후보는 프리릴리즈로 분리합니다.
2. 자동 전체 매치와 사람이 직접 하는 3판 검증을 함께 사용합니다.
3. 신규 콘텐츠보다 야간 가독성, 전투 피드백, HUD, 첫 사용자 흐름을 먼저 마감합니다.
4. 99인 scale telemetry는 최종 밸런스가 아니라 구조 안전성 게이트로만 사용합니다.

현재 로드맵과 야간 배틀로얄 페이싱 기준은 [docs/MASTERPLAN.md](docs/MASTERPLAN.md)에 함께 정리되어 있습니다.

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
| [docs/reference/TESTING.md](docs/reference/TESTING.md) | 검증 명령과 telemetry 해석 |
| [docs/assets/ASSET_STATUS.md](docs/assets/ASSET_STATUS.md) | 통합/보류 에셋 상태 |
| [docs/reference/RELEASE.md](docs/reference/RELEASE.md) | 빌드와 릴리즈 절차 |
| [docs/releases/v2.1.0-demo-dev.md](docs/releases/v2.1.0-demo-dev.md) | 현재 프리릴리즈 내용과 알려진 제한 |

## 개발

필요 환경:

- Godot **4.6.2**
- Windows x64가 현재 우선 지원·검증 대상입니다.
- macOS는 Universal 2로 내보내지만 현재 테스트 제공 범위이며, 지원 대상으로 승격하기 전에 실제 Intel/Apple Silicon Mac 실행·서명·공증 확인이 필요합니다.

자주 쓰는 로컬 검증:

```powershell
.\Godot_v4.6.2-stable_win64_console.exe --headless --script res://tools/verify_ai_lod_perception.gd
.\Godot_v4.6.2-stable_win64_console.exe --headless --script res://tools/verify_pickup_light_lod.gd
.\Godot_v4.6.2-stable_win64_console.exe --headless --script res://tools/verify_player_night_readability.gd
```

## 참고 사항

- 프리릴리즈에는 수동 3판, 실제 Mac, 다중 하드웨어 검증이 아직 남아 있습니다.
- 99인 모드는 구조 회귀용 probe이며 현재 배포 gameplay가 아닙니다.
- 최신 공개 안정 기준점은 GitHub 태그 `v2.0.0-pre-expansion`입니다.
