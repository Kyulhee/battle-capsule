extends SceneTree


class FakeMain:
	extends Node
	var match_timer: float = 0.0
	var map_spec_path: String = "res://tests/fake_map.json"
	var map_scale_preset: String = "test"
	var map_definition = null


class FakeMapDefinition:
	extends RefCounted

	func describe_strategic_position(world_pos: Vector2) -> Dictionary:
		var sector := int(floor(world_pos.x / 10.0)) * 10
		return {
			"poi_role": "loot_hub",
			"poi_name": "Sector %d" % sector,
			"poi_inside": true,
			"nearest_poi_role": "loot_hub",
			"nearest_poi_name": "Sector %d" % sector,
			"nearest_poi_edge_distance": 0.0,
			"route_role": "primary_choke",
			"route_id": "route_%d" % sector,
			"route_on": true,
			"nearest_route_role": "primary_choke",
			"nearest_route_id": "route_%d" % sector,
			"nearest_route_edge_distance": 0.0,
		}


func _init():
	call_deferred("_run")


func _run() -> void:
	if not _verify_pacing_schema_and_hooks():
		quit(1)
		return
	if not _verify_pacing_uses_game_seconds():
		quit(1)
		return
	if not _verify_opening_survival_exposure_exact_summary():
		quit(1)
		return
	if not await _verify_bot_opening_survival_exposure_shadow():
		quit(1)
		return
	if not _verify_survival_break_episode_exact_summary():
		quit(1)
		return
	if not await _verify_bot_survival_break_episode_shadow():
		quit(1)
		return
	if not _verify_target_continuity_exact_summary():
		quit(1)
		return
	if not await _verify_bot_target_continuity_shadow():
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
	if not tel.metrics.pacing.has("target_continuity_episode_samples") \
			or not tel.metrics.pacing.has("target_continuity_episode_sample_metadata") \
			or not tel.metrics.pacing.has("target_continuity_disengage_exit_samples") \
			or not tel.metrics.pacing.has("target_continuity_disengage_exit_sample_metadata") \
			or not tel.metrics.pacing.has("target_continuity_summary") \
			or tel.metrics.pacing.has("target_continuity_events") \
			or tel.metrics.pacing.has("target_continuity_dropped"):
		tel.free()
		return _fail("Pacing should expose only the linked schema-v2 continuity samples and exact summary.")
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
			"state_age_seconds": 4.567,
			"target_age_seconds": 2.345,
			"disengage_entry_reason": "Losing_Fight",
			"disengage_same_entry_target": true,
			"state_displacement": 3.456,
			"state_stuck_delta": 2,
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
	if (
		not is_equal_approx(float(attacker_context.get("state_age_seconds", -1.0)), 4.57)
		or not is_equal_approx(float(attacker_context.get("target_age_seconds", -1.0)), 2.35)
		or String(attacker_context.get("disengage_entry_reason", "")) != "losing_fight"
		or not bool(attacker_context.get("disengage_same_entry_target", false))
		or not is_equal_approx(float(attacker_context.get("state_displacement", -1.0)), 3.46)
		or int(attacker_context.get("state_stuck_delta", -1)) != 2
	):
		tel.free()
		return _fail("Kill context should preserve normalized target/state continuity fields.")
	if (
		float(victim_context.get("state_age_seconds", 0.0)) != -1.0
		or float(victim_context.get("target_age_seconds", 0.0)) != -1.0
		or String(victim_context.get("disengage_entry_reason", "")) != "none"
		or bool(victim_context.get("disengage_same_entry_target", true))
		or float(victim_context.get("state_displacement", 0.0)) != -1.0
		or int(victim_context.get("state_stuck_delta", 0)) != -1
	):
		tel.free()
		return _fail("Default/player kill continuity context should use safe sentinels.")
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

	var continuity_summary: Dictionary = tel.metrics.pacing.target_continuity_summary
	var episode_metadata: Dictionary = tel.metrics.pacing.target_continuity_episode_sample_metadata
	var exit_metadata: Dictionary = tel.metrics.pacing.target_continuity_disengage_exit_sample_metadata
	if (
		int(continuity_summary.get("schema_version", 0)) != 2
		or not bool(continuity_summary.get("exact", false))
		or not bool(continuity_summary.get("complete", false))
		or String(continuity_summary.get("release_time_basis", "")) != "match_elapsed"
		or String(episode_metadata.get("method", "")) != tel.TARGET_CONTINUITY_SAMPLE_METHOD
		or int(episode_metadata.get("capacity", 0)) != 128
		or not bool(episode_metadata.get("complete", false))
		or String(exit_metadata.get("method", "")) != tel.TARGET_CONTINUITY_SAMPLE_METHOD
		or int(exit_metadata.get("capacity", 0)) != 128
		or not bool(exit_metadata.get("complete", false))
	):
		tel.free()
		return _fail("Initial continuity schema-v2 summary or sample metadata changed.")

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
	var continuity_cutoff_available: bool = tel.can_track_target_continuity()
	main.match_timer = 60.01
	var outside_cutoff_recorded: bool = tel.log_kill_context("gun", "pistol", 4.0, {}, {})
	var continuity_outside_cutoff_available: bool = tel.can_track_target_continuity()
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
	if not continuity_cutoff_available or continuity_outside_cutoff_available:
		return _fail("Target continuity tracking must include 60.0s and reject 60.01s.")
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


func _verify_opening_survival_exposure_exact_summary() -> bool:
	var telemetry_script = load("res://src/core/Telemetry.gd")
	var main := FakeMain.new()
	main.name = "Main"
	main.map_spec_path = "res://maps/exposure_contract.json"
	main.map_scale_preset = "m1_contract"
	root.add_child(main)
	var tel = telemetry_script.new()
	root.add_child(tel)
	tel.start_match()
	var alpha := _opening_location("Alpha", "alpha_route")
	var bravo := _opening_location("Bravo", "bravo_route")
	var charlie := _opening_location("Charlie", "charlie_route")
	var unknown := {"_opening_location_known": false}

	# Canonical observation time, not the supplied physics delta, owns the
	# interval. Same-time observations credit zero and replace only the held
	# state/location for the following interval.
	main.match_timer = 0.0
	tel.register_opening_survival_actor(1, "IDLE", true)
	tel.observe_opening_survival_state(1, "IDLE", unknown)
	main.match_timer = 0.1
	tel.observe_opening_survival_state(1, "RECOVER", alpha)
	if not is_zero_approx(tel.observe_opening_survival_state(1, "RECOVER", alpha)):
		tel.free()
		main.free()
		return _fail("Same-time survival observations must not double-count actor-seconds.")
	main.match_timer = 0.35
	var credited_mixed_delta: float = tel.track_opening_survival_exposure(
		1, "RECOVER", 9.0, bravo
	)
	main.match_timer = 0.6
	tel.observe_opening_survival_state(1, "DISENGAGE", bravo)

	# Event attribution uses the same strategic bucketizer as the denominator.
	if not tel.track_opening_survival_target_acquisition({
		"actor_id": 1,
		"state": "RECOVER",
		"source": "Recover_Melee",
		"reason": "Target_Change",
		"distance": 1.5,
		"additional_threats": 0,
		"location": alpha,
	}) or not tel.track_opening_survival_disengage_entry({
		"actor_id": 1,
		"state": "DISENGAGE",
		"source": "Attack",
		"reason": "Losing_Fight",
		"distance": 4.0,
		"additional_threats": 2,
		"location": bravo,
	}):
		tel.free()
		main.free()
		return _fail("Opening acquisition or DISENGAGE entry event was rejected.")

	main.match_timer = 0.8
	var death_context := {
		"actor_id": 1,
		"state": "DISENGAGE",
		"source": "Gun",
		"reason": "Pistol",
		"distance": 8.0,
		"additional_threats": 3,
		"location": charlie,
	}
	if not tel.track_opening_bot_death(death_context) \
			or tel.track_opening_bot_death(death_context):
		tel.free()
		main.free()
		return _fail("Opening bot death must be exact-once per actor.")

	# A held observation crossing 60s is clipped exactly at the boundary even
	# when the next callback arrives late.
	main.match_timer = 59.9
	tel.register_opening_survival_actor(2, "RECOVER", true)
	tel.observe_opening_survival_state(2, "RECOVER", unknown)
	main.match_timer = 60.2
	var clipped: float = tel.observe_opening_survival_state(2, "RECOVER", alpha)
	var summary: Dictionary = tel.metrics.pacing.opening_survival_exposure_summary
	if (
		not is_equal_approx(credited_mixed_delta, 0.25)
		or not is_equal_approx(clipped, 0.1)
		or int(summary.get("schema_version", 0)) != 1
		or not bool(summary.get("exact", false))
		or not bool(summary.get("complete", false))
		or String(summary.get("population", "")) != "bots_only"
		or String(summary.get("time_basis", "")) != "match_elapsed"
		or String(summary.get("attribution", "")) != "left_edge_sample_hold"
		or String(summary.get("map_spec_path", "")) != main.map_spec_path
		or String(summary.get("scale_preset", "")) != main.map_scale_preset
		or String(summary.get("location_taxonomy", "")) != "strategic_position_v1"
		or int(summary.get("tracked_actors", 0)) != 2
		or int(summary.get("initial_survival_state_counts", {}).get("recover", 0)) != 1
		or not is_equal_approx(float(summary.get("actor_seconds_total", -1.0)), 0.8)
		or not is_equal_approx(float(summary.get("known_location_actor_seconds", -1.0)), 0.7)
		or not is_equal_approx(float(summary.get("unknown_location_actor_seconds", -1.0)), 0.1)
		or not is_equal_approx(float(summary.get("actor_seconds_by_state", {}).get("recover", -1.0)), 0.6)
		or not is_equal_approx(float(summary.get("actor_seconds_by_state", {}).get("disengage", -1.0)), 0.2)
	):
		tel.free()
		main.free()
		return _fail("Canonical opening exposure totals, identity, or 60s clipping changed.")
	if not is_equal_approx(float(
		summary.actor_seconds_by_state_and_poi_name.recover.get("alpha", 0.0)
	), 0.25) or not is_equal_approx(float(
		summary.actor_seconds_by_state_and_poi_name.recover.get("bravo", 0.0)
	), 0.25) or not is_equal_approx(float(
		summary.actor_seconds_by_state_and_poi_name.recover.get("unknown", 0.0)
	), 0.1) or not is_equal_approx(float(
		summary.actor_seconds_by_state_and_poi_name.disengage.get("bravo", 0.0)
	), 0.2):
		tel.free()
		main.free()
		return _fail("Left-edge POI sample hold attributed an interval to the wrong location.")
	for field_name in [
		"actor_seconds_by_state_and_poi_name",
		"actor_seconds_by_state_and_poi_role",
		"actor_seconds_by_state_and_poi_band",
		"actor_seconds_by_state_and_route_id",
		"actor_seconds_by_state_and_route_role",
		"actor_seconds_by_state_and_route_band",
	]:
		if not is_equal_approx(_nested_float_sum(summary[field_name]), 0.8):
			tel.free()
			main.free()
			return _fail("Exposure location axis %s must sum exactly to actor_seconds_total." % field_name)
	if int(summary.get("opening_bot_deaths", 0)) != 1:
		tel.free()
		main.free()
		return _fail("Opening all-state bot death numerator changed.")
	for event_name in ["target_acquisitions", "disengage_entries", "survival_deaths"]:
		var block: Dictionary = summary[event_name]
		if int(block.get("count", 0)) != 1 \
				or int(block.get("known_location_count", 0)) != 1 \
				or int(block.get("unknown_location_count", 0)) != 0 \
				or not _opening_event_marginals_equal_count(block):
			tel.free()
			main.free()
			return _fail("Opening event block %s lost an exact marginal invariant." % event_name)
	if int(summary.target_acquisitions.by_distance_bucket.get("under_2m", 0)) != 1 \
			or int(summary.disengage_entries.by_distance_bucket.get("2_5m", 0)) != 1 \
			or int(summary.survival_deaths.by_distance_bucket.get("5_10m", 0)) != 1 \
			or int(summary.survival_deaths.by_threat_count_bucket.get("3_plus", 0)) != 1 \
			or int(summary.survival_deaths.by_source.get("gun", 0)) != 1 \
			or int(summary.survival_deaths.by_reason.get("pistol", 0)) != 1:
		tel.free()
		main.free()
		return _fail("Opening event source/reason/distance/threat buckets changed.")
	main.match_timer = 10.0
	for index in range(70):
		var overflow_location := _opening_location(
			"Overflow %d" % index,
			"overflow_route"
		)
		tel.track_opening_survival_target_acquisition({
			"actor_id": 100 + index,
			"state": "RECOVER",
			"source": "overflow_probe",
			"reason": "target_change",
			"distance": 3.0,
			"additional_threats": -1,
			"location": overflow_location,
		})
	if summary.target_acquisitions.by_poi_name.size() > 64 \
			or _int_sum(summary.target_acquisitions.by_poi_name) != 71 \
			or int(summary.target_acquisitions.by_poi_name.get("other", 0)) <= 0 \
			or not bool(summary.get("location_overflowed", false)) \
			or not bool(summary.get("complete", false)):
		tel.free()
		main.free()
		return _fail("Location counters must pool overflow without invalidating exact totals.")
	tel.free()
	main.free()

	# end_match must own the tail when a match finishes before the next 0.25s
	# doctrine callback.
	var early_main := FakeMain.new()
	early_main.name = "Main"
	root.add_child(early_main)
	var early = telemetry_script.new()
	root.add_child(early)
	early.start_match()
	early_main.match_timer = 2.0
	early.register_opening_survival_actor(7, "DISENGAGE", true)
	early.observe_opening_survival_state(7, "DISENGAGE", alpha)
	early_main.match_timer = 2.4
	early.end_match(1, "Bot", 1, false)
	var early_total := float(
		early.metrics.pacing.opening_survival_exposure_summary.actor_seconds_total
	)
	early.free()
	early_main.free()
	if not is_equal_approx(early_total, 0.4):
		return _fail("end_match must finalize a held survival interval, got %.3fs." % early_total)

	# An observation exactly at the inclusive 60s edge credits the final slice
	# but must not retain a zero-width held sample beyond the window.
	var edge_main := FakeMain.new()
	edge_main.name = "Main"
	root.add_child(edge_main)
	var edge = telemetry_script.new()
	root.add_child(edge)
	edge.start_match()
	edge_main.match_timer = 59.9
	edge.register_opening_survival_actor(8, "RECOVER", true)
	edge.observe_opening_survival_state(8, "RECOVER", alpha)
	edge_main.match_timer = 60.0
	var edge_credit: float = edge.observe_opening_survival_state(8, "RECOVER", bravo)
	var edge_holds: Dictionary = edge.get("_opening_survival_held_by_actor")
	edge.match_in_progress = false
	edge.free()
	edge_main.free()
	if not is_equal_approx(edge_credit, 0.1) or not edge_holds.is_empty():
		return _fail("The exact 60s observation must credit 0.1s and close its held sample.")
	return true


func _verify_survival_break_episode_exact_summary() -> bool:
	var telemetry_script = load("res://src/core/Telemetry.gd")
	var main := FakeMain.new()
	main.name = "Main"
	root.add_child(main)
	var tel = telemetry_script.new()
	root.add_child(tel)
	tel.start_match()

	main.match_timer = 1.0
	var entry := {
		"actor_id": 10,
		"state_episode_id": 4,
		"hp_ratio": 0.24,
		"shield_ratio": 0.5,
		"target_id": 20,
		"target_kind": "bot",
		"target_distance": 3.0,
		"entry_visibility": "revealed",
	}
	if not tel.start_survival_break_episode(entry) \
			or tel.start_survival_break_episode(entry):
		tel.free()
		main.free()
		return _fail("survival_break episode start must be exact-once.")
	main.match_timer = 1.2
	if not tel.track_survival_break_episode_event(10, 4, "cover_selected", {
		"distance": 6.0,
	}) or not tel.track_survival_break_episode_event(10, 4, "damage", {
		"amount": 5.0, "attacker_id": 20,
	}) or not tel.track_survival_break_episode_event(10, 4, "damage", {
		"amount": 7.0, "attacker_id": 20,
	}) or not tel.track_survival_break_episode_event(10, 4, "release", {
		"target_id": 20,
	}):
		tel.free()
		main.free()
		return _fail("survival_break episode observations were rejected.")
	main.match_timer = 1.4
	tel.track_survival_break_episode_event(10, 4, "perception_lost")
	main.match_timer = 1.5
	tel.track_survival_break_episode_event(10, 4, "reacquire", {
		"target_id": 20, "source": "retreat_counteraction",
	})
	tel.track_survival_break_episode_event(10, 4, "counteraction")
	tel.track_survival_break_episode_event(10, 4, "cover_reached")
	main.match_timer = 2.0
	if not tel.finish_survival_break_episode({
		"actor_id": 10,
		"state_episode_id": 4,
		"reason": "death",
		"exit_state": "dead",
		"killer_id": 20,
		"cover_min_distance": 1.0,
	}) or tel.finish_survival_break_episode({
		"actor_id": 10,
		"state_episode_id": 4,
		"reason": "death",
		"exit_state": "dead",
		"killer_id": 20,
	}):
		tel.free()
		main.free()
		return _fail("survival_break episode finish must be exact-once.")

	var summary: Dictionary = tel.metrics.pacing.survival_break_episode_summary
	if int(summary.get("schema_version", 0)) != 2 \
			or not bool(summary.get("exact", false)) \
			or not bool(summary.get("complete", false)) \
			or int(summary.get("episodes", 0)) != 1 \
			or int(summary.get("completed", 0)) != 1 \
			or int(summary.get("deaths", 0)) != 1 \
			or int(summary.get("damaged_episodes", 0)) != 1 \
			or int(summary.get("counteraction_episodes", 0)) != 1 \
			or int(summary.get("cover_selected_episodes", 0)) != 1 \
			or int(summary.get("cover_reached_episodes", 0)) != 1 \
			or int(summary.get("cover_progress_observed_episodes", 0)) != 1 \
			or int(summary.get("perception_lost_episodes", 0)) != 1 \
			or int(summary.get("damage_after_cover_selected_episodes", 0)) != 1 \
			or int(summary.get("release_episodes", 0)) != 1 \
			or int(summary.get("fast_reacquired_1s_episodes", 0)) != 1:
		tel.free()
		main.free()
		return _fail("survival_break exact totals changed.")
	if int(summary.incoming_raw_damage.get("count", 0)) != 1 \
			or not is_equal_approx(float(summary.incoming_raw_damage.get("sum", 0.0)), 12.0) \
			or not is_equal_approx(float(summary.damage_events.get("sum", 0.0)), 2.0) \
			or int(summary.death_by_cover_outcome.get("reached", 0)) != 1 \
			or int(summary.death_by_cover_progress.get("reached", 0)) != 1 \
			or int(summary.death_by_first_damage_after_cover.get("under_0_25s", 0)) != 1 \
			or int(summary.death_by_perception_loss.get("yes", 0)) != 1 \
			or int(summary.death_by_entry_visibility.get("revealed", 0)) != 1 \
			or int(summary.death_by_counteraction.get("yes", 0)) != 1 \
			or int(summary.death_by_fast_reacquired.get("yes", 0)) != 1 \
			or int(summary.death_by_killer_relation.get("entry_target", 0)) != 1 \
			or int(summary.fast_reacquire_by_source.get("retreat_counteraction", 0)) != 1:
		tel.free()
		main.free()
		return _fail("survival_break linked death/measures changed.")
	if not is_equal_approx(float(summary.cover_min_distance.get("sum", 0.0)), 1.0) \
			or not is_equal_approx(
				float(summary.cover_progress_ratio.get("sum", 0.0)), 5.0 / 6.0
			) \
			or not is_equal_approx(
				float(summary.first_damage_after_cover_delay.get("sum", -1.0)), 0.0
			) \
			or not is_equal_approx(
				float(summary.death_after_cover_selection_delay.get("sum", 0.0)), 0.8
			) \
			or not is_equal_approx(
				float(summary.first_perception_loss_delay.get("sum", 0.0)), 0.4
			):
		tel.free()
		main.free()
		return _fail("survival_break v2 progression measures changed.")

	# Entries after 59s are censored out; an admitted 59s episode is finalized
	# at the 60s observation window rather than linked to later gameplay.
	main.match_timer = 59.0
	entry.actor_id = 11
	entry.state_episode_id = 5
	if not tel.start_survival_break_episode(entry):
		tel.free()
		main.free()
		return _fail("A survival_break episode at the 59s censor edge was rejected.")
	main.match_timer = 59.2
	if not tel.track_survival_break_episode_event(11, 5, "cover_selected", {
		"distance": 8.0,
	}):
		tel.free()
		main.free()
		return _fail("A pre-cutoff cover observation was rejected.")
	main.match_timer = 60.2
	if tel.track_survival_break_episode_event(11, 5, "damage", {"amount": 99.0}):
		tel.free()
		main.free()
		return _fail("Post-window survival_break observations must be rejected.")
	if int(summary.get("episodes", 0)) != 2 \
			or int(summary.get("censored", 0)) != 1 \
			or int(summary.get("cover_selected_episodes", 0)) != 2 \
			or int(summary.get("cover_progress_observed_episodes", 0)) != 1 \
			or int(summary.cover_min_distance.get("count", 0)) != 1 \
			or int(summary.cover_progress_ratio.get("count", 0)) != 1 \
			or int(summary.exit_by_state.get("censored", 0)) != 1 \
			or not is_equal_approx(float(summary.exit_duration.get("max", 0.0)), 1.0):
		tel.free()
		main.free()
		return _fail("survival_break right-censor contract changed.")

	tel.match_in_progress = false
	tel.free()
	main.free()
	return true


func _verify_bot_survival_break_episode_shadow() -> bool:
	var tel = root.get_node_or_null("Telemetry")
	if tel == null:
		return _fail("Telemetry autoload is required for the survival_break Bot smoke.")
	var main := FakeMain.new()
	main.name = "Main"
	root.add_child(main)
	tel.start_match()
	var bot_scene: PackedScene = load("res://src/entities/bot/Bot.tscn")
	var subject = bot_scene.instantiate()
	var target = bot_scene.instantiate()
	root.add_child(subject)
	root.add_child(target)
	subject.set_physics_process(false)
	target.set_physics_process(false)
	await create_timer(0.25).timeout
	subject.global_position = Vector3.ZERO
	target.global_position = Vector3(3.0, 0.0, 0.0)
	main.match_timer = 1.0
	if not subject.acquire_enemy_target(target, "episode_entry"):
		subject.free()
		target.free()
		main.free()
		return _fail("survival_break Bot fixture could not acquire its entry target.")
	subject.perception_meters[target] = 1.0
	subject.change_state(subject.State.CHASE, "episode_probe")
	subject.current_health = 1.0
	subject.stats.current_ammo = 1
	subject.reserve_ammo = 0
	subject.call("_check_survival_overrides")
	var summary: Dictionary = tel.metrics.pacing.survival_break_episode_summary
	if subject.current_state != subject.State.DISENGAGE \
			or int(summary.get("episodes", 0)) != 1 \
			or int(summary.entry_by_target_kind.get("bot", 0)) != 1 \
			or int(summary.entry_target_distance.get("count", 0)) != 1:
		subject.free()
		target.free()
		main.free()
		return _fail("CHASE survival_break must preserve its pre-clear entry target context.")
	subject._disengage_cover = Vector3(6.0, 0.0, 0.0)
	subject._survival_break_cover_tracking_started = true
	subject._survival_break_cover_min_distance = 6.0
	subject.call("_track_survival_break_episode_event", "cover_selected", {
		"distance": 6.0,
	})
	subject.call("_observe_survival_break_episode_progress")
	subject.global_position = Vector3(3.0, 0.0, 0.0)
	main.match_timer = 1.2
	subject.call("_observe_survival_break_episode_progress")
	subject.perception_meters.erase(target)
	main.match_timer = 1.3
	subject.call("_observe_survival_break_episode_progress")

	main.match_timer = 1.4
	if not subject.acquire_enemy_target(target, "retreat_counteraction"):
		subject.free()
		target.free()
		main.free()
		return _fail("survival_break Bot fixture could not reacquire its released target.")
	# Keep the terminal fixture drop-free after the armed transition has opened
	# the episode. Fatal damage must be observed before super invokes die().
	subject.stats.weapon_type = "pistol"
	subject.stats.current_ammo = 0
	subject.reserve_ammo = 0
	subject.stats.heal_items = 0
	subject.stats.advanced_heals = 0
	subject.equipped_armor_tier = 0
	main.match_timer = 1.5
	subject.take_damage(10.0, "gun", "pistol", target)
	if int(summary.get("completed", 0)) != 1 \
			or int(summary.get("deaths", 0)) != 1 \
			or int(summary.get("damaged_episodes", 0)) != 1 \
			or int(summary.get("release_episodes", 0)) != 1 \
			or int(summary.get("fast_reacquired_1s_episodes", 0)) != 1 \
			or int(summary.get("perception_lost_episodes", 0)) != 1 \
			or not is_equal_approx(float(summary.cover_min_distance.get("sum", 0.0)), 3.0) \
			or not is_equal_approx(float(summary.cover_progress_ratio.get("sum", 0.0)), 0.5) \
			or int(summary.death_by_fast_reacquired.get("yes", 0)) != 1 \
			or int(summary.death_by_perception_loss.get("yes", 0)) != 1 \
			or int(summary.death_by_killer_relation.get("entry_target", 0)) != 1:
		subject.free()
		target.free()
		main.free()
		return _fail("Bot survival_break damage/reacquire/death linkage changed.")
	await create_timer(1.5).timeout
	subject.free()
	target.free()
	main.free()
	tel.match_in_progress = false
	await process_frame
	return true


func _opening_location(poi_name: String, route_id: String) -> Dictionary:
	return {
		"_opening_location_known": true,
		"poi_role": "loot_hub",
		"poi_name": poi_name,
		"poi_inside": true,
		"nearest_poi_role": "loot_hub",
		"nearest_poi_name": poi_name,
		"nearest_poi_edge_distance": 0.0,
		"route_role": "primary_choke",
		"route_id": route_id,
		"route_on": true,
		"nearest_route_role": "primary_choke",
		"nearest_route_id": route_id,
		"nearest_route_edge_distance": 0.0,
	}


func _opening_event_marginals_equal_count(block: Dictionary) -> bool:
	var expected := int(block.get("count", -1))
	for field_name in [
		"by_state", "by_source", "by_reason", "by_distance_bucket",
		"by_threat_count_bucket", "by_poi_name", "by_poi_role", "by_poi_band",
		"by_route_id", "by_route_role", "by_route_band",
	]:
		if _int_sum(block.get(field_name, {})) != expected:
			return false
	return int(block.get("known_location_count", -1)) \
		+ int(block.get("unknown_location_count", -1)) == expected


func _int_sum(values: Dictionary) -> int:
	var total := 0
	for value in values.values():
		total += int(value)
	return total


func _nested_float_sum(values: Dictionary) -> float:
	var total := 0.0
	for nested in values.values():
		for value in Dictionary(nested).values():
			total += float(value)
	return total


func _verify_target_continuity_exact_summary() -> bool:
	var telemetry_script = load("res://src/core/Telemetry.gd")
	var main := FakeMain.new()
	main.name = "Main"
	root.add_child(main)
	var hash_probe = telemetry_script.new()
	root.add_child(hash_probe)
	if int(hash_probe.call("_target_continuity_stable_hash", "1|2|7")) != 1298719915 \
			or int(hash_probe.call("_target_continuity_stable_hash", "2|40")) != 28555174:
		hash_probe.free()
		main.free()
		return _fail("Continuity stable-hash known vectors changed.")
	var bounded_counter: Dictionary = {}
	for index in range(40):
		hash_probe.call("_target_continuity_increment", bounded_counter, "distinct_%d" % index)
	var bounded_counter_total := 0
	for value in bounded_counter.values():
		bounded_counter_total += int(value)
	if bounded_counter.size() > 32 \
			or bounded_counter_total != 40 \
			or int(bounded_counter.get("other", 0)) <= 0:
		hash_probe.free()
		main.free()
		return _fail("Continuity exact counter maps must stay bounded while preserving total counts.")
	var preexisting_other_counter := {"other": 1}
	for index in range(40):
		hash_probe.call(
			"_target_continuity_increment",
			preexisting_other_counter,
			"preexisting_%d" % index
		)
	var preexisting_total := 0
	for value in preexisting_other_counter.values():
		preexisting_total += int(value)
	if preexisting_other_counter.size() > 32 or preexisting_total != 41:
		hash_probe.free()
		main.free()
		return _fail("A preexisting 'other' bucket must still enforce the exact 32-key cap.")
	hash_probe.free()

	# Exact totals must be independent of insertion order, duplicates, sample
	# overflow, and the game's global RNG stream.
	var forward = telemetry_script.new()
	root.add_child(forward)
	forward.start_match()
	seed(424242)
	var expected_rng := randf()
	seed(424242)
	var forward_release_only_keys: Array = _populate_continuity_volume(forward, main, false)
	var actual_rng := randf()
	if not is_equal_approx(actual_rng, expected_rng):
		forward.free()
		main.free()
		return _fail("Continuity sampling must not consume or reseed the game RNG.")
	var forward_summary: Dictionary = forward.metrics.pacing.target_continuity_summary.duplicate(true)
	var forward_episode_samples: Array = forward.metrics.pacing.target_continuity_episode_samples.duplicate(true)
	var forward_exit_samples: Array = forward.metrics.pacing.target_continuity_disengage_exit_samples.duplicate(true)
	var forward_episode_meta: Dictionary = forward.metrics.pacing.target_continuity_episode_sample_metadata.duplicate(true)
	var forward_exit_meta: Dictionary = forward.metrics.pacing.target_continuity_disengage_exit_sample_metadata.duplicate(true)
	if (
		int(forward_summary.get("schema_version", 0)) != 2
		or not bool(forward_summary.get("exact", false))
		or not bool(forward_summary.get("complete", false))
		or int(forward_summary.get("survival_episode_releases", -1)) != 130
		or int(forward_summary.get("survival_episode_reacquired_1s", -1)) != 65
		or int(forward_summary.get("disengage_exit_count", -1)) != 140
		or int(forward_summary.get("reacquire_delay", {}).get("count", -1)) != 65
		or not is_equal_approx(float(forward_summary.get("reacquire_delay", {}).get("sum", -1.0)), 32.5)
	):
		forward.free()
		main.free()
		return _fail("Schema-v2 exact continuity totals must remain authoritative after sample overflow.")
	if not _verify_sample_metadata(forward_episode_meta, 130, 128, 2) \
			or not _verify_sample_metadata(forward_exit_meta, 140, 128, 12) \
			or forward_episode_samples.size() != 128 \
			or forward_exit_samples.size() != 128:
		forward.free()
		main.free()
		return _fail("Continuity bottom-k metadata must report exact population/stored/omitted values.")
	if not _verify_linked_episode_samples(forward_episode_samples):
		forward.free()
		main.free()
		return false
	var forward_episode_keys := _sample_keys(forward_episode_samples)
	var forward_exit_keys := _sample_keys(forward_exit_samples)
	if forward_episode_keys != forward_release_only_keys:
		forward.free()
		main.free()
		return _fail("An omitted episode reacquire must not reinsert or replace a bottom-k release sample.")
	forward.free()

	var reverse = telemetry_script.new()
	root.add_child(reverse)
	reverse.start_match()
	var reverse_release_only_keys: Array = _populate_continuity_volume(reverse, main, true)
	var reverse_episode_samples: Array = reverse.metrics.pacing.target_continuity_episode_samples
	var reverse_exit_samples: Array = reverse.metrics.pacing.target_continuity_disengage_exit_samples
	if reverse_release_only_keys != _sample_keys(reverse_episode_samples) \
			or forward_episode_keys != _sample_keys(reverse_episode_samples) \
			or forward_exit_keys != _sample_keys(reverse_exit_samples):
		reverse.free()
		main.free()
		return _fail("Bottom-k sampled keys and rank order must be insertion-order independent.")
	reverse.free()

	# Clock, censoring, terminal rejection, and immutable release linkage use a
	# small isolated match so their exact counts are unambiguous.
	var edge = telemetry_script.new()
	root.add_child(edge)
	edge.start_match()
	main.match_timer = 10.0
	var first_context := _continuity_release_context(501, 601, 7)
	first_context["reason"] = "Memory_Expired"
	first_context["source"] = "Attack"
	var first_release: Dictionary = edge.track_target_continuity_release(first_context)
	main.match_timer = 10.4
	var repeat_context := first_context.duplicate()
	repeat_context["reason"] = "Target_Switch"
	repeat_context["source"] = "Chase"
	var repeated_release: Dictionary = edge.track_target_continuity_release(repeat_context)
	var immutable_release: Dictionary = edge.metrics.pacing.target_continuity_episode_samples[0].release
	main.match_timer = 10.9
	var reacquire_context := _continuity_reacquire_context(501, 601, 7)
	reacquire_context["spawn_delay_seconds"] = 9.9
	var canonical_reacquire: Dictionary = edge.track_target_continuity_reacquire(reacquire_context)
	var linked_reacquire: Dictionary = edge.metrics.pacing.target_continuity_episode_samples[0].reacquire_1s
	if (
		not bool(first_release.get("first_episode", false))
		or bool(repeated_release.get("first_episode", true))
		or not is_equal_approx(float(repeated_release.get("release_time", -1.0)), 10.4)
		or not is_equal_approx(float(immutable_release.get("release_time", -1.0)), 10.0)
		or String(immutable_release.get("reason", "")) != "memory_expired"
		or not is_equal_approx(float(canonical_reacquire.get("delay_seconds", -1.0)), 0.5)
		or not is_equal_approx(float(linked_reacquire.get("paired_release_time", -1.0)), 10.4)
		or String(linked_reacquire.get("paired_release_reason", "")) != "target_switch"
		or String(linked_reacquire.get("paired_release_source", "")) != "chase"
		or not is_equal_approx(float(linked_reacquire.get("spawn_delay_seconds", -1.0)), 9.9)
	):
		edge.free()
		main.free()
		return _fail("Linked reacquire must use the canonical match clock/latest origin without mutating first release.")

	main.match_timer = 58.9
	var boundary_release: Dictionary = edge.track_target_continuity_release(
		_continuity_release_context(502, 602, 8)
	)
	main.match_timer = 59.8
	var boundary_reacquire: Dictionary = edge.track_target_continuity_reacquire(
		_continuity_reacquire_context(502, 602, 8)
	)
	main.match_timer = 59.5
	var censored_release: Dictionary = edge.track_target_continuity_release(
		_continuity_release_context(503, 603, 9)
	)
	main.match_timer = 60.0
	var censored_reacquire: Dictionary = edge.track_target_continuity_reacquire(
		_continuity_reacquire_context(503, 603, 9)
	)
	main.match_timer = 58.8
	var pre_censor_context := _continuity_release_context(506, 606, 12)
	var pre_censor_release: Dictionary = edge.track_target_continuity_release(pre_censor_context)
	main.match_timer = 59.5
	var ignored_repeat_context := pre_censor_context.duplicate()
	ignored_repeat_context["reason"] = "Target_Switch"
	ignored_repeat_context["source"] = "Chase"
	var ignored_post_censor_repeat: Dictionary = edge.track_target_continuity_release(
		ignored_repeat_context
	)
	main.match_timer = 59.7
	var pre_censor_reacquire: Dictionary = edge.track_target_continuity_reacquire(
		_continuity_reacquire_context(506, 606, 12)
	)
	var pre_censor_link: Dictionary = {}
	for sample in edge.metrics.pacing.target_continuity_episode_samples:
		if String(sample.get("sample_key", "")) == "506|606|12":
			pre_censor_link = sample.get("reacquire_1s", {})
			break
	var releases_before_terminal := int(edge.metrics.pacing.target_continuity_summary.survival_episode_releases)
	main.match_timer = 20.0
	var killed_context := _continuity_release_context(504, 604, 10)
	killed_context["reason"] = "Target_Killed"
	var invalid_context := _continuity_release_context(505, 605, 11)
	invalid_context["reason"] = "Invalid_Target"
	var killed_release: Dictionary = edge.track_target_continuity_release(killed_context)
	var invalid_release: Dictionary = edge.track_target_continuity_release(invalid_context)
	if (
		not bool(boundary_release.get("tracked", false))
		or not bool(boundary_reacquire.get("tracked", false))
		or bool(censored_release.get("tracked", false))
		or bool(censored_reacquire.get("tracked", false))
		or not bool(pre_censor_release.get("tracked", false))
		or bool(ignored_post_censor_repeat.get("tracked", false))
		or not bool(pre_censor_reacquire.get("tracked", false))
		or not is_equal_approx(float(pre_censor_link.get("paired_release_time", -1.0)), 58.8)
		or String(pre_censor_link.get("paired_release_reason", "")) != "memory_expired"
		or bool(killed_release.get("tracked", false))
		or bool(invalid_release.get("tracked", false))
		or int(edge.metrics.pacing.target_continuity_summary.survival_episode_releases) != releases_before_terminal
		or edge.metrics.pacing.target_continuity_summary.release_by_reason.has("target_killed")
		or edge.metrics.pacing.target_continuity_summary.release_by_reason.has("invalid_target")
	):
		edge.free()
		main.free()
		return _fail("Continuity censoring or terminal-release rejection changed.")
	edge.free()
	main.free()
	return true


func _continuity_release_context(actor_id: int, target_id: int, episode: int) -> Dictionary:
	return {
		"actor_id": actor_id,
		"target_id": target_id,
		"target_state_episode": episode,
		"state": "ATTACK",
		"target_state": "DISENGAGE" if episode % 2 == 0 else "RECOVER",
		"reason": "Memory_Expired",
		"source": "Attack",
		"target_source": "Idle_Reaction",
		"distance": 7.25,
		"target_age_seconds": 2.5,
		"move_intent": "Nav_Target",
		"nav_intent": true,
		"speed": 3.5,
		"nav_target_distance": 6.0,
	}


func _continuity_reacquire_context(actor_id: int, target_id: int, episode: int) -> Dictionary:
	return {
		"actor_id": actor_id,
		"target_id": target_id,
		"target_state_episode": episode,
		"state": "CHASE",
		"source": "Idle_Reaction",
		"target_state": "DISENGAGE" if episode % 2 == 0 else "RECOVER",
		"distance": 6.75,
		"target_age_seconds": 0.0,
		"spawn_delay_seconds": 0.25,
		"displacement": 1.5,
		"stuck_delta": 0,
		"disengage_entry_delta": 0,
		"move_intent": "Velocity",
		"nav_intent": false,
		"speed": 4.0,
		"nav_target_distance": 5.0,
	}


func _populate_continuity_volume(tel, main: FakeMain, reverse_order: bool) -> Array:
	var episode_indices: Array = []
	for index in range(130):
		episode_indices.append(index)
	if reverse_order:
		episode_indices.reverse()
	main.match_timer = 10.0
	for index in episode_indices:
		var context := _continuity_release_context(1000 + index, 2000 + index, 3000 + index)
		var first: Dictionary = tel.track_target_continuity_release(context)
		var duplicate: Dictionary = tel.track_target_continuity_release(context)
		if not bool(first.get("first_episode", false)) or bool(duplicate.get("first_episode", true)):
			push_error("Continuity volume duplicate-release invariant failed at %d." % index)
	var release_only_keys := _sample_keys(tel.metrics.pacing.target_continuity_episode_samples)
	main.match_timer = 10.5
	for index in episode_indices:
		if index % 2 != 0:
			continue
		var context := _continuity_reacquire_context(1000 + index, 2000 + index, 3000 + index)
		var first: Dictionary = tel.track_target_continuity_reacquire(context)
		var duplicate: Dictionary = tel.track_target_continuity_reacquire(context)
		if not bool(first.get("tracked", false)) or bool(duplicate.get("tracked", false)):
			push_error("Continuity volume duplicate-reacquire invariant failed at %d." % index)
	var exit_indices: Array = []
	for index in range(140):
		exit_indices.append(index)
	if reverse_order:
		exit_indices.reverse()
	main.match_timer = 20.0
	for index in exit_indices:
		var context := {
			"actor_id": 4000 + index,
			"target_id": 5000 + index,
			"entry_target_id": 5000 + index,
			"current_target_id": 5000 + index,
			"state_episode_id": 6000 + index,
			"state": "DISENGAGE",
			"entry_reason": "Losing_Fight",
			"reason": "Damage_Reengage",
			"exit_state": "CHASE",
			"source": "Damage_Reengage",
			"same_entry_target": true,
			"reengage": true,
			"duration_seconds": 2.5,
			"displacement": 3.25,
			"stuck_delta": 1,
			"visible_enemies": 2,
			"additional_threats": 1,
			"targeting_player": false,
			"move_intent": "Nav_Target",
			"nav_intent": true,
			"speed": 3.0,
			"nav_target_distance": 4.0,
		}
		if not tel.track_target_continuity_disengage_exit(context) \
				or tel.track_target_continuity_disengage_exit(context):
			push_error("Continuity volume duplicate-exit invariant failed at %d." % index)
	return release_only_keys


func _verify_sample_metadata(metadata: Dictionary, population: int, stored: int, omitted: int) -> bool:
	return String(metadata.get("method", "")) == "deterministic_bottom_k_stable_hash" \
		and int(metadata.get("capacity", -1)) == 128 \
		and int(metadata.get("population", -1)) == population \
		and int(metadata.get("stored", -1)) == stored \
		and int(metadata.get("omitted", -1)) == omitted \
		and bool(metadata.get("complete", true)) == (omitted == 0)


func _sample_keys(samples: Array) -> Array:
	var keys: Array = []
	for sample in samples:
		keys.append(String(sample.get("sample_key", "")))
	return keys


func _verify_linked_episode_samples(samples: Array) -> bool:
	var previous_hash := -1
	var previous_key := ""
	for sample in samples:
		var sample_key := String(sample.get("sample_key", ""))
		var sample_hash := int(sample.get("sample_hash", -1))
		var release: Dictionary = sample.get("release", {})
		var expected_key := "%d|%d|%d" % [
			int(release.get("actor_id", -1)),
			int(release.get("target_id", -1)),
			int(release.get("target_state_episode", -1)),
		]
		if sample_key != expected_key \
				or sample_hash < previous_hash \
				or (sample_hash == previous_hash and sample_key < previous_key):
			return _fail("Episode sample identity or deterministic rank order changed.")
		if sample.has("reacquire_1s"):
			var reacquire: Dictionary = sample.reacquire_1s
			if int(reacquire.get("actor_id", -2)) != int(release.get("actor_id", -1)) \
					or int(reacquire.get("target_id", -2)) != int(release.get("target_id", -1)) \
					or int(reacquire.get("target_state_episode", -2)) != int(release.get("target_state_episode", -1)) \
					or String(reacquire.get("release_time_basis", "")) != "match_elapsed" \
					or float(reacquire.get("delay_seconds", -1.0)) < 0.0 \
					or float(reacquire.get("delay_seconds", 2.0)) > 1.0:
				return _fail("Nested reacquire must remain linked to its selected release episode.")
		previous_hash = sample_hash
		previous_key = sample_key
	return true


func _verify_bot_opening_survival_exposure_shadow() -> bool:
	var tel = root.get_node_or_null("Telemetry")
	if tel == null:
		return _fail("Telemetry autoload is required for the opening exposure smoke.")
	var main := FakeMain.new()
	main.name = "Main"
	main.map_definition = FakeMapDefinition.new()
	root.add_child(main)
	tel.start_match()
	var bot_scene: PackedScene = load("res://src/entities/bot/Bot.tscn")
	var subject = bot_scene.instantiate()
	var target = bot_scene.instantiate()
	root.add_child(subject)
	root.add_child(target)
	subject.set_physics_process(false)
	target.set_physics_process(false)
	await create_timer(0.25).timeout
	subject.global_position = Vector3.ZERO
	target.global_position = Vector3(2.0, 0.0, 0.0)
	main.match_timer = 0.0
	subject.call("_register_opening_survival_actor", true)

	main.match_timer = 1.0
	subject.change_state(subject.State.RECOVER, "exposure_probe")
	subject.set("_doctrine_state_telemetry_delta", 0.25)
	subject.global_position = Vector3(10.0, 0.0, 0.0)
	main.match_timer = 1.25
	subject.call("_flush_doctrine_state_telemetry", true)
	var exposure: Dictionary = tel.metrics.pacing.opening_survival_exposure_summary
	if not is_equal_approx(float(
		exposure.actor_seconds_by_state_and_poi_name.recover.get("sector 0", 0.0)
	), 0.25) or String(
		subject.get("_opening_survival_location_context").get("poi_name", "")
	) != "Sector 10":
		subject.free()
		target.free()
		main.free()
		return _fail("Periodic exposure must credit the previous held location before refreshing.")

	# Acquisition classifies its exact event position without mutating the held
	# denominator sample. A refresh of the already-current target is not a new
	# acquisition event.
	subject.global_position = Vector3(20.0, 0.0, 0.0)
	target.global_position = Vector3(22.0, 0.0, 0.0)
	if not subject.acquire_enemy_target(target, "exposure_acquire"):
		subject.free()
		target.free()
		main.free()
		return _fail("Opening exposure fixture could not acquire its target.")
	var acquisition_count := int(exposure.target_acquisitions.count)
	if not subject.acquire_enemy_target(target, "exposure_refresh") \
			or int(exposure.target_acquisitions.count) != acquisition_count \
			or acquisition_count != 1 \
			or String(subject.get("_opening_survival_location_context").get("poi_name", "")) \
				!= "Sector 10" \
			or int(exposure.target_acquisitions.by_poi_name.get("sector 20", 0)) != 1:
		subject.free()
		target.free()
		main.free()
		return _fail("Target holds must not add acquisitions or mutate the exposure hold.")

	subject.set("_doctrine_state_telemetry_delta", 0.25)
	main.match_timer = 1.5
	subject.call("_flush_doctrine_state_telemetry", true)
	if not is_equal_approx(float(
		exposure.actor_seconds_by_state_and_poi_name.recover.get("sector 10", 0.0)
	), 0.25) or float(
		exposure.actor_seconds_by_state_and_poi_name.recover.get("sector 20", 0.0)
	) != 0.0:
		subject.free()
		target.free()
		main.free()
		return _fail("Acquisition event context leaked into the held exposure denominator.")

	subject.call("_log_disengage_entry", "losing_fight")
	subject.change_state(subject.State.DISENGAGE, "exposure_disengage")
	if int(exposure.disengage_entries.count) != 1 \
			or int(exposure.disengage_entries.by_state.get("disengage", 0)) != 1 \
			or int(exposure.disengage_entries.by_poi_name.get("sector 20", 0)) != 1:
		subject.free()
		target.free()
		main.free()
		return _fail("DISENGAGE entry must use its fresh same-state strategic context.")
	subject.set("_doctrine_state_telemetry_delta", 0.2)
	subject.global_position = Vector3(30.0, 0.0, 0.0)
	main.match_timer = 1.7
	subject.call("_flush_doctrine_state_telemetry", true)
	main.match_timer = 1.8
	subject.last_damage_source = "gun"
	subject.last_damage_weapon = "pistol"
	subject.last_damage_dist = 6.0
	# Keep the death fixture drop-free; duplicate die() must preserve the old
	# drop/super behavior while the new exact metric remains deduplicated.
	subject.stats.weapon_type = "pistol"
	subject.stats.current_ammo = 0
	subject.reserve_ammo = 0
	subject.stats.heal_items = 0
	subject.stats.advanced_heals = 0
	subject.equipped_armor_tier = 0
	subject.die()
	subject.die()
	if int(exposure.opening_bot_deaths) != 1 \
			or int(exposure.survival_deaths.count) != 1 \
			or int(exposure.survival_deaths.by_poi_name.get("sector 30", 0)) != 1 \
			or not is_equal_approx(float(exposure.actor_seconds_total), 0.8) \
			or not is_equal_approx(float(exposure.actor_seconds_by_state.disengage), 0.3):
		subject.free()
		target.free()
		main.free()
		return _fail("Death must close the held interval and record one exact fresh-location numerator.")
	await create_timer(1.5).timeout
	subject.free()
	target.free()
	main.free()
	tel.match_in_progress = false
	await process_frame
	return true


func _verify_bot_target_continuity_shadow() -> bool:
	var tel = root.get_node_or_null("Telemetry")
	if tel == null:
		return _fail("Telemetry autoload is required for the bot continuity smoke.")
	var main := FakeMain.new()
	main.name = "Main"
	root.add_child(main)
	tel.start_match()
	var bot_scene: PackedScene = load("res://src/entities/bot/Bot.tscn")
	var subject = bot_scene.instantiate()
	var target = bot_scene.instantiate()
	root.add_child(subject)
	root.add_child(target)
	subject.set_physics_process(false)
	target.set_physics_process(false)
	# Let Bot._ready() finish its staggered navigation setup timer before the
	# fixture is freed, avoiding pending SceneTreeTimer references at shutdown.
	await create_timer(0.25).timeout
	subject.global_position = Vector3.ZERO
	target.global_position = Vector3(0.0, 0.0, 4.0)
	# Release episodes are intentionally restricted to a target that is
	# actually in a survival state and to that target's concrete state episode.
	target.set("current_state", target.State.DISENGAGE)
	target.set("_state_episode_id", 10)

	if not subject.acquire_enemy_target(target, "continuity_probe"):
		subject.free()
		target.free()
		main.free()
		return _fail("Continuity fixture could not acquire its first target.")
	if not subject.acquire_enemy_target(target, "continuity_refresh"):
		subject.free()
		target.free()
		main.free()
		return _fail("Continuity fixture could not refresh its current target.")
	if not tel.metrics.pacing.target_continuity_episode_samples.is_empty():
		subject.free()
		target.free()
		main.free()
		return _fail("Already-current acquisition must not emit release/reacquire events.")

	main.match_timer = 1.0
	subject.set("_spawn_age", 0.0)
	subject.call("_record_enemy_target_release", "memory_expired", "probe_release")
	subject.target_actor = null
	main.match_timer = 1.5
	# Deliberately offset the Bot-local clock: match elapsed is the only
	# eligibility clock, while the 9s spawn delay remains diagnostic only.
	subject.set("_spawn_age", 9.0)
	if not subject.acquire_enemy_target(target, "probe_reacquire"):
		subject.free()
		target.free()
		main.free()
		return _fail("Continuity fixture could not reacquire its released target.")
	var episode_samples: Array = tel.metrics.pacing.target_continuity_episode_samples
	if episode_samples.size() != 1 or not episode_samples[0].has("reacquire_1s"):
		subject.free()
		target.free()
		main.free()
		return _fail("A <=1s real release/reacquire pair should produce one linked episode sample.")
	var linked_reacquire: Dictionary = episode_samples[0].reacquire_1s
	if not is_equal_approx(float(linked_reacquire.get("delay_seconds", -1.0)), 0.5) \
			or not is_equal_approx(float(linked_reacquire.get("spawn_delay_seconds", -1.0)), 9.0) \
			or int(linked_reacquire.get("target_id", -1)) != target.get_instance_id():
		subject.free()
		target.free()
		main.free()
		return _fail("Same-target reacquire should preserve delay and within-run target ID.")
	if not subject.acquire_enemy_target(target, "post_reacquire_refresh") \
			or tel.metrics.pacing.target_continuity_episode_samples.size() != 1:
		subject.free()
		target.free()
		main.free()
		return _fail("Repeated acquire after reacquisition must remain a hold/refresh.")

	# An expired release is consumed by the next real acquisition and cannot
	# leak into a later already-current refresh.
	target.set("_state_episode_id", 11)
	main.match_timer = 2.0
	subject.set("_spawn_age", 0.5)
	subject.call("_record_enemy_target_release", "memory_expired", "stale_probe")
	subject.target_actor = null
	main.match_timer = 3.5
	# The inverse mismatch is rejected by match elapsed even though the Bot-local
	# diagnostic delay is only 0.25s.
	subject.set("_spawn_age", 0.75)
	if not subject.acquire_enemy_target(target, "stale_reacquire"):
		subject.free()
		target.free()
		main.free()
		return _fail("Continuity fixture could not perform the stale acquisition.")
	if not subject.acquire_enemy_target(target, "stale_refresh"):
		subject.free()
		target.free()
		main.free()
		return _fail("Continuity fixture could not refresh after stale acquisition.")
	if int(tel.metrics.pacing.target_continuity_summary.survival_episode_releases) != 2 \
			or int(tel.metrics.pacing.target_continuity_summary.survival_episode_reacquired_1s) != 1:
		subject.free()
		target.free()
		main.free()
		return _fail("A >1s stale release must not create a reacquire event.")

	subject.set("_spawn_age", 2.0)
	subject.call("_log_disengage_entry", "probe_disengage")
	var episode_before_disengage: int = int(subject.get_state_episode_id())
	subject.change_state(subject.State.DISENGAGE)
	if subject.get_state_episode_id() != episode_before_disengage + 1:
		subject.free()
		target.free()
		main.free()
		return _fail("A real state change must increment the Bot state episode exactly once.")
	var disengage_kill_context: Dictionary = subject.get_kill_context(target)
	if String(disengage_kill_context.get("disengage_entry_reason", "")) != "probe_disengage" \
			or not bool(disengage_kill_context.get("disengage_same_entry_target", false)):
		subject.free()
		target.free()
		main.free()
		return _fail("Current DISENGAGE kill context should expose its active entry episode.")
	subject.set("_cached_threat_pressure_context", {
		"visible_enemies": 3,
		"additional_threats": 2,
		"targeting_player": false,
	})
	subject.set("_spawn_age", 4.5)
	subject.global_position = Vector3(3.0, 0.0, 0.0)
	subject.set("_stuck_event_count", int(subject.get("_stuck_event_count")) + 1)
	main.match_timer = 4.0
	subject.change_state(subject.State.CHASE, "probe_reengage")
	var exit_samples: Array = tel.metrics.pacing.target_continuity_disengage_exit_samples
	var exit_event: Dictionary = exit_samples[0]
	if (
		String(exit_event.get("entry_reason", "")) != "probe_disengage"
		or String(exit_event.get("reason", "")) != "probe_reengage"
		or not bool(exit_event.get("same_entry_target", false))
		or not bool(exit_event.get("reengage", false))
		or int(exit_event.get("visible_enemies", -1)) != 3
		or int(exit_event.get("additional_threats", -1)) != 2
		or not is_equal_approx(float(exit_event.get("duration_seconds", -1.0)), 2.5)
		or not is_equal_approx(float(exit_event.get("displacement", -1.0)), 3.0)
		or int(exit_event.get("stuck_delta", -1)) != 1
	):
		subject.free()
		target.free()
		main.free()
		return _fail("DISENGAGE exit should preserve entry, movement, target, and cached pressure context.")

	subject.set("_spawn_age", 5.0)
	subject.global_position = Vector3(4.0, 0.0, 0.0)
	subject.set("_stuck_event_count", int(subject.get("_stuck_event_count")) + 1)
	var kill_context: Dictionary = subject.get_kill_context(target)
	if (
		not is_equal_approx(float(kill_context.get("state_age_seconds", -1.0)), 0.5)
		or not is_equal_approx(float(kill_context.get("target_age_seconds", -1.0)), 4.25)
		or String(kill_context.get("disengage_entry_reason", "")) != "none"
		or bool(kill_context.get("disengage_same_entry_target", true))
		or not is_equal_approx(float(kill_context.get("state_displacement", -1.0)), 1.0)
		or int(kill_context.get("state_stuck_delta", -1)) != 1
	):
		subject.free()
		target.free()
		main.free()
		return _fail("Non-DISENGAGE kill context must not leak stale DISENGAGE episode fields.")
	if float(subject.get_kill_context(null).get("target_age_seconds", 0.0)) != -1.0:
		subject.free()
		target.free()
		main.free()
		return _fail("Bot target age must use a sentinel when the opponent is not the current target.")

	# A dead/invalid remembered target is not a current same-entry target on a
	# later DISENGAGE exit, even if the observation shadow still has its ID.
	subject.call("_log_disengage_entry", "dead_target_probe")
	subject.change_state(subject.State.DISENGAGE)
	target.is_dead = true
	subject.change_state(subject.State.IDLE, "dead_target_exit")
	target.is_dead = false
	exit_samples = tel.metrics.pacing.target_continuity_disengage_exit_samples
	var dead_target_exit: Dictionary = {}
	for sample in exit_samples:
		if String(sample.get("reason", "")) == "dead_target_exit":
			dead_target_exit = sample
			break
	if int(dead_target_exit.get("current_target_id", 0)) != -1 \
			or bool(dead_target_exit.get("same_entry_target", true)):
		subject.free()
		target.free()
		main.free()
		return _fail("DISENGAGE exit should not treat a dead remembered target as still current.")

	# The immediate RECOVER -> IDLE reload path contains two real state changes
	# and therefore advances the monotonic episode twice.
	subject.stats.current_ammo = 0
	subject.stats.max_ammo = maxi(2, int(subject.stats.max_ammo))
	subject.reserve_ammo = 1
	var episode_before_reload: int = int(subject.get_state_episode_id())
	subject.change_state(subject.State.RECOVER, "episode_probe")
	if subject.current_state != subject.State.IDLE \
			or subject.get_state_episode_id() != episode_before_reload + 2:
		subject.free()
		target.free()
		main.free()
		return _fail("Immediate RECOVER -> IDLE reload must increment both real state episodes.")

	# Terminal producer paths clear shadows without touching exact/sample counts.
	var summary: Dictionary = tel.metrics.pacing.target_continuity_summary
	var releases_before_terminal := int(summary.get("survival_episode_releases", 0))
	var sample_population_before_terminal := int(
		tel.metrics.pacing.target_continuity_episode_sample_metadata.population
	)
	target.set("_state_episode_id", 12)
	if not subject.acquire_enemy_target(target, "terminal_probe"):
		subject.free()
		target.free()
		main.free()
		return _fail("Continuity fixture could not acquire its terminal probe target.")
	subject.call("_record_enemy_target_release", "target_killed", "terminal_probe")
	if (
		int(summary.get("survival_episode_releases", 0)) != releases_before_terminal
		or int(tel.metrics.pacing.target_continuity_episode_sample_metadata.population) \
				!= sample_population_before_terminal
		or not subject.get("_enemy_release_shadows").is_empty()
	):
		subject.free()
		target.free()
		main.free()
		return _fail("Terminal target clears must not enter continuity exact totals or samples.")

	# Death is a terminal DISENGAGE exit even though it does not pass through
	# change_state(). Repeating die() must not duplicate the episode, and an
	# otherwise identical death outside the opening window must not be counted.
	main.match_timer = 6.0
	var death_subject = bot_scene.instantiate()
	root.add_child(death_subject)
	death_subject.set_physics_process(false)
	# Do not free a Bot while its asynchronous _ready navigation timer is still
	# pending; that leaves the SceneTreeTimer referenced at verifier shutdown.
	await create_timer(0.25).timeout
	death_subject.stats.weapon_type = "pistol"
	death_subject.stats.current_ammo = 0
	death_subject.reserve_ammo = 0
	death_subject.stats.heal_items = 0
	death_subject.stats.advanced_heals = 0
	death_subject.equipped_armor_tier = 0
	death_subject.call("_log_disengage_entry", "death_probe")
	death_subject.change_state(death_subject.State.DISENGAGE)
	death_subject.target_actor = target
	death_subject.call("_record_enemy_target_acquisition", target, "death_pending_probe", false)
	death_subject.call("_record_enemy_target_release", "target_switch", "death_pending_probe")
	if death_subject.get("_enemy_release_shadows").is_empty():
		death_subject.free()
		subject.free()
		target.free()
		main.free()
		return _fail("Death cleanup fixture did not create a pending release shadow.")
	var exits_before_death := int(summary.get("disengage_exit_count", 0))
	death_subject.die()
	death_subject.die()
	var death_exit: Dictionary = {}
	for sample in tel.metrics.pacing.target_continuity_disengage_exit_samples:
		if int(sample.get("actor_id", -1)) == death_subject.get_instance_id():
			death_exit = sample
			break
	if (
		int(summary.get("disengage_exit_count", 0)) != exits_before_death + 1
		or String(death_exit.get("reason", "")) != "death"
		or String(death_exit.get("exit_state", "")) != "dead"
		or bool(death_exit.get("reengage", true))
		or int(summary.get("disengage_by_exit_reason", {}).get("death", 0)) != 1
		or int(summary.get("disengage_by_exit_state", {}).get("dead", 0)) != 1
		or int(summary.get("disengage_transitions", {}).get("death_probe->death/dead", 0)) != 1
		or not bool(death_subject.get("_continuity_tracking_closed"))
		or not death_subject.get("_enemy_release_shadows").is_empty()
	):
		death_subject.free()
		subject.free()
		target.free()
		main.free()
		return _fail("DISENGAGE death must record one terminal exit with exact transition counters.")
	death_subject.free()

	main.match_timer = 60.01
	var cutoff_death_subject = bot_scene.instantiate()
	root.add_child(cutoff_death_subject)
	cutoff_death_subject.set_physics_process(false)
	await create_timer(0.25).timeout
	cutoff_death_subject.stats.weapon_type = "pistol"
	cutoff_death_subject.stats.current_ammo = 0
	cutoff_death_subject.reserve_ammo = 0
	cutoff_death_subject.stats.heal_items = 0
	cutoff_death_subject.stats.advanced_heals = 0
	cutoff_death_subject.equipped_armor_tier = 0
	cutoff_death_subject.call("_log_disengage_entry", "cutoff_death_probe")
	cutoff_death_subject.change_state(cutoff_death_subject.State.DISENGAGE)
	cutoff_death_subject.die()
	if int(summary.get("disengage_exit_count", 0)) != exits_before_death + 1:
		cutoff_death_subject.free()
		subject.free()
		target.free()
		main.free()
		return _fail("A DISENGAGE death after the 60s opening cutoff must not enter continuity totals.")
	# Both death fixtures spawn 1.3s death effects. Let them finish before
	# freeing the fixtures so this smoke exits without leaked effect references.
	await create_timer(1.5).timeout
	cutoff_death_subject.free()

	# Once Telemetry's match clock is outside the opening window, the next
	# behavior-neutral probe must clear all per-bot pending state.
	main.match_timer = 7.0
	target.set("_state_episode_id", 13)
	subject.acquire_enemy_target(target, "cutoff_probe")
	subject.call("_record_enemy_target_release", "target_switch", "cutoff_probe")
	if subject.get("_enemy_release_shadows").is_empty():
		subject.free()
		target.free()
		main.free()
		return _fail("Cutoff fixture did not create a pending continuity shadow.")
	main.match_timer = 60.01
	if bool(subject.call("_target_continuity_tracking_available")) \
			or not bool(subject.get("_continuity_tracking_closed")) \
			or not subject.get("_enemy_release_shadows").is_empty():
		subject.free()
		target.free()
		main.free()
		return _fail("Opening cutoff should clear per-bot continuity pending/dedup dictionaries.")

	tel.match_in_progress = false
	subject.free()
	target.free()
	main.free()
	await process_frame
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
