# 다음 세션 핸드오프

> 최종 업데이트: 2026-06-30. 새 세션은 `DOCS_INDEX.md`와 `CURRENT.md`를 먼저 읽고, 이 문서는 실행/재개 메모로 사용한다.

## 시작 루틴

1. 작업 디렉터리: `C:\test\game_dev`
2. 브랜치 확인:

```powershell
git status --short --branch
```

3. 현재 트래커 확인:

```powershell
Get-Content docs\CURRENT.md
Get-Content docs\DECISIONS.md
Get-Content docs\EXPERIMENTS.md
```

4. 작업 전 한 줄 재진술: 현재 마일스톤, 주요 리스크, 종료 조건.

## 실행 환경 메모

- Windows sandbox가 일반 shell 실행에서 `CreateProcessAsUserW failed: 1312`를 낼 수 있다.
- 이 경우 Codex tool call에 `sandbox_permissions: "require_escalated"`와 짧은 `justification`을 붙여 실행한다.
- Git 명령은 index/refs lock을 만들 수 있으므로 승격 실행을 기본으로 잡는 편이 안전하다.
- Godot/Python 검증은 `C:\tmp`에 산출물을 쓰므로 승격 실행이 필요할 수 있다.

## Git 상태 원칙

- 사용자가 별도로 금지하지 않는 한 검증된 작업은 커밋 후 `git push origin master`까지 진행한다.
- 아래 로컬 자료는 기존 별도 산출물로 취급한다. 현재 작업 범위가 아니면 staging하지 않는다.

```text
 M .gitignore
?? asset_generator/
?? plan_report/
```

- `docs/ASSET_GENERATION_PROMPTS.md`는 이번 한글화 이후 추적 문서로 전환했다.

## 현재 개발 상태

- 현재 milestone: M1 첫 플레이 가능한 Night BR.
- 최신 gameplay slice: N2-PACE-32 4초 opening hard-bump brush.
- 최신 자동 후보: `playable_pacing_v4`.
- N2-PACE-32 결과:
  - avg duration 554.3초
  - first contact 17.7초
  - first upgrade 293.9초
  - stage2 285.8초
  - stage3 655.7초
  - hard-bump first acquisition 1/3
  - `pacing_candidate` PASS
- 다음 리스크: match duration이 600초 목표 floor보다 짧다. 추가 opening 지연 전에 duration 여유를 확보해야 한다.

## 검증 진입점

가능하면 직접 명령 묶음 대신 profile을 사용한다.

```powershell
python tools\run_verify.py --profile docs_only
python tools\run_verify.py --profile tooling
python tools\run_verify.py --profile unit_smoke
python tools\run_verify.py --profile pacing_candidate --pacing-preset playable_pacing_v4 --runs 3 --out-root C:\tmp\some_run
python tools\run_verify.py --profile scale_99
python tools\run_verify.py --profile visual_review
```

## 중단 조건

사용자 확인 없이 계속 진행하되, 아래 조건이 같은 원인으로 반복되면 멈춘다.

- 같은 blocker가 3회 이상 반복된다.
- 이후 작업에도 계속 영향을 주는 외부 상태 문제다.
- 검증 없이 추측 구현을 해야만 하는 상황이다.

## 반복 금지

- 5초 이상 opening hard-bump brush: duration/stage3 붕괴.
- hard-bump threshold-only fix: duration/stage3 회귀.
- broad weapon chance cut: spike 또는 starvation.
- global loot/hotspot/rare cut: stage3 회귀.
- gate 완화로 PASS 만들기.
