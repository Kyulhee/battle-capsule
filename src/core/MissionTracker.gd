extends RefCounted
class_name MissionTracker

const MissionData = preload("res://src/core/MissionData.gd")
const MissionCatalogScript = preload("res://src/systems/mission/MissionCatalog.gd")
const MissionHudFormatterScript = preload("res://src/systems/mission/MissionHudFormatter.gd")
const ACHIEVEMENTS_PATH = "user://achievements.json"

# ── 보너스 미션 (기존 유지) ─────────────────────────────────────────────────
var active_mission = null  # MissionData

var _used_non_pistol: bool = false
var _last_kill_weapon: String = ""
var _kills_in_bush: int = 0
var _kills_near_supply: int = 0
var _kills_undetected: int = 0
var _kills_while_detected: int = 0
var _player_max_outside_sec: float = 0.0
var _player_current_outside_sec: float = 0.0
var _medkits_used: int = 0
var _max_gun_slots_used: int = 0  # peak simultaneous gun slots (1-4) held at once

# ── 압박 미션 조건 타입 ────────────────────────────────────────────────────
enum PressureCondition {
	KILL,               # 킬 N회
	NO_DAMAGE,          # 피해 0 (존 피해 포함)
	NO_HEAL,            # 힐 사용 금지 (위반 시 즉시 실패)
	ZONE_OUTSIDE_SEC,   # 자기장 밖 N초 체류
	KILL_MELEE,         # 칼로 킬 N회
	SURVIVE_DETECTED_SEC, # 봇 2마리+ 감지 상태에서 N초 생존
	KILL_WHILE_ZONE_OUTSIDE, # 자기장 밖에서 킬 N회
	KILL_LOW_HP,        # 플레이어 HP 30% 이하에서 킬 N회
}

# 압박 미션 리워드/패널티 타입과 표시 문구는 PressureEffectCatalog.gd가 소유한다.
# 미션/압박 디스크립터 목록은 MissionCatalog.gd가 소유한다.

static func _pressure_condition_ids() -> Dictionary:
	return {
		"KILL": PressureCondition.KILL,
		"NO_DAMAGE": PressureCondition.NO_DAMAGE,
		"NO_HEAL": PressureCondition.NO_HEAL,
		"ZONE_OUTSIDE_SEC": PressureCondition.ZONE_OUTSIDE_SEC,
		"KILL_MELEE": PressureCondition.KILL_MELEE,
		"SURVIVE_DETECTED_SEC": PressureCondition.SURVIVE_DETECTED_SEC,
		"KILL_WHILE_ZONE_OUTSIDE": PressureCondition.KILL_WHILE_ZONE_OUTSIDE,
		"KILL_LOW_HP": PressureCondition.KILL_LOW_HP,
	}

static func get_hard_pool() -> Array:
	return MissionCatalogScript.pressure_hard_pool(_pressure_condition_ids())

static func get_hell_pool() -> Array:
	return MissionCatalogScript.pressure_hell_pool(_pressure_condition_ids())

# ── 압박 미션 필터링 ────────────────────────────────────────────────────────
static func filter_feasible(pool: Array, zone_stage: int, bot_alive: int) -> Array:
	return pool.filter(func(d): return _is_descriptor_feasible(d, zone_stage, bot_alive))

static func _is_descriptor_feasible(descriptor: Dictionary, zone_stage: int, bot_alive: int) -> bool:
	for cond in descriptor.get("conditions", []):
		var target: int = int(cond.get("target", 1))
		match int(cond["type"]):
			PressureCondition.KILL, \
			PressureCondition.KILL_MELEE, \
			PressureCondition.KILL_WHILE_ZONE_OUTSIDE, \
			PressureCondition.KILL_LOW_HP:
				if bot_alive < target: return false
			PressureCondition.SURVIVE_DETECTED_SEC:
				if bot_alive < 2: return false
			PressureCondition.ZONE_OUTSIDE_SEC:
				if zone_stage >= 3 and target >= 10: return false
	return true

# ── 압박 미션 상태 ─────────────────────────────────────────────────────────
var pressure_active: bool = false
var _active_pressure: Dictionary = {}
var pressure_deadline: float = 0.0
var pressure_failed_instant: bool = false  # NO_HEAL 위반 즉시 실패 플래그

# 창 내 추적 카운터
var _p_kills_total: int = 0
var _p_kills_undetected: int = 0
var _p_kills_melee: int = 0
var _p_kills_outside_zone: int = 0
var _p_kills_low_hp: int = 0
var _p_kills_heavily_detected: int = 0  # 봇 3마리+ 감지 상태
var _p_damage_taken: float = 0.0
var _p_left_zone: bool = false
var _p_outside_zone_sec: float = 0.0
var _p_heals_violated: bool = false
var _p_detected_sec: float = 0.0  # 봇 2마리+ 감지 상태 누적 시간

func reset():
	_used_non_pistol = false
	_last_kill_weapon = ""
	_kills_in_bush = 0
	_kills_near_supply = 0
	_kills_undetected = 0
	_kills_while_detected = 0
	_player_max_outside_sec = 0.0
	_player_current_outside_sec = 0.0
	_medkits_used = 0
	pressure_active = false
	_active_pressure = {}
	pressure_deadline = 0.0
	pressure_failed_instant = false
	_reset_pressure_counters()

func _reset_pressure_counters():
	_p_kills_total = 0
	_p_kills_undetected = 0
	_p_kills_melee = 0
	_p_kills_outside_zone = 0
	_p_kills_low_hp = 0
	_p_kills_heavily_detected = 0
	_p_damage_taken = 0.0
	_p_left_zone = false
	_p_outside_zone_sec = 0.0
	_p_heals_violated = false
	_p_detected_sec = 0.0

# ── 압박 미션 제어 ─────────────────────────────────────────────────────────
func start_pressure(descriptor: Dictionary, duration: float):
	_active_pressure = descriptor
	pressure_deadline = duration
	pressure_active = true
	pressure_failed_instant = false
	_reset_pressure_counters()

func tick_pressure(delta: float, num_detecting_player: int) -> String:
	if not pressure_active:
		return ""

	# 감지 누적 (봇 2마리+ → detected_sec)
	if num_detecting_player >= 2:
		_p_detected_sec += delta

	# 즉시 실패 체크 (NO_HEAL 위반)
	if pressure_failed_instant:
		pressure_active = false
		return "fail"

	pressure_deadline -= delta
	if pressure_deadline <= 0.0:
		pressure_active = false
		return "success" if _evaluate_pressure_conditions() else "fail"

	return ""

func _evaluate_pressure_conditions() -> bool:
	for cond in _active_pressure.get("conditions", []):
		if not _eval_single_condition(cond):
			return false
	return true

func _eval_single_condition(cond: Dictionary) -> bool:
	var target: int = int(cond.get("target", 1))
	var modifier: String = cond.get("modifier", "")
	match int(cond["type"]):
		PressureCondition.KILL:
			match modifier:
				"undetected":        return _p_kills_undetected >= target
				"heavily_detected":  return _p_kills_heavily_detected >= target
				_:                   return _p_kills_total >= target
		PressureCondition.NO_DAMAGE:
			return _p_damage_taken == 0.0
		PressureCondition.NO_HEAL:
			return not _p_heals_violated
		PressureCondition.ZONE_OUTSIDE_SEC:
			return _p_outside_zone_sec >= float(target)
		PressureCondition.KILL_MELEE:
			return _p_kills_melee >= target
		PressureCondition.SURVIVE_DETECTED_SEC:
			return _p_detected_sec >= float(target)
		PressureCondition.KILL_WHILE_ZONE_OUTSIDE:
			return _p_kills_outside_zone >= target
		PressureCondition.KILL_LOW_HP:
			return _p_kills_low_hp >= target
	return false

# ── 압박 미션 훅 ──────────────────────────────────────────────────────────
func on_pressure_kill(weapon: String, undetected: bool, outside_zone: bool, player_hp_ratio: float, num_detecting: int):
	if not pressure_active: return
	_p_kills_total += 1
	if undetected:
		_p_kills_undetected += 1
	if weapon == "knife":
		_p_kills_melee += 1
	if outside_zone:
		_p_kills_outside_zone += 1
	if player_hp_ratio <= 0.3:
		_p_kills_low_hp += 1
	if num_detecting >= 3:
		_p_kills_heavily_detected += 1

func on_pressure_damage(amount: float):
	if not pressure_active: return
	_p_damage_taken += amount

func on_pressure_heal_used():
	if not pressure_active: return
	# 위반 시 즉시 실패 대상 여부 체크
	_p_heals_violated = true
	if _active_pressure.get("instant_fail_on_violation", false):
		pressure_failed_instant = true

func on_pressure_zone_tick(is_outside: bool, delta: float):
	if not pressure_active: return
	if is_outside:
		_p_outside_zone_sec += delta
		_p_left_zone = true

# ── HUD 텍스트 ─────────────────────────────────────────────────────────────
func get_pressure_hud_text() -> String:
	if not pressure_active or _active_pressure.is_empty():
		return ""
	return MissionHudFormatterScript.pressure_hud_text(
		_active_pressure,
		pressure_deadline,
		_pressure_counter_snapshot(),
		_pressure_condition_ids()
	)

func _pressure_counter_snapshot() -> Dictionary:
	return {
		"kills_total": _p_kills_total,
		"kills_undetected": _p_kills_undetected,
		"kills_melee": _p_kills_melee,
		"kills_outside_zone": _p_kills_outside_zone,
		"kills_low_hp": _p_kills_low_hp,
		"kills_heavily_detected": _p_kills_heavily_detected,
		"damage_taken": _p_damage_taken,
		"outside_zone_sec": _p_outside_zone_sec,
		"heals_violated": _p_heals_violated,
		"detected_sec": _p_detected_sec,
	}

# ── 보너스 미션 훅 (기존 유지) ────────────────────────────────────────────
func on_player_medkit_used():
	_medkits_used += 1

func on_weapon_slot_used(gun_slot_count: int):
	if gun_slot_count > _max_gun_slots_used:
		_max_gun_slots_used = gun_slot_count

func on_player_fire(weapon_type: String):
	if weapon_type != "pistol":
		_used_non_pistol = true

func on_player_kill(ctx: Dictionary):
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
	var kills: int = tel.metrics.session.kills if tel else 0

	match m.condition_type:
		MissionData.ConditionType.FIRST_KILL:
			return kills >= 1
		MissionData.ConditionType.WIN_HIGH_HP:
			return won and player_hp >= m.target_value
		MissionData.ConditionType.WIN_WITH_HEALS:
			return won and _medkits_used >= int(m.target_value)
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
		MissionData.ConditionType.KILL_WITH_ALL_WEAPONS:
			if not tel: return false
			var wk: Dictionary = tel.metrics.combat.kills_by_weapon
			return wk.get("pistol", 0) >= 1 and wk.get("ar", 0) >= 1 \
				and wk.get("shotgun", 0) >= 1 and wk.get("railgun", 0) >= 1
		MissionData.ConditionType.WIN_ONE_SLOT:
			return won and _max_gun_slots_used <= 1
	return false

func get_hud_text(tel: Node) -> String:
	if active_mission == null:
		return ""
	var m = active_mission
	var kills: int = tel.metrics.session.kills if tel else 0

	match m.condition_type:
		MissionData.ConditionType.FIRST_KILL:
			return "%s\n킬 횟수  %d / 1" % [m.title, kills]
		MissionData.ConditionType.WIN_HIGH_HP:
			var cur_hp: float = 0.0
			if tel:
				var main_node = tel.get_node_or_null("/root/Main")
				if main_node and is_instance_valid(main_node.player_ref):
					cur_hp = main_node.player_ref.current_health
			return "%s\n현재 HP %.0f — 우승 시 HP %.0f 이상 필요" % [m.title, cur_hp, m.target_value]
		MissionData.ConditionType.WIN_WITH_HEALS:
			return "%s\n구급상자(◆) 사용  %d / %d" % [m.title, _medkits_used, int(m.target_value)]
		MissionData.ConditionType.SURVIVE_NO_KILLS:
			if kills >= 1:
				return "%s\n✗ 킬 발생 — 실패 확정" % m.title
			return "%s\n킬 없이 90초 생존 — 현재 킬 0회" % m.title
		MissionData.ConditionType.WIN_PISTOL_ONLY:
			if _used_non_pistol:
				return "%s\n✗ 다른 무기 사용됨 — 실패 확정" % m.title
			return "%s\n권총만 사용 중 ✓" % m.title
		MissionData.ConditionType.KILL_LAST_WITH_MELEE:
			var wnames = {"knife": "칼 ✓", "pistol": "피스톨", "ar": "돌격소총", "shotgun": "샷건", "railgun": "레일건"}
			if _last_kill_weapon == "":
				return "%s\n칼로 마지막 킬 달성 — 아직 킬 없음" % m.title
			return "%s\n칼로 마지막 킬 달성 — 현재 %s" % [m.title, wnames.get(_last_kill_weapon, _last_kill_weapon)]
		MissionData.ConditionType.KILLS_WITH_WEAPON:
			var wkills: int = tel.metrics.combat.kills_by_weapon.get(m.weapon_filter, 0) if tel else 0
			var wnames2 = {"pistol": "피스톨", "ar": "돌격소총", "shotgun": "샷건", "railgun": "레일건", "knife": "칼"}
			return "%s\n%s 킬  %d / %d" % [m.title, wnames2.get(m.weapon_filter, m.weapon_filter), wkills, int(m.target_value)]
		MissionData.ConditionType.KILL_IN_BUSH:
			return "%s\n수풀 안/근처 킬  %d / %d" % [m.title, _kills_in_bush, int(m.target_value)]
		MissionData.ConditionType.WIN_AFTER_ZONE_OUTSIDE:
			return "%s\n자기장 밖 최장 체류  %.0f초 / %.0f초" % [m.title, _player_max_outside_sec, m.target_value]
		MissionData.ConditionType.KILL_NEAR_SUPPLY:
			return "%s\n보급 캡슐 근처(12m) 킬  %d / %d" % [m.title, _kills_near_supply, int(m.target_value)]
		MissionData.ConditionType.KILL_UNDETECTED:
			return "%s\n봇 미탐지 상태에서 킬  %d / %d" % [m.title, _kills_undetected, int(m.target_value)]
		MissionData.ConditionType.KILL_WHILE_DETECTED:
			return "%s\n봇 2명 이상 감지 상태에서 킬  %d / %d" % [m.title, _kills_while_detected, int(m.target_value)]
		MissionData.ConditionType.WIN_ON_DIFFICULTY:
			var diff_names = ["쉬움", "보통", "어려움", "지옥"]
			return "%s\n%s 난이도로 1등 달성 필요" % [m.title, diff_names[int(m.target_value)] if int(m.target_value) < diff_names.size() else "?"]
		MissionData.ConditionType.KILL_WITH_ALL_WEAPONS:
			if not tel:
				return "%s\n모든 총으로 각각 1킬 이상 달성" % m.title
			var wk: Dictionary = tel.metrics.combat.kills_by_weapon
			var gun_labels = [["pistol", "피스톨"], ["ar", "돌격소총"], ["shotgun", "샷건"], ["railgun", "레일건"]]
			var done: Array = []
			var todo: Array = []
			for g in gun_labels:
				if wk.get(g[0], 0) >= 1: done.append(g[1])
				else: todo.append(g[1])
			var status = ""
			if done.size() > 0: status += "✓ " + "  ".join(done)
			if todo.size() > 0:
				if status != "": status += "   /   "
				status += "✗ " + "  ".join(todo)
			return "%s\n%s" % [m.title, status]
		MissionData.ConditionType.WIN_ONE_SLOT:
			if _max_gun_slots_used > 1:
				return "%s\n✗ 총기 2종 이상 소지 — 실패 확정" % m.title
			return "%s\n총기 슬롯 %d/1 사용 중 ✓" % [m.title, _max_gun_slots_used]
	return m.title

func get_early_fail_status(tel: Node) -> bool:
	if not active_mission: return false
	match active_mission.condition_type:
		MissionData.ConditionType.WIN_PISTOL_ONLY:
			return _used_non_pistol
		MissionData.ConditionType.SURVIVE_NO_KILLS:
			return tel != null and tel.metrics.session.kills >= 1
		MissionData.ConditionType.WIN_ONE_SLOT:
			return _max_gun_slots_used > 1
	return false

# ── 배지 저장 ─────────────────────────────────────────────────────────────
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

# ── 보너스 미션 목록 ─────────────────────────────────────────────────────
static func get_all_missions() -> Array:
	return MissionCatalogScript.bonus_missions()
