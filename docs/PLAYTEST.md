# 플레이테스트 노트

> 최종 업데이트: 2026-06-30. 텔레메트리가 말하지 못하는 체감 판단을 짧게 기록한다.

## 현재 수동 테스트 대상

| 항목 | 값 |
|---|---|
| 빌드 표면 | `mapSpec_night_forest_candidate.json` |
| 권장 preset | 수동 체감: `visual_review`, 자동 페이싱: `playable_pacing_v4` |
| 현재 초점 | 야간 가독성, 오프닝 압박, v4 non-pistol 업그레이드 창, stage2-stage3 전환 |

## 수동 체크리스트

- 플레이어 위치, 주변 위협, 픽업, 존 방향이 UI 과부하 없이 읽히는가?
- 첫 1분이 즉사/랜덤 충돌이 아니라 긴장으로 느껴지는가?
- 첫 non-pistol 픽업이 보이고, 위험하며, 획득감이 있는가?
- 맵이 단순 충돌이 아니라 경로 선택을 만드는가?
- stage2가 회전 압박을 만들면서 stage3 도달을 막지 않는가?
- 죽음의 이유가 플레이어 관점에서 이해되는가?
- `visual_review` preset에서 성능이 유지되는가?

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
