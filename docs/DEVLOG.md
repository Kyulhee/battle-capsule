# Battle Capsule 개발 로그

> 최종 업데이트: 2026-07-17. 최근 검증된 작업만 유지한다. 과거 내용은 Git 이력을 참조한다.

## N2-AI-01 플레이어 표적 위협 판정

- 원인: outnumbered 판정이 현재 표적과 단순 방관자까지 모두 세어 `DEFENSIVE`/`SNIPER`는 1대1에서도 즉시 이탈하고, 여러 봇이 플레이어를 공격하면 서로를 보고 흩어졌다.
- 실패 후보: 실제 압박 위협만 세는 판정을 모든 교전에 적용했으나 5-run에서 평균 516.9초, 2개 run 300초 미만, first upgrade 1회 누락, stuck 0.17로 gate 실패했다.
- 채택 범위: 플레이어를 현재 표적으로 둔 경우에만 자신을 추적하거나 최근 5초 안에 공격한 제3자를 센다. bot-only는 기존 가시 적 판정을 유지한다.
- 검증: 현재 표적, 방관자, 추적자, 최근/만료 공격자를 구분하고 bot-only 계약 보존을 확인하는 smoke를 추가했다. `unit_smoke` 통과.
- 다음: 180m/장애물 4.2% 맵과 8봇/99봇 표면 불일치를 해소하는 whitebox를 설계한다.

## N2-PACE-43 초기 Pickup 간격 폐기

- 근거: v6 spawn은 최소 5.0m, fallback 0으로 정상이지만 첫 획득 4/5가 같은 route·POI 안 1.0-1.2m에서 발생했다. 초기 pickup 배치에는 상호 간격 검사가 없었다.
- 후보: v6의 수량, 종류, AI, zone, damage를 유지하고 초기 pickup끼리만 3.5m 간격을 둔 v7을 5-run 검증했다.
- 실패: 첫 획득은 5/5 모두 6.7초 `idle_reaction`, 1.0-1.3m였고 stage1 사망 96.0명, 평균 434.5초, stuck 106.0회/normalized 0.15 초과였다.
- 결정: runtime 필드, v7 preset, 배치 코드, 전용 smoke를 모두 제거했다. 수동 첫 1분 gate를 유지하고 다음 비차단 작업은 route/POI landmark 자산 audit로 전환한다.

## N2-MAP-04 Route 표현 철회와 지도 정렬

- 수동 판정: 자동 캡처를 통과한 map/world route 선이 실제 플레이에서는 과도하고 이질적이었으며, 봇이 소비하지 않는 분류를 전략 경로처럼 오해하게 만들었다.
- 철회: minimap/fullmap route 선, world의 127개 strip·4개 MultiMesh, 공유 style helper와 전용 smoke·캡처를 제거했다.
- 수정: 전체 지도를 미니맵과 같은 45도 좌표계로 회전하고 배경 경계, POI, cover, zone, 플레이어 방향이 한 투영을 공유하게 했다.
- 검증: `unit_smoke` 통과. `full_map_orientation.png`와 `minimap_orientation.png`에서 선 제거, 다이아몬드 경계와 방향 일치를 확인했다.
- 다음: 4봇이 플레이어를 견제 후 이탈한 원인과 맵의 이동 시간·시야·pickup·장애물 밀도를 분리해 audit한다.

## N2-MAP-01 Route/Cover 구조 audit

- audit: canonical v6의 `idle_loot` 목표 97.3%는 route 안이지만 킬은 flank 46.5%, off-route 33.4%였다. `routes`는 이동 유도가 아니라 위치 분류에만 쓰이고, 고엄폐 11개 중 primary route에는 1개뿐이었다.
- 후보: Sluice Crossing 양쪽에 고엄폐 rock 2개를 두어 primary 고엄폐를 3개로 늘렸다.
- 결과: primary 킬 14.3→23.1%, stage1 사망 95.6→94.0명. 반면 평균 stuck 78.6→104.4회, normalized 0.14→0.15, 새 cover 셀 두 곳이 stuck의 26.7%를 차지했고 평균 duration은 431.2초였다.
- 결정: 후보 맵과 전용 gate를 제거했다. 다음은 물리 cover 추가가 아니라 minimap/fullmap에서 route를 실제 선택 정보로 보이게 한다.

## N2-VIS-01 Night 월드 가독성 프로필

- 문제: 기존 deterministic 캡처에서 플레이어와 픽업만 보이고 지면, 수풀, cover가 검은 배경에 묻혔다.
- 수정: `NightWorldReadability`가 Night 맵에만 청색 주변광 0.38과 달빛 0.32를 적용한다. Main과 캡처가 같은 프로필을 사용하고 기본 맵은 원래 환경으로 복원한다.
- 회귀 방지: 1280x720 캡처의 background/cover/bush 표본 대비를 자동 gate로 추가했다.
- 검증: `unit_smoke`, `visual_review` 통과. cover blue 0.1765 vs background 0.0784, bush green 0.2235 vs 0.0627.
- 다음: 가독성 미세조정이 아니라 v6 kill의 85.8%가 flank/off-route에 몰리는 맵 구조를 audit한다.

## N2-PACE-42 Post-Kill Reacquire Delay 폐기

- 후보: v6의 피해·존·루팅을 유지하고 stage1에서만 post-kill 능동 재획득을 2초 늦췄다. 공격받을 때의 damage 반응은 유지했다.
- 검증: `unit_smoke` 통과. canonical 5-run 평균 301.5초, 범위 237.3-373.0초, first upgrade 225.5초, stage1 사망 95.6명.
- 실패: `post_kill_scan` 획득은 v6 평균 132.4→56.4회로 줄었지만 생존자는 평균 3.4명뿐이었다. idle/damage 획득으로 우회했고 stage3는 0/5였다.
- 결정: runtime 필드, v7 preset, 테스트를 모두 제거했다. AI 미세 예외를 멈추고 `visual_review`에서 route/encounter 구조를 확인한다.

## N2-PACE-41 Stage1 Bot Damage 폐기

- 후보: v6의 bot-vs-bot 피해 0.55는 유지하고 stage1에서만 0.35를 적용한 뒤 stage2부터 복원했다.
- 검증: `unit_smoke` 통과. canonical 5-run 평균 551.3초, 범위 237.7-900.3초, first upgrade 221.9초, stage1 사망 평균 92.4명.
- 실패: first upgrade 누락 1회, long-run stuck 0.19로 gate 실패. stuck의 62.3%가 `DISENGAGE`였고 생존 증가는 v6보다 3.2명에 그쳤다.
- 결정: runtime 필드, v7 preset, 테스트를 모두 제거했다. 다음은 피해량을 더 낮추지 않고 stage1 post-kill 즉시 재획득 연쇄를 제한한다.

## N2-PACE-40 Opening Noncombat Separation 폐기

- 후보: v6에 첫 12초 동안 loot `CHASE`와 `ZONE_ESCAPE` 주변 봇 분산을 0.2초 간격으로 추가했다. 전투와 플레이어 회피에는 적용하지 않았다.
- 검증: `unit_smoke` 통과. canonical 5-run 평균 465.4초, 범위 245.0-637.2초, first contact 7.0초, first upgrade 223.4초.
- 실패: stage1 사망은 v6와 같은 95.6명이고 normalized stuck는 0.14→0.16으로 악화했다.
- 결정: runtime 필드, v7 preset, 테스트를 모두 제거했다. 다음은 opening 예외가 아니라 stage1 bot damage를 직접 제한한다.

## N2-PACE-38 Inside-Edge Zone Return 분리

- 문제: 봇이 실제 존 안에서도 반경 95%에서 `ZONE_ESCAPE`에 진입해 75%까지 중앙으로 이동했다.
- 수정: runtime bot tuning을 추가하고 v6에서 stage1 안쪽 선제 복귀만 0.90에서 해제한다. 실제 존 밖에서 진입하거나 이동 중 밖이 된 봇은 기존 0.75 복귀를 유지한다.
- 검증: `unit_smoke` 통과. canonical 5-run 평균 465.1초, 범위 236.3-1132.7초, first upgrade 224.4초, stage2 220.1초, stage3 590.1초다.
- 구조 효과: normalized stuck 0.14 통과, ZONE_ESCAPE 체류 345.2→174.0초, 해당 stuck 51.2→10.4회.
- 남은 문제: first contact 6.7초와 stage1 사망 95.6명은 개선되지 않았다. v6는 비기본 pathing 후보로 유지하고 IDLE loot 수렴을 다음에 본다.

## N2-PACE-37 Opening Guard 진단 폐기

- 질문: idle/objective 계열 첫 획득을 늦추면 stage1 과소모가 줄어드는지 확인했다.
- 진단 후보: non-hard-bump opening guard만 6배로 늘리고 damage, loot, zone, 4초 hard-bump는 유지했다.
- 결과: 5-run 평균 401.3초, first contact 18.0초, first kill 37.8초, normalized stuck 0.26으로 v5보다 악화됐다.
- 원인 신호: 첫 획득 5/5가 hard-bump였고 80%는 `retreat_counteraction`이었다. 유예 중 이동한 봇이 `ZONE_ESCAPE` 경로에서 모인 뒤 충돌 전투로 우회했다.
- 결정: 후보 preset과 런타임 코드는 모두 제거했다. 다음은 유예 추가가 아니라 `ZONE_ESCAPE`의 95%-75% 복귀 구간을 분리한다.

## 기록 보존

이 문서는 최근 10개 작업 또는 120줄까지만 유지한다. 오래된 항목과 삭제된 전체 사본은 `git log -- docs/DEVLOG.md docs/MASTERPLAN.md`로 찾고, 필요한 커밋에서만 읽는다.
