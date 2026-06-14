extends SceneTree


func _init():
	call_deferred("_run")


func _run() -> void:
	if not _verify_pacing_schema_and_hooks():
		quit(1)
		return
	if not _verify_pacing_uses_game_seconds():
		quit(1)
		return

	print("Pacing telemetry smoke passed.")
	quit(0)


func _verify_pacing_schema_and_hooks() -> bool:
	var telemetry_script = load("res://src/core/Telemetry.gd")
	var tel = telemetry_script.new()
	root.add_child(tel)
	tel.start_match()

	if not tel.metrics.has("pacing"):
		tel.free()
		return _fail("Telemetry did not create pacing metrics.")
	if not tel.enabled_groups.get("pacing", false):
		tel.free()
		return _fail("Pacing group should be enabled by default.")
	if not tel.metrics.pacing.stage_times.has("1"):
		tel.free()
		return _fail("Pacing should record stage 1 at match start.")

	tel.log_shot()
	tel.log_doctrine_target_acquisition(
		"AGGRESSIVE",
		"idle_reaction",
		"IDLE",
		{
			"poi_role": "open",
			"nearest_poi_role": "transit_choke",
			"nearest_poi_edge_distance": 9.0,
			"route_role": "off_route",
			"nearest_route_role": "primary_choke",
			"nearest_route_edge_distance": 3.5,
		},
		18.5
	)
	tel.log_doctrine_objective_enemy_interrupt(
		"AGGRESSIVE",
		"idle_loot",
		"loot",
		"pickup_weapon",
		{
			"poi_role": "loot_hub",
			"nearest_poi_role": "loot_hub",
			"nearest_poi_edge_distance": 0.0,
			"route_role": "primary_choke",
			"nearest_route_role": "primary_choke",
			"nearest_route_edge_distance": 0.0,
		},
		6.0,
		{
			"poi_role": "open",
			"nearest_poi_role": "transit_choke",
			"nearest_poi_edge_distance": 4.0,
			"route_role": "off_route",
			"nearest_route_role": "flank",
			"nearest_route_edge_distance": 7.0,
		},
		14.0,
		{
			"need": "opportunity",
			"target_match": "weapon_new_type",
			"target_detail": "weapon_ar",
		}
	)
	tel.log_combat_location("damage", 12.0, {
		"poi_role": "transit_choke",
		"route_role": "primary_choke",
		"route_id": "sluice_direct_crossing",
	})
	tel.log_combat_location("kill", 0.0, {
		"poi_role": "transit_choke",
		"route_role": "primary_choke",
		"route_id": "sluice_direct_crossing",
	})
	tel.log_pickup("shotgun", "weapon", false)
	tel.set_stage(2)
	tel.log_doctrine_chase_location(
		"AGGRESSIVE",
		"combat",
		{
			"poi_role": "open",
			"route_role": "primary_choke",
			"route_id": "sluice_direct_crossing",
		},
		{
			"poi_role": "transit_choke",
			"route_role": "primary_choke",
			"route_id": "ridge_to_clinic_choke",
		},
		"entity",
		1.5
	)
	tel.log_stuck_context("CHASE", {
		"poi_role": "transit_choke",
		"route_role": "primary_choke",
		"route_id": "ridge_to_clinic_choke",
		"cell": "-20,20",
	}, true)

	var pacing: Dictionary = tel.metrics.pacing
	if float(pacing.first_shot_time) < 0.0:
		tel.free()
		return _fail("Pacing did not record first shot time.")
	if float(pacing.first_target_acquisition_time) < 0.0:
		tel.free()
		return _fail("Pacing did not record first target acquisition time.")
	if String(pacing.first_target_acquisition_source) != "idle_reaction":
		tel.free()
		return _fail("Pacing did not record first target acquisition source.")
	if String(pacing.first_target_acquisition_state) != "IDLE":
		tel.free()
		return _fail("Pacing did not record first target acquisition state.")
	if absf(float(pacing.first_target_acquisition_distance) - 18.5) > 0.001:
		tel.free()
		return _fail("Pacing did not record first target acquisition distance.")
	if String(pacing.first_target_acquisition_poi_band) != "far_8m_plus":
		tel.free()
		return _fail("Pacing did not record first target acquisition POI band.")
	if String(pacing.first_target_acquisition_route_band) != "near_0_4m":
		tel.free()
		return _fail("Pacing did not record first target acquisition route band.")
	if String(pacing.first_target_acquisition_nearest_route_role) != "primary_choke":
		tel.free()
		return _fail("Pacing did not record first target acquisition nearest route role.")
	if float(pacing.first_objective_interrupt_time) < 0.0:
		tel.free()
		return _fail("Pacing did not record first objective interrupt time.")
	if String(pacing.first_objective_interrupt_source) != "idle_loot":
		tel.free()
		return _fail("Pacing did not record first objective interrupt source.")
	if String(pacing.first_objective_interrupt_kind) != "pickup_weapon":
		tel.free()
		return _fail("Pacing did not record first objective interrupt kind.")
	if String(pacing.first_objective_interrupt_need) != "opportunity":
		tel.free()
		return _fail("Pacing did not record first objective interrupt need.")
	if String(pacing.first_objective_interrupt_target_match) != "weapon_new_type":
		tel.free()
		return _fail("Pacing did not record first objective interrupt target match.")
	if absf(float(pacing.first_objective_interrupt_enemy_distance) - 14.0) > 0.001:
		tel.free()
		return _fail("Pacing did not record first objective interrupt enemy distance.")
	if absf(float(pacing.first_objective_interrupt_objective_distance) - 6.0) > 0.001:
		tel.free()
		return _fail("Pacing did not record first objective interrupt objective distance.")
	if float(pacing.first_contact_time) < 0.0 or float(pacing.first_damage_time) < 0.0:
		tel.free()
		return _fail("Pacing did not record first contact/damage time.")
	if float(pacing.first_kill_time) < 0.0:
		tel.free()
		return _fail("Pacing did not record first kill time.")
	if String(pacing.first_non_pistol_upgrade_weapon) != "shotgun":
		tel.free()
		return _fail("Pacing did not mirror first non-pistol upgrade.")
	if not pacing.stage_times.has("2"):
		tel.free()
		return _fail("Pacing did not record stage 2 timing.")
	if not tel.metrics.doctrine.chase_target_route_role_by_context.has("combat"):
		tel.free()
		return _fail("Doctrine route dwell should remain available for pacing analyzer output.")
	if int(tel.metrics.tactics.stuck_by_state.get("CHASE", 0)) != 1:
		tel.free()
		return _fail("Stuck context did not record the bot state.")
	if int(tel.metrics.tactics.stuck_by_route_id.get("ridge_to_clinic_choke", 0)) != 1:
		tel.free()
		return _fail("Stuck context did not record the route id.")
	if int(tel.metrics.tactics.stuck_threat_by_route_id.get("ridge_to_clinic_choke", 0)) != 1:
		tel.free()
		return _fail("Stuck context did not record threatened route ids.")
	if int(tel.metrics.tactics.stuck_by_cell.get("-20,20", 0)) != 1:
		tel.free()
		return _fail("Stuck context did not record coarse position cells.")

	tel.free()
	return true


func _verify_pacing_uses_game_seconds() -> bool:
	var previous_scale := Engine.time_scale
	var telemetry_script = load("res://src/core/Telemetry.gd")
	var tel = telemetry_script.new()
	root.add_child(tel)
	Engine.time_scale = 3.0
	tel.start_match()
	tel._start_tick = Time.get_ticks_msec() - 1000
	tel.log_shot()
	tel.set_stage(2)

	var first_shot := float(tel.metrics.pacing.first_shot_time)
	var stage2 := float(tel.metrics.pacing.stage_times.get("2", 0.0))
	tel.free()
	Engine.time_scale = previous_scale

	if first_shot < 2.5:
		return _fail("Pacing first-shot time should use game seconds, got %.2f." % first_shot)
	if stage2 < 2.5:
		return _fail("Pacing stage time should use game seconds, got %.2f." % stage2)
	return true


func _fail(message: String) -> bool:
	push_error(message)
	return false
