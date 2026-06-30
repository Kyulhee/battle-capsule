# 문서 인덱스

> 최종 업데이트: 2026-06-30. 새 세션은 이 문서와 `CURRENT.md`부터 읽는다. 기본 문서는 한글로 유지한다.

## 기본 읽기 순서

| 문서 | 용도 | 기본 읽기 |
|---|---|---|
| [../CLAUDE.md](../CLAUDE.md) | 세션 운영 규칙과 협업 방식 | 예 |
| [CURRENT.md](CURRENT.md) | 현재 마일스톤, 리스크, 다음 작업 | 예 |
| [HANDOFF.md](HANDOFF.md) | 재개 맥락, 로컬 실행/깃 상태 | 예 |
| [DECISIONS.md](DECISIONS.md) | 유지 중인 결정과 재검토 조건 | 큰 결정을 바꾸기 전 |
| [EXPERIMENTS.md](EXPERIMENTS.md) | 채택/폐기 실험 기록 | 새 튜닝 전 |
| [PLAYTEST.md](PLAYTEST.md) | 수동 체감/가독성 체크 | 체감 변경 전 |
| [DEVLOG.md](DEVLOG.md) | 최근 검증된 작업 요약 | 작업 후 갱신 |
| [MASTERPLAN.md](MASTERPLAN.md) | 큰 로드맵과 현재 제품 방향 | 참조용 |
| [IMPACT_MAP.md](IMPACT_MAP.md) | 변경 영향과 소유 경계 | 코드 변경 전 |
| [ARCHITECTURE.md](ARCHITECTURE.md) | 모듈 경계와 의존 구조 | 구조 변경 시 |
| [TESTING.md](TESTING.md) | 검증 프로필과 판정 기준 | 검증 시 |

## 자산 문서

| 문서 | 용도 |
|---|---|
| [ASSET_BRIEF.md](ASSET_BRIEF.md) | 자산 스타일, 포맷, 수용 기준 |
| [ASSET_STATUS.md](ASSET_STATUS.md) | 통합/보류/미연결 자산 상태 |
| [ASSET_GENERATION_PROMPTS.md](ASSET_GENERATION_PROMPTS.md) | 외부 생성기에 전달할 프롬프트 초안 |

`asset_generator/expected_output/`은 런타임 자산이 아니라 원본 풀이다. 실제 게임에 쓰는 파일만 `assets/`로 승격하고 `data/asset_catalog.json`에 등록한다.

## 조건부 문서

| 문서 | 읽는 경우 |
|---|---|
| [UI_DESIGN.md](UI_DESIGN.md) | UI 변경이나 스크린샷 기반 리뷰가 필요할 때 |
| [RELEASE.md](RELEASE.md) | 릴리즈/빌드/GitHub 배포를 명시적으로 요청받았을 때 |
| [MAP_TILE_GROUPS.md](MAP_TILE_GROUPS.md) | 99명 맵 배치 그룹을 다시 설계할 때 |
| [NIGHT_BR_PACING_PLAN.md](NIGHT_BR_PACING_PLAN.md) | 10-15분 Night BR 페이싱을 큰 단위로 재설계할 때 |

## 문서 예산

| 문서 | 목표 |
|---|---|
| `CURRENT.md` | 100줄 이하 |
| `DECISIONS.md` | 120줄 이하 |
| `EXPERIMENTS.md` | 150줄 이하 |
| `PLAYTEST.md` | 150줄 이하 |
| `HANDOFF.md` | 100줄 이하 |
| `DEVLOG.md` | 최근 작업만 유지, 상세 로그는 아카이브 |
| `ARCHITECTURE.md`, `IMPACT_MAP.md`, `TESTING.md` | 필요한 판단을 빠르게 내릴 수 있는 참조 문서 |

긴 원문이 필요하면 새 내용을 붙이지 말고 `docs/archive/` 또는 `docs/devlog/`에 스냅샷을 남긴 뒤 활성 문서는 압축한다.

## 아카이브

아래 문서는 기본 컨텍스트에서 제외한다. 현재 문서에 없는 과거 세부사항이 필요할 때만 연다.

| 경로 | 내용 |
|---|---|
| `docs/archive/` | 이전 장문 마스터플랜과 레거시 아이디어 |
| `docs/devlog/DEVLOG_full_*.md` | 과거 전체 개발 로그 |
| `docs/devlog/v*.md` | 버전별 요약/원문 로그 |
| `docs/devlog/INDEX.md` | 버전 로그 인덱스 |
