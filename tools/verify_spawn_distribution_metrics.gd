extends SceneTree


class FakeMapDefinition:
	extends RefCounted

	func describe_strategic_position(pos: Vector2) -> Dictionary:
		if pos.x < 10.0:
			return {
				"poi_role": "loot_hub",
				"poi_name": "Central",
				"poi_inside": true,
				"nearest_poi_role": "loot_hub",
				"route_role": "loot_flow",
				"route_on": true,
				"nearest_route_role": "loot_flow",
			}
		if pos.x < 60.0:
			return {
				"poi_role": "transit_choke",
				"poi_name": "West",
				"poi_inside": true,
				"nearest_poi_role": "transit_choke",
				"route_role": "off_route",
				"route_on": false,
				"nearest_route_role": "primary_choke",
			}
		return {
			"poi_role": "open",
			"poi_name": "none",
			"poi_inside": false,
			"nearest_poi_role": "recovery_pocket",
			"route_role": "off_route",
			"route_on": false,
			"nearest_route_role": "flank",
		}


func _init() -> void:
	var metrics_script = load("res://src/systems/match/SpawnDistributionMetrics.gd")
	var summary: Dictionary = metrics_script.summarize(
		[
			Vector3(5.0, 0.0, 0.0),
			Vector3(40.0, 0.0, 0.0),
			Vector3(80.0, 0.0, 0.0),
		],
		3,
		90.0,
		0.0,
		3.5,
		260.0,
		0,
		6,
		4,
		0,
		FakeMapDefinition.new()
	)

	if int(summary.get("placed_count", 0)) != 3:
		_fail("Spawn summary did not preserve the placed count.")
		return
	if absf(float(summary.get("avg_origin_distance", 0.0)) - 125.0 / 3.0) > 0.001:
		_fail("Spawn summary changed the average origin distance.")
		return
	if absf(float(summary.get("min_nearest_distance", 0.0)) - 35.0) > 0.001:
		_fail("Spawn summary changed nearest-neighbor distance.")
		return
	if int(summary.origin_band_counts.get("inner", 0)) != 1 \
			or int(summary.origin_band_counts.get("middle", 0)) != 1 \
			or int(summary.origin_band_counts.get("outer", 0)) != 1:
		_fail("Spawn radial bands did not classify all positions.")
		return
	if absf(float(summary.get("radial_inner_half_share", 0.0)) - 2.0 / 3.0) > 0.001:
		_fail("Spawn inner-half share is incorrect.")
		return
	if int(summary.get("inside_poi_count", 0)) != 2:
		_fail("Spawn POI occupancy count is incorrect.")
		return
	if int(summary.poi_role_counts.get("loot_hub", 0)) != 1 \
			or int(summary.poi_role_counts.get("transit_choke", 0)) != 1 \
			or int(summary.poi_role_counts.get("open", 0)) != 1:
		_fail("Spawn POI role mix is incorrect.")
		return
	if int(summary.route_role_counts.get("loot_flow", 0)) != 1 \
			or int(summary.route_role_counts.get("off_route", 0)) != 2:
		_fail("Spawn route role mix is incorrect.")
		return

	print("Spawn distribution metrics smoke passed.")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
