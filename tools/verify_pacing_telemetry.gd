extends SceneTree


class FakeMain:
	extends Node
	var match_timer: float = 0.0


func _init():
	call_deferred("_run")


func _run() -> void:
	if not _verify_pacing_schema_and_hooks():
		quit(1)
		return
	if not _verify_pacing_uses_game_seconds():
		quit(1)
		return
	if not await _verify_entity_death_hook_exact_once():
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
	if not tel.metrics.pacing.has("alive_timeline"):
		tel.free()
		return _fail("Pacing should expose an alive timeline.")
	if not tel.metrics.pacing.alive_timeline.is_empty():
		tel.free()
		return _fail("Main should own the authoritative initial alive sample.")
	if not tel.metrics.pacing.has("kill_context_events"):
		tel.free()
		return _fail("Pacing should expose bounded kill context events.")
	var kill_recorded: bool = tel.log_kill_context(
		"Melee",
		"Knife",
		1.234,
		{
			"kind": "Bot",
			"state": "RECOVER",
			"weapon": "Shotgun",
			"mag": 0,
			"reserve": 0,
			"poi_role": "loot_hub",
			"route_role": "primary_choke",
		},
		{
			"kind": "Bot",
			"state": "ATTACK",
			"weapon": "Pistol",
			"mag": 0,
			"reserve": 0,
			"attack_origin": "recover_melee",
			"acquisition_source": "recover_melee",
			"target_match": true,
			"opponent_recent_attacker": false,
			"opponent_pressuring": false,
			"spawn_age": 31.257,
			"zone_ratio": 0.42,
			"zone_status": "inside",
			"poi_role": "loot_hub",
			"route_role": "primary_choke",
		}
	)
	if not kill_recorded or tel.metrics.pacing.kill_context_events.size() != 1:
		tel.free()
		return _fail("Kill context event was not recorded exactly once.")
	var kill_event: Dictionary = tel.metrics.pacing.kill_context_events[0]
	var victim_context: Dictionary = kill_event.get("victim", {})
	var attacker_context: Dictionary = kill_event.get("attacker", {})
	if (
		String(kill_event.get("cause", "")) != "melee"
		or String(kill_event.get("weapon", "")) != "knife"
		or not is_equal_approx(float(kill_event.get("distance", -1.0)), 1.23)
	):
		tel.free()
		return _fail("Kill context should normalize cause, weapon, and distance.")
	if String(victim_context.get("state", "")) != "recover" \
			or String(victim_context.get("weapon", "")) != "shotgun":
		tel.free()
		return _fail("Kill context should preserve normalized victim state and weapon.")
	if (
		String(attacker_context.get("attack_origin", "")) != "recover_melee"
		or String(attacker_context.get("acquisition_source", "")) != "recover_melee"
		or not bool(attacker_context.get("target_match", false))
		or not is_equal_approx(float(attacker_context.get("spawn_age", -1.0)), 31.26)
	):
		tel.free()
		return _fail("Kill context should preserve attacker intent and bounded numeric context.")
	if tel._kill_attack_origin("melee", "attack_empty") != "attack_empty" \
			or tel._kill_attack_origin("melee", "retreat_counter") != "retreat" \
			or tel._kill_attack_origin("melee", "player_melee") != "other" \
			or tel._kill_attack_origin("gun", "gun") != "none":
		tel.free()
		return _fail("Kill context attack-origin enum changed.")
	var bounded_events: Array = tel.metrics.pacing.kill_context_events
	bounded_events.resize(tel.MAX_KILL_CONTEXT_EVENTS)
	if tel.log_kill_context("gun", "pistol", 5.0, {}, {}) \
			or int(tel.metrics.pacing.kill_context_dropped) != 1:
		tel.free()
		return _fail("Kill context should expose overflow instead of exceeding its hard cap.")
	tel.metrics.pacing.kill_context_events = [kill_event]

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
		18.5,
		{
			"poi_role": "recovery_pocket",
			"nearest_poi_role": "recovery_pocket",
			"nearest_poi_edge_distance": 0.0,
			"route_role": "flank",
			"nearest_route_role": "flank",
			"nearest_route_edge_distance": 0.0,
		},
		{
			"target_kind": "player",
			"spawn_age": 3.25,
			"zone_distance": 82.0,
			"zone_radius": 100.0,
			"zone_ratio": 0.82,
			"zone_status": "edge",
		}
	)
	tel.log_doctrine_loot_objective_start(
		"AGGRESSIVE",
		"idle_loot",
		"loot",
		"IDLE",
		"pickup_weapon",
		{
			"poi_role": "loot_hub",
			"poi_name": "Supply Flats",
			"poi_inside": true,
			"nearest_poi_role": "loot_hub",
			"nearest_poi_name": "Supply Flats",
			"nearest_poi_edge_distance": 0.0,
			"route_role": "primary_choke",
			"nearest_route_role": "primary_choke",
			"nearest_route_edge_distance": 0.0,
		},
		6.0,
		{
			"need": "opportunity",
			"target_match": "weapon_new_type",
			"target_detail": "weapon_ar",
		}
	)
	tel.log_doctrine_objective_enemy_interrupt(
		"AGGRESSIVE",
		"idle_loot",
		"loot",
		"pickup_weapon",
		{
			"poi_role": "loot_hub",
			"poi_name": "Supply Flats",
			"nearest_poi_role": "loot_hub",
			"nearest_poi_name": "Supply Flats",
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
		"poi_role": "open",
		"route_role": "primary_choke",
		"route_id": "sluice_direct_crossing",
		"nearest_poi_name": "Central Meadow",
		"nearest_poi_edge_distance": 5.0,
		"cell": "10,20",
	})
	tel.log_combat_location("kill", 0.0, {
		"poi_role": "transit_choke",
		"route_role": "primary_choke",
		"route_id": "sluice_direct_crossing",
	})
	tel.log_pickup_location("collect", "weapon", {
		"poi_role": "loot_hub",
		"nearest_poi_role": "loot_hub",
		"nearest_poi_edge_distance": 0.0,
		"route_role": "primary_choke",
		"nearest_route_role": "primary_choke",
		"nearest_route_edge_distance": 0.0,
	}, "bot_drop")
	tel.log_pickup("shotgun", "weapon", false)
	tel.log_pickup("노후 돌격소총", "weapon", false)
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
	if String(pacing.first_target_acquisition_target_kind) != "player":
		tel.free()
		return _fail("Pacing did not record first target acquisition kind.")
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
	if String(pacing.first_target_acquisition_self_poi_role) != "recovery_pocket":
		tel.free()
		return _fail("Pacing did not record first target acquisition self POI role.")
	if String(pacing.first_target_acquisition_self_poi_band) != "inside":
		tel.free()
		return _fail("Pacing did not record first target acquisition self POI band.")
	if String(pacing.first_target_acquisition_self_route_role) != "flank":
		tel.free()
		return _fail("Pacing did not record first target acquisition self route role.")
	if String(pacing.first_target_acquisition_self_route_band) != "on_route":
		tel.free()
		return _fail("Pacing did not record first target acquisition self route band.")
	if String(pacing.first_target_acquisition_self_nearest_route_role) != "flank":
		tel.free()
		return _fail("Pacing did not record first target acquisition self nearest route role.")
	if absf(float(pacing.first_target_acquisition_spawn_age) - 3.25) > 0.001:
		tel.free()
		return _fail("Pacing did not record first target acquisition spawn age.")
	if absf(float(pacing.first_target_acquisition_zone_ratio) - 0.82) > 0.001:
		tel.free()
		return _fail("Pacing did not record first target acquisition zone ratio.")
	if String(pacing.first_target_acquisition_zone_status) != "edge":
		tel.free()
		return _fail("Pacing did not record first target acquisition zone status.")
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
	if int(tel.metrics.doctrine.loot_objective_target_nearest_poi_name_by_source.get("idle_loot", {}).get("supply flats", 0)) != 1:
		tel.free()
		return _fail("Doctrine did not preserve the loot objective POI name.")
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
	var open_context_key := "10,20|central meadow|near_4_8m"
	if absf(float(tel.metrics.combat.open_damage_by_context.get(open_context_key, 0.0)) - 12.0) > 0.001:
		tel.free()
		return _fail("Combat telemetry did not preserve the open damage cell context.")
	if String(pacing.first_non_pistol_upgrade_weapon) != "shotgun":
		tel.free()
		return _fail("Pacing did not mirror first non-pistol upgrade.")
	if int(tel.metrics.economy.weapon_pickups.get("ar", 0)) != 1:
		tel.free()
		return _fail("Economy did not normalize the worn AR display name.")
	if String(pacing.first_non_pistol_upgrade_source) != "bot_drop":
		tel.free()
		return _fail("Pacing did not record first upgrade source.")
	if String(pacing.first_non_pistol_upgrade_poi_role) != "loot_hub":
		tel.free()
		return _fail("Pacing did not record first upgrade POI role.")
	if String(pacing.first_non_pistol_upgrade_poi_band) != "inside":
		tel.free()
		return _fail("Pacing did not record first upgrade POI band.")
	if String(pacing.first_non_pistol_upgrade_route_role) != "primary_choke":
		tel.free()
		return _fail("Pacing did not record first upgrade route role.")
	if String(pacing.first_non_pistol_upgrade_route_band) != "on_route":
		tel.free()
		return _fail("Pacing did not record first upgrade route band.")
	if String(pacing.first_non_pistol_upgrade_nearest_route_role) != "primary_choke":
		tel.free()
		return _fail("Pacing did not record first upgrade nearest route role.")
	if String(tel.metrics.economy.first_upgrade_poi_role) != "loot_hub":
		tel.free()
		return _fail("Economy did not record first upgrade POI role.")
	if String(tel.metrics.economy.first_upgrade_source) != "bot_drop":
		tel.free()
		return _fail("Economy did not record first upgrade source.")
	if String(tel.metrics.economy.first_upgrade_route_role) != "primary_choke":
		tel.free()
		return _fail("Economy did not record first upgrade route role.")
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
	var telemetry_script = load("res://src/core/Telemetry.gd")
	var main := FakeMain.new()
	main.name = "Main"
	root.add_child(main)
	var tel = telemetry_script.new()
	root.add_child(tel)
	tel.start_match()
	var start_recorded: bool = tel.log_alive_sample(61, 1, "start", false)
	var start_duplicate_recorded: bool = tel.log_alive_sample(61, 1, "duplicate", false)
	main.match_timer = 3.0
	tel.log_shot()
	tel.set_stage(2)
	var death_recorded: bool = tel.log_alive_sample(60, 2, "death", true, "bot", "gun")
	var death_duplicate_recorded: bool = tel.log_alive_sample(60, 2, "death", true, "bot", "gun")
	var same_frame_death_recorded: bool = tel.log_alive_sample(59, 2, "death", true, "bot", "zone")
	main.match_timer = 60.0
	var cutoff_recorded: bool = tel.log_kill_context("gun", "pistol", 4.0, {}, {})
	main.match_timer = 60.01
	var outside_cutoff_recorded: bool = tel.log_kill_context("gun", "pistol", 4.0, {}, {})
	main.match_timer = 3.0
	tel.end_match(1, "Bot", 2, false)

	var first_shot := float(tel.metrics.pacing.first_shot_time)
	var stage2 := float(tel.metrics.pacing.stage_times.get("2", 0.0))
	var duration := float(tel.metrics.core.duration)
	var player_win := bool(tel.metrics.session.win)
	var alive_timeline: Array = tel.metrics.pacing.alive_timeline.duplicate(true)
	tel.free()
	main.free()

	if not is_equal_approx(first_shot, 3.0):
		return _fail("Pacing first-shot time should use Main.match_timer, got %.2f." % first_shot)
	if not is_equal_approx(stage2, 3.0):
		return _fail("Pacing stage time should use Main.match_timer, got %.2f." % stage2)
	if not is_equal_approx(duration, 3.0):
		return _fail("Core duration should use Main.match_timer, got %.2f." % duration)
	if player_win:
		return _fail("Bot winner should not be recorded as a player win.")
	if not start_recorded or not death_recorded or not same_frame_death_recorded:
		return _fail("Alive timeline rejected a start or distinct death sample.")
	if start_duplicate_recorded or death_duplicate_recorded:
		return _fail("Alive timeline should suppress equal time/count duplicates.")
	if not cutoff_recorded or outside_cutoff_recorded:
		return _fail("Kill context writer must include 60.0s and reject 60.01s.")
	if alive_timeline.size() != 4:
		return _fail("Alive timeline should contain start, two deaths, and match end, got %d." % alive_timeline.size())
	var start_sample: Dictionary = alive_timeline[0]
	var death_sample: Dictionary = alive_timeline[1]
	var same_frame_sample: Dictionary = alive_timeline[2]
	var end_sample: Dictionary = alive_timeline[3]
	if not is_equal_approx(float(start_sample.get("time", -1.0)), 0.0) or int(start_sample.get("alive", -1)) != 61:
		return _fail("Alive start sample should use Main.match_timer=0 and alive=61.")
	if not is_equal_approx(float(death_sample.get("time", -1.0)), 3.0):
		return _fail("Alive death sample should use Main.match_timer, got %.2f." % float(death_sample.get("time", -1.0)))
	if int(death_sample.get("stage", -1)) != 2 or String(death_sample.get("reason", "")) != "death":
		return _fail("Alive death sample should preserve stage and reason.")
	if not bool(death_sample.get("shrinking", false)):
		return _fail("Alive death sample should preserve shrinking state.")
	if String(death_sample.get("victim_kind", "")) != "bot" or String(death_sample.get("cause", "")) != "gun":
		return _fail("Alive death sample should preserve victim kind and cause.")
	if int(same_frame_sample.get("alive", -1)) != 59 or String(same_frame_sample.get("cause", "")) != "zone":
		return _fail("Alive timeline should retain distinct same-frame deaths.")
	if (
		not is_equal_approx(float(end_sample.get("time", -1.0)), 3.0)
		or int(end_sample.get("alive", -1)) != 59
		or String(end_sample.get("reason", "")) != "match_end"
	):
		return _fail("Alive timeline should carry the last known count to match end.")
	return true


func _verify_entity_death_hook_exact_once() -> bool:
	var tel = root.get_node_or_null("Telemetry")
	if tel == null:
		return _fail("Telemetry autoload is required for the Entity death-hook smoke.")
	var original_root_children: Array = root.get_children()
	tel.start_match()
	var entity_script = load("res://src/entities/Entity.gd")
	var stats_script = load("res://src/core/StatsData.gd")
	var killer = entity_script.new()
	var victim = entity_script.new()
	var zone_victim = entity_script.new()
	for actor in [killer, victim, zone_victim]:
		actor.stats = stats_script.new()
		var collision := CollisionShape3D.new()
		collision.name = "CollisionShape3D"
		actor.add_child(collision)
		actor.set_process(false)
		actor.set_physics_process(false)
		root.add_child(actor)
	killer.add_to_group("bots")
	victim.add_to_group("bots")
	zone_victim.add_to_group("bots")
	killer.stats.weapon_type = "pistol"
	killer.stats.current_ammo = 19
	victim.current_health = 1.0
	victim.take_damage(5.0, "gun", "pistol", killer)
	victim.die(killer)
	zone_victim.last_damage_source = "zone"
	zone_victim.die()
	var events: Array = tel.metrics.pacing.kill_context_events.duplicate(true)
	tel.match_in_progress = false
	# Let generated death audio/effects finish so this verifier does not leave
	# short-lived playback resources behind at process exit.
	await create_timer(1.0).timeout
	for child in root.get_children():
		if child not in original_root_children and is_instance_valid(child):
			child.queue_free()
	for _frame in range(3):
		await process_frame
	if events.size() != 2:
		return _fail("Entity death hook should record each victim exactly once, got %d events." % events.size())
	var combat_event: Dictionary = events[0]
	var zone_event: Dictionary = events[1]
	if String(combat_event.get("cause", "")) != "gun" \
			or String(combat_event.get("weapon", "")) != "pistol":
		return _fail("Entity fatal damage should preserve the exact combat cause and weapon.")
	var attacker_context: Dictionary = combat_event.get("attacker", {})
	if String(attacker_context.get("kind", "")) != "bot" \
			or int(attacker_context.get("mag", -1)) != 19:
		return _fail("Entity fatal damage should snapshot the attacker once at death time.")
	var zone_attacker: Dictionary = zone_event.get("attacker", {})
	if String(zone_event.get("cause", "")) != "zone" \
			or String(zone_attacker.get("kind", "")) != "none":
		return _fail("Null-killer zone deaths should retain an explicit empty attacker context.")
	return true


func _fail(message: String) -> bool:
	push_error(message)
	return false
