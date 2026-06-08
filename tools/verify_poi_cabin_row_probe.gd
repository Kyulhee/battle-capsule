extends SceneTree


const PoiProbeVerifier = preload("res://tools/PoiProbeVerifier.gd")


func _init():
	var result := PoiProbeVerifier.new().verify({
		"label": "Cabin Row POI probe",
		"path": "res://data/mapSpec_poi_cabin_row_probe.json",
		"required_poi_roles": _required_poi_roles(),
		"required_route_roles": _required_route_roles(),
		"poi_contracts": [
			{"name": "Cabin Row", "role": "concealment_field", "item_density_max": 0.45, "rare_bias_max": 0.12}
		],
		"route_contracts": [
			{"id": "cabin_door_lane", "role": "primary_choke", "min_points": 5, "min_width": 7.5, "max_width": 8.5, "requires_alternate": true, "connects": ["Cabin Door Bend"]},
			{"id": "shed_reentry", "role": "recovery_exit", "min_points": 3, "min_width": 7.0, "connects": ["Tool Shed Hollow", "Cabin Door Bend"]}
		],
		"obstacle_rules": [
			{"label": "facade wall segments", "types": ["canyon_wall"], "min_y": 3.0, "min": 2, "max": 4},
			{"label": "bush concealment pieces", "types": ["bush_patch"], "min": 2, "max": 4},
			{"label": "hard cover pieces", "types": ["canyon_wall", "log_pile", "rock_cluster"], "max": 8}
		],
		"classifications": [
			{"label": "door lane", "pos": Vector2.ZERO, "poi_name": "Cabin Door Bend", "route_id": "cabin_door_lane", "route_role": "primary_choke"},
			{"label": "cabin row", "pos": Vector2(-10.0, 24.0), "poi_name": "Cabin Row", "poi_role": "concealment_field", "route_role": "flank"},
			{"label": "shed reentry", "pos": Vector2(10.0, -12.0), "route_role": "recovery_exit"}
		],
		"scale": {"max_world": 80.0, "max_bots": 12}
	})
	if bool(result.get("ok", false)):
		print(result.get("message", "Cabin Row POI probe smoke passed."))
		quit(0)
		return
	push_error(result.get("message", "Cabin Row POI probe smoke failed."))
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
