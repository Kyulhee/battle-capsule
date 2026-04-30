0. 현재 게임의 정체성 재정의

현재 GitHub README 기준으로도 게임은 “쿼터뷰 배틀로얄, 플레이어 1명 vs 봇 11명, 숲 테마 1개, 자기장 생존” 구조다. 공개 저장소이고, 다운로드 링크도 이미 v0.8.1 기준으로 걸려 있다.

마스터플랜상 설계 원칙도 “절차적 우선, 상태 머신 AI, 데이터 분리, 난이도 파라미터화”에 맞춰져 있다. 즉, 이 프로젝트는 처음부터 대형 에셋 기반 스토리 게임보다 시스템 중심의 빠른 확장형 프로토타입에 더 적합하다.

내 판단은 이거다.

배틀캡슐은 “작은 배틀로얄 한 판”을 반복해서 돌리는 게임이 아니라, 매 판 조건이 달라지는 ‘캡슐형 전술 생존 실험장’으로 가야 한다.

이 방향이면 지금 구현한 난이도, 봇 성격, Telemetry, 기록, 자기장, 아이템, 킬피드가 모두 살아난다.

1. 1.0 이후 큰 방향 후보
방향 A. 로그라이트 배틀로얄

요지
매 판 시작 전/중간에 아티팩트, 패시브 능력, 저주, 보상 선택지를 준다.

예시

Glass Capsule: 공격력 +50%, 최대 HP 50%
Echo Boots: 발소리 감지 거리 감소
Blood Ammo: 탄약 부족 시 HP를 소모해 사격
Hunter Mark: 가장 강한 봇 위치가 미니맵에 주기적으로 표시
Overclock: 10초마다 3초간 연사 증가, 이후 이동속도 감소
Zone Pact: 자기장 피해 감소, 대신 회복량 감소

장점
반복 플레이 문제를 가장 직접적으로 해결한다. 코드 기반 아이템/스탯 시스템과 잘 맞는다. [신뢰 B]

단점
밸런싱이 어려워진다. Telemetry 기반 조정이 필요하다.

내 평가
가장 추천한다. 현재 프로젝트 구조와 제일 잘 맞는다.

방향 B. 미션/챌린지 모드

요지
그냥 1등하기가 아니라, 매치별 목표를 다르게 준다.

예시

Kill 3 bots with pistol
Survive 90 seconds without healing
Win without using armor
Reach supply capsule within 40 seconds
Win on Hell difficulty
Eliminate Bot Captain
Escape from blackout zone
Use only melee

장점
스토리 없이도 목적성이 생긴다. 구현비가 낮다. 기록/업적 UI와 연결하기 좋다. [신뢰 B]

단점
미션 종류가 적으면 금방 소모된다.

내 평가
v1.1~v1.3에 강력 추천. 아티팩트보다 먼저 넣어도 좋다.

방향 C. 맵 확장: 숲 + 도시

요지
현재 숲 맵 외에 도시형 맵을 추가한다.

숲 맵 특징

수풀 스텔스
큰 바위/나무 커버
시야가 불규칙
자연형 엄폐
은신/기습 중심

도시 맵 특징

골목
건물 벽
직선 시야
교차로
옥상 또는 고지대
실내/실외 경계
총기 교전 중심

장점
게임 체감이 크게 달라진다. 스크린샷만 봐도 확장감이 생긴다. [신뢰 B]

단점
Navigation, collision, camera occlusion, line-of-sight 문제가 급증한다.

내 평가
v2.0 이후가 적절하다. 지금 바로 도시 맵을 넣으면 pathfinding/시야 문제가 폭발할 가능성이 높다.

방향 D. 봇 수와 맵 크기 확장

요지
1 vs 11에서 1 vs 23, 1 vs 31 같은 대규모 전장으로 확장한다.

장점

배틀로얄 느낌이 강해진다.
킬피드, 봇끼리 싸움, 미니맵 정보가 더 살아난다.

단점

AI 비용 증가
pathfinding 필요성 증가
킬피드 과밀
플레이어가 아무것도 안 했는데 봇끼리 다 죽는 문제 증가
자기장/스폰/루팅 밸런스 재설계 필요

내 평가
봇 수 확장은 매력적이지만, v1.0 직후 바로 하면 안 된다. 먼저 12 → 16 → 24처럼 단계적으로 올려야 한다. [신뢰 B]

방향 E. 짧은 스토리/캠페인

요지
“왜 캡슐들이 싸우는가?”에 대한 세계관을 붙인다.

가능한 톤

실험장: AI 전투 실험 시뮬레이터
TV 쇼: 캡슐들이 방송용 경기장에서 싸움
디스토피아: 생존 테스트
장난감 세계: 작은 캡슐 피규어 전쟁
연구소 탈출: 플레이어 캡슐이 실험체

장점
게임의 정체성이 생긴다.

단점
스토리는 콘텐츠 밀도가 낮으면 오히려 어설퍼 보인다. 지금 단계에서 풀 캠페인을 넣는 건 비효율적이다. [신뢰 B]

내 평가
“스토리 모드”보다 챌린지 미션 사이에 짧은 텍스트/브리핑을 넣는 방식이 좋다.

2. 내가 추천하는 최종 방향
장르 포지셔닝
Battle Capsule = Solo Tactical Roguelite Battle Royale

한국어로는:

캡슐형 전술 로그라이트 배틀로얄

핵심은 이 4개다.

짧은 한 판
매 판 조건 변화
봇끼리도 살아 움직이는 전장
플레이어가 특수 능력/아티팩트로 판을 비트는 재미

이렇게 가면 스토리 없이도 반복 플레이가 가능하다.

3. 1.0 이후 로드맵 초안
v1.1 — Challenge Mission System

목표
단순 생존 외의 플레이 목적을 만든다.

기능

미션 선택 화면
매치 시작 전 목표 표시
매치 중 목표 진행도 HUD
결과 화면에 미션 성공/실패 표시
미션 기록 저장

미션 예시

Pistol Trial
- 피스톨로 3킬 이상
- 보상: Pistol Master badge

No Heal Run
- 치료 아이템 없이 승리
- 보상: Iron Capsule badge

Hunter Run
- 60초 안에 3킬
- 보상: Hunter badge

Supply Rush
- 첫 보급 캡슐을 획득하고 생존
- 보상: Drop Chaser badge

왜 먼저인가
미션은 새 맵보다 구현비가 낮고, 반복 플레이 이유를 즉시 만든다. [신뢰 B]

v1.2 — Artifact / Perk System

목표
매 판의 변수를 만든다.

구조

매치 시작 시 3개 중 1개 선택
또는 보급 캡슐/킬 보상으로 획득
긍정 효과 + 부정 효과를 같이 둬서 선택을 의미 있게 만듦

아티팩트 카테고리

공격형
생존형
은신형
자기장형
탄약형
고위험 고보상형

예시

Red Trigger
- 공격력 +25%
- 반동/탄퍼짐 +20%

Silent Core
- 발소리 감지 반경 -50%
- 이동속도 -10%

Last Bullet
- 탄창 마지막 탄 피해량 +100%
- 재장전 시간 +20%

Zone Skin
- 자기장 피해 -40%
- 회복량 -30%

Vulture Protocol
- 봇 사망 위치가 3초간 표시됨
- 플레이어 위치도 킬 후 2초간 노출됨

중요 설계 원칙
아티팩트는 단순 강화보다 플레이 스타일을 바꾸는 것이 좋다. [신뢰 A]

v1.3 — Meta Progression Lite

목표
장기 목표를 만든다. 단, 과한 RPG 성장으로 밸런스를 망치지 않는다.

추천 방식

영구 스탯 강화는 최소화
배지, 기록, 스킨, 난이도 해금 중심
플레이어 실력 중심 유지

가능한 해금

Hell 난이도 해금
도시 맵 해금
특수 미션 해금
색상 스킨
킬피드 타이틀
시작 무기 변형

비추천

영구 공격력 +10%
영구 HP +20
시작부터 강한 무기 보유

이런 식의 영구 강화는 배틀로얄의 공정성과 긴장감을 약화시킨다. [신뢰 B]

v1.4 — Director System

목표
매치가 너무 밋밋하거나 너무 불합리해지지 않도록 게임이 상황을 조절한다.

개념

GameDirector.gd가 전장 상태를 보고 이벤트를 조절한다.

관찰 지표

남은 봇 수
플레이어 HP
플레이어 킬 수
교전 없는 시간
자기장 단계
보급 획득 여부
봇 밀집도
플레이어 위치 안전도

개입 예시

교전이 너무 없으면 근처에 보급 핑
플레이어가 너무 압도하면 강한 봇을 근처에 이동
플레이어가 너무 빨리 죽으면 초반 이벤트 완화
후반에 생존자가 흩어져 있으면 zone 수축 강화

주의
Director는 티 나면 안 된다. 플레이어가 “조작당한다”고 느끼면 실패다. [신뢰 B]

v1.5 — Public Alpha / Open Source Showcase

목표
판매 전, 공개 배포용으로 다듬는다.

작업

README 개선
스크린샷/GIF 추가
조작법 명확화
라이선스 파일 정리
Credits / Third-party licenses 메뉴 추가
Windows/macOS release 자동화
Known Issues 문서화
itch.io 배포 검토

라이선스 체크

Godot는 MIT 라이선스이므로 상업적 사용 자체는 가능하다. 다만 배포물 안에 Godot 라이선스 텍스트를 포함하는 방식이 권장/요구되며, 공식 문서도 Credits screen, Licenses screen, output log 등 방식을 제시한다.
별도로, 네 프로젝트 자체의 라이선스와 외부 에셋/폰트/사운드 라이선스는 Godot와 별개로 정해야 한다. [신뢰 A]

4. v2.0 이후: 맵 확장
v2.0 — Map System Refactor

도시 맵을 바로 하나 만들기 전에, 먼저 맵 시스템을 일반화하는 게 좋다.

필요 구조

MapDefinition
- map_id
- display_name
- theme
- size
- spawn_rules
- loot_tables
- obstacle_sets
- cover_density
- bush_density
- verticality
- zone_profile
- bot_count_range

왜 필요한가
숲과 도시를 같은 코드에 억지로 넣으면 if map == "city"가 계속 늘어난다. 이건 장기적으로 망가지는 구조다. [신뢰 A]

v2.1 — Forest 2.0

도시보다 먼저 현재 숲 맵을 “완성형”으로 올리는 것도 좋다.

추가 요소

늪지대: 이동속도 감소
높은 풀숲: 은신 강함, 이동속도 감소
바위 협곡: 좁은 교전
벌목장: 중거리 교전
폐허 캠프: 루팅 집중 지역
동굴 입구: 위험하지만 희귀 아이템

장점
새 맵을 만드는 것보다 현재 시스템을 안정적으로 확장할 수 있다.

v2.2 — City Map

도시 맵 핵심

골목
건물 벽
교차로
실내/외
옥상 또는 고지대
엄폐물 많은 중거리 교전
수풀 대신 그림자/소음 스텔스

도시 맵 전용 시스템

Alley Ambush
- 좁은 골목에서 봇 시야가 제한됨

Street Sightline
- 긴 도로에서는 원거리 무기가 강함

Building Occlusion
- 카메라와 플레이어 사이 건물 투명화 중요

Noise Echo
- 도시에서는 발소리가 더 멀리 퍼짐

Rooftop Supply
- 보급 캡슐이 옥상 또는 광장에 떨어짐

리스크
도시 맵은 NavigationAgent3D 없이는 고통스러울 가능성이 높다. 그래서 v1.0에서 navigation이 안정화된 뒤 가는 게 맞다. [신뢰 B]

v2.3 — Bot Count Expansion

단계적 확장

Classic: 1 vs 11
Large:   1 vs 15
Chaos:   1 vs 23
Hell:    1 vs 31

필수 선행 조건

killfeed 필터링
minimap clutter 제어
AI 업데이트 최적화
spawn safety
loot density scaling
zone timing scaling

아이디어

봇 수가 늘어날수록 모든 봇을 매 프레임 똑같이 계산하지 말고, 거리 기반 LOD를 둔다.

Near bots: full AI
Mid bots: reduced perception update
Far bots: low-frequency state update
Offscreen bots: simplified combat simulation

[신뢰 B]

5. v3.0 이후: 캠페인/스토리
권장 방식: “스토리 모드”가 아니라 “Operation 모드”

완전한 컷신/대사 중심 스토리보다, 미션 묶음을 Operation으로 만드는 게 낫다.

Operation Green Ring
- 숲 맵 기본 생존 훈련
- 수풀 은신 튜토리얼
- 보급 캡슐 탈취
- Hell zone 실험

Operation Concrete Maze
- 도시 맵 진입
- 골목 교전
- 저격 봇 제거
- 암전 이벤트 생존

Operation Red Capsule
- 강화 봇 등장
- 아티팩트 강제 선택
- 최종 1 vs Captain Bot

장점

스토리 부담이 낮다.
미션 시스템을 재사용한다.
짧은 텍스트 브리핑만으로 세계관을 전달할 수 있다.
솔로 게임의 목표성을 강화한다.
6. 특수 능력/아티팩트 아이디어 풀
공격 계열
Double Tap
- 같은 대상에게 연속 명중 시 두 번째 탄 피해 증가

Ricochet Core
- 일정 확률로 탄환이 벽에 튕김

Execution Spark
- HP 30% 이하 대상에게 피해 증가

Overheat Barrel
- 연사할수록 공격력 증가
- 오래 쏘면 탄퍼짐 증가

Knife Protocol
- 칼 피해 증가
- 총기 장전 시간 증가
생존 계열
Emergency Shell
- HP 20% 이하가 되면 3초간 실드 생성
- 매치당 1회

Med Loop
- 치료 아이템 사용 후 5초간 이동속도 증가

Armor Sponge
- 방어구 획득량 증가
- 회복량 감소

Second Capsule
- 사망 시 HP 1로 1회 부활
- 무기 하나를 랜덤으로 잃음
은신/정보 계열
Silent Foot
- 발소리 감소

Pulse Scanner
- 15초마다 근처 봇 방향 표시

Ghost Grass
- 수풀 밖에서도 2초간 은신 보너스 유지

False Signal
- 플레이어의 가짜 소리 위치 생성
자기장 계열
Zone Eater
- 자기장 안쪽 경계 근처에서 공격력 증가

Blue Lung
- 자기장 피해 감소

Panic Sprint
- 자기장 밖에서 이동속도 증가
- 자기장 밖 사격 정확도 감소

Zone Debt
- 자기장 피해를 즉시 받지 않고 누적
- 안전지대 진입 후 천천히 피해 정산
고위험 계열
Glass Capsule
- HP 1
- 모든 피해량 2배

Marked King
- 플레이어 위치가 주기적으로 노출
- 킬당 회복

No Reload
- 재장전 불가
- 모든 탄약 픽업이 즉시 탄창에 추가됨

Blood Trigger
- 탄약이 없으면 HP를 소모해 사격
7. 미션 아이디어 풀
기본 챌린지
First Blood
- 첫 킬을 기록하라

Clean Win
- 1등 + HP 50 이상

Medic Run
- 치료 아이템 3회 이상 사용하고 승리

Scavenger
- 무기 3종 이상 획득

Survivor
- 킬 없이 90초 생존
무기 챌린지
Pistol Only
- 피스톨만 사용

Knife Finish
- 마지막 적을 칼로 처치

Shotgun Rush
- 샷건으로 3킬

Railgun Moment
- 레일건으로 한 방 킬

No Reload
- 재장전 없이 승리
전술 챌린지
Bush Hunter
- 수풀 안 또는 근처에서 2킬

Zone Walker
- 자기장 밖에서 10초 이상 생존 후 승리

Supply Thief
- 보급 캡슐 근처에서 적 처치

Ambush
- 봇이 플레이어를 완전 인식하기 전에 처치

Outnumbered
- 2명 이상에게 감지된 상태에서 생존 후 킬
Hell 챌린지
One HP King
- Hell 난이도에서 60초 생존

Blackout Kill
- 암전 중 킬

Bomb Dodge
- 폭격 피해 없이 승리

Hell Champion
- Hell 난이도 승리
8. 배포/판매 전략
지금은 오픈소스 배포 유지가 맞다

이유는 명확하다.

아직 시스템 실험 단계다.
플레이타임/반복성 검증 전이다.
공개 repo가 포트폴리오로도 기능한다.
Claude Code/Godot 개발 기록 자체가 좋은 쇼케이스다.
피드백 받기 쉽다.

[신뢰 B]

판매를 고려할 수 있는 시점

아래 조건 중 4개 이상 만족하면 판매 검토 가능하다.

- 2개 이상의 맵
- 20개 이상의 아티팩트
- 20개 이상의 미션
- Hell 포함 4개 이상 난이도
- 1시간 이상 반복 플레이해도 지루하지 않음
- itch.io 무료/후원 버전에서 긍정 피드백
- Windows/macOS 빌드 안정
- README/GIF/트레일러 준비
- 라이선스/크레딧 정리 완료
판매 형태 후보
1. 무료 오픈소스 + 후원

가장 부담이 낮다.

GitHub release
itch.io free download
Buy me a coffee / sponsor link
2. 무료 데모 + 유료 확장
Free:
- Forest map
- Normal/Hard
- 기본 아티팩트 10개

Paid:
- City map
- Hell mode
- Operation mode
- 추가 아티팩트/미션
3. 완전 유료 인디 게임

아직은 이르다. 콘텐츠 볼륨과 시각적 완성도가 더 필요하다. [신뢰 B]

9. 내가 제안하는 장기 마스터플랜
v1.0 — Alpha Completion
- Navigation
- Settings
- Result summary
- Stable build

v1.1 — Challenge Mission System
- Mission selection
- Objective HUD
- Mission result
- Badges

v1.2 — Artifact System
- Start artifact selection
- Loot/drop artifact
- Positive/negative effects
- 20 artifacts

v1.3 — Meta Progression Lite
- Badges
- Unlocks
- Records
- Challenge tiers

v1.4 — Game Director
- Dynamic event pacing
- Supply/zone/combat pressure control
- Anti-boring match logic

v1.5 — Public Alpha Polish
- README/GIF
- License/Credits
- Release automation
- itch.io page

v2.0 — Map System Refactor
- MapDefinition
- Loot table by map
- Zone profile by map
- Spawn profile by map

v2.1 — Forest 2.0
- Sub-biomes
- Better cover
- POI variation

v2.2 — City Map
- Alley/street/building layout
- Urban occlusion
- Noise echo
- New loot profile

v2.3 — Larger Battles
- 16/24/32 actor modes
- AI LOD
- Killfeed filtering
- Map size scaling

v3.0 — Operation Mode
- Mission chains
- Short briefings
- Boss/captain bots
- Lightweight story wrapper