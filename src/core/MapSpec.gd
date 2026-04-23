extends Resource

@export var metadata: Dictionary = {}
@export var pois: Array[Dictionary] = []
@export var obstacles: Array[Dictionary] = []
@export var routes: Array[Dictionary] = []

static func from_json(json_text: String) -> Resource:
	var json = JSON.new()
	var error = json.parse(json_text)
	if error != OK:
		push_error("MapSpec: JSON Parse Error at line ", json.get_error_line(), ": ", json.get_error_message())
		return null
		
	var data = json.get_data()
	var spec = (load("res://src/core/MapSpec.gd") as GDScript).new()
	spec.metadata = data.get("metadata", {})
	
	for p in data.get("pois", []):
		spec.pois.append(p)
		
	for o in data.get("obstacles", []):
		spec.obstacles.append(o)
		
	for r in data.get("routes", []):
		spec.routes.append(r)
		
	return spec

func get_world_size() -> float:
	return metadata.get("world_size", 100.0)
