# UI 시각 리뷰 가이드

> 최종 업데이트: 2026-06-30. UI 변경은 코드 의도보다 실제 화면 캡처로 판단한다.

## 적용 범위

HUD, 메뉴, 픽업 라벨, 미니맵, 결과 화면, 설정, 도움말, visible UI state를 바꾸는 작업에 사용한다.

## 확인 질문

- 텍스트, 아이콘, 패널, 미니맵, 라벨이 겹치지 않는가?
- 실제 게임 배경 위에서 중요한 정보가 읽히는가?
- 텍스트가 컨테이너 안에 들어가는가?
- 동적 값이 layout 크기나 위치를 흔들지 않는가?
- 1280x720 기준과 작은/넓은 화면에서도 유지되는가?

## 현재 캡처 지원

수동 캡처:

```text
F12 -> debug_screenshot_manual.png
```

구현 위치:

- `src/Main.gd`의 `KEY_F12`
- `_take_screenshot("debug_screenshot_manual.png")`

기본 viewport:

```text
1280x720
```

## 기본 리뷰 절차

1. 게임을 실행하고 관련 화면에서 F12 캡처.
2. 이미지로 직접 확인.
3. 비시각 검증 실행:

```powershell
git diff --check
.\Godot_v4.6.2-stable_win64_console.exe --path . --headless --quit
python tools\simulate_matches.py 1
```

문서/문구만 바뀐 경우 screenshot과 simulation은 생략할 수 있다.

## 변경 유형별 필요한 캡처

| 변경 | 캡처 |
|---|---|
| HUD 상태/체력/실드/미션 | 정상 상태, 낮은 HP/피해 상태 |
| Zone timer/warning | `ZONE Ns`, `ZONE CLOSING` |
| 픽업 라벨/아이콘/glow | sparse pickup, dense pickup, focus candidate |
| 무기 슬롯 HUD | empty, full inventory, reload/low ammo |
| 메뉴/설정/도움말/기록 | 변경 panel별 기본 viewport |
| 미니맵/full map | normal, zone closing, supply/loot marker |
| 결과 화면 | win/loss |

## 체크리스트

### Layout

- UI 요소가 서로 겹치지 않는다.
- 버튼/패널/슬롯/라벨 내부에 텍스트가 들어간다.
- 동적 값이 layout을 밀지 않는다.
- top-left HUD, center zone text, killfeed, minimap, bottom slot bar가 서로 싸우지 않는다.
- loot cluster에서 pickup label이 화면 중앙을 덮지 않는다.

### Readability

- HP, shield, alive count, zone, active weapon, focused pickup이 먼저 읽힌다.
- 보조 정보는 낮은 우선순위로 보인다.
- 어두운 지형/건물/zone overlay/glow 위에서 outline이나 shadow가 충분하다.
- 아이콘은 실제 게임 크기에서도 알아볼 수 있다.
- danger, rare, armor, heal, ammo, common loot 색이 구분된다.

### State

- `ZONE Ns`와 `ZONE CLOSING` 전환이 튀지 않는다.
- killfeed가 다른 HUD 영역으로 넘치지 않는다.
- reload/low ammo 표시가 layout jitter 없이 갱신된다.
- pause/settings/help/records/result에서 이전 화면으로 정상 복귀한다.

## 향후 자동 캡처 방향

반복 UI 리뷰가 필요하면 임시 mockup branch보다 deterministic capture path를 추가한다.

예시:

```powershell
.\Godot_v4.6.2-stable_win64_console.exe --path . -- ui_capture=true ui_state=pickup_dense screenshot=ui_pickup_dense_1280x720.png
```

권장 state: `hud_normal`, `hud_zone_closing`, `pickup_sparse`, `pickup_dense`, `inventory_full`, `menu_main`, `panel_help`, `panel_records`, `panel_settings`, `result_win`.
