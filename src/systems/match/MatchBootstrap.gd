class_name MatchBootstrap
extends RefCounted

static func create_zone(
	zone_script,
	wait_time: float,
	shrink_time: float,
	damage_per_second: float,
	initial_timer: float,
	stage_configs: Dictionary,
	on_stage_advanced: Callable,
	on_zone_warning: Callable
):
	var zone = zone_script.new()
	zone.wait_time = wait_time
	zone.shrink_time = shrink_time
	zone.damage_per_second = damage_per_second
	if zone.has_method("configure_stage_configs"):
		zone.configure_stage_configs(stage_configs)
	zone.timer = initial_timer
	zone.generate_next()
	if on_stage_advanced.is_valid():
		zone.stage_advanced.connect(on_stage_advanced)
	if on_zone_warning.is_valid():
		zone.zone_warning.connect(on_zone_warning)
	return zone

static func create_mission_tracker(
	mission_tracker_script,
	pending_artifact: Dictionary,
	is_bonus_mission_feasible: Callable
):
	var tracker = mission_tracker_script.new()
	var pool = mission_tracker_script.get_all_missions()
	var artifact_mods = pending_artifact.get("mods", {})
	var filtered_pool = []
	for mission in pool:
		if not is_bonus_mission_feasible.is_valid() or is_bonus_mission_feasible.call(mission, artifact_mods):
			filtered_pool.append(mission)
	if filtered_pool.is_empty():
		filtered_pool = pool
	if not filtered_pool.is_empty():
		tracker.active_mission = filtered_pool[randi() % filtered_pool.size()]
	return tracker

static func initial_pressure_state(
	difficulty_index: int,
	hard_opt_in: bool,
	hard_index: int,
	hell_index: int
) -> Dictionary:
	return {
		"heal_pickup_banned": false,
		"heal_ban_until_stage": -1,
		"railgun_unlimited_until_stage": -1,
		"pressure_missions_enabled": difficulty_index == hell_index or (
			difficulty_index == hard_index and hard_opt_in
		),
	}

static func pick_hell_modifier(min_modifier: int, max_modifier: int) -> int:
	var rng = RandomNumberGenerator.new()
	rng.seed = Time.get_ticks_usec() ^ (Time.get_ticks_msec() << 16)
	return rng.randi_range(min_modifier, max_modifier)
