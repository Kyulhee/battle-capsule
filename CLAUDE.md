# 배틀캡슐 — Claude 온보딩

**Godot 4.6.2 / GDScript** 쿼터뷰 배틀로얄 프로토타입.  
플레이어 1명 vs 봇 11명, 자기장 수축, 숲 맵 1개.  
저장소: https://github.com/Kyulhee/battle-capsule

---

## 현재 상태

| 항목 | 내용 |
|---|---|
| 완료 버전 | v1.6.2 (쿼터뷰 벽 가림 투명화 안정화) |
| 다음 버전 | v1.7 — AI Doctrine Hierarchy Refactor |
| 미해결 | 릴리즈 전 ObjectDB leak 간헐 경고 재현 시 `--verbose`로 상세 확인 |

---

## 핵심 문서 — 작업 전 읽기

| 문서 | 용도 |
|---|---|
| [MASTERPLAN.md](docs/MASTERPLAN.md) | 전체 로드맵 (v0.1~v1.0), 코드 구조, 설계 원칙 |
| [DEVLOG.md](docs/DEVLOG.md) | 버전별 구현 상세 기록 (가장 최근 항목부터) |
| [ARCHITECTURE.md](docs/ARCHITECTURE.md) | 레이어 구조, 의존성 맵, 시그널 흐름, 설계 원칙 상세 |
| [IMPACT_MAP.md](docs/IMPACT_MAP.md) | **코드 수정 전 필독** — 모듈 소유 관계, 양방향 참조, 변경→연쇄 영향 |
| [TESTING.md](docs/TESTING.md) | 헤드리스 시뮬레이션 실행법 + 지표별 판단 기준 |
| [RELEASE.md](docs/RELEASE.md) | Godot 빌드 → GitHub 릴리즈 → README 업데이트 전 절차 |
| [UI_DESIGN.md](docs/UI_DESIGN.md) | HUD 디자인 프로세스 (ASCII 스케치 → 목업 → 구현) |

**단계별 업데이트 기준**

| 단계 | 업데이트할 파일 |
|---|---|
| **코드 수정 전** | **[IMPACT_MAP.md](docs/IMPACT_MAP.md) 확인** — 변경 대상의 연쇄 영향 파악. 내용이 실제 코드와 다르면 즉시 사용자에게 보고 후 수정. |
| 구현 후 검증 | *(없음)* — TESTING.md 체크리스트만 실행 |
| 검증 통과 | **DEVLOG.md** 상단에 새 버전 섹션 추가 |
| 검증 통과 | **CLAUDE.md** 현재 상태 표 갱신 |
| 릴리즈 실행 | **RELEASE.md** 절차 따름 (export_presets → 빌드 → README) |
| 릴리즈 완료 | **MASTERPLAN.md** 릴리즈 히스토리 추가 + 완료 로드맵 표시 |
| 새 텔레메트리 추가 시 | **TESTING.md** 지표 기준표 + 체크리스트 갱신 |

---

## 핵심 파일

```
src/entities/bot/Bot.gd        — AI 상태 머신 + CombatPlan 개인 교전 수칙
src/entities/player/Player.gd  — 무기 슬롯, 재장전, HUD
src/entities/Entity.gd         — 공통 베이스 (이동, 피해, 인식)
src/core/ZoneController.gd     — 자기장 상태 머신 (수축, 피해, 외부 추적)
src/core/WeaponSlotManager.gd  — 무기 슬롯 5개, 탄약, 재장전 로직
src/core/MissionTracker.gd     — 보너스·압박 미션 상태, 풀 정의, 필터
src/core/Telemetry.gd          — 매치 통계 (그룹 토글, JSON 출력)
src/Main.gd                    — 게임 루프, 스폰, 보급 캡슐, UI 오케스트레이션
src/core/StatsData.gd          — 무기/캐릭터 스탯 Resource
```

빌드 아티팩트 → `builds/`  
Godot 실행 파일 → 프로젝트 루트 (`Godot_v4.6.2-stable_win64*.exe`)

---

## Godot 4 주의사항

- Control preset: `PRESET_CENTER_BOTTOM` (not `PRESET_BOTTOM_CENTER`)
- `grow_vertical = GROW_DIRECTION_BEGIN` 없으면 bottom anchor가 화면 밖으로 나감
- macOS export key: `application/bundle_identifier` (not `application/identifier`)
- 헤드리스 빌드 시 `textures/vram_compression/import_etc2_astc=true` 필요 (project.godot)
- 에디터 밖에서 새 `class_name` 스크립트를 만들 때는 헤드리스 안정성을 위해 직접 타입 의존보다 `preload()`를 우선한다.

---

## 헤드리스 시뮬레이션 (빠른 실행)

```bash
./Godot_v4.6.2-stable_win64_console.exe --headless -- autostart=true
# 결과: %APPDATA%\Godot\app_userdata\BattleRoyalePrototype\sim_result_latest.json
```

정상 기준: `duration > 60s`, `zone_stage_reached >= 2`, `recover_bouts > 0`, combat plan 카운트가 0에 고정되지 않음
상세 판단 기준 → [TESTING.md](docs/TESTING.md)
