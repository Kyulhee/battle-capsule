extends RefCounted
class_name MissionTracker

const MissionData = preload("res://src/core/MissionData.gd")
const ACHIEVEMENTS_PATH = "user://achievements.json"

var active_mission = null  # MissionData

var _used_non_pistol: bool = false
var _last_kill_weapon: String = ""
var _kills_in_bush: int = 0
var _kills_near_supply: int = 0
var _kills_undetected: int = 0
var _kills_while_detected: int = 0
var _player_max_outside_sec: float = 0.0
var _player_current_outside_sec: float = 0.0

func reset():
	_used_non_pistol = false
	_last_kill_weapon = ""
	_kills_in_bush = 0
	_kills_near_supply = 0
	_kills_undetected = 0
	_kills_while_detected = 0
	_player_max_outside_sec = 0.0
	_player_current_outside_sec = 0.0

func on_player_fire(weapon_type: String):
	if weapon_type != "pistol":
		_used_non_pistol = true

func on_player_kill(ctx: Dictionary):
	# ctx keys: weapon_type, in_bush, near_supply, undetected, num_detecting
	_last_kill_weapon = ctx.get("weapon_type", "")
	if ctx.get("in_bush", false):
		_kills_in_bush += 1
	if ctx.get("near_supply", false):
		_kills_near_supply += 1
	if ctx.get("undetected", false):
		_kills_undetected += 1
	if ctx.get("num_detecting", 0) >= 2:
		_kills_while_detected += 1

func on_player_zone_tick(is_outside: bool):
	if is_outside:
		_player_current_outside_sec += 1.0
		if _player_current_outside_sec > _player_max_outside_sec:
			_player_max_outside_sec = _player_current_outside_sec
	else:
		_player_current_outside_sec = 0.0

func evaluate(tel: Node, final_rank: int, player_hp: float, difficulty: int) -> bool:
	if active_mission == null:
		return false
	var m = active_mission
	var won: bool = final_rank == 1
	var kills: int = tel.metrics.combat.kills if tel else 0
	var heals: int = tel.metrics.economy.heals_used if tel else 0
	var weapon_types: Dictionary = tel.metrics.economy.weapon_pickups if tel else {}

	match m.condition_type:
		MissionData.ConditionType.FIRST_KILL:
			return kills >= 1

		MissionData.ConditionType.WIN_HIGH_HP:
			return won and player_hp >= m.target_value

		MissionData.ConditionType.WIN_WITH_HEALS:
			return won and heals >= int(m.target_value)

		MissionData.ConditionType.COLLECT_WEAPONS:
			return weapon_types.size() >= int(m.target_value)

		MissionData.ConditionType.SURVIVE_NO_KILLS:
			var duration: float = tel.metrics.core.duration if tel else 0.0
			return kills == 0 and duration >= m.target_value

		MissionData.ConditionType.WIN_PISTOL_ONLY:
			return won and not _used_non_pistol

		MissionData.ConditionType.KILL_LAST_WITH_MELEE:
			return won and _last_kill_weapon == "knife"

		MissionData.ConditionType.KILLS_WITH_WEAPON:
			var wkills: int = 0
			if tel:
				wkills = tel.metrics.combat.kills_by_weapon.get(m.weapon_filter, 0)
			return wkills >= int(m.target_value)

		MissionData.ConditionType.KILL_IN_BUSH:
			return _kills_in_bush >= int(m.target_value)

		MissionData.ConditionType.WIN_AFTER_ZONE_OUTSIDE:
			return won and _player_max_outside_sec >= m.target_value

		MissionData.ConditionType.KILL_NEAR_SUPPLY:
			return _kills_near_supply >= int(m.target_value)

		MissionData.ConditionType.KILL_UNDETECTED:
			return _kills_undetected >= int(m.target_value)

		MissionData.ConditionType.KILL_WHILE_DETECTED:
			return _kills_while_detected >= int(m.target_value)

		MissionData.ConditionType.WIN_ON_DIFFICULTY:
			return won and difficulty == int(m.target_value)

	return false

func get_hud_text(tel: Node) -> String:
	if active_mission == null:
		return ""
	var m = active_mission
	var kills: int = tel.metrics.combat.kills if tel else 0
	var heals: int = tel.metrics.economy.heals_used if tel else 0
	var weapon_types: Dictionary = tel.metrics.economy.weapon_pickups if tel else {}

	match m.condition_type:
		MissionData.ConditionType.FIRST_KILL:
			return "%s: %d/1" % [m.title, kills]
		MissionData.ConditionType.WIN_HIGH_HP:
			var cur_hp: float = 0.0
			if tel:
				var main_node = tel.get_node_or_null("/root/Main")
				if main_node and is_instance_valid(main_node.player_ref):
					cur_hp = main_node.player_ref.current_health
			return "%s: HP %.0f / %.0f 필요" % [m.title, cur_hp, m.target_value]
		MissionData.ConditionType.WIN_WITH_HEALS:
			return "%s: 치료 %d/%d" % [m.title, heals, int(m.target_value)]
		MissionData.ConditionType.COLLECT_WEAPONS:
			return "%s: 무기종류 %d/%d" % [m.title, weapon_types.size(), int(m.target_value)]
		MissionData.ConditionType.SURVIVE_NO_KILLS:
			return "%s: 킬 %d (0 유지)" % [m.title, kills]
		MissionData.ConditionType.WIN_PISTOL_ONLY:
			return "%s: %s" % [m.title, "FAIL" if _used_non_pistol else "OK"]
		MissionData.ConditionType.KILL_LAST_WITH_MELEE:
			return "%s: 마지막킬=%s" % [m.title, _last_kill_weapon if _last_kill_weapon != "" else "?"]
		MissionData.ConditionType.KILLS_WITH_WEAPON:
			var wkills: int = tel.metrics.combat.kills_by_weapon.get(m.weapon_filter, 0) if tel else 0
			return "%s: %d/%d" % [m.title, wkills, int(m.target_value)]
		MissionData.ConditionType.KILL_IN_BUSH:
			return "%s: %d/%d" % [m.title, _kills_in_bush, int(m.target_value)]
		MissionData.ConditionType.WIN_AFTER_ZONE_OUTSIDE:
			return "%s: %.0fs/%.0fs" % [m.title, _player_max_outside_sec, m.target_value]
		MissionData.ConditionType.KILL_NEAR_SUPPLY:
			return "%s: %d/%d" % [m.title, _kills_near_supply, int(m.target_value)]
		MissionData.ConditionType.KILL_UNDETECTED:
			return "%s: %d/%d" % [m.title, _kills_undetected, int(m.target_value)]
		MissionData.ConditionType.KILL_WHILE_DETECTED:
			return "%s: %d/%d" % [m.title, _kills_while_detected, int(m.target_value)]
		MissionData.ConditionType.WIN_ON_DIFFICULTY:
			var diff_names = ["쉬움", "보통", "어려움", "지옥"]
			return "%s: %s 클리어" % [m.title, diff_names[int(m.target_value)] if int(m.target_value) < diff_names.size() else "?"]

	return m.title

func save_badge(mission_id: String):
	var data = load_achievements()
	if not data.has("badges"):
		data["badges"] = []
	if not mission_id in data["badges"]:
		data["badges"].append(mission_id)
	var f = FileAccess.open(ACHIEVEMENTS_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data, "\t"))
		f.close()

func has_badge(mission_id: String) -> bool:
	var data = load_achievements()
	return data.get("badges", []).has(mission_id)

func load_achievements() -> Dictionary:
	if not FileAccess.file_exists(ACHIEVEMENTS_PATH):
		return {}
	var f = FileAccess.open(ACHIEVEMENTS_PATH, FileAccess.READ)
	if not f:
		return {}
	var result = JSON.parse_string(f.get_as_text())
	f.close()
	return result if result is Dictionary else {}

static func get_all_missions() -> Array:
	var list: Array = []

	var m: MissionData

	m = MissionData.new()
	m.id = "first_blood"; m.title = "FIRST BLOOD"
	m.description = "이번 매치에서 1킬 이상 달성"
	m.condition_type = MissionData.ConditionType.FIRST_KILL
	m.target_value = 1; m.badge_label = "첫 피"; m.badge_color = Color(0.85, 0.15, 0.15)
	list.append(m)

	m = MissionData.new()
	m.id = "clean_win"; m.title = "CLEAN WIN"
	m.description = "HP 50% 이상으로 1등"
	m.condition_type = MissionData.ConditionType.WIN_HIGH_HP
	m.target_value = 50; m.badge_label = "무결"; m.badge_color = Color(0.2, 0.9, 0.3)
	list.append(m)

	m = MissionData.new()
	m.id = "medic_run"; m.title = "MEDIC RUN"
	m.description = "치료 아이템 3회 이상 사용 후 1등"
	m.condition_type = MissionData.ConditionType.WIN_WITH_HEALS
	m.target_value = 3; m.badge_label = "메딕"; m.badge_color = Color(0.9, 0.9, 0.2)
	list.append(m)

	m = MissionData.new()
	m.id = "scavenger"; m.title = "SCAVENGER"
	m.description = "3종류 이상의 무기 픽업"
	m.condition_type = MissionData.ConditionType.COLLECT_WEAPONS
	m.target_value = 3; m.badge_label = "약탈자"; m.badge_color = Color(0.7, 0.5, 0.2)
	list.append(m)

	m = MissionData.new()
	m.id = "survivor"; m.title = "SURVIVOR"
	m.description = "킬 없이 90초 이상 생존"
	m.condition_type = MissionData.ConditionType.SURVIVE_NO_KILLS
	m.target_value = 90; m.badge_label = "생존자"; m.badge_color = Color(0.3, 0.7, 0.9)
	list.append(m)

	m = MissionData.new()
	m.id = "pistol_only"; m.title = "PISTOL ONLY"
	m.description = "권총만 사용해서 1등"
	m.condition_type = MissionData.ConditionType.WIN_PISTOL_ONLY
	m.target_value = 1; m.badge_label = "권총왕"; m.badge_color = Color(0.6, 0.6, 0.9)
	list.append(m)

	m = MissionData.new()
	m.id = "knife_finish"; m.title = "KNIFE FINISH"
	m.description = "마지막 킬을 칼로 끝내고 1등"
	m.condition_type = MissionData.ConditionType.KILL_LAST_WITH_MELEE
	m.target_value = 1; m.badge_label = "칼잡이"; m.badge_color = Color(0.8, 0.3, 0.5)
	list.append(m)

	m = MissionData.new()
	m.id = "shotgun_rush"; m.title = "SHOTGUN RUSH"
	m.description = "샷건으로 3킬 이상"
	m.condition_type = MissionData.ConditionType.KILLS_WITH_WEAPON
	m.target_value = 3; m.weapon_filter = "shotgun"
	m.badge_label = "산탄"; m.badge_color = Color(0.9, 0.5, 0.1)
	list.append(m)

	m = MissionData.new()
	m.id = "railgun_moment"; m.title = "RAILGUN MOMENT"
	m.description = "레일건으로 1킬 이상"
	m.condition_type = MissionData.ConditionType.KILLS_WITH_WEAPON
	m.target_value = 1; m.weapon_filter = "railgun"
	m.badge_label = "레일"; m.badge_color = Color(0.2, 0.8, 0.9)
	list.append(m)

	m = MissionData.new()
	m.id = "bush_hunter"; m.title = "BUSH HUNTER"
	m.description = "수풀 안/근처에서 2킬 이상"
	m.condition_type = MissionData.ConditionType.KILL_IN_BUSH
	m.target_value = 2; m.badge_label = "덤불"; m.badge_color = Color(0.2, 0.6, 0.2)
	list.append(m)

	m = MissionData.new()
	m.id = "zone_walker"; m.title = "ZONE WALKER"
	m.description = "자기장 밖에서 10초 이상 버티고 1등"
	m.condition_type = MissionData.ConditionType.WIN_AFTER_ZONE_OUTSIDE
	m.target_value = 10; m.badge_label = "존워커"; m.badge_color = Color(0.8, 0.2, 0.9)
	list.append(m)

	m = MissionData.new()
	m.id = "supply_thief"; m.title = "SUPPLY THIEF"
	m.description = "보급 캡슐 근처(12m)에서 1킬 이상"
	m.condition_type = MissionData.ConditionType.KILL_NEAR_SUPPLY
	m.target_value = 1; m.badge_label = "약탈"; m.badge_color = Color(0.9, 0.8, 0.1)
	list.append(m)

	m = MissionData.new()
	m.id = "ambush"; m.title = "AMBUSH"
	m.description = "봇이 인식하기 전(awareness < 1.0)에 1킬 이상"
	m.condition_type = MissionData.ConditionType.KILL_UNDETECTED
	m.target_value = 1; m.badge_label = "매복"; m.badge_color = Color(0.15, 0.15, 0.7)
	list.append(m)

	m = MissionData.new()
	m.id = "outnumbered"; m.title = "OUTNUMBERED"
	m.description = "봇 2명 이상 감지 상태에서 1킬 이상"
	m.condition_type = MissionData.ConditionType.KILL_WHILE_DETECTED
	m.target_value = 1; m.badge_label = "다굴"; m.badge_color = Color(0.9, 0.3, 0.2)
	list.append(m)

	m = MissionData.new()
	m.id = "hell_champion"; m.title = "HELL CHAMPION"
	m.description = "지옥 난이도(3)에서 1등"
	m.condition_type = MissionData.ConditionType.WIN_ON_DIFFICULTY
	m.target_value = 3; m.badge_label = "지옥왕"; m.badge_color = Color(1.0, 0.1, 0.0)
	list.append(m)

	return list
