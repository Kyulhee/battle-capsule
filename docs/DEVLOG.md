# Battle Capsule 개발 로그

> 최종 업데이트: 2026-08-29. 최근 검증된 작업만 유지한다. 과거 내용은 Git 이력을 참조한다.

## N2-PLAY-11 E-057 survival-break episode linkage

- 구현/검증: behavior-neutral exact aggregate가 entry 59초 이하 `survival_break` DISENGAGE의 HP·shield·target visibility/distance, cover 선택/도달, 피격·counteraction, release/reacquire, exit/death를 actor+state episode로 연결한다. gameplay/RNG는 이 값을 읽지 않으며 전체 `unit_smoke` 90.4초가 PASS했다.
- 실행: `C:\tmp\n2_play_11_survival_break_episode_linkage_v2_5run_20260829` 5-run은 평균 709.4초(583.4-773.9), first upgrade 3.4초, fallback 0, AI 평균/최대 298.9/24,940us, `check_scale_telemetry` PASS다.
- 생존: alive@30/60/120/260 중앙값 `51/35/24/15`, T50/T10 `30.7/305.1초`로 M1 watch는 여전히 FAIL이며 gameplay/package/manual PASS가 아니다.
- 원인: 581 episode/89 death 중 cover 선택 후 미도달 83, counteraction 68, fast same-target reacquire 55, entry-target killer 58이었다. run별 미도달 사망도 `22/16/13/17/15`로 반복됐고 fast reacquire 277건 중 276건이 `retreat_counteraction`이었다.
- 판정/다음: E-056 시간 연장은 실패 상태로 유지한다. E-058은 bot 대상 retreat counteraction이 release target을 다시 소유하지 않고 gun 방어만 유지하는 단일 seam을 1-run으로 검증하며 player·damage reacquire·일반 DISENGAGE는 바꾸지 않는다.

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

- 저장: 미션 판정 뒤 Result와 Records가 같은 점수를 커밋하고 simulation은 기록·배지를 남기지 않는다. 설정·기록·배지는 schema v1, 원자 교체, last-good backup, corrupt fallback과 legacy migration을 쓰며 기록은 난이도별 50개로 제한한다. 현재 공개판 rollback root write를 병합하고 지원하지 않는 미래 schema는 덮어쓰지 않는다.
- 식별: 공개 이름 `Battle Capsule`, 실행 파일 `BattleCapsule.exe`, 내부 채널 `v2.1.0-demo-dev`, Windows metadata `2.1.0.0`을 고정했다. 보이는 브랜드는 바꾸되 기존 `BattleRoyalePrototype` user data 경로는 유지한다.
- export: `Main.tscn` selected-scene 경계와 runtime source/assets·검토된 JSON만 포함하고 도구·테스트·문서·로컬 생성 원본·debug 산출물을 제외했다. verifier는 catalog 자산·runtime 논리 경로와 import/remap payload closure를 exact 비교한다.
- 자동 검증: release persistence/identity/settings가 포함된 `unit_smoke`를 84.6초에 통과했다. windowed 1280×720 Forward+ 3회 p95 15.059-15.429ms·p99 17.641-19.948ms로 p95 20ms 초과 0/3, 고정 입력 99봇 구조 5-run은 정체/이탈 0.01/0.44 per entity/min로 통과했다.
- 과거 clean artifact: source `ac9fff8fc115c86003da7a5685fbce0dc0b48d58`의 fresh worktree PCK에서 catalog 자산 44개·JSON 3개·runtime 경로 124개·핵심 load probe 20개와 generated payload closure exact를 확인했다. packaged headless 전체 simulation은 651.038초, spawn 60/60·fallback 0·최종 1위·오류 0이었고 legacy settings migration/backup·재실행 멱등성, 기존 기록·배지 불변, Windows x64 GUI·`2.1.0.0` metadata를 통과했다. 현재 후보 근거는 아니다.
- 과거 internal archive: EXE `B241A13…`, PCK `560CFD44…` SHA-256을 manifest에 기록하고 archive `92891081…` SHA-256을 산출했다. 압축 해제 뒤 세 파일 hash와 EXE 재부팅·오류 0도 확인했다. 이 archive는 공개 고지가 없는 stale internal smoke다.
- 재현성: 독립 clean worktree 두 곳의 EXE는 byte-identical이었지만 PCK는 2,060,916/2,060,900 bytes와 서로 다른 hash였다. 두 PCK 모두 exact contract를 통과했으나 cold PCK byte 재현성은 닫지 않았다.
- 잔여 gate: `N2-PLAY-11` 단일 후보 1-run→생존·continuity·정체/이탈 비회귀가 있을 때만 M1 5-run→packaged 수동 3판, 현재 commit의 clean package, 사람이 조작하는 전체 루프·정상 기록/배지 저장, cold PCK 비결정성·restart soak·호환성 matrix, LICENSES/CREDITS·지원·unsigned 정책은 아직 닫지 않았다.

## N2-PLAN-01 릴리즈 로드맵 통합

- 범위: 첫 공개 목표를 Windows x64·오프라인·한국어·키보드/마우스·`night_br_m1_60` 한 맵 무료 데모로 고정했다.
- 순서: M1 수동 종료 판정 뒤 `N2-REL-01` 저장·기록·clean export·브랜드/버전 기반을 닫고, M2 비주얼/첫 사용자 슬라이스와 M3 공개 데모 RC로 이어지게 재배열했다.
- gate: 최신 현실 창은 폐쇄 알파 2026-09-28~10-09, 공개 데모 RC 2026-12-18~2027-01-15다. 날짜보다 수동·패키지·외부 QA 통과를 우선한다.
- 문서: `CURRENT`, `MASTERPLAN`, `DECISIONS`, `PLAYTEST`, `reference/RELEASE`의 릴리즈 보류·과거 명령·완료 큐 충돌을 정리했다.

## N2-MAP-17 저밀도 구역의 설계형 구조물 군집

- 장소: `Inner Brush North`를 천막·수목·장작 중심의 은폐 거점 `Brush Camp`로 보강하고, 중앙 도로변에는 오두막·벽·상자 중심의 통과 병목 `Survey Camp`를 추가했다.
- 구조/경로: 흙 공터 2개, 프롭 18개, 점유 앵커와 중앙 도로 연결을 묶었다. 실제 맵 앵커의 중심, AI jitter 35/65/95% 대역과 선언 경계를 검사하는 6개 NavMesh 경로, Brush Camp 서쪽 1봇 강제 이동 4.85초·stuck 0을 `unit_smoke`에 고정했다.
- 자동 판정: 문제 seed를 다시 쓴 최종 5-run은 평균 787.2초, 범위 688.1-855.1초, first upgrade 4.9초, 정체 0.01·이탈 0.18/개체·분, AI 평균 322.3µs로 scale gate를 통과했다. open 피해/킬은 41.9%/33.9%, 상위 피해 셀은 5.4%이며 `-50,30` 정체는 수정 전 6/33에서 1/41로 줄었다.
- 성능/상태: 최종 Forward+ 60봇 20초 3회 중 2회는 p95 13.846-14.147ms, p99 16.541-16.755ms였다. 1회 p95/p99 32.695/46.437ms 이상치가 있었고 AI 평균 범위는 146.5-157.6µs다. 구조·페이싱 자동 후보는 유지하되 성능 이상치와 장소 체감은 수동 판정 전까지 승격하지 않는다.

## N2-EQUIP-01 지역별 무기 경제와 방어구 최소안

- 지역 경제: `loot_hub`·`transit_choke`는 T2 표준 총기, 외곽 `recovery_pocket`·`concealment_field`는 T1 노후 총기를 초기 후보로 쓴다. 보급 T3와 같은 계열 상위 티어 교체는 유지하고 봇의 하위 티어 교체는 막았다.
- 방어구: 기존 `방어구` 픽업은 `실드 충전`으로 바로잡고, 별도 방탄 조끼는 총기·근접 피해 15% 감소와 이동 96%를 적용한다. 존 피해는 줄이지 않으며 같은 티어 중복 장착은 거부한다.
- 검증: 전체 `unit_smoke`와 실제 M1 지역 스폰·장비 runtime을 통과했다. 5-run 평균 746.7초, 범위 606.0-857.9초, first non-pistol 4.5초, stage2/3 260.0/540.1초, 정체 0.01/개체·분이다.
- 분포/성능: 무기 획득의 69.7%가 loot hub·transit에서 발생했다. Forward+ 60봇 20초 p95 15.55ms, 33ms 초과 0.07%, AI 평균 160us이며 실제 HUD 캡처에서 방어구 아이콘과 실드 라벨 겹침이 없었다.
- 다음: `0,40`, `-10,-50` 등 저밀도 개방 구역을 무작위 장애물이 아닌 역할이 있는 구조물 군집으로 보강한다.

## N2-SURV-01 생존 제약과 초기 자기장 압력

- 수동 근거: 첫 자기장 대기가 길고 이동 부담이 약했으며, 구급상자·실드를 교전 중에도 즉시 써서 이탈 판단과 파밍 제약이 얕았다.
- 변경: 첫 축소 시작을 190→120초로 당기되 stage2/3는 260/540초로 보존했다. AI 선점 리드를 15초 늘리고, 플레이어 구급상자는 최대 1개·50HP·최근 교전 6초 잠금, 실드 픽업도 같은 잠금을 적용했다. 붕대는 교전 중 사용 가능하며 HP 50%/25% 이하는 이동이 92%/82%로 낮아진다.
- 검증: 전체 `unit_smoke`, survival runtime, zone timing gate를 통과했다. 5-run 평균 727.0초, 범위 654.3-829.5초, first upgrade 262.2초, stage2/3 260.0/540.1초, 정체 0.01/개체·분이다.
- 성능/다음: Forward+ 60봇 20초 p95 14.75ms, 33ms 초과 0.10%, AI 평균 155µs. 다음은 global 확률을 올리지 않고 지역별 초기 무기 접근과 별도 방어구를 설계한다.

## N2-PACE-44 M1 10-15분 자동 페이싱 기준선

- 원인: `night_br_m1_60`이 260m·60봇 규모만 덮어쓰고 whitebox의 짧은 존·경제 설정을 상속해 기존 5-run이 평균 238.5초에 끝났다.
- 통합: 첫 non-pistol을 stage wave 이후로 미루고, bot 대 bot 피해 0.55와 stage2/3 260/540초 존 일정을 M1 preset과 호환 alias에 함께 고정했다.
- 검증: 5-run 평균 660.3초, 범위 488.2-875.4초, first upgrade 260.7초, stage2/3 260.1/540.1초, 정체 0.01/개체·분으로 상·하한 gate와 전체 `unit_smoke`를 통과했다.
- 판단: bot-only 첫 접촉 7.4초와 첫 킬 21.9초는 수동 체감을 대신하지 않는다. 다음 변경은 N2-PLAY-09 수동 3판 결과 뒤 결정한다.

## N2-AI-10 상황 기반 전략 이동 효용

- 목적지: 교리별 기본 성향은 유지하되 장비 부족·생존 필요·최근 피격/가시 적·도착 시간·거점 점유로 loot/통과/회복/은폐 효용을 조정한다.
- 경로/선점: 고정 도로 확률을 제거하고 지형 직선 시간과 도로 우회 시간·노출 위험을 비교한다. 위협받은 봇은 선점을 앞당기고 장비가 부족한 봇은 파밍 시간을 더 확보한다.
- 점유: 다른 봇의 예약 목적지뿐 아니라 현재 POI 안의 실제 위치도 수용량 압력에 포함한다.
- 검증: 순수 정책, AI Arena 상태 변환, Night 목적지·도착 시간·경로·다음 원 앵커와 전체 `unit_smoke` 통과. 60봇 Forward+ 20초 2회 p95 13.82-13.87ms, p99 15.87-16.08ms, AI 평균 140-145us다.
- 다음: 같은 `night_br_m1_60`에서 N2-PACE-44 5-run 분포를 재고 N2-PLAY-09 수동 3판 기준을 고정한다.

## 기록 보존

이 문서는 최근 10개 작업 또는 120줄까지만 유지한다. 오래된 항목과 삭제된 전체 사본은 `git log -- docs/DEVLOG.md docs/MASTERPLAN.md`로 찾고, 필요한 커밋에서만 읽는다.
