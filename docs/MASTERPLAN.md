# 마스터플랜

> 최종 업데이트: 2026-08-29. 남은 작업은 마일스톤 -> 트랙 -> 종료 조건 -> 다음 slice 순서로 관리한다.

## 현재 제품 목표

Battle Capsule은 low-poly quarter-view tactical roguelite battle royale이다. 현재 목표는 “많은 봇이 도는 시뮬레이션”을 넘어, 외부 사용자가 설명 없이 설치하고 10-15분 Night BR 한 판을 완주·재시작할 수 있는 Windows 무료 데모를 만드는 것이다.

첫 공개 범위는 Windows x64, 오프라인 싱글플레이, 한국어, 키보드/마우스, `night_br_m1_60` 한 맵이다. 99봇 기본값, 온라인, macOS 공개 지원, 영어·controller, 완전한 flashlight/fear/battery는 이 범위에 포함하지 않는다.

## 마일스톤

| ID | 이름 | 상태 | 완료 기준 |
|---|---|---|---|
| M0 | 운영 기반 | 지원 중 | 현재 상태를 빠르게 재개하고 검증·빌드·푸쉬 결과를 반복 가능하게 유지 |
| M1 | 첫 플레이 가능한 Night BR | 종료 판정 중 | behavior-neutral episode linkage로 반복 fatal path를 고른 새 단일 후보가 1-run 방향 gate 뒤 5-run과 packaged 수동 3판을 통과하고 기존 성능·99 구조 gate를 보존 |
| M2 | 릴리즈 버티컬 슬라이스 | 다음 | 캐릭터·전투·야간·HUD·오디오·온보딩이 대표 한 판에서 설득력 있게 동작 |
| M3 | Windows 공개 데모 RC | 계획 | 실제 패키지·저장·호환성·외부 테스트·고지 gate를 통과하고 P0/P1 결함이 없음 |
| M4 | 오프라인 유료 EA 판단 | 이후 | 데모 반응 뒤 콘텐츠 반복성·운영·업데이트 범위에 대해 Go/No-Go |

## 릴리즈 단계

| 단계 | 제품 마일스톤 연결 | 목표 창 | 승격 결과 |
|---|---|---|---|
| R0 폐쇄 알파 후보 | M1 + `N2-REL-01` | 현실 창 2026-09-28~10-09 | 제한을 명시한 Windows 폐쇄 알파와 외부 테스트 시작 |
| R1 공개 무료 데모 RC | M2 + M3 | 현실 창 2026-12-18~2027-01-15 | clean artifact, 공개 페이지, 지원 경로를 갖춘 Windows 데모 RC |
| R2 유료 오프라인 EA 판단 | M4 | 2027 Q1 이후 | 데모 지표를 근거로 EA 진행·연기·중단 결정 |

날짜는 1인 풀타임 개발 기준 계획 창이며 약속된 출시일이 아니다. gate 실패 시 날짜보다 원인 수정과 재검증을 우선한다.

현재 개발 후보는 internal pre-alpha이며 공개 stable은 `v2.0.0-pre-expansion`을 유지한다. 새 package·수동·M2/M3 gate가 닫히기 전에는 공개판을 교체하지 않는다.

## 현재 기준선

- M1 개발 맵: `data/mapSpec_night_forest_expanded_candidate.json`
- M1 공통 preset: `night_br_m1_60` (일반 실행·수동 플레이·후보 페이싱 검증)
- 구조 부하 gate: `target_99_probe`; 제품 gameplay·출시 규모의 근거로 사용하지 않음
- 이전 continuity 기준: behavior-neutral `C:\tmp\n2_play_11_continuity_v2_5run_20260814` 5-run 평균 668.8초, 개별 531.5-805.5초, fallback 0, `check_scale_telemetry` PASS
- 최신 E-057 5-run: `C:\tmp\n2_play_11_survival_break_episode_linkage_v2_5run_20260829` 평균 709.4초(583.4-773.9), first upgrade 3.4초, fallback 0, AI 평균/최대 298.9/24,940us로 exact linkage·구조 gate PASS
- 존 기준: 첫 축소 120초, stage2 260초, stage3 540초
- 최신 gameplay 증거: N2-PLAY-10 packaged 수동 6판은 16-240초, 순위 60-1에 분포했고 88초 `25/61`, 92초 우승, 최신 stage1 사망 56명으로 M1 생존 페이싱을 거부했다
- 최신 E-057 생존: alive@30/60/120/260 중앙값 `51/35/24/15`, T50/T10 `30.7/305.1초`로 gameplay/survival FAIL이며 packaged 수동 결과는 없다
- episode linkage: 581 episode/89 death 중 cover 선택-미도달 83, counteraction 68, fast reacquire 55, entry-target killer 58. fast reacquire 277건 중 retreat_counteraction 276건이며 run별 미도달 사망 `22/16/13/17/15`로 반복됐다
- E-056 결과: 2.0초 `no_threat` hysteresis는 alive@60/120 `38/25`로 개선했지만 survival death `20>19`, 5m survival kill `14>13`, fast reacquire `35.8%>31.9%`로 hard gate를 실패했다. 완전 revert·5-run 금지이며 시간/조건 조정과 이전 실패 후보 재혼합을 하지 않는다
- 다음 후보: E-058은 `survival_break` DISENGAGE의 bot retreat counteraction에서 release target 재소유만 분리하고 gun 방어는 유지한다. player·damage reacquire·일반 DISENGAGE는 불변이며 1-run 실패 시 즉시 revert한다
- 보존 중인 자동 근거: N2-MAP-17의 Brush Camp·Survey Camp, release persistence/identity/settings와 exposure verifier를 포함한 `unit_smoke`, 고정 입력 `target_99_probe` 5-run
- stale package 근거: `ac9fff8` clean package exact inventory·전체 simulation·archive smoke는 당시 source만 증명하며 현재 candidate package로 재사용하지 않는다
- 최신 성능: windowed 1280×720 Forward+ p95/p99 15.429/19.948, 15.059/17.641, 15.197/17.924ms; p95 20ms 초과 0/3
- 과거 채택·폐기 상세는 `DEVLOG.md`, `EXPERIMENTS.md`, Git 이력이 소유함

## Night BR 페이싱 판정 창

| 지표 | 목표 창 | 현재 | 판단 |
|---|---|---|---|
| first upgrade | 2-30초 | 12.4초(1-run) | 방향 통과, 5-run에서 재판정 |
| stage2 | 240-420초 | 260.0초(1-run) | 자동 통과 |
| stage3 | 540-720초 | 540.1초 | 자동 통과 |
| match duration | 평균 600-900초, 개별 480-960초 | 849.696초(1-run) | 개별 방향 통과, 5-run 분포는 미판정 |
| alive@120 | 5-run 중앙값 34-46명(1차 watch) | 22명(1-run) | 실패, 새 단일 후보의 1-run에서 방향부터 확인 |
| alive@260 | 5-run 중앙값 17-29명(1차 watch) | 15명 | 실패, 첫 축소 완료 전 한 자리 방지 |
| 10명 도달 | 5-run 중앙값 360-650초(1차 watch) | 279.8초(1-run) | 실패, duration gate와 함께 판정 |
| 상태 노출 진단 | 고정 절대 gate 없음 | DISENGAGE 7.54 deaths/100초, RECOVER 0 | 후보 전후 causal 비교용, 단독 PASS 금지 |

생존 watch band는 첫 계측 후보를 거르는 내부 범위이며 출시 약속이 아니다. 새 후보는 1-run에서 방향성과 D-004·fallback·정체/이탈 보존을 보일 때만 5-run으로 확대하고, 5-run 통과 전에는 packaged 수동 3판으로 넘기지 않는다.

## 단계별 필수 gate

| 단계 | 필수 gate |
|---|---|
| R0 폐쇄 알파 후보 | N2-PLAY-11 지정 단일 후보 1-run→유효할 때만 M1 5-run→packaged 수동 3판, `unit_smoke`, Forward+ 이상치 재측정, 최종 `target_99_probe` 구조 회귀, 현재 commit의 점수/기록·저장·clean Windows 패키지 전체 루프 smoke |
| R1 공개 데모 후보 | M2 비주얼·UX exit, 무설명 테스터 5-10명의 첫 판 완주, 외부 20회 이상 완주, Win10/11·다중 해상도·최소 3개 하드웨어 등급·전체 매치/재시작 soak, P0/P1 0, 브랜드·버전·라이선스·고지·manifest/checksum |
| R2 유료 EA 판단 | 의미 있는 진행 또는 두 번째 콘텐츠 축, 20-30명·100회 이상 beta, 두 연속 RC의 save upgrade/rollback, keybind·독립 음량·접근성 범위, 자동 릴리즈·서명·업데이트/롤백 계획, P0/P1 0 |

## 현재 구현 상황

| 영역 | 현재 강점 | 릴리즈 공백 | 다음 gate |
|---|---|---|---|
| 매치/AI/맵 | 60봇 공통 표면, 실제 NavMesh·전투·전략 gate, continuity v2·exposure v1·E-057 episode exact aggregate | E-057은 cover 미도달과 retreat reacquire를 지목했지만 생존 watch는 실패한다 | E-058 target-ownership 단일 seam 1-run→유효할 때만 5-run |
| 비주얼/오디오 | 일관된 low-poly 프롭, 픽업 glow·아이콘, 총성·발걸음 일부 | 겹친 수관, procedural capsule, 약한 전투 피드백, 핵심 fallback audio | N2-M2-VIS-01 |
| UI/첫 사용자 | 메뉴·HUD·지도·아티팩트·결과·기록 골격 | HUD 위계, 혼합 언어, 밝기·감도·해상도·UI scale·첫 판 안내 | N2-M2-UX-01 |
| 기록/저장 | 기존 자동 계약에 더해 packaged legacy settings migration/backup·재실행 멱등성·simulation 중 기록/배지 불변 확인 | 사람 정상 매치의 기록·배지 생성/재실행과 실제 future migration/rollback matrix | N2-REL-01/02 |
| 빌드/법적 고지 | `ac9fff8`에서 clean PCK exact inventory, Windows x64 GUI metadata, 전체 headless simulation, internal manifest/checksum·archive extract/reboot 통과 | 근거가 현재 후보보다 오래됐다. current commit clean package, 사람 전체 루프, cold PCK byte 재현성, LICENSE/NOTICE/CREDITS·지원/서명 범위 | N2-REL-01/02 |
| 호환성/외부 QA | 1280x720 개발 머신의 짧은 profile과 같은 머신 packaged headless 전체 simulation | 사람 전체 매치·restart soak, Win10/11·한글/읽기 전용 경로·저사양·다중 해상도·지원 경로 부재 | N2-REL-02 |
| 콘텐츠 반복성 | 한 맵, 5개 무기, 6개 artifact, 4개 난이도, 미션 | 배지 노출·장기 진행·두 번째 콘텐츠 축 부족 | 공개 데모 반응 뒤 M4 |

## 남은 작업 구조

| 순서 | 트랙 | 종료 조건 | 다음 slice |
|---|---|---|---|
| 1A | M1 종료 | E-058이 생존·continuity 1-run을 통과할 때만 5-run으로 확대해 실제 3판까지 통과 | N2-PLAY-11 |
| 1B | 릴리즈 기반 마감 | gameplay 후보를 고정한 current commit에서 clean artifact를 재생성하고 사람 전체 루프·정상 기록/배지·cold PCK byte 재현성을 닫음 | N2-REL-01, 1A와 병행 |
| 3 | M2 비주얼 슬라이스 | 수관·야간·캡슐/무기·전투 피드백·HUD/지도가 대표 구간에서 수동 통과 | N2-M2-VIS-01 |
| 4 | M2 첫 사용자 UX | 무설명 사용자가 설정→첫 판→결과→재시작을 완료 | N2-M2-UX-01 |
| 5 | M3 데모 RC | 실제 artifact와 외부/호환성 matrix가 R1 gate 통과 | N2-REL-02 |
| 6 | M4 EA 판단 | 데모 지표로 콘텐츠·플랫폼·운영 투자를 결정 | R1 공개 후 |

## 범위 확장 경계

- 신규 장소·무기·방어구 티어보다 현재 한 판의 가독성·피드백·첫 사용자 완주를 먼저 닫는다.
- 공개 데모 이후 반복성 부족이 실제 이탈 원인일 때만 두 번째 콘텐츠 축이나 보이는 진행을 추가한다.
- online/99 default/macOS/영어/controller는 각자의 비용·QA·운영 gate를 가진 별도 범위 결정으로 다룬다.

## 우선순위 원칙

1. N2-PLAY-11은 E-057이 지목한 retreat target 재소유만 E-058로 분리한다. 1-run에서 생존·continuity·정체/이탈·D-004가 함께 개선될 때만 5-run→packaged 수동 3판으로 확대하고 E-056 등 실패 후보를 재혼합하지 않는다.
2. 점수·저장·export·버전·고지는 화면 폴리시와 별개의 release blocker이므로 M2 전에 N2-REL-01로 제거한다.
3. M2는 신규 콘텐츠가 아니라 플레이어가 실제로 보는 수관·캐릭터·전투·HUD·오디오·온보딩을 우선한다.
4. 공개 승격은 소스 실행이 아니라 clean packaged artifact와 외부 사용자의 무설명 완주를 기준으로 한다.
5. 큰 파일 리팩터링은 release slice가 닿는 경계에서만 작게 수행한다.

## 금지된 빠른 해결책

- 99명 default promotion.
- M1 수동 판정 전 공개 릴리즈 또는 M2 품질 gate 전 공개 데모 승격.
- dirty workspace에서 만든 artifact 공개, manifest/checksum 없는 archive 승격.
- 저장 손실·기록 오염·제품 식별 불일치를 known issue로만 남기고 공개.
- 데모 critical path보다 신규 장소·장비·온라인·macOS 범위를 우선.
- broad economy cut으로 first upgrade 해결.
- broad weapon chance cut.
- stuck 원인 분리 없이 장애물 위치만 반복 이동.
- gate 완화로 candidate 통과.

## 문서 운영

- `CURRENT.md`: 지금 할 일과 다음 slice.
- `DECISIONS.md`: 안정 결정.
- `EXPERIMENTS.md`: 채택/폐기 실험.
- `PLAYTEST.md`: 수동 체감.
- `DEVLOG.md`: 최근 완료 작업.
- 구조/검증/맵/릴리즈 자료는 `reference/`, 자산 자료는 `assets/`에서 필요할 때만 읽는다.
- 오래된 장문과 압축 전 원문은 별도 사본을 만들지 않고 Git 이력에서 확인한다.
