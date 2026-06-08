extends SceneTree


const PoiProbeVerifier = preload("res://tools/PoiProbeVerifier.gd")


func _init():
	var result := PoiProbeVerifier.new().verify({
		"label": "Supply Flats POI probe",
		"path": "res://data/mapSpec_poi_supply_flats_probe.json",
		"required_poi_roles": _required_poi_roles(),
		"required_route_roles": _required_route_roles(),
		"poi_contracts": [
			{"name": "Supply Flats", "role": "loot_hub", "item_density_min": 0.78, "rare_bias_max": 0.26}
		],
		"route_contracts": [
			{"id": "supply_exposed_lane", "role": "primary_choke", "min_points": 5, "min_width": 8.5, "max_width": 9.5, "requires_alternate": true, "connects": ["Supply Flats"]},
			{"id": "ditch_reentry", "role": "recovery_exit", "min_points": 3, "min_width": 7.0, "connects": ["Drain Ditch", "Supply Flats"]}
		],
		"obstacle_rules": [
			{"label": "high hard walls", "types": ["canyon_wall"], "min_y": 3.0, "max": 0},
			{"label": "central hard cover pieces", "types": ["log_pile", "rock_cluster"], "max": 5},
			{"label": "soft cover pieces", "types": ["bush_patch", "tree_cluster"], "min": 4}
		],
		"classifications": [
			{"label": "open center", "pos": Vector2.ZERO, "poi_name": "Supply Flats", "poi_role": "loot_hub", "route_id": "supply_exposed_lane", "route_role": "primary_choke"},
			{"label": "north flank", "pos": Vector2(-12.0, 24.0), "poi_name": "North Tree Screen", "route_role": "flank"},
			{"label": "reentry", "pos": Vector2(10.0, -12.0), "route_role": "recovery_exit"}
		],
		"scale": {"max_world": 80.0, "max_bots": 12}
	})
	if bool(result.get("ok", false)):
		print(result.get("message", "Supply Flats POI probe smoke passed."))
		quit(0)
		return
	push_error(result.get("message", "Supply Flats POI probe smoke failed."))
	quit(1)


func _required_poi_roles() -> Dictionary:
	return {
		"loot_hub": 1,
		"transit_choke": 2,
		"recovery_pocket": 1,
		"concealment_field": 2,
	}


func _required_route_roles() -> Dictionary:
	return {
		"primary_choke": 1,
		"flank": 2,
		"loot_flow": 1,
		"recovery_exit": 1,
	}
