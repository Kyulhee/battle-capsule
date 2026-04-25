# 배틀캡슐 — Claude 온보딩

**Godot 4.6.2 / GDScript** 쿼터뷰 배틀로얄 프로토타입.  
플레이어 1명 vs 봇 11명, 자기장 수축, 숲 맵 1개.  
저장소: https://github.com/Kyulhee/battle-capsule

---

## 현재 상태

| 항목 | 내용 |
|---|---|
| 완료 버전 | v0.4 (Bot AI 개선, Telemetry 재설계) |
| 다음 버전 | v0.5 — outnumbered 감지 + DISENGAGE, 실제 엄폐물, 봇 무기 다양화 |
| 미해결 | ShotPing/ImpactEffect UID 충돌 경고 (무해), 자기장 피해 플레이어 미적용 |

---

## 핵심 문서 — 작업 전 읽기

| 문서 | 용도 |
|---|---|
| [MASTERPLAN.md](docs/MASTERPLAN.md) | 전체 로드맵 (v0.1~v1.0), 코드 구조, 설계 원칙 |
| [DEVLOG.md](docs/DEVLOG.md) | 버전별 구현 상세 기록 (가장 최근 항목부터) |
| [TESTING.md](docs/TESTING.md) | 헤드리스 시뮬레이션 실행법 + 지표별 판단 기준 |
| [RELEASE.md](docs/RELEASE.md) | Godot 빌드 → GitHub 릴리즈 → README 업데이트 전 절차 |

**작업 흐름**: 구현 → 시뮬레이션 검증(TESTING.md) → DEVLOG 기록 → 빌드/릴리즈(RELEASE.md) → README 배지 업데이트

---

## 핵심 파일

```
src/entities/bot/Bot.gd      — AI 상태 머신 (IDLE/CHASE/ATTACK/RECOVER/ZONE_ESCAPE)
src/entities/player/Player.gd — 무기 슬롯, 재장전, HUD
src/entities/Entity.gd        — 공통 베이스 (이동, 피해, 인식)
src/core/Telemetry.gd         — 매치 통계 (그룹 토글, JSON 출력)
src/Main.gd                   — 게임 루프, 존, 스폰, 보급 캡슐
src/core/StatsData.gd         — 무기/캐릭터 스탯 Resource
```

빌드 아티팩트 → `builds/`  
Godot 실행 파일 → 프로젝트 루트 (`Godot_v4.6.2-stable_win64*.exe`)

---

## Godot 4 주의사항

- Control preset: `PRESET_CENTER_BOTTOM` (not `PRESET_BOTTOM_CENTER`)
- `grow_vertical = GROW_DIRECTION_BEGIN` 없으면 bottom anchor가 화면 밖으로 나감
- macOS export key: `application/bundle_identifier` (not `application/identifier`)
- 헤드리스 빌드 시 `textures/vram_compression/import_etc2_astc=true` 필요 (project.godot)

---

## 헤드리스 시뮬레이션 (빠른 실행)

```bash
./Godot_v4.6.2-stable_win64_console.exe --headless -- autostart=true
# 결과: %APPDATA%\Godot\app_userdata\BattleRoyalePrototype\sim_result_latest.json
```

정상 기준: `duration > 60s`, `zone_stage_reached >= 2`, `recover_bouts > 0`  
상세 판단 기준 → [TESTING.md](docs/TESTING.md)
