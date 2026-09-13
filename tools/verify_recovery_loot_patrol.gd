extends SceneTree

const POLICY = preload("res://src/entities/bot/BotStrategicMovementPolicy.gd")
const POIS: Array[Dictionary] = [
	{"name": "loot", "pos": [24, 0], "radius": 8, "role": "loot_hub", "item_density": 0.8},
	{"name": "recovery", "pos": [-35, 0], "radius": 8, "role": "recovery_pocket", "item_density": 0.4},
	{"name": "bush", "pos": [0, 25], "radius": 8, "role": "concealment_field", "item_density": 1.0},
	{"name": "empty", "pos": [0, -25], "radius": 8, "role": "loot_hub", "item_density": 0.0},
	{"name": "outside", "pos": [110, 0], "radius": 8, "role": "loot_hub", "item_density": 1.0},
	{"name": "here", "pos": [0, 0], "radius": 8, "role": "loot_hub", "item_density": 1.0},
]
class MapKnowledge:
	extends Node
	var pois: Array[Dictionary] = []
	var reads := 0
	func get_poi_descriptors() -> Array[Dictionary]:
		reads += 1
		return pois
class FixtureMain:
	extends Node
	var zone = {"current_center": Vector2.ZERO, "current_radius": 100.0, "stage": 1, "timer": 90.0}
	var map_spec = {"pois": []}
	var map_definition: Node
	var supply_telegraphed := false
	var supply_spawned := false
	var supply_pos := Vector3(9, 0, 9)
class PatrolBot:
	extends "res://src/entities/bot/Bot.gd"
	var enemy: Entity
	var loot: Node3D
	var context_calls := 0
	var expensive_context := false
	var bush := Vector3(0, 0, 20)
	var hotspot := Vector3(20, 0, 0)
	var pursue_supply := true
	func _ready(): pass
	func _ensure_doctrine_profile(): pass
	func _find_nearest_bush() -> Vector3: return bush
	func _find_nearest_hotspot() -> Vector3: return hotspot
	func _should_pursue_supply(_main) -> bool: return pursue_supply
	func _strategic_occupancy_by_name(_pois: Array[Dictionary]) -> Dictionary: return {}
	func _strategic_utility_context(_main, _mode: String, enemies: bool = true, surface: bool = true) -> Dictionary:
		context_calls += 1
		expensive_context = expensive_context or enemies or surface
		return {}
	func _find_nearest_target() -> Entity: return enemy
	func _is_close_player_threat(_enemy: Entity) -> bool: return false
	func acquire_enemy_target(_enemy: Entity, _source: String, _keep: bool = false) -> bool: return true
	func _find_best_pickup(_radius: float, _prefer: bool = false) -> Node3D: return loot
	func _start_loot_objective(pickup: Node3D, _source: String, _recovering_value: bool = false) -> void:
		target_actor = pickup
	func change_state(new_state: State, _reason: String = ""):
		current_state = new_state
	func _nav_move_toward(pos: Vector3, delta: float, _rotate: bool = true):
		position = position.move_toward(pos, 4.0 * delta)

var failures: Array[String] = []

func _init(): _run.call_deferred()
func _check(ok: bool, message: String):
	if not ok: failures.append(message)

func _pure():
	var before := POIS.duplicate(true)
	var normal_loot := 0
	var crowded_loot := 0
	var targets := {}
	seed(27)
	var expected_random := randi()
	seed(27)
	for phase in range(128):
		var result := POLICY.select_recovery_patrol_destination(POIS, Vector2.ZERO, Vector2.ZERO, 100, phase, {}, {})
		_check(result.get("name") in ["loot", "recovery"], "Selected non-supply/empty/outside/local POI")
		_check(result["target"].distance_to(Vector2.ZERO) <= 95.0, "Target outside safe margin")
		_check(result["planning_mode"] == "roam", "Recovery entered preposition mode")
		targets[result["target"]] = true
		normal_loot += int(result["name"] == "loot")
		var crowded := POLICY.select_recovery_patrol_destination(POIS, Vector2.ZERO, Vector2.ZERO, 100, phase, {"loot": 20}, {})
		crowded_loot += int(crowded["name"] == "loot")
	_check(randi() == expected_random and POIS == before, "Policy mutated input/RNG")
	_check(normal_loot > crowded_loot and crowded_loot > 0 and targets.size() > 32, "Occupancy/spread lost")
	for radius in [0.0, 5.0, NAN]:
		_check(POLICY.select_recovery_patrol_destination(POIS, Vector2.ZERO, Vector2.ZERO, radius, 0, {}, {}).is_empty(), "Invalid zone accepted")
	_check(POLICY.select_recovery_patrol_destination(POIS, Vector2(101, 0), Vector2.ZERO, 100, 0, {}, {}).is_empty(), "Outside origin accepted")
	_check(POLICY.select_recovery_patrol_destination([], Vector2.ZERO, Vector2.ZERO, 100, 0, {}, {}).is_empty(), "Empty map selected")
	var edge: Array[Dictionary] = [{"name": "edge", "pos": [94, 0], "radius": 12, "role": "loot_hub", "item_density": 1.0,
		"strategic_anchors": [{"id": "entry", "role": "entry", "pos": [94, 0], "jitter_radius": 3.0}]}]
	for phase in range(32):
		var selected := POLICY.select_recovery_patrol_destination(edge, Vector2.ZERO, Vector2.ZERO, 100, phase, {}, {})
		_check(selected["target"].length() <= 95.001, "Anchor jitter escaped zone margin")

func _run():
	create_timer(8).timeout.connect(func(): quit(1))
	_pure()
	var main := FixtureMain.new()
	main.name = "Main"
	var knowledge := MapKnowledge.new()
	knowledge.pois = POIS.duplicate(true)
	main.map_definition = knowledge
	main.add_child(knowledge)
	root.add_child(main)
	var bot := PatrolBot.new()
	bot.stats = StatsData.new()
	bot.stats.current_ammo = 0
	bot.stats.weapon_type = "ar"
	bot.current_health = bot.stats.max_health
	var ray := RayCast3D.new()
	ray.name = "RayCast3D"
	bot.add_child(ray)
	root.add_child(bot)
	bot.set_process(false)
	bot.set_physics_process(false)
	bot.current_state = bot.State.RECOVER
	bot.recovery_substate = "patrol"
	_check(not bot._recovery_loot_patrol_enabled, "Candidate default enabled")
	bot._doctrine_profile = {"patrol_preference": "bush"}
	_check(bot._pick_patrol_target() == bot.bush, "Default bush branch changed")
	bot._doctrine_profile["patrol_preference"] = "hotspot"
	_check(bot._pick_patrol_target() == bot.hotspot, "Default hotspot branch changed")
	bot._doctrine_profile["patrol_preference"] = "random"
	seed(31)
	var baseline := bot._pick_patrol_target()
	var baseline_rng := randi()
	_check(knowledge.reads == 0 and bot.context_calls == 0, "Default touched candidate map/context")
	bot._recovery_loot_patrol_enabled = true
	knowledge.pois = []
	seed(31)
	_check(bot._pick_patrol_target() == baseline and randi() == baseline_rng, "Fallback changed random branch/RNG")
	knowledge.pois = POIS.duplicate(true)
	for mode in ["loaded", "reserve", "idle", "seek_cover", "seek_loot"]:
		bot.current_state = bot.State.IDLE if mode == "idle" else bot.State.RECOVER
		bot.recovery_substate = mode if mode in ["seek_cover", "seek_loot"] else "patrol"
		bot.stats.current_ammo = 1 if mode == "loaded" else 0
		bot.reserve_ammo = 1 if mode == "reserve" else 0
		var reads := knowledge.reads
		seed(31)
		_check(bot._pick_patrol_target() == baseline and randi() == baseline_rng and knowledge.reads == reads, "Scope/RNG changed: " + mode)
	bot.stats.current_ammo = 0
	bot.reserve_ammo = 0
	bot.current_state = bot.State.RECOVER
	bot.recovery_substate = "patrol"
	main.supply_telegraphed = true
	var reads := knowledge.reads
	_check(bot._pick_patrol_target() == main.supply_pos and knowledge.reads == reads, "Supply lost priority")
	main.supply_telegraphed = false
	seed(59)
	var expected_rng := randi()
	seed(59)
	var selected := bot._pick_patrol_target()
	_check(selected.is_finite() and bot._recovery_loot_patrol_selections == 1 and randi() == expected_rng,
		"Candidate selection/counter/RNG differs")
	_check(not bot.expensive_context and bot._strategic_destination.is_empty(), "Candidate rescanned perception/surface or replaced strategic state")
	bot.recovery_substate = "seek_loot"
	bot.recovery_timer = 4.0
	bot.handle_recover_state(0.1)
	_check(bot.recovery_substate == "patrol" and bot._recovery_loot_patrol_selections == 2, "Actual seek_loot did not choose candidate")
	var distance := bot.position.distance_to(bot.patrol_target)
	bot.handle_recover_state(0.5)
	_check(bot.position.distance_to(bot.patrol_target) < distance, "Patrol handler did not advance")
	bot.loot = Node3D.new()
	root.add_child(bot.loot)
	bot.handle_recover_state(0.1)
	_check(bot.current_state == bot.State.CHASE and bot.target_actor == bot.loot, "Visible loot lost priority")
	bot.current_state = bot.State.RECOVER
	bot.loot.free()
	bot.loot = null
	bot.enemy = Entity.new()
	root.add_child(bot.enemy)
	bot.enemy.position = bot.position + Vector3(1, 0, 0)
	reads = knowledge.reads
	bot.handle_recover_state(0.1)
	_check(bot.current_state == bot.State.ATTACK and knowledge.reads == reads, "Enemy lost priority")
	bot.enemy.free()
	bot.enemy = null
	bot.current_state = bot.State.RECOVER
	bot.position = Vector3(99, 0, 0)
	bot._check_state_overrides(0.1)
	_check(bot.current_state == bot.State.ZONE_ESCAPE, "Zone override lost")
	bot.free()
	main.free()
	if not failures.is_empty():
		for failure in failures: push_error(failure)
		quit(1)
		return
	print("Recovery loot patrol passed: pure zone/role/occupancy/spread, OFF/fallback RNG, scope/supply/enemy/zone/loot priorities and handler advance. Nav stub, not reachability proof.")
	quit(0)
