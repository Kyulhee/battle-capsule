extends SceneTree

const AUDIT = preload("res://tools/LootFlowAudit.gd")
const ITEMS = preload("res://src/core/ItemResourceCatalog.gd")
const SLOTS = preload("res://src/core/WeaponSlotManager.gd")
const PICKUP_SCENE = preload("res://src/entities/pickup/Pickup.tscn")
const BUILD_INFO = preload("res://src/core/BuildInfo.gd")


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var output_path := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("audit_output="):
			output_path = arg.trim_prefix("audit_output=")
	if output_path.is_empty() or FileAccess.file_exists(output_path):
		push_error("Provide a new audit_output JSON path; existing evidence is never overwritten.")
		quit(1)
		return
	var main = load("res://src/Main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	var nav = main.get("_nav_region")
	if nav != null and nav.is_baking():
		await nav.bake_finished
	main.start_game()
	# 다음 physics frame 이전에 읽는다. 봇 습득/파동/사망 드랍은 포함하지 않는다.
	var records: Array = []
	for pickup in main.get_node("Loot").get_children():
		if not pickup is Pickup or pickup.item == null:
			continue
		var item: ItemData = pickup.item
		var position_2d := Vector2(pickup.global_position.x, pickup.global_position.z)
		var context: Dictionary = main.map_definition.describe_strategic_position(position_2d)
		records.append({
			"poi": String(context.get("nearest_poi_name", "none")),
			"role": String(context.get("nearest_poi_role", "none")),
			"kind": ItemData.Type.keys()[item.type].to_lower(),
			"family": item.weapon_stats.weapon_type if item.type == ItemData.Type.WEAPON \
				else item.ammo_weapon_type if item.type == ItemData.Type.AMMO else "",
			"amount": item.amount,
			"name": item.item_name,
			"position": [position_2d.x, position_2d.y],
		})
	var report := AUDIT.summarize(records)
	main.process_mode = Node.PROCESS_MODE_DISABLED
	report["schema_version"] = 1
	report["build"] = BUILD_INFO.MENU_VERSION
	report["map"] = main.map_spec_path
	report["preset"] = main.map_scale_preset
	report["seed"] = main.simulation_seed
	report["match_time"] = main.match_timer
	report["scope"] = "initial_snapshot_before_actor_physics; no survival or player scarcity duration inference"
	report["records"] = records
	# 별도 강제 재현. 자연 플레이 발생률로 해석하지 않는다.
	report["forced_player_probes"] = _probe_player_ammo(main.player_ref)
	var parent_error := DirAccess.make_dir_recursive_absolute(output_path.get_base_dir())
	if parent_error != OK:
		push_error("Cannot create audit directory: %s" % error_string(parent_error))
		main.free()
		quit(1)
		return
	var file := FileAccess.open(output_path, FileAccess.WRITE)
	if file == null:
		push_error("Cannot write audit: %s" % error_string(FileAccess.get_open_error()))
		main.free()
		quit(1)
		return
	file.store_string(JSON.stringify(report, "\t") + "\n")
	file.close()
	print("LOOT_AUDIT ", JSON.stringify(report["totals"]))
	print("PLAYER_AMMO_PROBES ", JSON.stringify(report["forced_player_probes"]))
	# finish_match를 호출하지 않으므로 user://의 최신 수동 결과를 교체하지 않는다.
	main.queue_free()
	await process_frame
	quit(0)


func _probe_player_ammo(player) -> Dictionary:
	var results := {}
	var family: String = ITEMS.AMMO_AR.ammo_weapon_type
	player.slots = SLOTS.new()
	results["unowned_family"] = _collect_probe(player, ITEMS.AMMO_AR)
	player.slots.receive_weapon(ITEMS.WEAPON_AR.weapon_stats)
	player.slots.receive_ammo(family, SLOTS.get_reserve_max(family))
	results["full_reserve"] = _collect_probe(player, ITEMS.AMMO_AR)
	player.slots.clear_all_ammo()
	results["compatible_space"] = _collect_probe(player, ITEMS.AMMO_AR)
	var upgrade = SLOTS.new()
	upgrade.receive_weapon(ITEMS.WEAPON_AR_WORN.weapon_stats)
	upgrade.receive_ammo(family, 15)
	var before := int(upgrade.slot_reserve[upgrade.active_slot])
	var accepted: bool = upgrade.receive_weapon(ITEMS.WEAPON_AR.weapon_stats)
	results["same_family_upgrade"] = {
		"accepted": accepted, "reserve_before": before,
		"reserve_after": upgrade.slot_reserve[upgrade.active_slot],
	}
	return results


func _collect_probe(player, item: ItemData) -> Dictionary:
	var pickup = PICKUP_SCENE.instantiate()
	root.add_child(pickup)
	pickup.init(item.duplicate(true), "audit_fixture")
	var before: int = _total_reserve(player.slots)
	var accepted: bool = pickup.collect(player)
	var result := {
		"accepted": accepted, "queued_for_deletion": pickup.is_queued_for_deletion(),
		"reserve_delta": _total_reserve(player.slots) - before,
	}
	pickup.free()
	return result


func _total_reserve(slots) -> int:
	var result := 0
	for amount in slots.slot_reserve:
		result += int(amount)
	return result
