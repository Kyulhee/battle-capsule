extends SceneTree


const POLICY := preload("res://src/entities/bot/BotStrategicMovementPolicy.gd")
const POIS: Array[Dictionary] = [
	{"name": "Center", "pos": [0.0, 0.0], "radius": 20.0, "role": "loot_hub", "item_density": 0.5},
	{"name": "North", "pos": [0.0, 80.0], "radius": 18.0, "role": "loot_hub", "item_density": 0.9},
	{"name": "East Gate", "pos": [55.0, 0.0], "radius": 16.0, "role": "transit_choke", "item_density": 0.6},
	{"name": "West Cover", "pos": [-48.0, 0.0], "radius": 16.0, "role": "recovery_pocket", "item_density": 0.4},
	{"name": "Outside", "pos": [0.0, 130.0], "radius": 20.0, "role": "loot_hub", "item_density": 1.0},
]
const ANCHORED_POIS: Array[Dictionary] = [
	{
		"name": "Compound",
		"pos": [50.0, 0.0],
		"radius": 18.0,
		"role": "loot_hub",
		"item_density": 0.9,
		"strategic_anchors": [
			{"id": "yard", "role": "objective", "pos": [50.0, 0.0], "jitter_radius": 1.0},
			{"id": "west_gate", "role": "entry", "pos": [37.0, 0.0], "jitter_radius": 1.0},
			{"id": "west_outer", "role": "outer", "pos": [28.0, 0.0], "jitter_radius": 1.0},
		],
	},
]
const PREPOSITION_POIS: Array[Dictionary] = [
	{
		"name": "Edge Compound",
		"pos": [62.0, 0.0],
		"radius": 18.0,
		"role": "transit_choke",
		"item_density": 0.7,
		"strategic_anchors": [
			{"id": "yard", "role": "objective", "pos": [62.0, 0.0], "jitter_radius": 0.0},
			{"id": "safe_gate", "role": "entry", "pos": [42.0, 0.0], "jitter_radius": 0.0},
			{"id": "safe_outer", "role": "outer", "pos": [38.0, 5.0], "jitter_radius": 0.0},
		],
	},
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

	var occupied_destination := POLICY.select_destination(
		POIS,
		Vector2.ZERO,
		Vector2.ZERO,
		100.0,
		"loot_hub",
		0.1,
		1,
		{"North": 50}
	)
	if String(occupied_destination.get("name", "")) == "North":
		_fail("Heavy POI occupancy must redirect new strategic arrivals.")
		return
	var empty_weight := POLICY.occupancy_multiplier(0, 5)
	var full_weight := POLICY.occupancy_multiplier(5, 5)
	var overloaded_weight := POLICY.occupancy_multiplier(10, 5)
	if not is_equal_approx(empty_weight, 1.0) \
			or full_weight >= empty_weight \
			or overloaded_weight >= full_weight:
		_fail("POI occupancy pressure must decrease monotonically.")
		return

	var anchored_destination := POLICY.select_destination(
		ANCHORED_POIS,
		Vector2.ZERO,
		Vector2.ZERO,
		100.0,
		"cover",
		0.42,
		3
	)
	var anchor_center: Vector2 = anchored_destination.get("anchor_center", Vector2.INF)
	var anchored_target: Vector2 = anchored_destination.get("target", Vector2.INF)
	if String(anchored_destination.get("anchor_id", "")).is_empty() \
			or String(anchored_destination.get("anchor_role", "")) not in ["entry", "outer"]:
		_fail("Cover-oriented bots must read compound entry or outer anchors.")
		return
	if not anchor_center.is_finite() or anchored_target.distance_to(anchor_center) > 1.01:
		_fail("Strategic anchor jitter escaped its local navigation pocket.")
		return

	var preposition_destination := POLICY.select_destination(
		PREPOSITION_POIS,
		Vector2.ZERO,
		Vector2.ZERO,
		50.0,
		"transit",
		0.42,
		4,
		{},
		"preposition"
	)
	var preposition_target: Vector2 = preposition_destination.get("target", Vector2.INF)
	if preposition_destination.is_empty() \
			or String(preposition_destination.get("planning_mode", "")) != "preposition":
		_fail("Preposition planning must select an eligible next-zone anchor.")
		return
	if String(preposition_destination.get("anchor_role", "")) not in ["entry", "outer"]:
		_fail("Preposition planning must occupy an entry or outer approach anchor.")
		return
	if not preposition_target.is_finite() or preposition_target.length() > 45.01:
		_fail("Preposition target must stay inside the next zone safety margin.")
		return
	if POLICY.preposition_lead_seconds("cover") <= POLICY.preposition_lead_seconds("loot_hub"):
		_fail("Cover doctrines must preposition before loot-focused doctrines.")
		return
	if not POLICY.should_use_road("transit", 0.5) or POLICY.should_use_road("cover", 0.5):
		_fail("Road use must be common for transit bots and selective for cover bots.")
		return

	print("Bot strategic movement policy smoke passed: occupancy, roads, and next-zone anchors.")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
