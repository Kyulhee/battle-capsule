extends SceneTree

const DIRECTOR = preload("res://src/systems/loot/LootSpawnDirector.gd")
const ITEMS = preload("res://src/core/ItemResourceCatalog.gd")
const SPAWNER = preload("res://src/systems/loot/LootSpawner.gd")
var failures: Array[String] = []

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var pool := [ITEMS.AMMO_AR, ITEMS.AMMO_SHOTGUN, ITEMS.AMMO_RAILGUN, ITEMS.HEAL_PICKUP]
	var guns := [ITEMS.WEAPON_AR, ITEMS.WEAPON_SHOTGUN]
	var original := [ITEMS.HEAL_PICKUP, ITEMS.AMMO_RAILGUN, ITEMS.AMMO_SHOTGUN]
	var copy := original.duplicate()
	seed(991)
	var expected_random := randi()
	seed(991)
	var result: Array = DIRECTOR.match_initial_ammo(original, guns, pool)
	_check(randi() == expected_random, "Ammo matching consumed RNG.")
	_check(original == copy, "Ammo matching mutated its input.")
	_check(result == [ITEMS.HEAL_PICKUP, ITEMS.AMMO_AR, ITEMS.AMMO_SHOTGUN], "Only the first existing ammo slot should change.")
	_check(DIRECTOR.match_initial_ammo(result, guns, pool) == result, "Matching is not idempotent.")
	_check(DIRECTOR.match_initial_ammo(original, [], pool) == original, "Gunless POI gained ammo.")
	_check(DIRECTOR.match_initial_ammo(original, guns, []) == original, "Missing ammo catalog was invented.")
	_check(DIRECTOR.match_initial_ammo([], guns, pool).is_empty(), "Empty budget gained a slot.")
	_check(DIRECTOR.match_initial_ammo([ITEMS.BALLISTIC_VEST, ITEMS.WEAPON_AR], guns, pool) \
		== [ITEMS.BALLISTIC_VEST, ITEMS.WEAPON_AR], "Equipment/weapon was replaced.")
	_check(DIRECTOR.match_initial_ammo([ITEMS.HEAL_PICKUP], guns, pool) == [ITEMS.AMMO_AR], "No-ammo fallback did not replace one consumable.")
	_check(DIRECTOR.match_initial_ammo([ITEMS.AMMO_SHOTGUN], [ITEMS.WEAPON_SHOTGUN_WORN], pool) \
		== [ITEMS.AMMO_SHOTGUN], "Weapon tier changed compatibility.")
	_verify_spawn_boundary()
	if not failures.is_empty():
		for failure in failures:
			push_error(failure)
		quit(1)
		return
	print("Initial ammo match passed: finite budget, one replacement, existing match, RNG, resources, boundaries.")
	quit(0)

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

func _verify_spawn_boundary() -> void:
	var control := _spawn_variant(false)
	var candidate := _spawn_variant(true)
	_check(control["next_random"] == candidate["next_random"], "Spawn matching changed later RNG.")
	var before: Array = control["records"]
	var after: Array = candidate["records"]
	_check(before.size() == after.size() and before.size() == 15, "Spawn budget changed.")
	if before.size() != after.size():
		return
	var changed := {}
	for index in range(before.size()):
		_check(before[index]["position"] == after[index]["position"], "Spawn position moved.")
		var poi_index := index / 5
		if before[index]["kind"] == ItemData.Type.WEAPON or poi_index == 2:
			_check(before[index] == after[index], "Unselected POI or weapon changed.")
		if before[index] != after[index]:
			changed[poi_index] = int(changed.get(poi_index, 0)) + 1
	for count in changed.values():
		_check(int(count) <= 1, "More than one slot replaced per POI.")
	for start in [0, 5]:
		var matched := false
		for index in range(start + 2, start + 5):
			matched = matched or (after[index]["kind"] == ItemData.Type.AMMO \
				and after[index]["family"] == after[start]["family"])
		_check(matched, "Runtime first weapon has no matching ammo.")

func _spawn_variant(enabled: bool) -> Dictionary:
	seed(721)
	var parent := Node3D.new()
	root.add_child(parent)
	var spawner = SPAWNER.new()
	var hotspots: Array = []
	for index in range(3):
		hotspots.append({"pos": Vector2(index * 20, 0), "density": 0.6,
			"initial_weapon_slots": 2, "initial_ammo_match": enabled and index < 2})
	DIRECTOR.spawn_initial_loot(ITEMS.PICKUP_SCENE, parent, hotspots, spawner,
		[ITEMS.WEAPON_AR, ITEMS.WEAPON_SHOTGUN],
		[ITEMS.HEAL_PICKUP, ITEMS.AMMO_RAILGUN, ITEMS.AMMO_AR, ITEMS.AMMO_SHOTGUN], [],
		func(hotspot: Dictionary): return hotspot["pos"] + Vector2(randf(), randf()))
	var records: Array = []
	for pickup in parent.get_children():
		var item: ItemData = pickup.item
		records.append({"kind": item.type, "name": item.item_name, "position": pickup.position,
			"family": item.weapon_stats.weapon_type if item.type == ItemData.Type.WEAPON else item.ammo_weapon_type})
	var next_random := randi()
	parent.free()
	return {"records": records, "next_random": next_random}
