# 플레이테스트 노트

> 최종 업데이트: 2026-08-28. 텔레메트리가 말하지 못하는 체감과 화면 판단을 짧게 기록한다.

## 현재 수동 테스트 대상

| 항목 | 값 |
|---|---|
| 빌드 표면 | `mapSpec_night_forest_expanded_candidate.json` M1 개발 기준 맵 |
| 권장 preset | `night_br_m1_60` 공통 기준선. `target_99_probe`는 자동 부하 검증 전용 |
| 현재 단위 | `N2-PLAY-11` opening survival exposure schema v1·1-run 진단 완료. data-quality/구조 PASS, gameplay/survival FAIL이며 `survival_break`-only 2.0초 `no_threat` exit hysteresis의 1-run 통과 전 packaged 수동 재판정은 보류 |
| 승격 목적 | N2-PLAY-10에서 확인한 무기 공백·초기 인원 붕괴·지도 HUD 중첩을 닫고 오프닝·장소/경로·생존/완주를 다시 승인 |

## N2-PLAY-11 재판정 프로토콜

2026-08-28 exposure 1-run은 849.696초·spawn 60/60·fallback 0으로 구조는 통과했지만 alive@60/120/260 `29/22/15`, T10 279.8초로 생존을 실패했다. 새 후보는 생존뿐 아니라 continuity·정체/이탈·D-004를 1-run에서 함께 확인하고 모두 개선될 때만 5-run, 그 결과가 통과할 때만 같은 후보를 packaged 수동 3판으로 판정한다. 새 packaged/manual PASS는 없다.

| 판 | 초점 | 필수 기록 |
|---|---|---|
| 1 | 첫 사용자·오프닝·지도 | 첫 2분의 픽업·이동·교전 선택, 즉사/공백, 전체 지도 HUD 격리, 미니맵 크기·교전 투명도 |
| 2 | 장소·파밍·생존 | 중심 거점과 외곽 POI의 무기 접근 차이, 오브젝트 주변 보급 배치, 드랍 누적, Brush/Survey 진입·우회와 죽음 이유 |
| 3 | 완주·성능·재시작 | stage2/3와 10-15분 흐름, 다중 전투 끊김, 결과→재시작, 두 번째 판 초기 상태 정상 여부 |

### M1 승격 차단 조건

- 첫 2분이 무작위 즉사 또는 의미 없는 대기로 반복되지 않고 지역별 장비가 이동 이유로 읽힌다.
- 초기 장총이 중심 거점에는 많고 외곽에는 적게 읽히며, 기본 권총 무기 드랍이나 만료되지 않는 wave/death loot가 필드를 채우지 않는다.
- Brush Camp·Survey Camp의 역할과 진입/우회가 구분되며 수관·구조물이 플레이어·입구·근접 위협을 지속적으로 가리지 않는다.
- 첫 축소 120초, stage2/3 260/540초가 회전을 만들고 실제 완주가 10-15분 목표를 심하게 벗어나지 않는다.
- 전체 지도에서 gameplay HUD가 겹치지 않고, 220px 미니맵은 교전 중 정적 배경만 흐려져 시야와 동적 표식을 함께 보존한다.
- 교전 중 회복 잠금과 저체력 이동 저하가 선택을 만들며 죽음·피격·탄약 상태의 이유를 이해할 수 있다.
- 세 판에서 반복 crash, softlock, navigation 막힘, 지속적인 프레임 끊김이 없다.
- 세 판의 결과와 실패 원인을 아래 기록 양식에 남긴다. 하나라도 실패하면 global 수치 조정보다 해당 화면·경로·상태만 좁게 수정한다.

오디오 세부, AI archetype 차이, 기존 거점 표현은 회귀 관찰 항목이다. 플레이 불능·오판을 만들 때만 M1 blocker로 올리고, 나머지 폴리시는 M2 대표 슬라이스에서 처리한다.

```powershell
.\Godot_v4.6.2-stable_win64_console.exe --path . -- map_spec_path=res://data/mapSpec_night_forest_expanded_candidate.json scale_preset=night_br_m1_60
```

`visual_review`의 8봇 결과로 encounter 빈도나 매치 페이싱을 판정하지 않는다. `night_br_m1_60`만 현재 gameplay 대표 표면이며 M1 통과 자체를 의미하지는 않는다.

## AI 빠른 재현 표면

`mapSpec_ai_test_arena.json`은 작은 AI 오류를 격리하는 `96m` 테스트 맵이다. 실제 Night BR의 조우 빈도나 페이싱 판정에는 사용하지 않는다.

| preset | 용도 |
|---|---|
| `duel_1` | 플레이어-봇 4.5m 고정, 초기 loot 없음. 감지·반응·1대1 상태 전이 |
| `cover_lab_1` | 수목 시야 차폐를 사이에 둔 고정 1대1. 감지 상실·우회·재획득 |
| `squad_4` | 중앙 4방향 고정. 다중 위협·이탈·재교전 |
| `systems_8` | 중앙 8방향 고정 + loot. 상태 전이와 목표 충돌 스트레스 |
| `random_8` | 같은 맵의 무작위 스폰. 고정 앵커에만 재현되는지 비교 |

```powershell
.\Godot_v4.6.2-stable_win64_console.exe --path . -- map_spec_path=res://data/mapSpec_ai_test_arena.json scale_preset=duel_1 debug_flags=ai,perception,nav
python tools\run_verify.py --profile ai_test_arena
```

## 화면 리뷰 체크리스트

HUD, 메뉴, 픽업 라벨, 미니맵, 결과 화면을 바꾸면 실제 게임 화면으로 확인한다.

- 텍스트, 아이콘, 패널, 미니맵, 라벨이 서로 겹치지 않는가?
- 동적 값이 컨테이너를 넘거나 layout을 흔들지 않는가?
- HP, shield, alive count, zone, active weapon, focused pickup 순서가 분명한가?
- 어두운 지형과 zone overlay 위에서도 outline과 색 구분이 충분한가?
- `ZONE Ns`/`ZONE CLOSING`, reload/low ammo, killfeed 전환이 튀지 않는가?
- 1280x720 기준과 작은/넓은 화면에서 핵심 정보가 유지되는가?
- 첫 실행, 설정, 일시정지, 사망/결과, 기록, 재시작에서 조작 초점과 상태 전이가 끊기지 않는가?

수동 캡처는 게임 중 `F12`를 눌러 `debug_screenshot_manual.png`를 만든다. HUD 변경은 정상/낮은 HP, zone 변경은 대기/축소, inventory 변경은 빈 슬롯/가득 찬 슬롯처럼 동적 상태를 함께 확인한다.

R1 후보의 HUD·지도·메뉴 변경은 같은 상태와 여러 해상도를 다시 찍을 수 있는 capture matrix를 둔다. 일회성 mockup이나 별도 장문 UI 보고서는 승격 근거로 쓰지 않는다.

## 기록 양식

```text
날짜:
표면:
테스트 변경:
결과: 채택 / 폐기 / 반복 필요
체감:
다음 행동:
```

## 최근 기록

### 2026-08-14 - N2-PLAY-11 continuity schema v2 기준선과 후보 폐기

계약: behavior-neutral schema v2는 `Main.match_timer`를 canonical clock으로 쓰며 `complete=true` exact aggregate를 판정 근거로 둔다. raw는 run마다 결정적 bottom-k로 release episode·DISENGAGE exit 각각 최대 128개만 보존하고 omitted sample이 있어도 완전 aggregate를 무효화하지 않으며 terminal target release는 제외한다.
사전 확인: v2 1-run sanity는 data contract를 통과했지만 stuck gate를 실패해 gameplay 근거로 승격하지 않았다. 이어 실행한 `C:\tmp\n2_play_11_continuity_v2_5run_20260814`는 평균 668.8초(531.5-805.5), alive 중앙값 `54/34/24/23/21/15`, T50/T10 `31.5/306.7초`, first upgrade 3.5초, fallback 0이었다.
판정: opening kill 132건 중 생존 상태 피해자 100건·2초 이내 71건이며 59초 이내 생존 상태 unique release/reacquire/opening exit는 `414/132/1284`다. raw coverage 합계는 episode `414/414/0`, exit `1284/640/644`(population/stored/omitted)이고 `check_scale_telemetry`는 PASS했지만 생존 watch band는 FAIL, 기록된 entry 보조 watch는 run2 0.782·run4 0.864로 2/5에서 0.70을 넘었다.
폐기/다음: bot-only survival HP buffer와 DISENGAGE 첫 1초 counteraction grace는 각각 1-run 방향 gate를 실패해 완전 revert하고 5-run을 금지했다. 새 gameplay PASS·패키지·수동 주장은 없으며, 다음 후보 전 behavior-neutral opening 생존 상태 노출 분모로 위치·상태 집중을 좁힌다.

### 2026-08-09 - N2-PLAY-10 packaged 수동 6판 거부

날짜: 2026-08-09
표면: clean smoke `ac9fff8`의 `BattleCapsule.exe`, `night_br_m1_60`, 사용자 직접 플레이 6판.
결과: M1 승격 거부. 화면·경제·생존 페이싱 수정 뒤 반복 필요.
체감: 대부분의 플레이 시간에 비권총 무기를 찾지 못했고, 첫 축소 전에 한 자리만 남거나 경기가 끝났다. 조우는 파밍·자기장 회전보다 스폰 과밀과 우연한 근접에서 시작하는 경우가 많았다. 전체 지도를 열어도 미니맵·상단 상태/미션·킬피드·하단 무기 HUD가 남아 지도를 가렸다.
근거: `(지속시간초/순위)`는 `16/60, 50/40, 84/21, 92/1, 135/14, 240/6`; 화면은 88초에 `25/61`, 최신 240초 결과는 stage1 사망 56명이다. 초기 pickup은 무기 5·탄약 23·방어/회복 14로 61명에 비해 무기가 적었고, 봇 무기 드랍 55개 중 기본 권총은 기존 권총과 동급이라 누구도 줍지 못했다.
자동 후속: 전체 지도 뒤 gameplay HUD를 숨기고 미니맵을 220px로 줄이며 교전 중 정적 배경만 흐리게 한다. 기본 권총 무기 드랍을 제거하고 `bot_drop`은 soft 120초/hard 150초, `stage_wave`는 soft 180초/hard 210초로 제한했으며 비무기 wave가 무기를 다시 뽑는 경로를 막았다. 생존 event staircase와 첫 표적 종류를 기록하고 스폰 반경을 면적 균등화했다. 초기 장총은 전역 확률 대신 14개 POI의 보장 슬롯 18개와 오브젝트 앵커에 배치했다.
다음 행동: 자동 후속의 5-run 생존 실패와 최신 continuity v2 기준선·후보 폐기는 위 기록이 소유한다. 새 1-run 방향 gate 통과 전 packaged 수동 3판을 다시 하지 않는다.

### 2026-07-23 - N2-PLAY-09 지역·압력·파밍 판정

날짜: 2026-07-23
표면: `mapSpec_night_forest_expanded_candidate.json`, `night_br_m1_60`, 사용자 직접 플레이.
결과: 지역 구분·고품질 구조물·일부 AI 잠복은 채택, 빈 평지·초기 자기장 압력·지역별 파밍 경제는 반복 필요.
체감: 집과 천막은 품질이 좋고 지역 구분도 생겼지만 대부분은 여전히 평지다. 봇의 잠복은 재미있었으나 자기장과 무관하게 돌아다니는 봇이 많아 이동 부담이 약했다. 초반 총기는 부족하고 후반에는 남으며, 구급상자와 실드의 전투 중 사용이 생존 제약을 무너뜨렸다.
자동 후속: N2-SURV-01에서 첫 축소를 120초로 당기고 AI 선점 리드를 늘렸다. 구급상자 1개·50HP·6초 전투 잠금, 실드 픽업 전투 잠금, 붕대 전투 사용, 저체력 이동 저하를 적용했다.
다음 행동: N2-EQUIP-01에서 중심·도로와 외곽의 초기 무기 접근을 분리하고 실드 충전과 장착 방어구를 구분한다. 이후 N2-MAP-17에서 무작위 장애물 대신 장소가 되는 구조물 군집을 추가한다.

### 2026-07-22 - N2-PLAY-08 지역 표현·압력 판정

날짜: 2026-07-22
표면: `mapSpec_night_forest_expanded_candidate.json`, `xlarge_60`, 사용자 직접 플레이.
결과: 지면·지역 표현은 개선, 도로/숲 선택 압력과 자기장 선점은 반복 필요.
체감: 지면은 지역을 구분했지만 도로와 숲의 이동·위험 차이가 없었고, 자기장을 피해 진입할 때 먼저 자리를 잡은 무리와 부딪히는 구조도 거의 없었다. 맵은 이전보다 풍부해졌으나 장애물과 AI 점유가 하나의 압력으로 연결되지 않았다. 지옥은 최대 체력 잠금이 아니라 현재 HP 1에서 회복 가능해야 한다.
자동 후속: 도로 100%, 일반 지면 92%, 숲 84% 이동 계약을 플레이어와 AI에 연결했다. AI는 성향별로 축소 35-65초 전부터 다음 원의 입구·외곽 앵커를 선점하고 일부는 물리 도로를 경유해 다음 stage까지 유지한다. 지옥은 `1/100`, 회복 불가 유물만 `1/1`로 분리했다.
다음 행동: N2-PLAY-09에서 실제 도로 교통량, 숲 우회 체감, 다음 원 접근 조우와 지옥 회복을 판정한다.

### 2026-07-20 - N2-PLAY-05 맵 압력·칼·앉기 재판정

날짜: 2026-07-20
표면: `mapSpec_night_forest_expanded_candidate.json`, `xlarge_60`, 사용자 직접 플레이.
결과: 긴장·조우와 앉기 발걸음 채택, 칼과 거점·지역 밀도 반복 필요.
체감: 교전 압력과 앉기 소리는 적절했다. 칼은 실제 휘두름·피격 구분이 없어 어색했고, 맵은 여전히 프롭을 흩뿌린 인상이라 길가·숲·거점이 장소로 구분되지 않았다.
자동 후속: 칼을 CC0 휘두름 3종과 살점 피격음으로 분리했다. 지면 10구역과 Cabin Row의 3동 cabin·수목 외곽·벽·보급 프롭·fire pit을 묶고 지형 발소리와 지도 표현을 연결했다.
다음 행동: N2-PLAY-06에서 Cabin Row 접근과 이탈이 장소 이동으로 읽히는지, 칼 명중 여부가 소리만으로 구분되는지 판정한다.

### 2026-07-19 - N2-PLAY-04 로컬 지도·AI·오디오 재판정

날짜: 2026-07-19
표면: `mapSpec_night_forest_expanded_candidate.json`, `xlarge_60`, 사용자 직접 플레이.
결과: 로컬 미니맵과 AI 교전 개선 채택, 맵 전체 압력과 오디오 세부 반복 필요.
체감: 미니맵은 훨씬 좋아졌고 AI 자체도 크게 개선됐다. 그러나 거점으로 끌리는 자연스러운 강제성은 발견하지 못했다. 권총은 다른 총보다 컸고 칼은 부자연스러우며 앉기 발걸음 감쇠가 필요했다.
자동 후속: 비전투 IDLE에 저빈도 POI 목적지를 연결하고 앉기 -10dB/청취 45%, 권총 -8.5dB, CC0 칼 Foley를 적용했다. 60봇 p95 12.9ms, 3-run 평균 231.1초.
다음 행동: N2-PLAY-05에서 지역 간 이동이 실제 압력으로 느껴지는지와 전투 과소모, 오디오 3항목을 함께 판정한다.

## 메모

- `night_br_m1_60`은 수동·자동 공통 gameplay 기준선, `target_99_probe`는 자동 구조 부하용이다. 과거 기록의 `xlarge_60`은 현재 기준과 같은 호환 alias다.
- 텔레메트리 PASS는 플레이테스트 PASS가 아니다.
- 기존 `playable_pacing_v4-v6` 결과는 과거 비교 자료이며 현재 수동 승격 기준선이 아니다.
- 명확하게 체감이 나쁘면 수동 기록 하나가 수치 후보를 뒤집을 수 있다.
- 메모 전용 안정화 이후 아이디어: 가방 같은 보급 아이템이 있으면 현재 총과 맞지 않는 탄약도 보관하고, 악세서리는 자동 재장전·탄 퍼짐 감소처럼 선택을 만든다.
- 메모 전용 무기 확장: 숫자키 `1-4`로 무기군을 고르고 `Tab`으로 군 안의 사용 무기를 순환하며, 더블배럴 같은 샷건 변형은 피해·발사 속도·장전 trade-off로 구분한다. 이번 M1/R0 범위에서는 구현하지 않는다.
- 다음 맵 대표 슬라이스는 대형 폐쇄 구조물 하나와 두 개 이상의 진입/우회로를 POI 보상과 묶는다. 봇은 장비 필요·남은 재고·자기장 시간에 따라 중심 파밍, 외곽 파밍, 우회를 달리하고 모든 봇이 한 지점에 수렴하지 않아야 한다.
