# 맵 타일/배치 그룹 메모

> 최종 업데이트: 2026-07-20. 99명 규모 맵 배치를 다시 설계할 때 읽는 요약 문서다.

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

## Compound 문법

| 요소 | 역할 |
|---|---|
| 보상 중심 | loot와 시선이 모이는 마당. 직선 관통 시야는 건물 덩어리로 한 번 끊는다 |
| 건물·외곽 | 지역 실루엣과 `hard` 엄폐를 만든다. 내부 진입을 지원하지 않으면 닫힌 덩어리로 취급한다 |
| 복수 입구 | 최소 3방향, agent 폭보다 넓은 틈을 유지한다. 각 입구는 NavMesh 실제 경로로 검증한다 |
| 입구 어깨 | 입구 양옆 폐벽처럼 통로를 읽히게 하되 완전한 강제 복도는 만들지 않는다 |
| 접근 엄폐 | 입구 밖 1-2단의 낮은 프롭으로 노출 평지를 잘게 나눈다 |
| 외곽 차폐 | 수목·수풀로 장거리 시야를 끊되 탄도 엄폐와 혼동하지 않는다 |

엄폐 역할은 `hard`(이동+탄도+시야), `screen`(이동+시야), `soft`(이동)로 명시한다. Cabin Row는 남·서·동 입구와 중앙 마당을 첫 기준으로 쓴다.

참조한 공식 사례는 PUBG Pochinki의 노출 출구 엄폐 보강, Hunt Lawson Delta의 빈 벽을 복수 개구부·접근 엄폐로 바꾼 방식, Apex Quarantine Zone의 응축된 중심과 예측 가능한 회전, Warzone Drone Labs의 L자 건물·중앙 마당 구성이다.

보류 컴포넌트:

- 저엄폐 탄도: 자세와 발사 높이가 고정이라 현재 crate 높이와 실제 탄도 판정이 어긋난다.
- 진입형 cabin: 벽 분할 collision, 문, 내부 NavMesh와 카메라 지붕 숨김이 함께 필요하다.
- camp tarp: 쿼터뷰에서 캐릭터를 가리므로 지붕 fade/hide 계약 전에는 승격하지 않는다.
