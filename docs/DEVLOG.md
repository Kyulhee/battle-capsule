# Battle Capsule 개발 로그

> 최종 업데이트: 2026-09-15. 최근 검증된 작업만 유지한다. 과거 내용은 Git 이력을 참조한다.

## E-087 초기 사망과 엄폐 종료 경로 검토

- `c5a9d0d`에서 E083 process 대조 5개·E086 보급 순찰 후보 5개·보호된 수동 JSON 1개를 읽었다. 입력 SHA는 `builds/verification/E087_opening_review/inputs.json`, 재현 명령/필터는 실험 README에 기록했다. 기존 분석기의 exact exposure·episode·continuity 및 raw coverage 검사는 세 군 모두 오류 없음이다. 새 분석기/계측/게임 변경·경기는 없으며 60초 노출·entry<=59초 episode·120초 kill 저장 창을 분리했다.
- 첫 60초 봇 사망은 대조 **117**, 후보 **115**이며 DISENGAGE 사망은 **96/117(82.1%)→94/115(81.7%)**다. RECOVER 사망은 양군 5, 사망 당시 빈 장전탄+예비탄은 전체 **9/117→12/115**다. 생존 상태 노출 **2625.4→2573.5 actor-s**, 사망 **101→99**, 군별 합산 사망률은 양군 **3.85/100 state-s**다. DISENGAGE만 보면 **5.24→4.86/100s**, RECOVER는 **0.63→0.78/100s**다. 보급 순찰의 탄약 비율 개선이 초기 생존 문제를 해결했다고 보지 않는다.
- survival_break episode는 **380/381**, 엄폐 선택/도달 **304/69→323/47**, 관측 진행률 평균 **0.29→0.27**이다. 사망 **90/81** 중 엄폐 미도달은 **83/78**, 선택 후 사망 평균 **2.06/1.99초**, 선택 거리 평균 **11.85/12.35m**다. 별도 kill 필터의 survival_break 사망 **90/82**와 episode 분모는 같지 않다. 속도 상향·근거리 cover fallback·counteraction 억제는 과거 반증이 있어 재혼합하지 않는다.
- exact episode 종료 `pressure_no_target`은 **89/108건**이다. bottom-k 종료 표본은 전체 **640/921·640/941건**만 남아 있고, 그중 `survival_break/pressure_no_target` **57/70건**의 nav 목표 >2m는 **56/70건**, 캐시 visible=0은 **55/66건**이다. 모든 해당 표본의 상태 지속 시간은 4.49초 이상이다. 예: 대조 seed41000, actor222784657095/episode17은 t35.32094에 상태 4.5초·nav13.06m·이동 의도/속도3.68m/s를 기록하고 IDLE로 종료했다. nav 목표는 엄폐 identity가 아니고 상태 지속은 spawn-age 기반이다. 이 표본 비율을 전체 빈도나 사망 인과로 외삽하지 않는다.
- 코드상 `handle_disengage_state`의 압력 해제 분기는 2초 이후, 저체력 유예 4.5초 이후에도 `_find_nearest_target()`이 null이면 기존 엄폐 거리와 무관하게 `pressure_no_target`으로 반환한다. 아래쪽의 `should_complete_survival_cover_after_threat_loss`는 이때 실행되지 않는다. **선택한 엄폐가 >2m 남고 재교전 탐색이 null인 survival_break**를 다음 단일 재현 조건으로 채택한다. 획득 거절도 같은 종료 reason이므로 null과 구분하고, 4.5초 이전 사망 대부분의 원인이나 이 변경의 생존 효과까지 입증했다고 주장하지 않는다.
- 수동 원본(`65724e4…`)은 **64.390초·22위**, player 포함 초기61명·최종21명에서 끝난 판이다. 첫60초 봇37명 중 DISENGAGE30명, 별도 player 사망은64.390초의 근접 공격이며 해당 시점 플레이어/공격자 모두 장전·예비탄0이다. build/commit 식별자가 없어 **E067 실행 결과로 확인할 수 없다**. 시작 인원/플레이어 참여·중도 종료가 다른 한 판을 자동군과 합산하거나120/260초까지 외삽하지 않는다. 기존 E067 패키지 수동 대기는 유지한다.
- 종료/다음: E087 자료 검토를 닫고 E088에서 위 조건을 실제 handler fixture로 먼저 재현한다. 재현 시 null 경로만 기존 안전 override와 공간 완료 분기로 연결하는 기본 OFF 후보로 한정한다. 일반 이탈·도달/엄폐 없음·유효 적/획득 거절·ammo/zone/8초 timeout 경계를 보존하고 새 동일 소스 대조/후보 pilot 1쌍으로 판단한다. 미재현·구조 회귀·생존 방향 근거 없음이면 5-run 확대 없이 보류한다. 현재는 문서 공백 검사 PASS, 기존 기준선/사용자 파일6개 SHA 불변이며 새 게임 실행·패키지·푸시는 없다.

## E-086 회복 보급 순찰 5경기 효과 판정

- 사용자 승인으로 E085 `700f0ef81d4ae84b0f5bf49eb4c13ee98d8385e1`을 master에 푸시하고 원격 SHA를 확인했다. 이후 E086은 외부 실행/분석/fixture와 문서만 추가했다. E083 기준 `76591da` 이후 src/data/project 변경 없음과 소스 9개·엔진 SHA·입력/명령·정상 종료/무결성·초기 기준/분석 복사본을 확인해 **process control_match 5개만** 재사용했다. physics 후보 자료는 합산하지 않았다.
- `builds/verification/E086_recovery_patrol`에 seed 41000-41004의 E078 후보 초기-only 5회와 전체 5경기를 순차 보존했다. 양군 process 시계·5배속·추가 trace OFF이며, 새 초기/전체 snapshot은 대조 raw ID/배치와 10/10 exact다. 0/120/260초 인원·중복·빈 탄약 재계산, timeline 60→1·단조성·관측 시각 인원·종료 시각 일치 PASS, 양군 최대 관측 지연 **0.034658초 미만**이다. 전체 후보 5회는 exit 0·ERROR/WARNING 없음, 초기-only 5회는 기존 ObjectDB 종료 경고를 따로 남겼다. 소스/엔진/기준선/사용자 JSON·CFG·backup 6개 SHA 불변, Godot 잔여 프로세스 없음이다.
- 기존 최소 5-run duration/upgrade/scale gate로 후보 **PASS(exit 0)**다. 재사용 대조의 E083 PASS는 유지하고 재실행하지 않았다. 평균 duration **676.417→709.813초**, 후보 범위 **635.941-811.216초**, 평균 first **3.296941→3.433461초**·미기록 0이다. 후보 AI 가중 평균/최대 **271.3/33,046µs**, stuck/disengage **0.01/0.18 per entity/min**, fallback 0·최소 스폰 이격 3.5m다. headless 비용을 화면 성능 개선으로 주장하지 않는다.
- 120초 실제 관측의 빈 탄약/생존자는 seed 순서대로 대조 `12/28, 9/23, 8/31, 7/24, 6/25`, 후보 `5/25, 6/29, 6/29, 6/21, 6/32`다. 전체 **42/131(32.1%)→29/136(21.3%)**, 경기별 비율 중앙 **29.2%→20.7%**로 5쌍 모두 비율이 낮지만 생존자가 늘어난 쌍은 2/5다. 장전탄·예비탄 모두 0인 생존자 표본이며 부족 지속 시간·재보급 성공·결정적 인과 효과를 뜻하지 않는다.
- event staircase alive@30/60/90/120/180/260 중앙은 **55/36/31/25/23/17→52/38/33/29/26/16**, T50/T10은 **34.0/333.6→31.3/321.3초**다. alive@120은 개선 신호가 있지만 목표 34-46 미달, alive@260은 목표 17-29 아래로 내려갔고 T10도 목표 360-650 미달이다. 260초 재고는 stage2/비축소가 같은 **41000/41001/41004 세 쌍만** 비교했다. 빈 탄약 **19/48→15/52**, 바닥 탄약 팩 합 **277→279**이며 같은 phase도 보급 후 정확한 경과 시간이 같다는 뜻은 아니다. 41002/41003의 phase 불일치는 원시에 보존하고 재고 합산에서 제외했다.
- 판정: 탄약 부족 완화 신호는 채택하되 전체 생존 개선/기본값 승격은 **보류**한다. 추가 계측·반복 튜닝이나 시계 혼합 없이 이 후보 판정을 닫는다. Python compile, 직접 실행한 전용 fixture 3개(모드/시각/인원/탄약 불일치 10종·분모/phase·출력 보호)와 전체 원시 분석·공백 검사 PASS다. 일반 게임 코드는 불변이라 기존 전체 unit_smoke/Forward+·수동을 재실행하지 않았고 E067 EXE를 유지한다. 다음은 보관된 사망/상태 노출과 수동 자료에서 단일 수정 근거/종료 조건을 정하는 E087이며 새 실험을 먼저 늘리지 않는다.

## E-085 측정 창 취소 종료 수정

- 외부 Win32 재현기는 직접 실행한 GUI 엔진의 PID에 속한 가시 창이 정확히 하나일 때만 WM_CLOSE를 보낸다. 다른 창/이름 기반 종료는 하지 않는다. seed 41000·Forward+·기존 측정 도구의 OFF/ON을 같은 조건으로 비교하고 명령/PID/HWND/요청 시각/종료/소스/저장 hash를 격리 보존했다.
- `E085_window_close_before`는 nav 준비 7초 뒤 닫기에서 양군 모두 close 요청 로그·결과 미생성·exit **3221225477**을 기록했고, E084의 shader/RID/resource 오류 목록과 같았다. 측정 창 닫기가 같은 실패를 만드는 경로임을 입증했지만 E084 실제 사용자 동작은 여전히 미확정이며 과거 실패를 PASS로 소급하지 않는다.
- `profile_runtime_performance.gd`만 자동 즉시 종료를 끄고 close flag를 준비/측정 루프에서 소비하게 했다. 장면을 정리하고 코루틴이 반환된 뒤 취소 코드 **2**로 끝내며 성능 JSON은 쓰지 않는다. 최초 수정의 측정 중 닫기는 오류 없이 끝났지만 준비 직후에는 ObjectDB 경고가 남았다. 별도 verbose 결과에서 다수 SceneTreeTimer를 확인했다.
- 준비 타이머를 종료시키고 gameplay를 pause한 채 0.25초 동안 초기 대기를 마친 뒤 장면을 제거하도록 보완했다. Bot._ready의 기존 대기는 0.05-0.2초이며 봇/일반 게임 코드는 바꾸지 않았다. 준비 중 최종 OFF/ON은 **0.622/0.649초**, 측정 중 최종은 **0.602/0.602초**에 취소 코드 2·요청/취소 로그·결과 없음·ERROR/WARNING 없음으로 종료했다. 네 경우 모두 강제 종료는 없었다.
- 정상 완료 OFF/ON 1쌍은 기존 5초 준비+20초 관측 후 exit **0**·유효 결과·초기 ID/배치 일치·시계/1배속·실제 Forward+·관측 창을 통과했다. 이는 종료 회귀 확인이며 새 3+3 성능 승격이 아니다. 기존 E084 6회 성능과 E083 5+5는 재실행하지 않았다. 옵션/출력 보호 focused fixture·Python compile·diff 공백 검사 PASS다.
- 원시는 `builds/verification/E085_window_close_{before,sampling,warmup,warmup_verbose,warmup_final,sampling_final}` 및 `E085_normal_completion`에 실패 단계까지 보존했다. normal 입력의 expected_exit 표기는 이후 0으로 바로잡았으며 실제 `--complete` 판정/종료는 처음부터 0이다. 소스와 수동 JSON/CFG/backup 6개 SHA 불변, 모든 시험 프로세스 종료를 확인했다. 일반 게임 창 전체 종료/전체 매치/수동 체감 보장으로 확대하지 않는다. 기본 시계 OFF·E067 EXE·기존 릴리즈는 유지한다.

## E-084 화면 있는 물리 시계 성능 비교

- 기존 `profile_runtime_performance.gd`에 기본 OFF `perf_physics_clock_candidate`만 연결했다. Main 기본값은 불변이며 live player/60봇·준비 5초+관측 20초·windowed 1280×720을 유지한다. 초기 actor/pickup ID/위치는 시작 직후 한 번만 기록하며 관측 loop에 검색을 추가하지 않는다. 실제 맵/preset/seed·시계 priority/처리·1배속·GPU/렌더러/vsync·canonical 창·종료 여부를 결과에 남긴다.
- 오타/다른 probe·autostart 혼합/후보와 숨긴 미니맵 혼합, 기존 출력·상대/user-data 경로를 거부한다. 옵션/출력 보호 fixture·검증 runner 15개 회귀 PASS, 최종 종료 요청 로그 추가 뒤 해당 fixture와 Python compile·기존 출력 재사용 거부도 확인했다. 최초 샌드박스 실행은 user 로그 접근 거부로 Godot 시작에 실패했으며 정상 권한의 fixture는 오류 없이 통과했다.
- 첫 `builds/verification/E084_clock_performance`는 대조 p95/p99 **16.347/25.960ms**, 후보 **19.028/32.494ms**로 완료했으나 다음 후보가 약 10초 뒤 결과 없이 exit **3221225477**로 중단됐다. shader/RID/resource 정리 오류만 있고 원인을 특정할 스택/해당 Windows Application 오류 이벤트는 찾지 못했다. 수동 파일/소스 hash는 불변이다. 사용자 창 닫기 여부를 비차단으로 질문했으며 작성 시 답변은 없다. 실패한 후보를 표본에서 숨기거나 PASS로 처리하지 않는다.
- 창 닫기 요청만 로그로 구분하고 기존 종료 동작은 유지한 뒤, 별도 `E084_clock_recheck`에서 순서 **OFF1/ON1/ON2/OFF2/OFF3/ON3**, 동일 seed 41000·RTX 4060 Ti/Vulkan Forward+/vsync 1로 6회 정상 종료했다. 원시 입력/명령/종료 코드/해시/profile/summary를 보존했고 ERROR/WARNING/창 닫기 요청은 없다. 이번에는 최초 오류가 재현되지 않았지만 원인 해결을 입증하지 않는다.
- 재확인 p95/p99(ms)는 대조 `15.385/18.676, 16.285/27.292, 15.172/18.748`, 후보 `15.557/21.005, 15.972/22.440, 16.564/24.479`다. p95 20ms 초과 0/6, 중앙 p95 **15.385→15.972ms**, 중앙 p99 **18.748→22.440ms**이며 성능 동일/개선으로 주장하지 않는다. 프레임 max는 대조 44.177-68.345ms·후보 42.289-49.132ms다. AI 평균 166.8-171.3/170.5-174.5µs, 최대 32,406/23,542µs로 50ms 상한 이내다.
- 초기 raw ID/배치 6/6 exact이며 종료 로그 추가 전후 초기 snapshot도 일치한다. 같은 소스·GPU/vsync/해상도/맵·시계 OFF/ON·관측 인원/실제 draw·1배속을 확인했다. 기존 achievements/history/settings/수동 결과 및 backup 총 6개 파일 SHA 불변, 창/프로세스는 모두 종료했다. E083의 headless 5+5나 첫 중단 묶음을 새 성능 표본에 합산하지 않았다.
- 판정: 짧은 화면 성능 근거와 도구를 채택하되 초기 종료 오류·장시간/전체 매치·수동 체감·E083 생존 미달은 남는다. 기본 시계 OFF, 새 EXE/릴리즈 승격 없음. 사용자 추가 요청으로 E082/E083을 먼저 `5a0a188`까지 푸시 확인했고 E084도 실패 기록과 함께 푸시 범위에 포함한다.

## E-083 물리 시계 후보 5경기 반복 판정

- `76591da`의 동일 런타임에서 seed 41000-41004 각각 process 대조→physics 후보 순서로 총 10경기를 순차 실행했다. 기존 E081 실행기를 재사용했고 headless 5배속·추가 trace/시작 지연/다른 후보 OFF다. 초기-only 기준 5개는 경기 수에 포함하지 않는다. 과거 run 혼합·재추첨·기준 변경 없이 새 묶음만 판정했다.
- `builds/verification/E083_clock_repeat/seed_<seed>/{control_match,candidate_match}`에 command/inputs/flow/result/exit/integrity를 보존했다. 원시 초기 ID exact, 모드/배속, 0/120/260초 인원·중복/시각, timeline 60→1·단조성, 종료 시각, 9개 소스/참조/수동 SHA는 10/10 통과했다. 최대 관측 지연은 0.083334초 미만이다. 전체 매치 로그는 ERROR/WARNING 없음, 초기-only 종료 5개에는 기존 ObjectDB 누수 경고가 남는다. 체크포인트의 첫 문자열 비교는 `0.0` 표기 때문에 잘못 거부되어 숫자 비교로 바로잡았으며 경기 자료는 변경하지 않았다.
- 기존 `check_scale_telemetry.py`에 최소 5-run·평균 duration 600-900/개별 480-960·평균 first 2-30·미기록 0과 기본 scale 기준을 적용해 양군 PASS(exit 0). 대조/후보 평균 duration **676.417/743.100초**, 범위 **625.626-723.449/661.000-873.000초**, 평균 first **3.296941/3.666667초**다. 후보가 더 긴 이번 차이를 결정적 시계 효과나 밸런스 개선으로 단정하지 않는다.
- first 시각은 seed 순서대로 대조 `12.0068/0/3.812607/0/0.6653`, 후보 `12.583333/0.666667/4.083333/0.083333/0.916667초`다. 유효 0초는 2/5→0/5이고 미기록은 양군 0이다. E082의 평균 해석을 새 묶음에서 확인했으며 개별 2초 지연을 추가하지 않았다.
- AI 가중 평균/최대는 대조 **306.0/32,357µs**, 후보 **307.5/25,198µs**로 모두 예산 이내다. stuck/disengage는 **0.02/0.19→0.02/0.18 per entity/min**, fallback 0이며 스폰 수/최소 이격을 보존했다. 이는 headless AI 비용이며 Forward+ 프레임 성능은 아니다.
- 기존 `survival_curve`의 event staircase 중앙 alive@30/60/90/120/180/260은 대조 `55/36/31/25/23/17`, 후보 `54/36/29/25/23/20`; T50/T10은 **34.0/333.6→32.3/320.3초**다. alive@120 목표 34-46 및 T10 360-650은 양군 FAIL, alive@260 17-29는 양군 범위 안이다. 초기 생존 개선으로 판정하지 않는다. 260초는 대조 4판 stage2/후보 5판 stage1로 phase가 달라 재고를 직접 비교하지 않았다.
- 판정: 반복 시계/페이싱/구조 근거를 채택하되 후보는 기본 OFF, 생존/M1/EXE 승격 없음. 전체 unit_smoke·수동/화면 성능은 이번에 재실행하지 않았다. 문서 내용은 원시/기존 분석기와 대조했고 `docs_only` 공백 검사 PASS다. 기존 수동 SHA `65724e4ab1d8ab5a56ba93854bf3dfd258b77e1c6348ee36e74169441f417b23` 불변이며 사용자 파일을 보존했다. 분석용 `control|candidate/run_1..5.json`은 원시 결과와 SHA 일치하는 복사본이며 시계 식별은 원래 seed별 inputs/flow를 함께 사용한다.

## E-082 초기 접근 거리와 평균 하한 정합성

- 승인된 6개 커밋을 master에 푸시하고 원격 `630048a1b96920a9dcd8ea4c88d941fb26dd0da1`을 확인했다. 이후 검토는 읽기 전용 자료 분석과 문서 명확화이며 게임/스폰/수치·새 계측은 변경하지 않았다.
- 하한 도입 커밋 `a977fe5`는 지역 장비 접근 개선과 함께 `min_avg_first_upgrade=2.0`/상한 30을 설정했다. 현재 `check_scale_telemetry.py`도 경기별 `economy.first_upgrade_time`의 산술평균에 적용한다. D-004의 누락된 ‘평균’을 명시했으며 기준 변경은 아니다. 전 참가자 중 최초 기록이지 플레이어 또는 봇별 접근 분포가 아니다.
- `E074_probe_identity/{control,candidate}/flow/run_1..5.json`의 seed 41000-41004 초기 snapshot은 ID 포함 5쌍 exact다. 각 60봇×18비권총의 최소 XZ 거리는 순서대로 `9.98508/4.16684/5.65327/1.30213/5.01477m`, 2.5m 이내 쌍은 `0/0/0/1/0`이다. Main→LootSpawner 초기 배치는 장애물만 검사하고 봇과의 최소 거리를 강제하지 않는다. XZ는 3D 하한이며 LOS/경로/최초 수집자 증거는 아니다. E080의 41001 실제 이동 후 약 0.6초 성공과 모순되지 않으며, 41001의 겹침 없음도 모든 seed로 일반화할 수 없다.
- 같은 E074 `results/run_1..5.json` 최초 시각은 대조 `12.05875/0.619322/3.61288/0/0.650483`(평균 3.388287초), 후보 `15.778315/0.633153/3.977262/0/0.713422`(4.220430초)다. 독립 보관 묶음 E068_repeat 대조/후보 평균도 3.446752/3.281252초다. 네 묶음을 합산하지 않았고 20파일의 economy/pacing 시각 일치·묶음별 유효 0초 1건/미기록 0건을 확인했다. 과거 process 시계 자료라 E081 후보의 새 5-run 통과 근거로 쓰지 않는다.
- 판정: E078/E081 단발 수치 FAIL은 보존하되 ‘약 0.6초 때문에 5-run도 통과 불가’ 추론은 철회한다. 단발 하한을 맞추려는 스폰 이격·수집 지연·시각 보정은 채택하지 않는다. 검증 안내에 평균/단발 구분을 명시하고 MASTERPLAN의 오래된 실험 상태는 CURRENT 링크로 교체했다. `docs_only` 공백 검사 PASS이며 내용은 위 원시 자료·코드와 대조했다. 관련 runtime은 변경하지 않아 재실행하지 않았다. 수동 결과 SHA256 `65724e4ab1d8ab5a56ba93854bf3dfd258b77e1c6348ee36e74169441f417b23` 불변, 새 EXE/기본값 승격 없음.

## E-081 선택적 물리 시계 후보

- 기본 OFF 후보는 Main의 physics priority -100에서 canonical 시계와 기존 존·피해·미션·보급 갱신을 같은 delta로 실행한다. 일반 플레이는 기존 process 경로, 화면 갱신은 process로 유지한다. 별도 시계/임의 양수 보정/배속 재곱셈은 없고 Telemetry는 계속 Main.match_timer를 읽는다.
- E080 실행기에 `--clock-candidate`와 선택적 `--full-match`를 추가했다. 100ms 시작 지연의 기존 방식 1x/5x는 0.595913/0초, 후보는 0.600/0.666667초에 같은 actor/pickup의 성공 장착을 기록했다. OFF 물리 처리 비활성/priority 0, ON 활성/-100과 초기 원시 ID 일치를 확인했다.
- 비계측 5배속 대조/후보 1+1은 698.708/761.667초, 첫 upgrade 0.654742/0.666667초다. 초기 ID·0/120/260초 checkpoint·flow/core 종료 시각·소스/수동 hash 보존과 정상 종료를 통과했다. 단발 수치 검사(`--min-runs 1`, 나머지 기존 duration/upgrade/scale 기준)는 양군 모두 첫 upgrade 2초 하한만 FAIL이다. AI 평균/최대는 292.0/26,745us와 291.1/20,422us, stuck/disengage는 0.01/0.19와 0.01/0.18 per entity/min이다. 단발 차이를 밸런스/성능 개선으로 해석하지 않는다.
- 시계·pacing telemetry·첫 수집 fixture 통과. 새 시계 fixture는 실제 Main 분기로 단일 누적·1x/5x·pause/menu/result/end·존 경계·피해/미션/보급 delta를 검사한다. 최초 Main 조기 로드의 Sfx compile 오류는 autoload 이후 helper 로드로 고친 뒤 해당 fixture만 재검증했다. 실제 시작/전체 매치 로그에는 script/runtime ERROR가 없다. 시계/AI 혼합 2종과 전체 매치/지연 오용 2종도 출력 쓰기 전에 거부됐다.
- 근거는 `builds/verification/E081_clock_delayed`, `E081_clock_full`의 inputs/command/flow/exit/integrity/case_summary와 run_1.json이다. 전체 unit_smoke·5-run·수동/EXE 검증은 하지 않았다. lifecycle/피해 호출 순서가 달라지는 후보이므로 기본 승격하지 않으며, 약 0.6초 첫 획득 문제와 기존 E078 FAIL은 별도로 유지한다.

## E-080 실제 첫 수집과 시계 순서

- `Pickup.collect`의 실제 적용 성공 뒤 선택적 callback으로 actor/pickup/source·장착·거리·physics/process frame·canonical 시각을 연결했다. 기본 OFF는 성공 끝의 유효성 검사만 추가하며 추가 시계/검색/Resource 생성은 없다. probe는 봇 생성 뒤 초기 비권총에 연결하며 성공 8건·process 경계 16개로 제한한다. 거부된 수집에는 callback이 없다.
- 동일 소스의 자연 시작 대조/후보 1x는 0.581794/0.593690초, 5x는 0.642840/0초다. 100ms 시작 지연을 별도 주입한 대조/후보 1x는 0.585241/0.591687초, 5x는 양군 0초다. 모두 actor `229227108423`이 초기 산탄총 `246373424021`을 실제 장착했고 수집 거리 2.49m다. 0초 사건은 시작 뒤 physics 8회에서 발생했고 다음 process 경계까지 canonical 0이 유지됐다. 기존 E079의 초기 4.16684m 겹침 없음과 함께, 실제 이동·수집이 시계 갱신에 선행하는 경로를 입증한다.
- 초기 자연 관측과 최종 동일 소스 자연/지연 대조를 모두 보존했다. 각 묶음은 OFF 초기 1회+짧은 창 4회이며 모든 초기 snapshot/원시 ID, 종료 코드, 소스·수동 hash가 일치한다. 원시는 `builds/verification/E080_first_collection`, `E080_start_delay`, `E080_natural_final`의 inputs/command/flow/integrity/summary다. 재현 코드는 `tools/experiments/run_first_collection.py`로 추적하고 기존 결과를 덮어쓰지 않는다.
- 관련 수집 시계·드랍 수명·플레이어 탄약 보존 fixture 통과. 추가 거부 fixture의 RayCast3D 누락 오류는 보완 후 시계 fixture만 재실행해 오류 없는 최종 로그를 확인했다. 잘못된 배속/지연/혼합 5종은 결과 쓰기 전에 거부됐다. 전체 unit_smoke/tooling·전체 매치·5-run은 실행하지 않았다.
- E078 당시 프레임은 없으므로 과거 사건을 직접 증명한 것은 아니다. 계측 ON의 전체 물리 중립성/발생 빈도도 주장하지 않는다. 1x의 약 0.6초는 여전히 2초 하한 미달이므로 시계 정합성과 빠른 첫 획득을 분리한다. 시계·하한·스폰·기본 후보·EXE는 불변이며 기존 gate FAIL/승격 보류를 유지한다.

## M0 작업 지침·검증 경량화

- 공통 AGENTS와 짧은 CLAUDE 안내, 조건별 문서 참조/갱신을 적용했다. CURRENT의 상세 결과·로드맵 중복을 줄였고, 줄 수를 맞추는 압축 대신 문서별 소유 기준을 사용한다. 게임 코드·승격 기준·공개판은 불변이다.
- `focused --test`로 관련 verifier의 기존 인자/모든 변형을 선택한다. 빈 선택·오타·전체 profile 필터링은 거부하고, dry-run/선택 PASS를 전체 검증·승격 PASS와 구분한다. runner 회귀 15개 PASS, 기존 9개 profile의 명령 순서는 새 runner 자체 검사/compile 항목 외 동일함을 확인했다. Godot 전체 회귀는 실행하지 않았다.
- E079 초기 기하 분석을 `tools/experiments/inspect_initial_geometry.py`의 읽기 전용 CLI로 이전했다. 보관된 geometry JSON과 동일한 출력, 누락 입력 종료 코드 2, 변경 문서의 파일 링크를 확인했다. 기존 runner·원시 결과·사용자 변경은 보존했고 추가 푸시는 하지 않았다.

## E-079 첫 수집 시계 소형 재현

- 제품 코드/시계/스폰/하한은 유지하고 실제 chase→collect→equip→Telemetry를1x/5x×5경우로 검증했다.2.5m 포함/2.5001m 제외·process 전/후 시각·양수 시계 이중 배속 없음·미기록-1/유효0 유지가 PASS다. 첫 fixture 타입 추론 오류 로그를 보존했고 최종 전체 unit_smoke/tooling PASS다.
- E078 초기1,080쌍 최소 수평4.16684m·2.5m 내0쌍으로 초기 겹침은 없었다. 시계 갱신 전8회 handler 재현에서5배속은 stub2m 이동/실제 장착 후0초,1배속은 미수집이다. 실제 매치 collector/frame은 미관측이므로 이 순서가 원인이라고 확정하지 않는다. 원시/판정은 E079_first_upgrade/RESULTS.md.
- 다음은 E-080 실제 성공 수집/프레임 연결이다. E078 양군 첫 upgrade0초 gate FAIL·기본OFF/5-run 보류·EXE/수동 hash를 유지하며 새 전체 매치나 추가 푸시는 하지 않았다.

## E-078 회복 보급 목적지 opt-in

- 승인된190fdb2/1559e9f를 원격 master에 푸시하고 SHA 확인했다. 이후 기본OFF 후보는 빈 탄약 RECOVER/patrol에서 기존 보급 투하 뒤 지도 POI를 선택하며 추가 재고/시야/ray/nav query·시간 연장은 없다. 기본/fallback RNG·우선순위·순수/stub 이동·6모드 초기ID/혼합6종 거부·전체 unit_smoke/tooling PASS다. ON 성공은 기존 분기의 난수 호출을 건너뛴다.
- 진단 없는 대조/후보1+1은663.9/678.6초·AI max25,943/25,020us이며 초기ID/수동 hash불변이다. 빈 탄약120초10/23→6/25지만260초6/16→8/19·phase 불일치로 재고 비교 제외다. 후보 생존 봇의 선택24/21회는 기능 활성만 확인한다. 양군 upgrade0초로 전체 gate FAIL·기본/EXE/5-run 승격 보류다.
- 요약 키 KeyError와 원래 runner를 보존하고 완료 대조의 명령/해시/종료를 검증해 재실행 없이 후보로 이어갔다. 원시/판정은 E078_recovery_patrol/RESULTS.md, 다음은 초기 근접 픽업/시계 순서 재현이며 하한/스폰 변경 없음. E-077/E-078 푸시는 하지 않았다.

## E-077 실제 감지 첫 탈락

- 선택적 caller-owned 계수로 거리/FOV/LOS 실제 반환을 기록하며 추가 ray/predicate·기본 Dictionary/Resource는 없다. schema1 호환·schema2 합계·경계/실제 장애물·결정/RNG/ray parity·초기5모드 ID exact·전체 unit_smoke/tooling PASS. 45도 float 경계의 잘못된 fixture 기대값 실패2건을 보존하고 게임 비교식은 유지했다.
- 실시간54,195콜/fresh3,517·감지 탈락23,567아이템 방문 중 거리20,016(84.932%)/FOV3,169(13.447%)/LOS382(1.621%)다. 예시26/누락54,169·최대지연0.004초·초기ID/수동 hash PASS. 콜별 원인/부족 시간·호환성/접근성 증거가 아니며 다음은 RECOVER 순찰 목적지 소형 재현/보급 지향 별도 후보다.
- OFF546.6초·AI309.3/41,112us는 비용 통과지만 duration/upgrade0.664초 하한으로 전체 gate FAIL 보존. 원시/판정은 E077_loot_sensing/RESULTS.md. 기존190fdb2/1559e9f 푸시는 자동 검토가 대상/내용 승인을 요구해 차단·질문 대기다. E-077 로컬, 기본/EXE 승격 없음.

## E-076 빈 탄약 실제 검색 필터

- 기본 비활성 sink는 실제 IDLE/RECOVER 검색을 cache/fresh 및 첫 탈락 조건으로 기록한다. 선택/동점·RNG·감지/장비 판정 횟수·cache/만료·96콜/64저장/32누락 fixture와 Python24종 오류·초기5모드 ID exact·전체 unit_smoke/tooling PASS. 개발 fixture 오류 로그는 보존했다.
- 실시간seed41001 창은44,368콜·fresh2,907: 감지 없음1,835(63.12%), 탄종/장비1,031(35.47%), 반경만9·선택32다. 예시27/누락44,341 및 합계/시각/인원 PASS, 부모 초기ID exact·수동 hash불변. 단일 콜 분포이지 부족 체류 시간/생존 개선이 아니며 다음은 감지의 거리/FOV/LOS 분리다.
- OFF 단발631.5초·AI 평균268.3/최대17,112us·stuck/disengage0.01/0.18은 비용/구조 항목을 통과했지만 initial shotgun upgrade0.577초로 전체 gate FAIL이다. 실패를 보존하고 하한·기본 후보·지도/드랍·EXE를 바꾸지 않았다. 원시/판정은 E076_loot_search/RESULTS.md, 푸시 없음.

## E-075 구역 전환 뒤 재고 관측

- 사용자 재승인으로 E-074 `1eb3453`까지 원격 master SHA 확인. 로컬 probe는 초기ID/기존 표본을 보존하고 stage2 시작+1초를 별도로 관측한다. 분석기21종 오류 입력·불변성·최종 초기ID fixture PASS. 전체 회귀 첫 wall_traffic 실패는 보존했고 독립/전체 재실행 PASS, 이후 전용 창 배속 수정은 targeted/실제 실행 검증이다.
- 5배4창 중 지연0.396초 실패를 보존하고 전용 창을1배로 분리했다. 실시간seed41001 쌍은 지연0.0039/0.0065초·동일phase·초기ID exact·재고208/201·생존/빈 탄약8/3과9/1이다. 단일 창으로 보급/생존 승격하지 않으며 다음은 RECOVER/IDLE 실제 검색 탈락 문맥이다. 게임 소스/EXE/수동 hash불변, E-075는 로컬.

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

- 공통 티어 표시/픽업 비교/HUD·정렬/가독성을 추가했다. 게임 수치 불변·신규 장비 없음, 전체 회귀와 Night Forward+720p/1080p×6상태12캡처를 통과했다. 상세 과거 기록은 Git 이력, 현재 패키지/수동은 CURRENT/PLAYTEST가 기준이다.

## E-065 수동 피드백과 로드맵 우선순위 정리

- E-065 수동 피드백으로 티어 가독성→유한 거점 보급→비파괴 cabin 순서를 정하고 붕괴·폭격·보라 장비는 조건부 후속으로 분리했다. 게임/수치/후보는 불변이며 `docs_only` PASS다. 상세 과거 기록은 Git 이력에 보존한다.

## v2.1.0-demo-dev 테스트 프리릴리즈 게시

- c33cdab clean Windows/macOS Universal2 ZIP·manifest/checksum을 테스트 프리릴리즈로 게시하고 PCK exact/Windows 짧은 부팅을 검증했다. AI max strict 실패·수동/Mac/서명 미검증과 상세 artifact는 Git 이력에 보존하며 stable v2.0.0-pre-expansion·공개 RC 비승격을 유지한다.

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

## 과거 opening survival exposure

- Main.match_timer 기반 exact exposure 계약·전체 회귀와849.7초/AI max35,515us 단발 구조는 통과했지만 alive120/260=22/15·생존 FAIL이었다. DISENGAGE318.4초/사망24명,RECOVER126초/사망0·빠른 재획득22/78의 원시와 E-056 revert는 Git 이력에 보존하며 단일 hotspot/topology 변경·릴리즈 승격 근거로 쓰지 않는다. 최신 제품/출시 판정은 CURRENT가 기준이다.

## 과거 continuity·릴리즈 기반

- v2 5-run 평균668.8초·HP buffer/counteraction grace 실패 revert·E-062 export AI max57.914ms 실패와 상세 증거는 Git 이력에 보존한다. 원자 저장/backup/migration·simulation 기록/배지 미기록·브랜드/user data 경로·PCK exact 계약은 유지하며 현재 미해결 gate는 CURRENT가 기준이다.

## 기록 보존

이 문서는 최근 10개 작업 또는 120줄까지만 유지한다. 오래된 항목과 삭제된 전체 사본은 `git log -- docs/DEVLOG.md docs/MASTERPLAN.md`로 찾고, 필요한 커밋에서만 읽는다.
