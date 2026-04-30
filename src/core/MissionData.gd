extends Resource
class_name MissionData

enum ConditionType {
	FIRST_KILL,             # 킬 >= 1
	WIN_HIGH_HP,            # 승리 + HP >= target_value
	WIN_WITH_HEALS,         # 승리 + MedKit 사용 >= target_value
	COLLECT_WEAPONS,        # 무기 종류 픽업 >= target_value (미사용)
	SURVIVE_NO_KILLS,       # 킬 0 + 생존 시간 >= target_value
	WIN_PISTOL_ONLY,        # 승리 + 비피스톨 발사 없음
	KILL_LAST_WITH_MELEE,   # 승리 + 마지막 킬이 칼
	KILLS_WITH_WEAPON,      # kills_by_weapon[weapon_filter] >= target_value
	KILL_IN_BUSH,           # 수풀 안/근처 킬 >= target_value
	WIN_AFTER_ZONE_OUTSIDE, # 승리 + 자기장 밖 최장 연속 >= target_value 초
	KILL_NEAR_SUPPLY,       # 보급 캡슐 근처(12m) 킬 >= target_value
	KILL_UNDETECTED,        # 봇 인식 < 1.0 상태에서 킬 >= target_value
	KILL_WHILE_DETECTED,    # 봇 2명 이상 감지 상태에서 킬 >= target_value
	WIN_ON_DIFFICULTY,      # 승리 + difficulty == target_value
	KILL_WITH_ALL_WEAPONS,  # pistol/ar/shotgun/railgun 각각 1킬 이상
}

@export var id: String = ""
@export var title: String = ""
@export var description: String = ""
@export var condition_type: ConditionType = ConditionType.FIRST_KILL
@export var target_value: float = 1.0
@export var weapon_filter: String = ""  # KILLS_WITH_WEAPON용 weapon_type 필터
@export var score_bonus: int = 500       # 미션 성공 시 추가 점수
@export var badge_label: String = ""
@export var badge_color: Color = Color.GOLD
