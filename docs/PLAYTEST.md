# 플레이테스트 노트

> 최종 업데이트: 2026-07-17. 텔레메트리가 말하지 못하는 체감과 화면 판단을 짧게 기록한다.

## 현재 수동 테스트 대상

| 항목 | 값 |
|---|---|
| 빌드 표면 | `mapSpec_night_forest_candidate.json` |
| 권장 preset | 수동 체감: `visual_review`, 자동 페이싱: `playable_pacing_v4` |
| 현재 초점 | map/world route 연결, 야간 가독성, 오프닝 압박, v4 non-pistol 업그레이드 창 |

## 수동 체크리스트

- 플레이어 위치, 주변 위협, 픽업, 존 방향이 UI 과부하 없이 읽히는가?
- 첫 1분이 즉사/랜덤 충돌이 아니라 긴장으로 느껴지는가?
- 첫 non-pistol 픽업이 보이고, 위험하며, 획득감이 있는가?
- 맵이 단순 충돌이 아니라 경로 선택을 만드는가?
- stage2가 회전 압박을 만들면서 stage3 도달을 막지 않는가?
- 죽음의 이유가 플레이어 관점에서 이해되는가?
- `visual_review` preset에서 성능이 유지되는가?

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

### 2026-07-17 - N2-MAP-03 World Route Cue 자동 화면 리뷰

날짜: 2026-07-17
표면: `tools/run_verify.py --profile visual_review`, 캡처 `C:\tmp\world_route_cues_overview.png`, `C:\tmp\world_route_cues_player_view.png`.
테스트 변경: map UI의 route 역할을 폭 0.26-0.36m의 비충돌 ground strip으로 world에 연결하고 역할별 4개 MultiMesh로 배치했다.
결과: 자동 화면 채택, 실제 조작 반복 필요.
체감: 조감에서 6개 route가 좌표대로 이어지고 Wire Maze 플레이 시점에서 primary/flank가 낮은 strip으로 구분되며 통나무 아래에서 가려진다. 실제 첫 1분의 시선 우선순위와 전투 중 강도는 아직 미확정이다.
다음 행동: 실제 조작으로 첫 1분을 플레이하며 route/cover 판독, cue 과표시, 첫 교전 이해도를 기록한다.

### 2026-07-17 - N2-MAP-02 Map Route 가시화

날짜: 2026-07-17
표면: `tools/run_verify.py --profile visual_review --out-root C:\tmp\n2_map_02_visual`, 캡처 `C:\tmp\full_map_routes.png`, `C:\tmp\minimap_routes.png`.
테스트 변경: primary, flank, loot, recovery route를 공유 색·선형으로 minimap/fullmap의 POI·cover 아래에 표시했다.
결과: 채택.
체감: 1280x720 fullmap과 240x240 minimap에서 primary 실선, flank 점선, loot 녹색, recovery 보라 점선이 zone·POI와 구분된다. 중앙 교차부는 조밀하지만 경로 연속성은 유지된다.
다음 행동: map UI만 보고 끝내지 않고 collider 없는 world route cue로 실제 이동 화면과 연결한다.

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

- `xlarge_60`, `target_99_probe`는 구조 부하 테스트다. 체감 리뷰에 쓰지 않는다.
- 텔레메트리 PASS는 플레이테스트 PASS가 아니다.
- `playable_pacing_v4`는 자동 기준 후보이지 수동 승격 기준선이 아니다.
- 명확하게 체감이 나쁘면 수동 기록 하나가 수치 후보를 뒤집을 수 있다.
