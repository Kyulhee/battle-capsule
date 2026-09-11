# Battle Capsule 개발 로그

> 최종 업데이트: 2026-09-12. 최근 검증된 작업만 유지한다. 과거 내용은 Git 이력을 참조한다.

## E-074 비활성 진단의 초기 ID 중립성

- E-073의 대조/후보4+4를 보존하고 비교에서 제외했다. OFF에서도 eager 진단 Resource/RefCounted가 ID를 소비해 첫 입력60봇 모두의 ID%8 방향이 달랐다. ID를 제외한 초기 필드 일치만으로 중립성을 판정한 검증 공백이다.
- probe의 진단 스크립트/객체는 ON일 때 봇 생성 뒤에만 로드한다. 부모 `9f23dde`와 OFF/ON의 초기 스냅샷을 원시 ID까지 exact 확인했다. OFF 미로드·미생성과 OFF/ON/loot 후보 전체 초기 일치를 검사하는 실제 실행 fixture를 추가했고 전체 unit_smoke PASS다. E-074 별도 출력에 비계측5+5를 재수행하며 기본 게임 동작·패키지는 유지한다.
- `3220d11` 비계측5+5 완료: 다섯 쌍 초기 ID exact, 합계332,847 AI표본, 평균696.0/750.5초·최대22,638/26,514us·양군 gate PASS. 탄약 추적 수집/포기 평균52.2/40.8→52.8/33.6, 무기25.8/28.0→28.4/18.8이나 120초 빈 탄약24.2→25.0%, alive260 중앙17→17로 기본 승격하지 않는다.
- 260초 대조4판만 stage2 wave184~186개를 포함해 필드 평균175.6→28.4의 직접 비교는 무효다. 지연0.25초 이내도 phase가 다를 수 있어 최종 `summary_phase_aware.json`에 단계/수축 불일치를 명시했다. 원시10판·E-071 실패·수동 hash불변, EXE/푸시 없음. 다음은 phase 정렬 관측과 회복 탐색 진단이다.

## E-072 AI 단계 계측과 실제 추적 확인

- 기본 비활성 sink로 기존 AI timer를7구간으로 나눴다. 같은 종료 시각·4회당1회 표본을 유지하고5ms 이상 중 느린32개만 저장한다. 합성6ms handler·합계/샘플 주기·저장 상한/누락·오프라인 분석·전체 unit_smoke PASS. CPU 작업과 OS 중단은 구분하지 못하며 계측 비용을 비계측 pacing에 섞지 않는다.
- `builds/verification/E072_ai_phases` seed41000 대조/후보는767.3/640.6초·AI max35,381/26,467us로 단발 gate PASS. 최대 구간은 각각 IDLE→CHASE 및 ATTACK handler, 모두 비loot였다. 기존 E-071의1.19초 실패는 보존하며 원인을 단정하지 않는다.
- 추가seed41001 대조/후보665.3/752.0초·max18,136/24,522us. 총128,879표본 중50ms 초과0, 양군2-run 진단 gate와 네 파일의 capture/telemetry 무결성 PASS. 비계측5+5를 별도로 진행하며 과거 실패가 해결됐다고 판정하지 않는다.
- 별도 실시간 후보 창은261표본·최대 지연0.0128초·alive120/260=18/7, 재무장 관측16회다. 같은 목표를5초 넘게 추적한 뒤 다음 표본에 재무장한 사례를 확인했다. 빈 탄약1,482표본 중 RECOVER739/IDLE465이므로 보급 병목 전체 해결이나 생존 개선을 뜻하지 않는다. 전체 매치 결과 미생성·수동 hash불변을 확인했다.

## E-071 진행 기반 아이템 추적 opt-in

- 사용자 승인으로 `9f23dde`까지 원격 master SHA 반영을 확인했다. 이후 후보는 로컬/기본 비활성이다. 기존 5초 제한은 유지하고 외부 probe만 후보를 켜며, E-068 동시 활성은 거부한다. 드랍·시야·전투 우선순위·지도·사용자 패키지는 바꾸지 않았다.
- 후보는 최단 목표 거리0.5m 개선 때 정체 시계를 갱신하고 5초 정체/총15초 상한으로 기존 재탐색·포기를 유지한다. 수집 반경은 도착을 우선하며 직선 거리 한계상 길게 멀어지는 우회는 아직 포기할 수 있다. 추가 전역 탐색/LOS/nav query는 없다.
- 결정적 handler fixture에서 30m 대조는5.1초에12.5m를 남기고 포기, 후보는8.0초에 수집했다. 정지/미세왕복·총시간 상한·도착·retarget 초기화·목표 삭제·적 반응 우선순위, 전체 unit_smoke, 분석기 후보 구분/fixture7개 PASS다. 이동/지각 fixture와 실제 NavMesh 검증은 구분한다.
- `builds/verification/E071_chase` 첫60봇 후보는759.0초·alive120/260 `26/16`·first upgrade16.0초·stuck/disengage0.02/0.19·fallback0이다. AI 평균339.1us/최대1,187,585us로 50ms gate FAIL. 종료 상태 bucket은 DEFENSIVE/DISENGAGE이지만 해당 함수나 후보가 원인/무관하다고 단정할 수 없다. 실패를 보존하고 반복 승격 전에 재현을 확인한다.
- 같은 입력의 순차 재실행은648.8초·alive120/260 `28/18`·AI 평균351.3us/최대24,256us로 급증이 재현되지 않았다. 합산 성능 gate는 첫 실패 때문에 FAIL이다. 두 판의 초기 재고/actor 기존 필드·완료/인원/관측 시각과 후보 혼합 거부를 확인했고 수동 hash `65724e4…` 불변이다. 성능 원인 확인 전 기본 적용/5+5 승격/새 패키지는 보류한다.

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

## N2-REL-01 과거 기반 요약

- 저장의 원자 교체/backup/migration, simulation의 기록·배지 미기록, 브랜드/기존 user data 경로 유지, PCK payload exact 검증은 유지한다. 과거 E-062 export와 AI max57.914ms 실패 등 상세 근거는 Git 이력에 보존한다. 현재 패키지와 미해결 수동·성능·배포 gate는 CURRENT가 기준이다.

## 기록 보존

이 문서는 최근 10개 작업 또는 120줄까지만 유지한다. 오래된 항목과 삭제된 전체 사본은 `git log -- docs/DEVLOG.md docs/MASTERPLAN.md`로 찾고, 필요한 커밋에서만 읽는다.
