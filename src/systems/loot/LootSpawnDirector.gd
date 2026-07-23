class_name LootSpawnDirector
extends RefCounted

const ItemDataScript = preload("res://src/core/ItemData.gd")

static func categorize_templates(item_templates: Array, extra_consumables: Array = []) -> Dictionary:
	var weapons: Array = []
	var consumables: Array = []
	for template in item_templates:
		if not template:
			continue
		if template.type == ItemDataScript.Type.WEAPON:
			weapons.append(template)
		else:
			consumables.append(template)
	for template in extra_consumables:
		if template:
			consumables.append(template)
	return {
		"weapons": weapons,
		"consumables": consumables,
	}

static func spawn_initial_loot(
	pickup_scene: PackedScene,
	loot_parent: Node,
	hotspots: Array,
	loot_spawner,
	weapon_templates: Array,
	consumable_templates: Array,
	equipment_templates: Array,
	random_position: Callable
) -> int:
	if not pickup_scene or not loot_parent or not loot_spawner or hotspots.is_empty():
		return 0
	var spawned = 0
	for hotspot in hotspots:
		var weapon_chance = loot_spawner.initial_weapon_chance(hotspot)
		if not weapon_templates.is_empty() and randf() < weapon_chance:
			var weapon_pos = _call_random_position(random_position, hotspot)
			var weapon_template = loot_spawner.choose_initial_weapon_template(
				weapon_templates,
				hotspot
			) if loot_spawner.has_method("choose_initial_weapon_template") else _random_item(weapon_templates)
			if weapon_template:
				_spawn_pickup(pickup_scene, loot_parent, Vector3(weapon_pos.x, 0.5, weapon_pos.y), weapon_template, true, "initial_loot")
				spawned += 1
		var equipment_chance = loot_spawner.initial_equipment_chance(hotspot) \
			if loot_spawner.has_method("initial_equipment_chance") else 0.0
		if not equipment_templates.is_empty() and randf() < equipment_chance:
			var equipment_pos = _call_random_position(random_position, hotspot)
			_spawn_pickup(
				pickup_scene,
				loot_parent,
				Vector3(equipment_pos.x, 0.5, equipment_pos.y),
				_random_item(equipment_templates),
				true,
				"initial_loot"
			)
			spawned += 1
		var consumable_count = loot_spawner.initial_consumable_count(hotspot)
		for _i in range(consumable_count):
			if consumable_templates.is_empty():
				break
			var consumable_pos = _call_random_position(random_position, hotspot)
			_spawn_pickup(pickup_scene, loot_parent, Vector3(consumable_pos.x, 0.5, consumable_pos.y), _random_item(consumable_templates), false, "initial_loot")
			spawned += 1
	return spawned

static func spawn_loot_wave(
	pickup_scene: PackedScene,
	loot_parent: Node,
	total_to_spawn: int,
	loot_spawner,
	choose_hotspot: Callable,
	random_position: Callable,
	weapon_templates: Array,
	item_templates: Array
) -> int:
	if total_to_spawn <= 0 or not pickup_scene or not loot_parent:
		return 0
	var spawned = 0
	for _i in range(total_to_spawn):
		var hotspot: Dictionary = choose_hotspot.call() if choose_hotspot.is_valid() else {}
		if hotspot.is_empty():
			continue
		var spawn_pos = _call_random_position(random_position, hotspot)
		var weapon_chance = loot_spawner.wave_weapon_chance(hotspot) if loot_spawner and loot_spawner.has_method("wave_weapon_chance") else float(hotspot.get("rare_bias", 0.0))
		var use_weapon = randf() < weapon_chance and not weapon_templates.is_empty()
		var template = loot_spawner.choose_wave_weapon_template(weapon_templates) \
			if use_weapon and loot_spawner and loot_spawner.has_method("choose_wave_weapon_template") \
			else _random_item(weapon_templates if use_weapon else item_templates)
		if not template:
			continue
		_spawn_pickup(pickup_scene, loot_parent, Vector3(spawn_pos.x, 0.5, spawn_pos.y), template, use_weapon, "stage_wave")
		spawned += 1
	return spawned

static func create_supply_pillar(parent: Node, supply_pos: Vector3) -> MeshInstance3D:
	if not parent:
		return null
	var pillar = MeshInstance3D.new()
	var mesh = CylinderMesh.new()
	mesh.top_radius = 0.5
	mesh.bottom_radius = 0.5
	mesh.height = 100.0
	pillar.mesh = mesh
	var material = StandardMaterial3D.new()
	material.albedo_color = Color(1.0, 0.8, 0.2, 0.3)
	material.transparency = StandardMaterial3D.TRANSPARENCY_ALPHA
	material.emission_enabled = true
	material.emission = Color(1.0, 0.8, 0.2)
	pillar.material_override = material
	parent.add_child(pillar)
	pillar.global_position = supply_pos + Vector3(0, 50, 0)
	return pillar

static func spawn_supply_cluster(
	pickup_scene: PackedScene,
	loot_parent: Node,
	supply_pos: Vector3,
	railgun_item,
	consumable_count: int,
	cluster_offset: Callable,
	consumable_templates: Array,
	item_templates: Array
) -> int:
	if not pickup_scene or not loot_parent:
		return 0
	var spawned = 0
	if railgun_item:
		_spawn_pickup(pickup_scene, loot_parent, supply_pos, railgun_item, true, "supply")
		spawned += 1
	for _i in range(max(0, consumable_count)):
		var template = _random_item(consumable_templates if not consumable_templates.is_empty() else item_templates)
		if not template:
			continue
		_spawn_pickup(pickup_scene, loot_parent, supply_pos + _call_cluster_offset(cluster_offset), template, false, "supply")
		spawned += 1
	return spawned

static func _spawn_pickup(
	pickup_scene: PackedScene,
	loot_parent: Node,
	world_position: Vector3,
	template,
	duplicate_template: bool,
	spawn_source: String
):
	if not template:
		return null
	var pickup = pickup_scene.instantiate()
	loot_parent.add_child(pickup)
	pickup.global_position = world_position
	pickup.init(template.duplicate(true) if duplicate_template else template, spawn_source)
	if pickup.has_method("log_spawn_location"):
		pickup.log_spawn_location()
	return pickup

static func _random_item(items: Array):
	if items.is_empty():
		return null
	return items[randi() % items.size()]

static func _call_random_position(random_position: Callable, hotspot: Dictionary) -> Vector2:
	if random_position.is_valid():
		return random_position.call(hotspot)
	return hotspot.get("pos", Vector2.ZERO)

static func _call_cluster_offset(cluster_offset: Callable) -> Vector3:
	if cluster_offset.is_valid():
		return cluster_offset.call()
	return Vector3(randf_range(-2.5, 2.5), 0.0, randf_range(-2.5, 2.5))
