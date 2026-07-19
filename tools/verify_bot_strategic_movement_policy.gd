extends SceneTree


const POLICY := preload("res://src/entities/bot/BotStrategicMovementPolicy.gd")
const POIS: Array[Dictionary] = [
	{"name": "Center", "pos": [0.0, 0.0], "radius": 20.0, "role": "loot_hub", "item_density": 0.5},
	{"name": "North", "pos": [0.0, 80.0], "radius": 18.0, "role": "loot_hub", "item_density": 0.9},
	{"name": "East Gate", "pos": [55.0, 0.0], "radius": 16.0, "role": "transit_choke", "item_density": 0.6},
	{"name": "West Cover", "pos": [-48.0, 0.0], "radius": 16.0, "role": "recovery_pocket", "item_density": 0.4},
	{"name": "Outside", "pos": [0.0, 130.0], "radius": 20.0, "role": "loot_hub", "item_density": 1.0},
]


func _init() -> void:
	var loot_destination := POLICY.select_destination(
		POIS,
		Vector2.ZERO,
		Vector2.ZERO,
		100.0,
		"loot_hub",
		0.1,
		1
	)
	if loot_destination.is_empty() or String(loot_destination.get("role", "")) != "loot_hub":
		_fail("Loot preference must select an in-zone loot hub outside the current POI.")
		return
	if String(loot_destination.get("name", "")) == "Center":
		_fail("Strategic movement must not loiter in the current POI.")
		return
	if String(loot_destination.get("name", "")) == "Outside":
		_fail("Strategic movement must reject POIs outside the current zone.")
		return

	var cover_destination := POLICY.select_destination(
		POIS,
		Vector2(20.0, 0.0),
		Vector2.ZERO,
		100.0,
		"cover",
		0.95,
		2
	)
	if String(cover_destination.get("role", "")) not in ["recovery_pocket", "transit_choke"]:
		_fail("Cover preference must favor recovery or transit cover.")
		return

	var first_target: Vector2 = loot_destination.get("target", Vector2.INF)
	var alternate := POLICY.select_destination(
		POIS,
		Vector2.ZERO,
		Vector2.ZERO,
		100.0,
		"loot_hub",
		0.1,
		9
	)
	var alternate_target: Vector2 = alternate.get("target", Vector2.INF)
	if not first_target.is_finite() or not alternate_target.is_finite():
		_fail("Strategic destinations must expose finite navigation targets.")
		return
	if first_target.is_equal_approx(alternate_target):
		_fail("Bots targeting the same POI must receive dispersed arrival points.")
		return
	var center: Vector2 = loot_destination.get("center", Vector2.INF)
	if first_target.distance_to(center) > float(loot_destination.get("radius", 0.0)) * 0.36:
		_fail("Dispersed arrival target escaped its POI.")
		return

	print("Bot strategic movement policy smoke passed: weighted POI convergence.")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
