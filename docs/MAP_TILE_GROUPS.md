# 맵 타일/배치 그룹 메모

> 최종 업데이트: 2026-06-30. 99명 규모 맵 배치를 다시 설계할 때 읽는 요약 문서다.

## 목적

Night Artificial Forest 후보 맵에서 POI, route, cover, loot source가 단순 산개가 아니라 전술적 흐름을 만들도록 배치 그룹을 관리한다.

## 주요 배치 역할

| 역할 | 의미 | 주의 |
|---|---|---|
| `transit_choke` | 이동과 전투가 자주 만나는 통로 | 과밀하면 opening pressure와 stuck 증가 |
| `loot_hub` | 높은 보상/위험 loot 영역 | initial non-pistol spike 주의 |
| `concealment_field` | 수풀/은신 기반 회전 영역 | 너무 어두우면 route/cover가 안 읽힘 |
| `recovery_pocket` | 회복/재정비 여지 | 너무 강하면 교전 밀도 저하 |
| `flank` | 우회 경로 | stuck cell과 route dwell 확인 |
| `open` | 노출 공간 | 무의미한 bot collision이 되지 않게 cover와 연결 |

## 현재 watch 지표

- spawn fallback: 0 유지.
- min nearest spawn: 5m 이상 유지.
- stuck route/cell 상위 항목 확인.
- combat damage가 특정 choke에 과도하게 몰리는지 확인.
- pickup collect route가 off-route에만 몰리지 않는지 확인.

## 변경 원칙

- spawn-spacing-only로 opening 문제를 해결하려 하지 않는다.
- loot_hub/concealment에 non-pistol 초기 spike를 다시 만들지 않는다.
- route를 추가하면 minimap/full map, telemetry route role, pathing watch를 같이 확인한다.
- visual prop만 바꿀 때도 collision authority를 명확히 한다.
