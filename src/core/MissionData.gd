extends Resource
class_name MissionData

enum ConditionType {
	FIRST_KILL,             # kills >= target_value
	WIN_HIGH_HP,            # 승리 + HP >= target_value
	WIN_WITH_HEALS,         # 승리 + MedKit 사용 >= target_value
	COLLECT_WEAPONS,        # 무기 종류 픽업 >= target_value (미사용)
	SURVIVE_NO_KILLS,       # 킬 0 + 생존 시간 >= target_value
	WIN_PISTOL_ONLY,        # 승리 + 비피스톨 발사 없음
	KILL_LAST_WITH_MELEE,   # 승리 + 마지막 킬이 칼
	KILLS_WITH_WEAPON,      # kills_by_weapon[weapon_filter] >= target_value
	KILL_IN_BUSH,           # 수풀 안/근처 킬 >= target_value
	WIN_AFTER_ZONE_OUTSIDE, # 승리 + 자기장 밖 최장 연속 >= target_value 초
	KILL_NEAR_SUPPLY,       # MissionTuning supply radius 안에서 킬 >= target_value
	KILL_UNDETECTED,        # MissionTuning detection threshold 미만에서 킬 >= target_value
	KILL_WHILE_DETECTED,    # MissionTuning detected bot count 이상에서 킬 >= target_value
	WIN_ON_DIFFICULTY,      # 승리 + difficulty == target_value
	KILL_WITH_ALL_WEAPONS,  # MissionTuning all-weapon set/target 충족
	WIN_ONE_SLOT,           # 승리 + 총기 슬롯 target_value개 이하만 사용
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
