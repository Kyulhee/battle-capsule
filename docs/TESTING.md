# 배틀캡슐 테스팅 가이드

> 마지막 업데이트: 2026-04-26 (v0.6.1 기준)

> ⚠️ **중요: 체크리스트 기준 변경 금지**
> 이 파일의 체크리스트 기준값(임계치, pass/fail 조건)은 **반드시 개발자와 상의 후에만** 수정한다.
> 버그를 수정하지 않고 기준을 낮춰 통과시키는 것을 방지하기 위함이다.
> AI 에이전트가 단독으로 기준을 조정하는 것은 허용되지 않는다.

---

## 개요

Godot 헤드리스 모드로 게임을 자동 실행하면 `Telemetry.gd`가 지표를 수집하고  
`user://sim_result_latest.json`에 저장합니다. 이 파일을 분석해서 AI 행동, 밸런스,  
버그 여부를 판단합니다.

---

## 빠른 실행

```bash
# 헤드리스로 1판 실행 (5배속, 자동 종료)
./Godot_v4.6.2-stable_win64.exe --headless -- autostart=true

# 결과 파일 위치 (Windows)
# %APPDATA%\Godot\app_userdata\BattleRoyalePrototype\sim_result_latest.json
```

---

## 지표 그룹

`Telemetry.gd`의 `enabled_groups` 딕셔너리로 그룹별 ON/OFF가 가능합니다.  
`start_match()` 호출 전에 `set_groups({...})`를 사용하세요.

### `core` (항상 ON 권장)

| 지표 | 설명 | 이상 판단 기준 |
|---|---|---|
| `duration` | 매치 소요 시간 (초) | < 20s → 즉사/스폰 버그 의심 |
| `zone_stage_reached` | 자기장 최대 단계 | 항상 1이면 봇이 너무 빠르게 전멸 |
| `kills` / `assists` | 플레이어 킬/어시스트 | 매번 0이면 전투가 발생 안 함 |
| `deaths_by_stage` | 스테이지별 봇 사망 수 | 1단계에만 몰리면 초반 밸런스 과도 |
| `win` | 플레이어 승리 여부 | — |

### `combat`

| 지표 | 설명 | 이상 판단 기준 |
|---|---|---|
| `shots_fired` | 봇 전체 발사 수 | 0이면 봇이 전투 안 함 |
| `total_damage_dealt` | 게임 내 발생한 총 피해량 | 지나치게 낮으면 봇 사거리 버그 |
| `damage_by_weapon` | 무기별 피해량 | 특정 무기가 0이면 해당 무기 미사용 |
| `kills_by_weapon` | 무기별 킬 수 | — |
| `kill_distances` | 무기별 평균 킬 거리 | 피스톨 > 20m 이상이면 교전 범위 이상 |
| `attack_max_continuous` | 봇의 최장 연속 교전 시간 | > 30s → 봇이 ATTACK 루프에 갇힘 |

### `tactics` (봇 AI 검증 핵심)

| 지표 | 설명 | v0.4 기대값 |
|---|---|---|
| `ammo_empty_enter` | 탄약 소진 후 RECOVER 진입 횟수 | > 0 (정상 작동 확인) |
| `reserve_reload` | reserve 있어서 RECOVER 스킵한 횟수 | 탄약 픽업 후 증가해야 함 |
| `recover_bouts` | 실제 RECOVER 상태 진입 횟수 | ammo_empty_enter보다 적어야 정상 |
| `recover_success` | RECOVER 중 루팅 성공 횟수 | bouts 대비 50%+ 목표 |
| `died_in_recover` | RECOVER 중 사망 횟수 | 높으면 도주 로직 부족 |
| `stuck_triggered` | stuck 우회 발동 횟수 | > 0이지만 과도하면 맵/이동 문제 |
| `patrol_entered` | 루팅 못 찾고 patrol로 전환된 횟수 | 아이템이 충분하면 낮아야 함 |
| `weapon_drop_spawned` | 봇 사망 시 무기 드롭 생성 수 | 봇 사망 수와 유사해야 함 |
| `disengage_triggered` | 수적 열세(2+ 적) 감지 후 DISENGAGE 진입 횟수 | > 0이면 정상 동작, 0이면 outnumbered 감지 실패 |

### `economy`

| 지표 | 설명 | 이상 판단 기준 |
|---|---|---|
| `heals_used` | 치료 아이템 사용 횟수 | 0이면 힐 시스템 미작동 |
| `shields_picked` | 방어구 픽업 횟수 | — |
| `rare_pickups` | 희귀 아이템 픽업 횟수 | 보급 캡슐 이후 > 0 기대 |
| `weapon_pickups` | 무기별 픽업 횟수 | 특정 무기만 0이면 스폰 문제 |
| `first_upgrade_time` | 첫 피스톨 외 무기 획득까지 걸린 시간 | > 60s면 아이템 밀도 부족 |

### `supply`

| 지표 | 설명 |
|---|---|
| `telegraphed` | 보급 캡슐 예고 발생 여부 |
| `visits` | 보급 위치 방문 횟수 |
| `preannounce_interest` | 예고 중 봇이 이동 관심 표시 횟수 |
| `contests` | 보급 경합 횟수 |

---

## 테스팅 시나리오별 그룹 설정

### 봇 AI 행동 검증 (v0.4)

```gdscript
Telemetry.set_groups({
    "core":    true,
    "tactics": true,
    "combat":  true,
    "economy": false,
    "supply":  false,
})
```

**체크리스트**
- [ ] `stuck_triggered` > 0 → 끼임 감지 작동
- [ ] `reserve_reload` ≥ 0 → (v0.6+) 교전 중 ammo 아이템 opportunistic pickup 미구현으로 0 정상
- [ ] `recover_success` / `recover_bouts` > 0 → 회복 시스템 작동 확인 (v0.6+ 빠른 전투로 성공 전 피격 사망 흔함 — 500 HP 테스트에서 21% 확인, 시스템 버그 아님)
- [ ] `died_in_recover` / `recover_bouts` < 0.5 → 회복 중 사망 50% 미만
- [ ] `patrol_entered` < `recover_bouts` → 패트롤은 마지막 수단으로만 사용
- [ ] `attack_max_continuous` < 20.0 → 봇이 ATTACK에 갇히지 않음
- [ ] `weapon_drop_spawned` ≈ 봇 사망 수 (11 - alive_count) → 드롭 정상 작동
- [ ] `disengage_triggered` > 0 → 수적 열세 감지 및 DISENGAGE 상태 작동

### 무기 밸런스 검증

```gdscript
Telemetry.set_groups({
    "core":    true,
    "combat":  true,
    "economy": true,
    "tactics": false,
    "supply":  false,
})
```

**체크리스트**
- [ ] `kill_distances["pistol"]` 평균 5~12m 이내
- [ ] `kill_distances["assault_rifle"]` 평균 10~25m
- [ ] `kill_distances["shotgun"]` 평균 3~8m
- [ ] `damage_by_weapon` 비율이 픽업 빈도와 대략 비례
- [ ] `first_upgrade_time` 20~60s 사이 (너무 빠르면 초반 무기 밀도 과도)

### 경제 & 루프 검증

```gdscript
Telemetry.set_groups({
    "core":    true,
    "economy": true,
    "supply":  true,
    "combat":  false,
    "tactics": false,
})
```

**체크리스트**
- [ ] `weapon_pickups` 전 무기 종류에 고르게 분포
- [ ] `rare_pickups` > 0 → 보급 캡슐 정상 작동
- [ ] `duration` > 60s → 게임이 너무 빨리 끝나지 않음

> 체크리스트를 모두 통과하면 **DEVLOG.md** 업데이트 후 릴리즈를 진행합니다.  
> 단계 전체 기준 → [CLAUDE.md](../CLAUDE.md)

---

## 결과 파일 읽기

`sim_result_latest.json` 예시:

```json
{
  "enabled_groups": { "core": true, "tactics": true, ... },
  "session": { "kills": 3, "assists": 1, "rank": 1, "win": true },
  "core": { "duration": 87.4, "zone_stage_reached": 2, ... },
  "tactics": {
    "ammo_empty_enter": 14,
    "reserve_reload": 6,
    "recover_bouts": 8,
    "recover_success": 5,
    "stuck_triggered": 3,
    "patrol_entered": 2,
    "weapon_drop_spawned": 11
  }
}
```

---

## 추후 추가 예정 지표

| 지표 | 버전 | 용도 |
|---|---|---|
| `log_stealth` 구현 | v0.5 | 풀숲 활용률, 웅크리기 탐지 회피율 |
| `outnumbered_disengage` | v0.5 | 수적 열세 감지 후 후퇴 횟수 |
| `flank_attempts` | v0.6 | 플랭킹 시도 횟수 |
| `cover_claimed` | v0.6 | CoverRegistry 사용 횟수 |
| `shots_on_target` | 미정 | 명중률 계산 (log_shot 활용) |
