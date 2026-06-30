# 문서 라우팅

> 최종 업데이트: 2026-06-30. 문서는 중요도 순으로 읽는다. 기본 세션에서 모든 문서를 열지 않는다.

## 0순위: 매 세션 필수

| 문서 | 용도 | 읽는 시점 |
|---|---|---|
| [../CLAUDE.md](../CLAUDE.md) | 에이전트 운영 규칙과 기본 금지선 | 새 세션 시작 |
| [CURRENT.md](CURRENT.md) | 현재 목표, 리스크, 다음 작업, 로컬 실행 메모 | 매 작업 시작 |
| [DOCS_INDEX.md](DOCS_INDEX.md) | 필요한 문서 선택 | 문서/참조가 필요할 때 |

## 1순위: 판단 장부

| 문서 | 용도 | 읽는 시점 |
|---|---|---|
| [DECISIONS.md](DECISIONS.md) | 안정된 결정과 재검토 조건 | 큰 결정/정책 변경 전 |
| [EXPERIMENTS.md](EXPERIMENTS.md) | 채택/폐기 실험 기록 | 새 튜닝 후보 전 |
| [DEVLOG.md](DEVLOG.md) | 최근 검증된 작업 요약 | 작업 맥락이 필요할 때, 작업 후 갱신 |
| [PLAYTEST.md](PLAYTEST.md) | 수동 체감/가독성 판단 | 체감 변경 전후 |

## 2순위: 실행 참조

| 문서 | 용도 | 읽는 시점 |
|---|---|---|
| [TESTING.md](TESTING.md) | 검증 profile과 gate 해석 | 검증 선택 시 |
| [IMPACT_MAP.md](IMPACT_MAP.md) | 변경 영향과 소유 경계 | gameplay/UI/map/telemetry 코드 변경 전 |
| [ARCHITECTURE.md](ARCHITECTURE.md) | 모듈 구조와 의존 경계 | 구조 변경 또는 큰 파일 추출 전 |

## 3순위: 작업별 참조

| 문서 | 용도 | 읽는 시점 |
|---|---|---|
| [MASTERPLAN.md](MASTERPLAN.md) | 큰 제품 방향과 마일스톤 | 로드맵을 바꿀 때 |
| [NIGHT_BR_PACING_PLAN.md](NIGHT_BR_PACING_PLAN.md) | Night BR pacing 기준 | pacing 큰 단위 설계 |
| [MAP_TILE_GROUPS.md](MAP_TILE_GROUPS.md) | 맵 배치/route 역할 메모 | 맵 구조 변경 |
| [ASSET_BRIEF.md](ASSET_BRIEF.md) | 자산 스타일/포맷 기준 | 자산 제작/검수 |
| [ASSET_STATUS.md](ASSET_STATUS.md) | 자산 통합 상태 | 자산 통합 전 |
| [ASSET_GENERATION_PROMPTS.md](ASSET_GENERATION_PROMPTS.md) | 외부 생성 프롬프트 | 생성 요청 작성 |
| [UI_DESIGN.md](UI_DESIGN.md) | UI screenshot 리뷰 기준 | UI 변경 |
| [RELEASE.md](RELEASE.md) | 릴리즈 절차 | 릴리즈 명시 요청 시 |

## 폐기/제외 정책

- `HANDOFF.md`는 삭제했다. 재개 정보는 1회용이라 금방 낡는다.
- 재개에 필요한 상태는 [CURRENT.md](CURRENT.md)의 `현재 작업면`과 `리스크 보드`에만 둔다.
- 완료 작업은 [DEVLOG.md](DEVLOG.md)에 짧게 남긴다.
- 안정 결정은 [DECISIONS.md](DECISIONS.md)에만 남긴다.
- 실험 실패/채택은 [EXPERIMENTS.md](EXPERIMENTS.md)에 한 줄로 남긴다.
- 긴 원문과 과거 맥락은 `docs/archive/` 또는 `docs/devlog/`에 보존하되 기본 컨텍스트에서 제외한다.

## 아카이브

| 경로 | 상태 |
|---|---|
| `docs/archive/` | 과거 장문 계획. 기본 읽기 금지 |
| `docs/devlog/DEVLOG_full_*.md` | 과거 전체 개발 로그. 기본 읽기 금지 |
| `docs/devlog/v*.md` | 버전별 과거 로그. 필요할 때만 |
| `docs/devlog/INDEX.md` | 과거 로그를 찾아야 할 때만 |

## 문서 예산

| 문서군 | 목표 |
|---|---|
| 0순위 문서 | 짧고 항상 최신 |
| 1순위 판단 장부 | 표와 짧은 요약 중심 |
| 2순위 실행 참조 | 명령/판정 기준 중심 |
| 3순위 작업별 참조 | 해당 작업 때만 읽어도 충분하게 유지 |

새 정보를 추가할 때 문서가 길어진다면, 현재 문서에 원문을 붙이지 말고 요약만 남긴다.
