# 플레이테스트 노트

> 최종 업데이트: 2026-07-17. 텔레메트리가 말하지 못하는 체감과 화면 판단을 짧게 기록한다.

## 현재 수동 테스트 대상

| 항목 | 값 |
|---|---|
| 빌드 표면 | `mapSpec_night_forest_expanded_candidate.json` 비기본 whitebox |
| 권장 preset | `xlarge_60` 임시 대표 수동 표면. `target_99_probe`는 자동 부하 검증 전용 |
| 현재 초점 | 5m 근거리 IDLE/RECOVER 반응, 대인 교전 지속·이탈, 외곽 픽업 이동, 장애물 가림 |

## 수동 체크리스트

- 플레이어 위치, 주변 위협, 픽업, 존 방향이 UI 과부하 없이 읽히는가?
- 첫 1분이 즉사/랜덤 충돌이 아니라 긴장으로 느껴지는가?
- 첫 non-pistol 픽업이 보이고, 위험하며, 획득감이 있는가?
- 맵이 단순 충돌이 아니라 경로 선택을 만드는가?
- stage2가 회전 압박을 만들면서 stage3 도달을 막지 않는가?
- 죽음의 이유가 플레이어 관점에서 이해되는가?
- `visual_review` preset에서 성능이 유지되는가?

```powershell
.\Godot_v4.6.2-stable_win64_console.exe --path . -- map_spec_path=res://data/mapSpec_night_forest_expanded_candidate.json scale_preset=xlarge_60
```

`visual_review`의 8봇 결과로 encounter 빈도나 매치 페이싱을 판정하지 않는다. `xlarge_60`도 승격된 기준선이 아니라 260m 구조의 수동 비교 표면이다.

플레이어 주변의 얇은 원은 `3.2m` 야간 주변 조명이며 AI 감지 범위 표시는 아니다. 이번 확인에서는 첫 10초와 이후 시점에 정지 상태로 봇의 옆·뒤 5m 안에 접근해 IDLE은 목표를 전환하고 RECOVER는 회피·반격하는지 본다.

## AI 빠른 재현 표면

`mapSpec_ai_test_arena.json`은 작은 AI 오류를 격리하는 `72m` 테스트 맵이다. 실제 Night BR의 조우 빈도나 페이싱 판정에는 사용하지 않는다.

| preset | 용도 |
|---|---|
| `duel_1` | 플레이어-봇 4.5m 고정, 초기 loot 없음. 감지·반응·1대1 상태 전이 |
| `squad_4` | 중앙 4방향 고정. 다중 위협·이탈·재교전 |
| `systems_8` | 중앙 8방향 고정 + loot. 상태 전이와 목표 충돌 스트레스 |
| `random_8` | 같은 맵의 무작위 스폰. 고정 앵커에만 재현되는지 비교 |

```powershell
.\Godot_v4.6.2-stable_win64_console.exe --path . -- map_spec_path=res://data/mapSpec_ai_test_arena.json scale_preset=duel_1 debug_flags=ai,perception,nav
python tools\run_verify.py --profile ai_test_arena
```

## 화면 리뷰 체크리스트

HUD, 메뉴, 픽업 라벨, 미니맵, 결과 화면을 바꾸면 실제 게임 화면으로 확인한다.

- 텍스트, 아이콘, 패널, 미니맵, 라벨이 서로 겹치지 않는가?
- 동적 값이 컨테이너를 넘거나 layout을 흔들지 않는가?
- HP, shield, alive count, zone, active weapon, focused pickup 순서가 분명한가?
- 어두운 지형과 zone overlay 위에서도 outline과 색 구분이 충분한가?
- `ZONE Ns`/`ZONE CLOSING`, reload/low ammo, killfeed 전환이 튀지 않는가?
- 1280x720 기준과 작은/넓은 화면에서 핵심 정보가 유지되는가?

수동 캡처는 게임 중 `F12`를 눌러 `debug_screenshot_manual.png`를 만든다. HUD 변경은 정상/낮은 HP, zone 변경은 대기/축소, inventory 변경은 빈 슬롯/가득 찬 슬롯처럼 동적 상태를 함께 확인한다.

반복 캡처가 필요할 때만 deterministic capture path를 구현한다. 일회성 mockup이나 별도 UI 보고서는 만들지 않는다.

## 기록 양식

```text
날짜:
표면:
테스트 변경:
결과: 채택 / 폐기 / 반복 필요
체감:
다음 행동:
```

## 최근 기록

### 2026-07-17 - Night 후보 실제 조작 1차

날짜: 2026-07-17
표면: `mapSpec_night_forest_candidate.json`, 사용자 직접 플레이와 `debug_screenshot_manual.png`.
테스트 변경: map/world route 표현, Night 가독성, 현재 AI와 맵 구조를 함께 체감 확인했다.
결과: route 표현 폐기, AI와 맵 구조 반복 필요.
체감: 정지하면 접촉이 적고 4봇이 플레이어를 견제하다 처리하지 않고 이탈했다. 플레이어는 원인을 이해할 수 있게 피해를 받았지만 너무 덜 죽었다. 추가 확인에서는 얇은 주변광 안에서 옆에 붙어도 봇이 반응하지 않았다. route 선은 과도하고 이질적이며 AI가 따르는 경로도 아니었다. cover는 읽혔지만 맵은 예상보다 좁고 평지가 많아 비어 보였다. 전체 지도는 게임 방향과 45도 어긋나 있었다.
다음 행동: route 표현과 지도 정렬 수정은 완료했다. 플레이어 근접 위협은 수동/duel에서 개선됐고, `squad_4`는 player 기억 5초 적용 후 격리 구간 유지율 100%를 통과한다. 자연 교전의 약 1m 근접 겹침을 다음에 분리한다.

### 2026-07-17 - N2-VIS-01 Night 월드 가독성

날짜: 2026-07-17
표면: `tools/run_verify.py --profile visual_review --out-root C:\tmp\n2_vis_01_final`, 캡처 `C:\tmp\player_night_readability.png`.
테스트 변경: Night 맵 전용 청색 주변광/달빛 프로필을 Main과 deterministic 캡처가 공유하고, cover·수풀 대비 gate를 추가했다.
결과: 채택.
체감: 플레이어/픽업 외에도 양쪽 cover, 수풀 덩어리, 지면 경계가 읽힌다. 어둠은 유지되며 화면 전체가 회색으로 뜨지 않는다.
다음 행동: v6와 visual run에서 open/off-route 교전이 우세하므로 route 폭, cover, POI 연결을 구조적으로 audit한다.

### 2026-06-29 - N2-PACE-31 v4 시각 리뷰

날짜: 2026-06-29
표면: `tools/run_verify.py --profile visual_review --out-root C:\tmp\game_dev_N2_PACE_31_visual_review`, 캡처 `C:\tmp\player_night_readability.png`, 페이싱 기준 `playable_pacing_v4`.
테스트 변경: initial non-pistol weapon을 initial loot에서 제거하고 stage/supply source가 첫 업그레이드 창을 담당하는 v4 후보.
결과: 반복 필요.
체감: 플레이어 실루엣, 픽업 라벨, 픽업 glow는 읽힌다. 주변 수풀/지형 윤곽은 매우 어두워서 route/cover 읽기는 별도 시각 패스가 필요하다. 1-run visual sim은 first contact 10.1초, first kill 23.4초, first upgrade 없음, hard-bump acquisition 0/1이었다.
다음 행동: `playable_pacing_v4`는 자동 후보로 유지하되, hard-bump threshold-only, zone, broad economy 변경을 반복하지 않고 오프닝 압박을 다룬 뒤에만 수동 기준선으로 승격한다.

## 메모

- `xlarge_60`은 수동 비교용, `target_99_probe`는 자동 구조 부하용이다.
- 텔레메트리 PASS는 플레이테스트 PASS가 아니다.
- `playable_pacing_v4`는 자동 기준 후보이지 수동 승격 기준선이 아니다.
- 명확하게 체감이 나쁘면 수동 기록 하나가 수치 후보를 뒤집을 수 있다.
