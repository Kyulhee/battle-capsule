# BATTLE CAPSULE (배틀캡슐) - 기술 핸드오프 가이드 (v1.5 최종본)

본 문서는 배틀로얄 프로토타입 '배틀캡슐'의 후속 개발 및 폴리싱을 담당할 에이전트를 위한 통합 기술 가이드입니다. 초기 설계부터 최종 메타 시스템까지 모든 핵심 내용을 포함합니다.

---

## 1. 프로젝트 개요
- **플랫폼**: Godot 4.x (GDScript)
- **장르**: 쿼터뷰 탑다운 전술 배틀로얄
- **브랜드**: '배틀캡슐' - 캡슐 아이템과 전술적 위치 선점이 핵심인 하이엔드 프로토타입.

---

## 2. 초기화 및 게임 루프 (Initialization & Flow)

### A. 메인 초기화 시퀀스 (`Main.gd`)
1. **MapSpec 로드**: JSON 파일에서 POI, 구역 설정, 장애물 데이터를 파싱.
2. **WorldBuilder 실행**: 파싱된 데이터를 기반으로 POI 모델 배치, 지형 생성, 수풀(Bush) 및 장애물 동적 생성.
3. **Minimap 동기화**: 생성된 월드 크기와 POI 위치 정보를 미니맵 UI에 전달.
4. **엔티티 스폰**: 플레이어 및 봇을 안전한 위치(장애물 없는 POI 등)에 배치.

### B. 게임 상태 머신 (GameState)
- **MENU**: 메인 메뉴 레이어 활성화. 게임 로직 정지.
- **PLAYING**: 실제 게임 플레이. 타이머, 구역 축소, 텔레메트리 작동.
- **RESULT**: 매치 종료 시 진입. 결과 패널 활성화 및 로컬 데이터 저장.

---

## 3. 핵심 시스템 상세

### A. 지각 및 은신 시스템 (Perception & Stealth)
- **Perception Meter**: 봇은 적을 즉시 발견하지 않습니다. 거리와 노출 정도에 따라 미터가 차오르며, 100% 도달 시 발견(Revealed) 처리됩니다.
- **Bush Interaction**: 수풀 내부는 액터를 반투명하게 만들고 인식을 늦춥니다. 사격 시에는 위치가 즉시 노출됩니다.
- **Reveal Logic**: 사격이나 피해 발생 시 일정 시간 동안 모든 적에게 위치가 강제 노출됩니다.

### B. 전술적 전투 및 물리 (`Entity.gd`, `Bot.gd`)
- **높이 기반 물리 (Layer 4)**: 
    - 2.5m 이상의 장애물: 시야 차단, 사격 차단, 이동 차단.
    - 2.5m 이하의 낮은 장애물: 이동은 차단하지만 **시야 및 사격은 허용**.
- **Combat FX**: 
    - `BulletTrail`: Raycast 기반의 물리 탄도 시각화.
    - `MuzzleFlash / ImpactEffect`: 총구 화염 및 탄착지 파편 효과.
    - `DamageOverlay`: 플레이어 피격 시 화면 붉은기 연출.
- **Predictive Fire**: 시야 상실 후 2.5초간 마지막 위치를 향해 사격. 시간이 갈수록 탄 퍼짐(Spread) 가중치 증가.

### C. 구역 관리 시스템 (Zone Control)
- **Blue Zone**: 시간에 따라 `current_zone_radius`가 감소. `generate_next_zone()`을 통해 다음 안전 구역의 중심점을 예측 불가능하게 생성.
- **Zone Damage**: 구역 외부에 있는 액터는 주기적으로 체력 데미지를 입으며, `zone_stage`가 올라갈수록 데미지가 강화됨.

---

## 4. 디렉토리 구조 상세 (Directory Map)

### `src/core/` (기반 시스템)
- **Telemetry.gd**: 모든 매치 이벤트를 캡처하고 어시스트 판정(5초 윈도우)을 수행.
- **StatsData.gd**: 이동 속도, 시야 범위, 데미지 등 모든 밸런스 수치 관리.
- **MapSpec.gd**: 지형 세부 속성 및 POI 명칭 관리.

### `src/entities/` (액터 시스템)
- **Bot.gd**: IDLE -> CHASE -> ATTACK -> RECOVER 상태를 순환하는 정교한 AI.
- **Pickup.gd**: `Area3D`를 통해 아이템 획득 범위 관리. `PickupData` 리소스를 사용.

### `src/maps/` & `src/items/`
- **WorldBuilder.gd**: POI(Point of Interest) 간의 동선 최적화 배치 알고리즘.
- **weapon_*.tres**: 무기별 연사 속도, 탄환 수, 데미지 데이터.

---

## 5. 다음 단계 폴리싱 가이드 (Roadmap)

### 1단계: 시각적 극대화 (Visual Juice)
- **Tweening**: UI 패널 등장 시 부드러운 슬라이드/페이드 효과.
- **Killfeed**: 화면 우측 상단에 실시간 킬/사망 정보 표시.
- **Hit Indicator**: 공격 적중 시 크로스헤어 변화 및 히트마커 사운드.

### 2단계: 오디오 정밀 설계 (Audio Immersion)
- **공간 오디오**: 발소리와 총성의 3D 위치 정위감 개선.
- **시스템 보이스**: "Zone Shrinking", "Supply Incoming" 등의 보이스 알림.

### 3단계: 콘텐츠 확장
- **City 테마**: 고층 빌딩과 실내 교전 시스템 추가.
- **Active Capsules**: 대시(Dash), 은신(Cloak) 등의 액티브 스킬 캡슐 구현.

---
**최종 보고서 종료.**
*작성일: 2026-04-23*
*작성자: antigravity (Google Deepmind)*
