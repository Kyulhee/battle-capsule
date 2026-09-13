# 문서 안내

> 최종 업데이트: 2026-09-13. 필요한 문서만 읽고 바뀐 사실의 소유 문서만 갱신한다.

## 읽기와 갱신 경로

공통 지침은 [AGENTS.md](../AGENTS.md)다. 재개·다음 작업 선택에는 `CURRENT`를 읽고, 범위가 명확한 수정에는 관련 코드와 아래 해당 참조만 읽는다.

| 문서 | 읽는 조건 / 단일 역할 | 갱신 조건 |
|---|---|---|
| [CURRENT.md](CURRENT.md) | 작업 재개: 현재 목표·중단점·다음 행동 | 목표·막힌 점·다음 행동이 바뀔 때 |
| [DEVLOG.md](DEVLOG.md) | 최근 구현·검증 결과 확인 | 검증 완료 결과를 한 항목으로 기록 |
| [MASTERPLAN.md](MASTERPLAN.md) | 제품 범위·마일스톤·기준선 판단 | 로드맵이나 제품 기준 변경만 |
| [DECISIONS.md](DECISIONS.md) | 관련 정책·재검토 조건 확인 | 장기 정책 결정 변경만 |
| [EXPERIMENTS.md](EXPERIMENTS.md) | 관련 후보의 채택·폐기 근거 확인 | 후보 판정과 근거 링크; DEVLOG 수치 복제 금지 |
| [PLAYTEST.md](PLAYTEST.md) | 수동 체감·화면 리뷰 | 실제 수동/시각 검증 결과 |
| [reference/ARCHITECTURE.md](reference/ARCHITECTURE.md) | 구조·소유 경계·Godot 주의점 | 해당 구조/계약 변경 |
| [reference/TESTING.md](reference/TESTING.md) | 검증 선택·승격 기준 | 명령·profile·gate 계약 변경만 |
| [reference/MAP_TILE_GROUPS.md](reference/MAP_TILE_GROUPS.md) | 맵 배치 역할 | 맵 역할 변경 |
| [reference/RELEASE.md](reference/RELEASE.md) | 패키징·tag·공개 절차 | 릴리즈 절차 변경 |
| [reference/LICENSES_CREDITS.md](reference/LICENSES_CREDITS.md) | 배포 고지 | 배포 의존성/고지 변경 |
| [releases/v2.1.0-demo-dev.md](releases/v2.1.0-demo-dev.md) | 프리릴리즈 내용·제한 | 해당 릴리즈 변경 |
| [assets/ASSET_BRIEF.md](assets/ASSET_BRIEF.md) | 자산 스타일·포맷 | 자산 기준 변경 |
| [assets/ASSET_STATUS.md](assets/ASSET_STATUS.md) | 자산 통합 현황 | 자산 통합 변경 |
| [assets/ASSET_GENERATION_PROMPTS.md](assets/ASSET_GENERATION_PROMPTS.md) | 외부 자산 생성 요청 | 생성 요청 변경 |

## 기록 기준

- 작업마다 위 문서를 일괄 갱신하지 않는다. 구현 결과는 `DEVLOG`, 재개 상태는 `CURRENT`, 장기 기준은 해당 참조에 한 번만 둔다.
- 결과는 판단·검증 범위·남은 한계와 근거 경로를 짧게 기록한다. 원시 로그나 동일 수치 표를 여러 문서에 복사하지 않는다.
- `CURRENT`에는 실험 이력을 누적하지 않는다. `DEVLOG`는 최근 약 10개 작업을 유지하되, 줄 수를 맞추려고 긴 한 줄로 압축하거나 매번 무관한 과거 항목을 고치지 않는다.
- 과거 판정·실패·기준선의 의미는 보존한다. 중복을 제거하고 관련 항목 링크를 사용하며, 과거 원문은 Git 이력에서 찾는다.
- 루트에는 공통 진입점 `AGENTS.md`, 도구별 안내 `CLAUDE.md`, 사용자 안내 `README.md`만 둔다. 일회성 보고서·인수인계 사본은 추가하지 않는다.
- 실험 재현 코드·입력 안내는 [tools/experiments/README.md](../tools/experiments/README.md), 원시 산출물은 무시되는 `builds/verification/`에 둔다. 과거 데이터는 일괄 이동·삭제하지 않는다.
