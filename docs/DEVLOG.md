# Battle Capsule 개발 로그

> 최종 업데이트: 2026-07-16. 최근 검증된 작업만 유지한다. 과거 내용은 Git 이력을 참조한다.

## N2-PACE-33 Bot-vs-Bot Damage Pacing 후보

- 진단: v4 control 5-run 평균은 350.6초였고 사망 98/99가 stage1 combat, zone death는 0회여서 zone보다 bot 교전 속도가 match length를 지배했다.
- 구현: runtime combat tuning을 추가하고 `bot_vs_bot_damage_mult=0.55`를 bot끼리의 melee/gun/engagement estimate에만 적용했다. 플레이어 damage는 그대로다.
- 후보: `playable_pacing_v5`는 v4 timing을 유지하되 initial zone timer를 150초로 두어 first upgrade band를 보존한다.
- 검증: `pacing_candidate --pacing-preset playable_pacing_v5 --runs 3`와 scale gate 통과. avg 689.0초, first upgrade 285.5초, stage2 283.4초, stage3 654.2초, stuck/entity/min 0.11.
- 판단: 평균 목표는 통과했지만 개별 run이 336.2-1219.9초라 기본 승격을 보류한다. 다음은 조기/장기 종료 원인을 분리해 분산을 줄인다.

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

## N2-DOC-02 문서 라우팅 다이어트

- 범위: `HANDOFF.md`를 삭제하고, `DOCS_INDEX.md`를 중요도 순 문서 라우팅 표로 재작성.
- 결정: 1회용 재개 정보는 별도 문서로 두지 않고 `CURRENT.md`에 흡수한다.
- 목표: 새 세션 기본 읽기를 `CLAUDE.md`, `CURRENT.md`, `DOCS_INDEX.md` 중심으로 줄인다.

## N2-DOC-03 남은 작업 구조화

- 범위: `MASTERPLAN.md`에 남은 작업을 T1-T6 트랙으로 정리하고, `CURRENT.md`의 큐를 실행 순서로 재정렬.
- 결정: 다음 구현 우선순위는 T1 match duration margin 확보이며, opening pressure 추가 지연은 duration 여유 뒤에 진행한다.
- 목표: 향후 작업을 문서/실험 맥락에 잡아먹히지 않고 제품 트랙 단위로 진행한다.

## N2-PACE-32 Opening Hard-Bump Brush

- 범위: 스폰 직후 4초 동안 1m hard-bump가 즉시 idle reaction, idle-loot enemy interrupt, zone-escape counteraction으로 승격되지 않게 했다.
- 폐기한 probe: 5초 brush는 first contact 18.3초로 좋아 보였지만 avg duration 326.9초, stage3 없음으로 실패.
- 검증: `unit_smoke` 통과. `pacing_candidate --pacing-preset playable_pacing_v4 --runs 3` 통과.
- 결과: avg duration 554.3초, first contact 17.7초, first kill 24.4초, first upgrade 293.9초, stage2 285.8초, stage3 655.7초, hard-bump first acquisition 1/3.
- 판단: 4초 brush는 좁은 자동 후보로 유지. 더 넓히기 전에 match duration 여유가 필요하다.

## N2-PACE-31 v4 시각 리뷰

- 범위: `visual_review` profile로 v4 후보의 실제 가독성 확인.
- 검증: `visual_review` 통과.
- 결과: 플레이어 실루엣과 픽업 라벨/glow는 읽히지만, 주변 수풀/지형 윤곽은 매우 어둡다.
- 판단: v4는 자동 후보로 유지하되 수동 기준선 승격은 보류.

## N2-PACE-30 Initial Non-Pistol Pool Candidate

- 범위: `playable_pacing_v4` 추가. initial loot에서 non-pistol weapon weight를 0으로 낮추고 stage/supply source가 첫 upgrade를 담당하게 했다.
- 검증: `pacing_candidate --pacing-preset playable_pacing_v4 --runs 3` 통과.
- 결과: avg duration 599.6초, first contact 14.1초, first kill 23.2초, first upgrade 294.9초, stage2 284.3초, stage3 654.2초.
- 판단: first-upgrade timing은 band 안에 들어왔다. opening pressure는 별도 문제로 남았다.

## N2-PACE-29 First-Upgrade Source Telemetry

- 범위: first upgrade source/context telemetry 추가, wall-clock 혼입 수정.
- 결과: v3 corrected read는 first upgrade 97.4초, source initial_loot 66.7% / stage_wave 33.3%.
- 판단: bot drop이 아니라 map/wave non-pistol access를 다뤄야 한다.

## N2-OPS-02 검증 프로필 실행기

- 범위: `tools/run_verify.py`를 검증 진입점으로 추가.
- profile: `docs_only`, `tooling`, `unit_smoke`, `pacing_v2`, `pacing_v3`, `pacing_candidate`, `scale_99`, `visual_review`.
- 판단: 새 작업은 command 복붙보다 profile을 먼저 고른다.

## 기록 보존

이 문서는 최근 10개 작업 또는 120줄까지만 유지한다. 오래된 항목과 삭제된 전체 사본은 `git log -- docs/DEVLOG.md docs/MASTERPLAN.md`로 찾고, 필요한 커밋에서만 읽는다.
