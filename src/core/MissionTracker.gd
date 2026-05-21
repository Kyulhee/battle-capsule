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
	return MissionHudFormatterScript.bonus_hud_text(active_mission, _bonus_hud_context(tel))

func _bonus_hud_context(tel: Node) -> Dictionary:
	var kills: int = tel.metrics.session.kills if tel else 0
	var current_hp: float = 0.0
	var kills_by_weapon: Dictionary = {}
	if tel:
		kills_by_weapon = tel.metrics.combat.kills_by_weapon
		var main_node = tel.get_node_or_null("/root/Main")
		if main_node and is_instance_valid(main_node.player_ref):
			current_hp = main_node.player_ref.current_health

	return {
		"has_telemetry": tel != null,
		"kills": kills,
		"current_hp": current_hp,
		"kills_by_weapon": kills_by_weapon,
		"medkits_used": _medkits_used,
		"used_non_pistol": _used_non_pistol,
		"last_kill_weapon": _last_kill_weapon,
		"kills_in_bush": _kills_in_bush,
		"kills_near_supply": _kills_near_supply,
		"kills_undetected": _kills_undetected,
		"kills_while_detected": _kills_while_detected,
		"player_max_outside_sec": _player_max_outside_sec,
		"max_gun_slots_used": _max_gun_slots_used,
	}

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
