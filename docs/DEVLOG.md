# Battle Capsule 개발 로그

> 최종 업데이트: 2026-07-19. 최근 검증된 작업만 유지한다. 과거 내용은 Git 이력을 참조한다.

## N2-ASSET-01 핵심 전투·이동 오디오 승격

- 감사: catalog에는 무기 4종·지면 발걸음 3종 경로가 있었지만 실제 `assets/sfx/` 파일이 없어 시작할 때마다 7개 누락 경고와 procedural fallback이 발생했다.
- 수정: 생성 풀에서 해당 WAV만 승격하고 import metadata가 없는 실행에서도 raw WAV를 읽도록 했다. 성공 스트림은 사운드 ID별로 캐시한다.
- 검증: 전용 smoke가 경로·파일·길이·캐시 재사용·누락 0을 확인하고 전체 `unit_smoke`가 통과했다. 60봇 Forward+ 2회는 p95 15.5-16.5ms, p99 20.7-26.6ms였다.
- 안정화: wall traffic은 플레이어와의 최소 거리 대신 벽 북쪽 `z=35` 통과를 판정해 fixture 목적과 일치시켰다. 시간 12초와 stuck 최대 4는 유지했다.
- 다음: N2-PLAY-03에서 거점 동선과 함께 무기 식별, 발걸음 거리감, 야간 분위기 적합성을 수동 판정한다.

## N2-MAP-10 loot hub 자연 엄폐 후보

- 감사: 260m 맵을 카메라 크기, 방사 대역, 빈 셀, POI별 물리·은폐 비율로 계측했다. 중앙/남쪽 loot hub 개방률은 80.2/39.5%였다.
- 수정: 인공 route 선이나 wall/high rock 없이 중앙에 수목·수풀 각 2개, 남쪽에 각 1개를 추가했다. 고정 좌표 실제 카메라 캡처로 중심 통과 폭과 양측 접근을 조정했다.
- 검증: 중앙/남쪽 개방률 16.0/17.3%, 60/99봇 POI 피해 45.6/37.3%, stuck 약 0.01/0.00. 60봇 Forward+ p95 15.8-16.1ms, 전체 `unit_smoke` 통과.
- 다음: N2-PLAY-03에서 중앙·남쪽 pickup 접근과 우회가 자연스러운지 수동 판정한다.

## N2-PERF-02 Minimap 정적 지도 캐시

- 진단: 실제 Minimap 정상 로드 뒤 60봇 Forward+ p95 36.6-39.1ms, 33ms 초과 9.2-13.1%, draw call 평균 502-519로 회귀했다. Minimap 비표시는 p95 21.7ms였다.
- 원인: 배경·POI·64개 지형 footprint를 `_draw()`에서 매 프레임 다시 만들고 제출했다. navigation p95는 0.03ms 이하라 병목이 아니었다.
- 수정: 정적 지도는 `SubViewport.UPDATE_ONCE` 텍스처로 굽고 supply·zone·player만 실시간 overlay에 남겼다. profiler에는 Minimap 비표시 대조 옵션을 추가했다.
- 검증: 반복 2회 p95 15.4-15.8ms, p99 21.1-23.9ms, 33ms 초과 0.14-0.27%. 방향 캡처와 정적 캐시 gate, `unit_smoke`를 통과했다.
- 다음: N2-MAP-10에서 올바른 260m 월드의 빈 공간·픽업·물리 병목을 감사하고 후보는 하나만 만든다.

## N2-NAV-03 Minimap 물리 오염 제거

- 재현: 실제 260m 맵의 봇 하나가 `(4.2,44.5)`에서 유효한 9점 경로를 가진 채 반복 정체했다. 충돌 진단은 `/HUD/Minimap/Cabin_South/Wall2`를 지목했다.
- 원인: `Main.tscn`의 Minimap 외부 리소스 UID가 `TestMap.tscn` UID여서 legacy 테스트 맵 물리가 UI 하위에 로드됐다. 경로 허용치와 high rock proxy 가설은 폐기했다.
- 수정: Minimap UID를 교정하고 zone 초기화 null guard를 추가했다. 제품 hotspot smoke는 Minimap 하위 충돌체 0개, 8초 내 ZONE_ESCAPE 종료, stuck 1 이하를 요구한다.
- 검증: hotspot은 약 5.1초·stuck 0, `unit_smoke` 통과. 동일 seed 60봇은 종료 245.6초·stuck 1.4·AI 317.9µs·open 피해 63.0%였다.
- 확대: 99봇은 종료 239.8초·stuck 1.2·AI 435.6µs·open 피해 69.6%였다. disengage 165.8회는 별도 실패로 유지한다.
- 다음: 오염된 물리 기준과 수치가 달라졌으므로 N2-PERF-02에서 60봇 Forward+ 프레임을 다시 측정한다.

## N2-NAV-02 실제 내비게이션 메시 복구

- 원인: runtime `NavigationRegion3D`는 `WorldBuilder`의 형제였고 기본 child scan을 사용해 bake 결과가 `polygons=0, vertices=0`이었다. 봇은 실제 경로 없이 direct fallback과 stuck override로만 이동했다.
- 수정: WorldBuilder와 하위 static collider를 source group으로 명시해 실제 geometry를 bake했다. voxel 양자화 실효값에 맞춰 agent height/radius/climb 기본값도 2.0/0.6/0.25로 정렬했다.
- Arena: rock 횡단은 stuck 1→0, open traffic은 5/5회 약 5.0초·stuck 0, 강제 wall traffic은 5/5회 11.0초·stuck 4였다. runtime gate는 빈 메시를 즉시 실패시킨다.
- Night: 동일 seed 60봇은 stuck 39.0→2.8·AI 341.9→260.7µs·종료 225.1→222.5초, 99봇은 53.2→12.4·473.0→353.6µs·199.7→222.9초였다.
- 잔여: 99봇 정체의 59.7%가 `0,40` ZONE_ESCAPE에 몰렸고 disengage 166.8회는 실패 유지다. 다음은 두 문제를 섞지 않고 hotspot부터 격리한다.

## N2-MAP-09 다중 traffic gate와 wall 후보 기각

- Arena: 기존 진단 구역과 분리된 96m 맵에 open/wall 4봇 traffic preset을 추가했다. open은 5/5회 4.20초·stuck 0이었다.
- primitive: low log는 1봇도 nav가 상단을 walkable로 보고 11.75m/stuck 3에서 실패했다. 폭 8m·18도 wall도 실패했고 축 정렬 폭 4m wall만 5/5회 6.55초·stuck 2로 통과했다.
- 제품 60봇: 동일 seed에서 전체 stuck 39.0→26.6, duration 225.1→242.0초였지만 직접 셀 `10,10`은 0→16회, open 피해는 69.7→69.6%였다.
- 결정: 제품 wall과 전용 계약을 제거하고 99봇 확대를 중단했다. Arena traffic gate만 유지하고 N2-NAV-02에서 wall stuck 0을 요구한다.

## N2-MAP-08 중앙 초원 high rock 재기각

- 조건: ramp 제거 뒤 `[17,12]` high rock 하나를 복원했다. 구조 gate와 실제 260m 맵 32m CHASE는 5/5회 2.8-3.0m, stuck 1회로 통과했다.
- 동일 seed 60봇: 기준선 대비 평균 종료 225.1→201.0초, open 피해 69.7→69.9%, loot-hub 10.4→12.2%, 전체 stuck 39.0→43.6이었다.
- 국소 회귀: `10,10` stuck이 0→5회로 5-run 중 4회 발생했고 별도 5-run에서도 14회였다. 1대1 횡단은 다중 traffic 보장이 아니다.
- 결정: 후보·전용 gate를 제거하고 99봇 확대를 중단했다. high rock 추가 배치를 금지하고 비-rock 엄폐를 다중 traffic Arena에서 먼저 비교한다.

## N2-AI-07 POI 목적지 수렴 감사

- 구현: spawn 반경 대역·POI·route 점유를 한 번 계산하는 `SpawnDistributionMetrics`를 분리하고 loot 목적지 POI 이름을 JSON과 분석기에 연결했다.
- 결과: 60/99봇 spawn은 POI 내부 25.7/26.5%, IDLE loot 목표는 66.3/67.2%가 내부이고 약 90%가 route 위였다. 전투 피해는 open 70-71%였다.
- 판단: AI가 pickup 배치를 소비하지 않는 것이 아니라 POI에서 교전이 개방지로 유출된다. 단일 99봇 진단에서 `Central Meadow`가 IDLE loot 113/300으로 가장 커 다음 whitebox 대상으로 정했다.
- 검증: `unit_smoke` 통과. 60/99봇 각 5-run 완료. 99봇 gate는 기존 구조 실패인 stuck 75.4>60, disengage 156.4>130을 유지했다.

## N2-PLAY-02 60봇 성능 수동 통과

- 표면: 확장 Night whitebox `xlarge_60`, 사용자 직접 플레이.
- 결과: N2-PERF-01 뒤 이전의 심한 렉이 확실히 줄었다. 앞서 통과한 조우·간격·공격·추적·사망 압박 판단도 유지한다.
- 결정: 성능 미세조정을 종료하고 AI 목적지 결정과 확장 맵 흐름 연결로 이동한다.

## N2-PERF-01 60봇 프레임 안정화

- 진단: Forward+ 60봇 기준 프레임 p95 45.5ms, 33ms 초과 12.8%. 렌더보다 동기화된 perception/sensory와 매 프레임 표적·픽업·후퇴 위협 검색, 교리 위치 텔레메트리가 병목이었다.
- 수정: 갱신 위상 분산, 0.10-0.25초 상태 인식 캐시, 교리 텔레메트리 0.25초 누적 기록, nav target 0.35m 갱신과 상태/stuck 복구 시 재경로를 적용했다. 픽업 상태 변화와 이미 공개된 근접 표적은 즉시 캐시를 무효화한다.
- 검증: 최종 60봇 p95 13.5ms, p99 17.5ms, 33ms 초과 0.04%. 동일 seed 99봇 대조에서 AI 평균 476→353µs, stuck 0.15→0.16, ATTACK+CHASE -0.58%p. `unit_smoke` 통과.
- 잔여: 확장 whitebox `scale_99`는 기존 disengage 161.6>130으로 실패한다. 성능 회귀와 구분하며 다음은 `xlarge_60` 수동 끊김 재확인이다.

## 기록 보존

이 문서는 최근 10개 작업 또는 120줄까지만 유지한다. 오래된 항목과 삭제된 전체 사본은 `git log -- docs/DEVLOG.md docs/MASTERPLAN.md`로 찾고, 필요한 커밋에서만 읽는다.
