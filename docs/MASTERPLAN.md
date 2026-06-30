# 마스터플랜

> 최종 업데이트: 2026-06-30. 장기 로드맵은 짧게 유지하고, 세부 완료 로그는 `DEVLOG.md`와 아카이브에 둔다.

## 현재 제품 목표

Battle Capsule은 low-poly quarter-view tactical roguelite battle royale 프로토타입이다. 현재 목표는 “기술적으로 많은 봇이 도는 시뮬레이션”이 아니라, 플레이어가 읽고 판단할 수 있는 10-15분 Night BR 한 판을 만드는 것이다.

## 마일스톤

| ID | 이름 | 상태 | 완료 기준 |
|---|---|---|---|
| M0 | 운영 정리 | 진행 중 | 문서/검증/푸쉬 루틴이 짧고 반복 가능 |
| M1 | 첫 플레이 가능한 Night BR | 진행 중 | v4 계열 후보가 자동/수동 기준을 모두 통과 |
| M2 | 버티컬 슬라이스 | 계획 | 맵, 전투, 루트, 존, UI, 자산이 한 화면에서 설득력 있게 동작 |
| M3 | 콘텐츠 안정화 | 이후 | 밸런스, 자산, 추가 시스템 확장 |

## 현재 기준선

- 후보 맵: `data/mapSpec_night_forest_candidate.json`
- 구조 gate: `target_99_probe`
- 자동 페이싱 후보: `playable_pacing_v4`
- 최신 gameplay slice: N2-PACE-32 4초 opening hard-bump brush
- 최신 자동 결과:
  - avg duration 554.3초
  - first contact 17.7초
  - first upgrade 293.9초
  - stage2 285.8초
  - stage3 655.7초
  - hard-bump first acquisition 1/3

## 다음 제품 문제

1. Match duration을 600초 이상으로 안정화한다.
2. 오프닝 first contact가 아직 빠르지만, 5초 brush처럼 duration을 무너뜨리는 방식은 쓰지 않는다.
3. v4 후보를 수동 플레이/가독성으로 평가한다.
4. 야간 지형/수풀/cover 윤곽을 실제 화면에서 더 읽히게 만든다.
5. 자산은 gameplay를 막는 순서로만 승격한다.

## 금지된 빠른 해결책

- 99명 default promotion.
- release/build 작업 선행.
- broad economy cut으로 first upgrade 해결.
- broad weapon chance cut.
- hard-bump threshold-only fix.
- 5초 이상 opening hard-bump brush.
- gate 완화로 candidate 통과.

## 문서 운영

- `CURRENT.md`: 지금 할 일.
- `DECISIONS.md`: 안정 결정.
- `EXPERIMENTS.md`: 채택/폐기 실험.
- `PLAYTEST.md`: 수동 체감.
- `DEVLOG.md`: 최근 완료 작업.
- 오래된 장문은 archive/devlog 폴더에서 필요할 때만 확인한다.
