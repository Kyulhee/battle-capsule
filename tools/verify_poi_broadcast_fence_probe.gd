extends SceneTree


const PoiProbeVerifier = preload("res://tools/PoiProbeVerifier.gd")


func _init():
	var result := PoiProbeVerifier.new().verify({
		"label": "Broadcast Fence POI probe",
		"path": "res://data/mapSpec_poi_broadcast_fence_probe.json",
		"required_poi_roles": _required_poi_roles(),
		"required_route_roles": _required_route_roles(),
		"poi_contracts": [
			{"name": "Broadcast Fence", "role": "transit_choke", "item_density_max": 0.66, "rare_bias_max": 0.24}
		],
		"route_contracts": [
			{"id": "broadcast_gate_lane", "role": "primary_choke", "min_points": 5, "min_width": 8.0, "max_width": 9.5, "requires_alternate": true, "connects": ["Broadcast Fence"]},
			{"id": "fuse_reentry", "role": "recovery_exit", "min_points": 3, "min_width": 7.0, "connects": ["Fuse Shelter", "Broadcast Fence"]}
		],
		"obstacle_rules": [
			{"label": "fence/log segments", "types": ["log_pile"], "min": 5, "max": 7},
			{"label": "high hard walls", "types": ["canyon_wall"], "min_y": 3.0, "max": 2},
			{"label": "soft cover pieces", "types": ["bush_patch", "tree_cluster"], "min": 4}
		],
		"classifications": [
			{"label": "broadcast gate", "pos": Vector2(0.0, 4.0), "poi_name": "Broadcast Fence", "poi_role": "transit_choke", "route_id": "broadcast_gate_lane", "route_role": "primary_choke"},
			{"label": "north flank", "pos": Vector2(-10.0, 26.0), "poi_name": "North Screen Pines", "route_role": "flank"},
			{"label": "fuse reentry", "pos": Vector2(10.0, -14.0), "route_role": "recovery_exit"}
		],
		"scale": {"max_world": 82.0, "max_bots": 12}
	})
	if bool(result.get("ok", false)):
		print(result.get("message", "Broadcast Fence POI probe smoke passed."))
		quit(0)
		return
	push_error(result.get("message", "Broadcast Fence POI probe smoke failed."))
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
