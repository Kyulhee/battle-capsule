# Battle Capsule 개발 로그

> 최종 업데이트: 2026-07-16. 최근 검증된 작업만 유지한다. 과거 내용은 Git 이력을 참조한다.

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

## N2-PACE-36 Simulation Participant 정리

- 문제: headless player가 `actors`, alive count, spawn 분포에 포함돼 아무 행동 없이 모든 run에서 승리했고, simulation이 봇 1명 생존이 아니라 봇 전멸까지 진행됐다.
- 수정: simulation player를 충돌/타게팅/처리에서 빠진 observer로 두고 99봇 중 1명이 남을 때 종료한다. `session.win`은 rank가 아니라 실제 winner로 기록한다.
- 구조: `SimulationParticipants.gd`로 participant count와 observer 설정을 분리하고 unit smoke를 추가했다.
- 검증: `unit_smoke` 통과. v5 bot-only 5-run에서 win=false, spawn 99/99, ATTACK 최대 16.0초로 기존 245.5초 이상치가 사라졌다.
- 기준선: 평균 434.7초, 범위 271.0-655.5초, first contact 7.0초, first upgrade 222.8초, stage2 220.1초, stage3 590.1초. duration/stuck 0.21 gate는 실패했다.
- 다음: hard-bump 첫 획득은 0/5이므로 초기 배치 밀도와 idle/objective acquisition을 stage1 소모 원인으로 비교한다.

## N2-PACE-35 Canonical 기준선과 Nav Unstick

- 기준선: v4 5-run 평균 426.5초, v5 평균 501.2초로 모두 duration gate에 실패했다. v5 first upgrade는 225.9초, stage2 220.0초, stage3 590.1초였다.
- 진단: stage1 사망이 run당 95-98명이고 첫 접촉은 약 7초였다. 45초 opening grace와 obstacle 점 이동은 stuck 또는 duration 회귀로 폐기하고 코드를 제거했다.
- 원인: nav 경로가 유효하면 `handle_movement()`를 직접 호출해 `_stuck_override_dir`을 무시하고 같은 코너에서 DISENGAGE 이탈을 반복했다.
- 수정: nav 이동도 `_move_or_unstick()`을 거치게 해 생성된 이탈 방향을 실제 이동에 반영했다.
- 검증: `unit_smoke` 통과. 수정 후 v5 5-run normalized stuck 0.14로 구조 gate를 통과했지만 평균 duration 486.3초로 페이싱 후보는 미승격이다.
- 다음: 한 run의 연속 공격 245.5초 이상치와 stage1 과소모를 분리해 duration 분산의 다음 lever를 고른다.

## N2-PACE-34 페이싱 검증 기반 정리

- 문제: `Telemetry.start_match()`가 동기 bot/loot 초기화 전에 실행되어 wall-clock 기반 duration과 stage 시간이 75-118초가량 부풀 수 있었다.
- 수정: 실제 match 진행 시간은 `Main.match_timer`를 canonical clock으로 사용하고, simulation autostart는 navigation bake 완료 뒤 시작한다.
- 추적: 각 simulation에 seed를 기록하고 bot snapshot을 출력하며, 개별 duration 최소/최대 gate를 추가했다.
- 판정: nav bake 대기 뒤에도 같은 seed가 525.4초와 909.6초로 갈려 고정 seed를 결정적 재현으로 사용할 수 없다. `pacing_candidate` 최소 run을 5로 올렸다.
- 정리: 이 과정에서 시험한 v6와 stage damage 후보는 증거 부족으로 제거했다. 다음은 canonical v4/v5 5-run 기준선 재구축이다.

## N2-PACE-33 Bot-vs-Bot Damage Pacing 후보

- 진단: v4 control 5-run 평균은 350.6초였고 사망 98/99가 stage1 combat, zone death는 0회여서 zone보다 bot 교전 속도가 match length를 지배했다.
- 구현: runtime combat tuning을 추가하고 `bot_vs_bot_damage_mult=0.55`를 bot끼리의 melee/gun/engagement estimate에만 적용했다. 플레이어 damage는 그대로다.
- 후보: `playable_pacing_v5`는 v4 timing을 유지하되 initial zone timer를 150초로 두어 first upgrade band를 보존한다.
- 당시 검증: pre-canonical 3-run에서 avg 689.0초, 범위 336.2-1219.9초를 기록했다.
- 현재 판단: bot-only damage 동작은 유지하지만 당시 초 단위는 현재 기준선에서 제외한다. canonical 5-run 재측정 전 기본 승격을 보류한다.

## N2-DOC-05 문서 구조 축소

- 범위: 활성 루트 문서를 7개로 줄이고 기술 자료는 `reference/`, 자산 자료는 `assets/`로 분리.
- 병합: 변경 영향은 `ARCHITECTURE`, UI 화면 리뷰는 `PLAYTEST`, Night BR 페이싱 기준은 `MASTERPLAN`에 흡수.
- 폐기: 날짜별 전체 로그와 마스터플랜 사본은 저장소에서 제거하고 Git 이력으로 대체.
- 규칙: 설명은 한글 우선, 새 루트 문서 금지, 문서별 줄 수 예산 적용.

## N2-DOC-04 구현 현황 정리

- 범위: `MASTERPLAN.md`에 현재 구현됨, 후보/검증 신호, 아직 아닌 것, 다음 판단을 영역별로 추가.
- 이유: 남은 작업 트랙만 있으면 실제 구현 상태와 계획의 거리가 불분명해져 다음 slice 범위가 흔들린다.
- 결정: 현재 상태는 별도 장문 보고서가 아니라 마스터플랜의 압축 표로 유지한다.

## N2-DOC-01 활성 문서 한글화

- 범위: 기본 읽기 문서와 자산/구조/검증 문서를 한글 운영 문서로 압축.
- 이유: 기존 문서가 영어와 한글, 실험 원문, 오래된 handoff를 섞어 다음 행동을 흐리게 만들었다.
- 원칙: 활성 문서는 다음 판단에 필요한 정보만 남기고, 상세 이력은 Git에서 찾는다.

## 기록 보존

이 문서는 최근 10개 작업 또는 120줄까지만 유지한다. 오래된 항목과 삭제된 전체 사본은 `git log -- docs/DEVLOG.md docs/MASTERPLAN.md`로 찾고, 필요한 커밋에서만 읽는다.
