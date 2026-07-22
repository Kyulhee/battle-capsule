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

	var ready_context := {
		"equipment_need": 0.05,
		"survival_need": 0.05,
		"threat_pressure": 0.0,
		"combat_readiness": 0.95,
		"move_speed": 5.0,
		"movement_multiplier": 0.8,
		"time_budget_seconds": 60.0,
	}
	var under_equipped_context := ready_context.duplicate()
	under_equipped_context["equipment_need"] = 1.0
	under_equipped_context["combat_readiness"] = 0.1
	var ready_loot_utility := POLICY.destination_utility(
		"loot_hub", "mixed", 0.8, 40.0, 0, 5, "roam", ready_context
	)
	var needy_loot_utility := POLICY.destination_utility(
		"loot_hub", "mixed", 0.8, 40.0, 0, 5, "roam", under_equipped_context
	)
	if needy_loot_utility <= ready_loot_utility:
		_fail("Equipment need must raise loot-hub utility.")
		return

	var threatened_context := ready_context.duplicate()
	threatened_context["survival_need"] = 1.0
	threatened_context["threat_pressure"] = 1.0
	threatened_context["combat_readiness"] = 0.15
	var recovery_utility := POLICY.destination_utility(
		"recovery_pocket", "mixed", 0.4, 35.0, 0, 2, "roam", threatened_context
	)
	var transit_utility := POLICY.destination_utility(
		"transit_choke", "mixed", 0.6, 35.0, 0, 3, "roam", threatened_context
	)
	if recovery_utility <= transit_utility:
		_fail("Wounded threatened bots must value recovery over exposed transit.")
		return

	var impossible_context := ready_context.duplicate()
	impossible_context["time_budget_seconds"] = 20.0
	var impossible_utility := POLICY.destination_utility(
		"transit_choke", "transit", 0.7, 120.0, 0, 3, "preposition", impossible_context
	)
	if impossible_utility > 0.0:
		_fail("Preposition utility must reject destinations outside the arrival budget.")
		return

	var fast_road := POLICY.choose_route("transit", 100.0, 110.0, ready_context)
	if not bool(fast_road.get("use_road", false)):
		_fail("A safe transit bot must use a road when its travel time is lower.")
		return
	var threatened_cover := POLICY.choose_route("cover", 100.0, 110.0, threatened_context)
	if bool(threatened_cover.get("use_road", false)):
		_fail("A threatened cover bot must avoid a marginal exposed road shortcut.")
		return
	var urgent_context := threatened_context.duplicate()
	urgent_context["time_budget_seconds"] = 15.0
	var urgent_cover := POLICY.choose_route("cover", 100.0, 100.0, urgent_context)
	if not bool(urgent_cover.get("use_road", false)):
		_fail("Arrival urgency must outweigh road exposure when the time saving is decisive.")
		return
	if POLICY.preposition_lead_seconds("mixed", threatened_context) \
			<= POLICY.preposition_lead_seconds("mixed", ready_context):
		_fail("Threat pressure must advance the preposition window.")
		return
	if POLICY.preposition_lead_seconds("mixed", under_equipped_context) \
			>= POLICY.preposition_lead_seconds("mixed", ready_context):
		_fail("Equipment need must preserve more looting time before prepositioning.")
		return

	print("Bot strategic movement policy smoke passed: utility, occupancy, routes, and anchors.")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
