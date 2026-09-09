# Battle Capsule 개발 로그

> 최종 업데이트: 2026-09-09. 최근 검증된 작업만 유지한다. 과거 내용은 Git 이력을 참조한다.

## E-070 빈 탄약 봇의 진행 표본

- 제품 AI/맵/드랍은 유지하고 probe schema v3에 opt-in 1초 간격 상태 episode·목표/캐시·회복/순찰·전략 진행 표본과 오프라인 분석기를 추가했다. 실시간 260초 창은 전체 매치 결과를 만들지 않는다. 초기 기존 필드는 세션별 instance ID를 제외하고 E-069와 exact 일치했다.
- `builds/verification/E070_progress`: 5배 가속 전체 2-run은 721.5/753.9초·구조 gate PASS지만 진행 표본31/25개가 0.25초 지연 기준을 넘어 정밀 분석에서 제외했다. 원시 자료와 실행 중첩 한계는 INPUTS에 보존했다. 실시간 창은 261표본·최대 지연0.012초·인원/시각/중복 검사 PASS다.
- 빈 탄약 1,557/5,711 actor 표본 중 RECOVER/IDLE/CHASE는 `831/490/56`, 회복 하위 상태 탐색/순찰/엄폐는 `314/452/65`다. 재무장 관측6회, 빈 탄약 뒤 표본에서 사라진 경우17회이며 정확한 부족 시간/사망 원인으로 해석하지 않는다. 약29→15m 정상 접근 후 동일 탄약 추적을 새 episode로 재시작한 사례가 있어 E-071 소형 재현 후보로 분리한다.
- alive@120/260 `17/8`은 한 진단 창의 미해결 생존 신호이며 전체 매치/수동 개선이 아니다. 분석 fixture 7개·전체 `unit_smoke`·문서 검증 PASS, 최신 수동 결과 hash `65724e4…` 불변. 새 EXE·릴리즈·푸시는 없고 E-067 패키지를 유지한다.

## E-069 보급 접근·선점 대기 문맥 진단

- 제품 동작은 유지하고 외부 probe만 schema v2로 확장했다. 실제 존·계획 목표 거리·도착 대기 기하·HP·사후 탐색·직선 호환 탄약 거리를 읽으며 새 LOS/nav/AI 판단은 호출하지 않는다.
- 초기 재고/기존 actor 필드 exact 불변, 호환 탄 거리·현재/다음 존·도착 조건의 독립 재계산 PASS. `builds/verification/E069_context` 기본 동작 1-run은 689.3초, alive@120/260 `22/16`, first upgrade 11.9초, stuck/disengage `0.02/0.23`, AI 평균/최대 `313.2/32,555us`, fallback 0·구조 PASS다.
- 빈 탄약 봇 `9/7` 중 IDLE+선점 도착 기하는 두 시점 모두 0이다. 코드의 선점 대기 우선 분기를 주원인으로 채택하지 않고, 탐색·회복/비전투 상태·목표까지의 진행을 다음 진단으로 둔다. v1 5-run과 합산하지 않으며 새 EXE/수동 요청/런타임 수정은 없다.
- 문서 후속: README에서 공개 E-062 첨부/로컬 E-067 패키지/E-068 보류/E-069 진단을 구분하고 탄약 보존·실드/조끼 설명·Mac 미검증·다음 우선순위를 정리했다. 사용자 요청의 푸시 범위는 기존 `04bdb46`과 이 문서 갱신이며 릴리즈 첨부 교체는 포함하지 않는다.

## E-068 두 거점 유한 호환 탄약 반복 판정

- 첫 배치 총의 호환 탄약이 없을 때 기존 탄약 우선, 없으면 소모품 한 슬롯만 교체하는 opt-in을 추가했다. 총·장비·위치·파동·AI는 불변이고 제품 맵은 비활성이다. 아이템 개수는 같지만 탄종별 발 수/회복품 구성은 달라질 수 있다.
- 순수/실제 스폰 fixture와 전체 `unit_smoke`, 초기 5쌍 경계 PASS. 별도 출력 경로의 60봇 대조/후보 1-run에서 0/120/260초 재고·탄약 부족·POI 점유·목적지를 기록했고 완료/인원 일치 확인. duration 725.0/854.5초, first upgrade 12.2/11.1초, stuck/disengage `0.01/0.18`·`0.01/0.16`, fallback 0·구조 PASS다.
- 반복: `builds/verification/E068_repeat`에 pilot을 제외한 대조/후보 각 5-run을 seed 41000-41004로 순차 실행했다. 완료·입력·0/120/260초 관측 시각·인원 품질은 10/10 PASS. 평균 705.9/713.1초, 범위 596.7-930.2/543.0-847.8초, first upgrade 3.4/3.3초, stuck/disengage `0.02/0.20`·`0.02/0.18`, AI 평균/최대 `301.5/25,590us`·`291.1/22,033us`, fallback 0·기존 5-run gate 양쪽 PASS다.
- 판정: alive@30/60/90/120/180/260 중앙은 대조 `53/38/30/23/20/17`, 후보 `52/34/28/27/22/16`; T10 317.3/321.0초로 초기 생존 개선을 지지하지 않아 기본 적용 보류다. 120초 실제 관측 표본의 빈 탄약은 `33/118`·`48/127`, 10m 내 호환 탄은 `0/33`·`1/48`이고 호환 탄까지 중앙 직선 거리는 62.4/63.1m다. 지도 재고 존재를 안전한 접근 가능성으로 해석하지 않는다.
- 사용자 승인 푸시는 `70059e6`까지 원격 master SHA 확인 완료다. 반복 판정 이후 진단/문서는 별도 로컬 커밋이다. 수동 원본(`65724e4…`)은 반복/추가 진단 후에도 hash 불변이며 E-067 EXE와 기존 GitHub 릴리즈를 유지했다.

## E-067 N2-LOOT-FLOW-01 탄약 손실 분리

- 초기 5개 배치와 실제 player 강제 수집/교체 진단을 추가했다. 미보유/가득 찬 탄약을 바닥에 남기고 동일 탄종 상위 무기 교체 시 예비탄을 보존한다. 신규 가방·전역 드랍률·AI·존·맵은 변경하지 않았다. 부분 수집은 기존대로 잔여 용량만 채우고 묶음을 소비한다.
- 집계 fixture·비활성 슬롯/상한/업그레이드 중 재장전 취소/탄종 분리/비플레이어 경계와 전체 `unit_smoke` PASS. 실제 Main 재현도 무효 수집 거부·예비탄 15→15를 확인했고 초기 재고는 이전과 같다. 기존 종료 시 ObjectDB/resource 경고는 남아 있으며 새 생존 5-run이나 수동 완주 판정은 아니다.
- 우선순위: 재고 손실 수정 후 두 거점의 제한된 탄종 구성 후보를 분리한다. 초기 스냅샷은 120/260초 재고 고갈·이동·생존을 측정하지 않으며, 위치 교환만으로 호환 탄종 부재가 해소된다고 가정하지 않는다.

## E-066 N2-ITEM-VIS-01 티어 가독성

- 공통 tier 색·필드 이름/교체 비교·HUD 등급/사용 표시를 연결하고 무기 바 중앙 정렬과 라벨 크기를 보정했다. 성능·경제·AI·존·맵 데이터는 불변이며 금색 신규 티어나 특수 장비는 추가하지 않았다.
- 획득 경로/가림/교체 규칙/슬롯 상태 fixture와 전체 `unit_smoke` PASS. 실제 Night Forward+ 720p/1080p×6상태 12캡처로 두 산탄총과 재장전/빈 탄약 경고를 확인했다. 패키지 검증과 수동 결과는 CURRENT/PLAYTEST가 소유한다.

## E-065 수동 피드백과 로드맵 우선순위 정리

- E-065 근접 소리 반응 개선/후방 반응 잔여 관찰과 총·탄 부족/약한 존 압력/티어 혼동을 PLAYTEST에 기록했다. CURRENT/MASTERPLAN은 티어 가독성→유한 거점 보급→비파괴 cabin 내부 순으로 정렬하고 붕괴·폭격·보라 특수 장비는 조건부 후속으로 분리했다.
- 오래된 현재 기준선과 중복 실험 기록을 정리했다. 게임 코드·아이템 수치·실행 후보는 변경하지 않았으며 새 출시 약속·기능 구현 완료로 취급하지 않는다.
- 검증: `docs_only` PASS. 활성 문서 줄 수 예산과 현재/예정/조건부 기능의 구분을 확인했다.

## v2.1.0-demo-dev 테스트 프리릴리즈 게시

- 범위: 안정판 `v2.0.0-pre-expansion`은 유지하고 E-062 Night BR을 `v2.1.0-demo-dev` 프리릴리즈로 분리한다. Windows x64는 우선 검증 대상, macOS Universal 2는 Intel/Apple Silicon 호환성 피드백용 교차 빌드다.
- 고지: README와 릴리즈 노트에 packaged AI max 1/2 strict 실패, 수동 3판·실제 Mac·서명/공증 미완료, PCK byte 재현성, legacy 저장 경로를 명시했다. Godot MIT와 CC0 오디오 출처 문서를 추가했다.
- artifact: source `c33cdab` clean export의 Windows ZIP 37,990,493 bytes(`767412ae…`)와 macOS ZIP 64,771,016 bytes(`10364b17…`)를 GitHub 프리릴리즈에 게시했다. manifest와 `SHA256SUMS.txt`를 함께 첨부했다.
- 검증/경계: 최종 ZIP 재압축 해제 뒤 두 PCK의 exact 계약과 동일 hash `3a8c195e…`, Windows `Battle Capsule`/`2.1.0.0`, 짧은 packaged 부팅을 통과했다. Mac binary는 x86_64+arm64이고 ZIP 실행 권한 속성을 보존했지만 실기기 smoke는 하지 않았으므로 stable/latest나 공개 데모 RC로 판정하지 않는다.

## N2-PLAY-11 E-059 진단과 E-060 fallback 반증

- 구현/검증: survival-break exact aggregate를 schema v2로 올려 첫 cover의 최소 거리·진행률, 선택 후 첫 피격/사망 지연, 이미 유지되던 perception reveal의 첫 소실을 연결했다. 새 ray/scan은 없고 gameplay/RNG는 값을 읽지 않는다. schema v1 호환·검열 분모 fixture와 전체 `unit_smoke`가 PASS했다.
- 실행: sanity `C:\tmp\n2_play_11_e059_cover_progression_pilot_20260901` 뒤 `C:\tmp\n2_play_11_e059_cover_progression_5run_20260901`을 seed 41000-41004로 실행했다. 5-run 평균 665.7초(640.8-684.8), first upgrade 3.4초, fallback 0, AI 평균/최대 276.2/22,076us, `check_scale_telemetry` PASS다.
- 생존: alive@30/60/120/260 중앙값 `50/35/23/16`, T50/T10 `28.8/298.9초`로 M1 watch는 계속 FAIL이다. 진단 계약 채택이지 gameplay/package/manual PASS가 아니다.
- 원인: 648 episode 중 cover 진행을 530건 관측했고 평균 진행률은 0.11, 선택 거리 평균은 12.98m다. 사망 68건은 `no_progress/partial/reached=34/32/2`, 선택 후 첫 피격 `under0.25/0.25-1/1s+=10/37/21`, perception 소실 `24/68`로 모든 seed에서 낮은 진행이 반복됐다.
- 해석: 사망 counteraction `62/68`, fast reacquire `43/68`은 높지만 counteraction은 이동을 정지시키지 않고 E-058도 재획득 단독 원인을 반증했다. 평균 사망 선택 후 1.62초와 4m/s 이동에 비해 평균 12.98m cover가 멀다는 reachability가 더 직접적인 다음 축이다.
- E-060: 4m/s×1.5초의 6m 안 cover만 채택하고 없으면 기존 deterministic scatter를 쓰는 pure/runtime seam은 전체 `unit_smoke`를 통과했다. `C:\tmp\n2_play_11_e060_reachable_cover_fallback_pilot_20260901`은 486.6초, alive `54/27/24/22/21/18`, survival death 21, stuck 0.04/entity/min, stage3 미도달로 hard FAIL했다.
- E-061: 기존 cover/nav를 보존하고 `survival_break` 접근 속도만 1.25배로 올린 후보는 전체 `unit_smoke`를 통과했다. `C:\tmp\n2_play_11_e061_cover_approach_speed_125_pilot_20260901`은 536.0초, alive `50/34/25/22/18/12`, T50/T10 `29.2/276.3초`, survival death 17, cover selected/reached `87/4`, 진행률 0.09, stuck 0.03/entity/min, stage3 미도달로 hard FAIL했다.
- 판정/다음: E-061은 코드·테스트 완전 revert·5-run 금지다. 동일 seed E-059의 806.8초·cover 진행 0.11·stuck 0.01에 비해 생존/도달은 그대로이고 구조 gate가 악화됐다. episode 108건 중 `no_threat` 종료 91건, perception 소실 84건, 평균 exit 0.68초이므로 E-062는 속도나 blanket 시간 연장이 아니라 선택한 cover까지의 spatial commitment만 단일 후보화한다.
- E-062 구현/검증: `survival_break`에서 cover가 이미 선택됐고 threat가 사라진 경우에만 해당 공간 목표 도달까지 nav를 유지한다. 도달·8초 timeout·zone/ammo override는 유지하고 일반 DISENGAGE와 플레이어는 바꾸지 않았다. pure policy fixture, headless parse와 전체 `unit_smoke`가 PASS했다.
- E-062 실행: pilot `C:\tmp\n2_play_11_e062_spatial_cover_commitment_pilot_20260901` 뒤 `C:\tmp\n2_play_11_e062_spatial_cover_commitment_5run_20260901`을 seed 41000-41004로 실행했다. 5-run 평균 753.5초(576.3-881.9), first upgrade 3.4초, fallback 0, AI 평균/최대 305.3/35,241us, `check_scale_telemetry` PASS다.
- E-062 판정: alive 중앙 `52/39/30/26/23/19`, T50/T10 `33.2/322.8초`, survival-state death rate `4.78→4.18/100s`, DISENGAGE death rate `6.40→5.30/100s`, cover selected/reached `269/42`, 진행률 `0.11→0.26`, 빠른 동일 표적 재획득 `28.3→25.3%`, stuck/disengage `0.02/0.17`로 자동 후보를 유지한다. episode death `68→84`와 전체 DISENGAGE reengage `14.9→25.0%`는 수동 watch이며 M1/package PASS는 아니다.

## N2-PLAY-11 opening survival exposure 진단과 릴리즈 재판정

- 계측 계약: schema v1은 `Main.match_timer` 기준 opening 60초의 이전 held 상태·위치를 다음 관측까지 적분해 exact RECOVER/DISENGAGE actor-seconds·death·acquisition·entry를 POI/route 축으로 집계한다. identity·coverage·overflow가 위치 판정을 차단하며 bounded sample은 분모를 대신하지 않는다.
- 자동 검증: exposure telemetry/analyzer·headless parse·`git diff --check`와 전체 `unit_smoke` 87.5초가 통과했다. behavior와 RNG를 바꾸지 않는 계측 계약·정적 위치 분류·비용 gate를 확인했다.
- 1-run 구조 결과: `C:\tmp\n2_play_11_survival_exposure_sanity_20260828`은 849.696초, first upgrade 12.4초, spawn 60/60·fallback 0, AI 평균/최대 264.7/35,515us였다. data-quality와 `check_scale_telemetry`는 PASS다.
- 생존 결과: alive@30/60/120/260은 `55/29/22/15`, T50/T10은 `35.8/279.8초`라 gameplay/survival은 FAIL이다. 단일 run이므로 기준선 승격이나 릴리즈 근거로 쓰지 않는다.
- 상태 노출: exact 444.3 actor-sec는 known 100%·overflow false다. DISENGAGE 318.4초·사망 24명·7.54/100초, RECOVER 126.0초·사망 0명이며 entry/exit는 `305/303`이다.
- 종료 문맥: 생존 상태 사망 24명 중 22명이 `survival_break` 진입이고 18명은 진입 2초 미만이었다. continuity release 78 중 1초 내 같은 대상 재획득은 22(28.2%)다.
- 판정/후속: 위치 노출 정규화는 단일 hotspot을 지목하지 않아 topology를 바꾸지 않는다. E-056은 revert됐고 후속 E-057 exact linkage 결과는 위 최신 기록이 소유한다.
- 릴리즈: 현재는 internal pre-alpha다. 공개 stable `v2.0.0-pre-expansion`을 유지하고, 폐쇄 알파 현실 창은 2026-09-28~10-09, 공개 데모 RC 현실 창은 2026-12-18~2027-01-15로 재조정했다. 날짜는 gate 통과 창이다.

## N2-PLAY-11 continuity v2 기준선과 후보 폐기

- 근거: N2-PLAY-10 packaged 6판은 16-240초, 88초 `25/61`, 92초 우승과 초기 무기 5개·주울 수 없는 권총 드랍 55개·전체 지도 HUD 중첩으로 M1을 거부했다.
- 경제/스폰: 14개 POI에 초기 장총 18개와 오브젝트 앵커를 명시하고 기본 권총 무기 드랍을 제거했다. 반경 스폰은 면적 균등화하고 `bot_drop` soft/hard 120/150초, `stage_wave` 180/210초 TTL과 비무기 pool을 적용했다.
- 화면/계측: 전체 지도에서 gameplay HUD를 격리하고 미니맵을 220px로 줄여 최근 교전 중 정적 배경만 흐리게 했다. 사망별 alive event staircase, 절대 50명/10명과 중앙값·완료 carry/수동 censor 분석을 추가했다.
- continuity 계약: behavior-neutral schema v2는 `Main.match_timer`를 canonical clock으로 쓰고 unique episode의 `complete=true` exact aggregate를 판정 근거로 둔다. raw는 run마다 결정적 bottom-k release episode·DISENGAGE exit 각각 최대 128개로 제한하며 population/stored/omitted/complete를 분리하고 terminal target release를 제외한다.
- 사전 확인: v2 1-run sanity는 aggregate/sample data contract를 통과했지만 stuck gate를 실패해 기준선이나 gameplay 근거로 승격하지 않았다.
- 5-run 기준선: `C:\tmp\n2_play_11_continuity_v2_5run_20260814`은 평균 668.8초·범위 531.5-805.5초, first upgrade 3.5초, fallback 0, alive@30/60/90/120/180/260 중앙값 `54/34/24/23/21/15`, T50/T10 `31.5/306.7초`였다. D-004와 `check_scale_telemetry`를 통과했다.
- 종료 문맥: opening kill 132건 중 생존 상태 피해자 100건·2초 이내 71건이며 59초 이내 생존 상태 unique release 414·1초 내 재획득 132(31.9%)·opening DISENGAGE exit 1284다. 기록된 `tactics.disengage_entries/(spawned×duration_min)` 보조 watch는 run2 0.782·run4 0.864로 2/5에서 0.70을 넘었다.
- 폐기/상태: bot-only HP buffer와 DISENGAGE 첫 1초 counteraction grace는 각각 1-run 방향 gate를 실패해 완전 revert하고 5-run을 금지했다. ceasefire 등 기존 실패 후보와도 재혼합하지 않으며 gameplay PASS·새 package·packaged 수동 결과는 없다. 다음은 behavior-neutral opening 생존 상태 노출 분모로 반복 이탈과 근거리 교전 집중의 위치·상태 원인을 좁힌다.

## N2-REL-01 릴리즈 저장·식별·export 기반

- 현재 E-062 clean artifact: source `2acf9651eeff1c79a64d9190ea4c8e66f83a0c7d`의 fresh detached worktree에서 `BattleCapsule.exe` 104,548,352 bytes와 PCK 2,132,932 bytes를 export했다. 빈 host package verifier가 catalog 자산 44개·JSON 3개·runtime 경로 124개·load probe 20개·generated payload closure exact를 통과했고 EXE product/file description과 `2.1.0.0` metadata도 일치했다.
- 현재 packaged smoke: `C:\tmp\n2_rel_01_e062_packaged_smoke_20260901`의 seed 41000/41001은 평균 661.8초(630.4-693.2), alive 중앙 `55.5/39.5/30/26/24/19`, first upgrade 평균 6.3초, spawn 60/60·fallback 0, stuck/disengage 0.02/0.20이다. AI max는 `57.914/28.584ms`라 두 번째 run은 PASS지만 합산 strict gate는 첫 spike 때문에 FAIL이다.
- 현재 artifact hash: EXE `B241A13F6FB1E7FB297018D6D622601F9D68A5B4F8B0B389ED7F6CD5690E238D`, PCK `488EA4B94BFEFB73C4857A0A2EC875F999A07D89383D0AE92411EB9341B20A20`. `LICENSES/CREDITS`·`KNOWN_ISSUES`·build manifest가 없고 Forward+ 반복·사람 전체 루프·정상 저장·재시작도 미판정이라 archive는 만들지 않았다.
- 저장: 미션 판정 뒤 Result와 Records가 같은 점수를 커밋하고 simulation은 기록·배지를 남기지 않는다. 설정·기록·배지는 schema v1, 원자 교체, last-good backup, corrupt fallback과 legacy migration을 쓰며 기록은 난이도별 50개로 제한한다. 현재 공개판 rollback root write를 병합하고 지원하지 않는 미래 schema는 덮어쓰지 않는다.
- 식별: 공개 이름 `Battle Capsule`, 실행 파일 `BattleCapsule.exe`, 내부 채널 `v2.1.0-demo-dev`, Windows metadata `2.1.0.0`을 고정했다. 보이는 브랜드는 바꾸되 기존 `BattleRoyalePrototype` user data 경로는 유지한다.
- export: `Main.tscn` selected-scene 경계와 runtime source/assets·검토된 JSON만 포함하고 도구·테스트·문서·로컬 생성 원본·debug 산출물을 제외했다. verifier는 catalog 자산·runtime 논리 경로와 import/remap payload closure를 exact 비교한다.
- 자동 검증: release persistence/identity/settings가 포함된 `unit_smoke`를 84.6초에 통과했다. windowed 1280×720 Forward+ 3회 p95 15.059-15.429ms·p99 17.641-19.948ms로 p95 20ms 초과 0/3, 고정 입력 99봇 구조 5-run은 정체/이탈 0.01/0.44 per entity/min로 통과했다.
- 과거 clean artifact: source `ac9fff8fc115c86003da7a5685fbce0dc0b48d58`의 fresh worktree PCK에서 catalog 자산 44개·JSON 3개·runtime 경로 124개·핵심 load probe 20개와 generated payload closure exact를 확인했다. packaged headless 전체 simulation은 651.038초, spawn 60/60·fallback 0·최종 1위·오류 0이었고 legacy settings migration/backup·재실행 멱등성, 기존 기록·배지 불변, Windows x64 GUI·`2.1.0.0` metadata를 통과했다. 현재 후보 근거는 아니다.
- 과거 internal archive: EXE `B241A13…`, PCK `560CFD44…` SHA-256을 manifest에 기록하고 archive `92891081…` SHA-256을 산출했다. 압축 해제 뒤 세 파일 hash와 EXE 재부팅·오류 0도 확인했다. 이 archive는 공개 고지가 없는 stale internal smoke다.
- 재현성: 독립 clean worktree 두 곳의 EXE는 byte-identical이었지만 PCK는 2,060,916/2,060,900 bytes와 서로 다른 hash였다. 두 PCK 모두 exact contract를 통과했으나 cold PCK byte 재현성은 닫지 않았다.
- 잔여 gate: E-062 자동 gameplay와 current clean EXE/PCK는 확보했지만 packaged AI max spike 반복 판정, 수동 3판, 사람이 조작하는 전체 루프·정상 기록/배지 저장, cold PCK 비결정성·restart soak·호환성 matrix, LICENSES/CREDITS·KNOWN_ISSUES·manifest·지원·unsigned 정책은 아직 닫지 않았다.

## 기록 보존

이 문서는 최근 10개 작업 또는 120줄까지만 유지한다. 오래된 항목과 삭제된 전체 사본은 `git log -- docs/DEVLOG.md docs/MASTERPLAN.md`로 찾고, 필요한 커밋에서만 읽는다.
