# 문서 안내

> 최종 업데이트: 2026-07-16. 루트 문서는 현재 작업에 직접 쓰는 문서만 둔다.

## 기본 읽기 경로

| 순서 | 문서 | 용도 |
|---|---|---|
| 1 | [../CLAUDE.md](../CLAUDE.md) | 저장소 운영 규칙 |
| 2 | [CURRENT.md](CURRENT.md) | 현재 목표, 리스크, 다음 작업 |
| 3 | [DOCS_INDEX.md](DOCS_INDEX.md) | 추가 참조 선택 |

매 세션에 다른 문서를 전부 읽지 않는다.

## 활성 문서

| 문서 | 단일 역할 | 갱신 조건 |
|---|---|---|
| [CURRENT.md](CURRENT.md) | 지금 할 일과 다음 작업 | 작업 단위 시작/종료 |
| [MASTERPLAN.md](MASTERPLAN.md) | 제품 목표, 트랙, 페이싱 기준 | 로드맵/기준선 변경 |
| [DECISIONS.md](DECISIONS.md) | 안정된 결정과 재검토 조건 | 정책 변경 |
| [EXPERIMENTS.md](EXPERIMENTS.md) | 채택/폐기 실험 | 후보 판정 |
| [PLAYTEST.md](PLAYTEST.md) | 수동 체감과 화면 리뷰 | 수동/시각 검증 |
| [DEVLOG.md](DEVLOG.md) | 최근 검증 작업 요약 | 검증 완료 |

## 필요할 때만 읽는 참조

| 경로 | 용도 |
|---|---|
| [reference/ARCHITECTURE.md](reference/ARCHITECTURE.md) | 구조, 소유 경계, 변경 영향 |
| [reference/TESTING.md](reference/TESTING.md) | 검증 profile과 gate |
| [reference/MAP_TILE_GROUPS.md](reference/MAP_TILE_GROUPS.md) | 맵 배치 역할 |
| [reference/RELEASE.md](reference/RELEASE.md) | 명시적 릴리즈 절차 |
| [assets/ASSET_BRIEF.md](assets/ASSET_BRIEF.md) | 자산 스타일과 포맷 |
| [assets/ASSET_STATUS.md](assets/ASSET_STATUS.md) | 자산 통합 상태 |
| [assets/ASSET_GENERATION_PROMPTS.md](assets/ASSET_GENERATION_PROMPTS.md) | 외부 생성기용 프롬프트 |

## 운영 규칙

- 설명 문장은 한글로 쓴다. 식별자, 명령, 원문 문자열, 생성기 프롬프트만 영어를 허용한다.
- 새 루트 문서를 만들지 않는다. 먼저 기존 문서의 역할에 병합한다.
- 일회용 인수인계 문서, 날짜별 전체 사본, 압축 전 원문을 저장소에 만들지 않는다. 과거 내용은 Git 이력에서 찾는다.
- 분석기 원문을 붙이지 않는다. 결과, 판단, 다음 행동만 각각 1-3줄로 남긴다.
- 같은 상태를 여러 문서에 복제하지 않는다. 현재 상태는 `CURRENT`, 기준은 `MASTERPLAN`, 결과는 `DEVLOG`가 소유한다.
- 문서 정리만 한 작업은 `DEVLOG` 한 항목으로 끝내며 별도 보고서를 만들지 않는다.

## 문서 예산

| 문서 | 상한 |
|---|---|
| `CURRENT.md` | 80줄 |
| `DEVLOG.md` | 120줄 또는 최근 10개 작업 |
| `MASTERPLAN.md` | 180줄 |
| 그 외 활성 문서 | 150줄 |

상한을 넘기면 새 문서로 분할하지 않고 오래된 내용과 중복을 먼저 줄인다.
