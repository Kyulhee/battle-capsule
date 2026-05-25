extends RefCounted
class_name MissionCatalog

const MissionDataScript = preload("res://src/core/MissionData.gd")
const MissionDescriptionFormatterScript = preload("res://src/systems/mission/MissionDescriptionFormatter.gd")
const PressureEffectCatalogScript = preload("res://src/core/PressureEffectCatalog.gd")
const PressureMissionDescriptionFormatterScript = preload("res://src/systems/mission/PressureMissionDescriptionFormatter.gd")


static func pressure_hard_pool(condition: Dictionary) -> Array:
	return _with_pressure_descriptions([
		{
			"id": "h_kill", "title": "계약 킬",
			"conditions": [{"type": condition["KILL"], "target": 1}],
			"reward":  [{"type": PressureEffectCatalogScript.AMMO_REFILL}],
			"penalty": [{"type": PressureEffectCatalogScript.AMMO_CLEAR}],
		},
		{
			"id": "h_no_heal", "title": "금욕",
			"conditions": [{"type": condition["NO_HEAL"], "target": 0}],
			"reward":  [{"type": PressureEffectCatalogScript.SHIELD_ADD, "amount": 50.0}],
			"penalty": [{"type": PressureEffectCatalogScript.HEAL_PICKUP_BAN}],
			"instant_fail_on_violation": true,
		},
		{
			"id": "h_zone_dare", "title": "존 도전자",
			"conditions": [{"type": condition["ZONE_OUTSIDE_SEC"], "target": 5}],
			"reward":  [{"type": PressureEffectCatalogScript.HP_RESTORE, "amount": 40.0}],
			"penalty": [{"type": PressureEffectCatalogScript.HP_DAMAGE, "amount": 40.0}],
		},
		{
			"id": "h_no_dmg", "title": "무결",
			"conditions": [{"type": condition["NO_DAMAGE"], "target": 0}],
			"reward":  [{"type": PressureEffectCatalogScript.SHIELD_ADD, "amount": 50.0}],
			"penalty": [{"type": PressureEffectCatalogScript.HP_DAMAGE, "amount": 30.0}],
		},
		{
			"id": "h_stealth_kill", "title": "은신 사냥",
			"conditions": [{"type": condition["KILL"], "target": 1, "modifier": "undetected"}],
			"reward":  [{"type": PressureEffectCatalogScript.AMMO_REFILL}],
			"penalty": [{"type": PressureEffectCatalogScript.ALL_BOTS_DETECT}],
		},
		{
			"id": "h_melee_kill", "title": "칼잡이",
			"conditions": [{"type": condition["KILL_MELEE"], "target": 1}],
			"reward":  [{"type": PressureEffectCatalogScript.AMMO_REFILL}],
			"penalty": [{"type": PressureEffectCatalogScript.AMMO_ACTIVE_CLEAR}],
		},
		{
			"id": "h_target_practice", "title": "표적 생존",
			"conditions": [{"type": condition["SURVIVE_DETECTED_SEC"], "target": 10}],
			"reward":  [{"type": PressureEffectCatalogScript.HEAL_ADD, "count": 1}, {"type": PressureEffectCatalogScript.SHIELD_ADD, "amount": 30.0}],
			"penalty": [{"type": PressureEffectCatalogScript.HP_DAMAGE, "amount": 20.0}],
		},
		{
			"id": "h_zone_kill", "title": "경계선",
			"conditions": [{"type": condition["KILL_WHILE_ZONE_OUTSIDE"], "target": 1}],
			"reward":  [{"type": PressureEffectCatalogScript.HP_RESTORE, "full": true}],
			"penalty": [{"type": PressureEffectCatalogScript.HP_DAMAGE, "amount": 40.0}],
		},
	], condition)


static func pressure_hell_pool(condition: Dictionary) -> Array:
	return _with_pressure_descriptions([
		{
			"id": "ha_kill2", "title": "이중 계약",
			"conditions": [{"type": condition["KILL"], "target": 2}],
			"reward":  [{"type": PressureEffectCatalogScript.RAILGUN_UNLIMITED, "stages": 1}],
			"penalty": [{"type": PressureEffectCatalogScript.AMMO_CLEAR}, {"type": PressureEffectCatalogScript.HP_DAMAGE, "amount": 20.0}],
		},
		{
			"id": "ha_no_heal_nodmg", "title": "완벽한 금욕",
			"conditions": [
				{"type": condition["NO_HEAL"], "target": 0},
				{"type": condition["NO_DAMAGE"], "target": 0},
			],
			"reward":  [{"type": PressureEffectCatalogScript.HP_RESTORE, "full": true}],
			"penalty": [{"type": PressureEffectCatalogScript.HP_DAMAGE, "amount": 50.0}],
			"instant_fail_on_violation": true,
		},
		{
			"id": "ha_zone_dare_long", "title": "지옥 존",
			"conditions": [
				{"type": condition["ZONE_OUTSIDE_SEC"], "target": 10},
				{"type": condition["KILL"], "target": 1},
			],
			"reward":  [{"type": PressureEffectCatalogScript.HP_RESTORE, "full": true}, {"type": PressureEffectCatalogScript.SHIELD_ADD, "amount": 50.0}],
			"penalty": [{"type": PressureEffectCatalogScript.HP_DAMAGE, "amount": 50.0}],
		},
		{
			"id": "hb_stealth_clean", "title": "완벽한 암살",
			"conditions": [
				{"type": condition["KILL"], "target": 1, "modifier": "undetected"},
				{"type": condition["NO_DAMAGE"], "target": 0},
			],
			"reward":  [{"type": PressureEffectCatalogScript.RAILGUN_UNLIMITED, "stages": 1}, {"type": PressureEffectCatalogScript.HEAL_ADD, "count": 2}],
			"penalty": [{"type": PressureEffectCatalogScript.ALL_BOTS_DETECT}, {"type": PressureEffectCatalogScript.HP_DAMAGE, "amount": 30.0}],
		},
		{
			"id": "hb_no_heal_2kill", "title": "금욕 학살",
			"conditions": [
				{"type": condition["NO_HEAL"], "target": 0},
				{"type": condition["KILL"], "target": 2},
			],
			"reward":  [{"type": PressureEffectCatalogScript.RAILGUN_UNLIMITED, "stages": 1}, {"type": PressureEffectCatalogScript.HEAL_ADD, "count": 3}],
			"penalty": [{"type": PressureEffectCatalogScript.HEAL_CLEAR}, {"type": PressureEffectCatalogScript.HP_DAMAGE, "amount": 30.0}],
			"instant_fail_on_violation": true,
		},
		{
			"id": "hb_melee_nodmg", "title": "무적 칼잡이",
			"conditions": [
				{"type": condition["KILL_MELEE"], "target": 1},
				{"type": condition["NO_DAMAGE"], "target": 0},
			],
			"reward":  [{"type": PressureEffectCatalogScript.HP_RESTORE, "full": true}, {"type": PressureEffectCatalogScript.SHIELD_ADD, "amount": 50.0}],
			"penalty": [{"type": PressureEffectCatalogScript.HP_DAMAGE, "amount": 40.0}],
		},
		{
			"id": "hc_blood_pact", "title": "피의 계약",
			"conditions": [{"type": condition["KILL_LOW_HP"], "target": 1}],
			"reward":  [{"type": PressureEffectCatalogScript.RAILGUN_UNLIMITED, "stages": 1}, {"type": PressureEffectCatalogScript.HP_RESTORE, "full": true}],
			"penalty": [{"type": PressureEffectCatalogScript.HP_DAMAGE, "fraction": 0.5}],
		},
		{
			"id": "hc_berserker", "title": "광전사",
			"conditions": [{"type": condition["KILL"], "target": 1, "modifier": "heavily_detected"}],
			"reward":  [{"type": PressureEffectCatalogScript.RAILGUN_UNLIMITED, "stages": 1}, {"type": PressureEffectCatalogScript.HP_RESTORE, "full": true}],
			"penalty": [{"type": PressureEffectCatalogScript.HP_DAMAGE, "amount": 50.0}],
		},
		{
			"id": "hc_zone_massacre", "title": "존 바깥의 학살",
			"conditions": [{"type": condition["KILL_WHILE_ZONE_OUTSIDE"], "target": 2}],
			"reward":  [{"type": PressureEffectCatalogScript.HP_RESTORE, "full": true}, {"type": PressureEffectCatalogScript.SHIELD_ADD, "amount": 50.0}, {"type": PressureEffectCatalogScript.HEAL_ADD, "count": 1}],
			"penalty": [{"type": PressureEffectCatalogScript.HP_DAMAGE, "amount": 50.0}],
		},
	], condition)


static func _with_pressure_descriptions(descriptors: Array, condition: Dictionary) -> Array:
	for descriptor in descriptors:
		descriptor["description"] = PressureMissionDescriptionFormatterScript.description(
			descriptor.get("conditions", []),
			condition
		)
	return descriptors


static func bonus_missions() -> Array:
	var list: Array = []
	var m

	m = MissionDataScript.new()
	m.id = "first_blood"; m.title = "FIRST BLOOD"
	m.condition_type = MissionDataScript.ConditionType.FIRST_KILL
	m.target_value = 1; m.badge_label = "첫 피"; m.badge_color = Color(0.85, 0.15, 0.15)
	_append_bonus(list, m)

	m = MissionDataScript.new()
	m.id = "clean_win"; m.title = "CLEAN WIN"
	m.condition_type = MissionDataScript.ConditionType.WIN_HIGH_HP
	m.target_value = 50; m.badge_label = "무결"; m.badge_color = Color(0.2, 0.9, 0.3)
	_append_bonus(list, m)

	m = MissionDataScript.new()
	m.id = "medic_run"; m.title = "MEDIC RUN"
	m.condition_type = MissionDataScript.ConditionType.WIN_WITH_HEALS
	m.target_value = 3; m.badge_label = "메딕"; m.badge_color = Color(0.9, 0.9, 0.2)
	_append_bonus(list, m)

	m = MissionDataScript.new()
	m.id = "scavenger"; m.title = "SCAVENGER"
	m.condition_type = MissionDataScript.ConditionType.KILL_WITH_ALL_WEAPONS
	m.score_bonus = 1000; m.badge_label = "약탈자"; m.badge_color = Color(0.7, 0.5, 0.2)
	_append_bonus(list, m)

	m = MissionDataScript.new()
	m.id = "survivor"; m.title = "SURVIVOR"
	m.condition_type = MissionDataScript.ConditionType.SURVIVE_NO_KILLS
	m.target_value = 90; m.badge_label = "생존자"; m.badge_color = Color(0.3, 0.7, 0.9)
	_append_bonus(list, m)

	m = MissionDataScript.new()
	m.id = "pistol_only"; m.title = "PISTOL ONLY"
	m.condition_type = MissionDataScript.ConditionType.WIN_PISTOL_ONLY
	m.target_value = 1; m.badge_label = "권총왕"; m.badge_color = Color(0.6, 0.6, 0.9)
	_append_bonus(list, m)

	m = MissionDataScript.new()
	m.id = "knife_finish"; m.title = "KNIFE FINISH"
	m.condition_type = MissionDataScript.ConditionType.KILL_LAST_WITH_MELEE
	m.target_value = 1; m.badge_label = "칼잡이"; m.badge_color = Color(0.8, 0.3, 0.5)
	_append_bonus(list, m)

	m = MissionDataScript.new()
	m.id = "shotgun_rush"; m.title = "SHOTGUN RUSH"
	m.condition_type = MissionDataScript.ConditionType.KILLS_WITH_WEAPON
	m.target_value = 3; m.weapon_filter = "shotgun"
	m.badge_label = "산탄"; m.badge_color = Color(0.9, 0.5, 0.1)
	_append_bonus(list, m)

	m = MissionDataScript.new()
	m.id = "railgun_moment"; m.title = "RAILGUN MOMENT"
	m.condition_type = MissionDataScript.ConditionType.KILLS_WITH_WEAPON
	m.target_value = 1; m.weapon_filter = "railgun"
	m.badge_label = "레일"; m.badge_color = Color(0.2, 0.8, 0.9)
	_append_bonus(list, m)

	m = MissionDataScript.new()
	m.id = "bush_hunter"; m.title = "BUSH HUNTER"
	m.condition_type = MissionDataScript.ConditionType.KILL_IN_BUSH
	m.target_value = 2; m.badge_label = "덤불"; m.badge_color = Color(0.2, 0.6, 0.2)
	_append_bonus(list, m)

	m = MissionDataScript.new()
	m.id = "zone_walker"; m.title = "ZONE WALKER"
	m.condition_type = MissionDataScript.ConditionType.WIN_AFTER_ZONE_OUTSIDE
	m.target_value = 10; m.badge_label = "존워커"; m.badge_color = Color(0.8, 0.2, 0.9)
	_append_bonus(list, m)

	m = MissionDataScript.new()
	m.id = "supply_thief"; m.title = "SUPPLY THIEF"
	m.condition_type = MissionDataScript.ConditionType.KILL_NEAR_SUPPLY
	m.target_value = 1; m.badge_label = "약탈"; m.badge_color = Color(0.9, 0.8, 0.1)
	_append_bonus(list, m)

	m = MissionDataScript.new()
	m.id = "ambush"; m.title = "AMBUSH"
	m.condition_type = MissionDataScript.ConditionType.KILL_UNDETECTED
	m.target_value = 1; m.badge_label = "매복"; m.badge_color = Color(0.15, 0.15, 0.7)
	_append_bonus(list, m)

	m = MissionDataScript.new()
	m.id = "outnumbered"; m.title = "OUTNUMBERED"
	m.condition_type = MissionDataScript.ConditionType.KILL_WHILE_DETECTED
	m.target_value = 1; m.badge_label = "다굴"; m.badge_color = Color(0.9, 0.3, 0.2)
	_append_bonus(list, m)

	m = MissionDataScript.new()
	m.id = "one_slot_run"; m.title = "ONE SLOT RUN"
	m.condition_type = MissionDataScript.ConditionType.WIN_ONE_SLOT
	m.target_value = 1; m.score_bonus = 800; m.badge_label = "미니멀"; m.badge_color = Color(0.85, 0.85, 0.85)
	_append_bonus(list, m)

	return list


static func _append_bonus(list: Array, mission) -> void:
	mission.description = MissionDescriptionFormatterScript.bonus_description(mission)
	list.append(mission)
