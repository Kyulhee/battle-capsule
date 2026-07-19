extends SceneTree


const REQUIRED_PROPS := {
	"forest.bush": "res://assets/props/forest/bush_dense.glb",
	"forest.bush.low": "res://assets/props/forest/bush_low.glb",
	"forest.bush.dense": "res://assets/props/forest/bush_dense.glb",
	"forest.tree": "res://assets/props/forest/tree_cluster.glb",
	"landmark.cabin": "res://assets/props/landmarks/cabin.glb",
	"landmark.wall": "res://assets/props/landmarks/ruined_wall.glb",
	"landmark.crate": "res://assets/props/landmarks/camp_crate.glb",
	"landmark.barrels": "res://assets/props/landmarks/barrel_cluster.glb",
	"landmark.fire_pit": "res://assets/props/landmarks/fire_pit.glb",
}

const EXPECTED_WORLD_PROP_COUNTS := {
	"forest.tree": 6,
	"landmark.cabin": 3,
	"landmark.wall": 2,
	"landmark.crate": 3,
	"landmark.barrels": 2,
	"landmark.fire_pit": 1,
}


func _init():
	var asset_catalog_script = load("res://src/core/AssetCatalog.gd")
	var map_spec_script = load("res://src/core/MapSpec.gd")
	var world_builder_script = load("res://src/maps/WorldBuilder.gd")

	var asset_catalog = asset_catalog_script.new()
	asset_catalog.load_or_default()

	for prop_id in REQUIRED_PROPS.keys():
		var expected_path := String(REQUIRED_PROPS[prop_id])
		var path := String(asset_catalog.get_path("props", prop_id, ""))
		if path != expected_path:
			_fail("%s catalog path mismatch: expected %s, got %s." % [prop_id, expected_path, path])
			return
		var instance := _instantiate_prop_node(prop_id, path)
		if instance == null:
			return
		var mesh_count := _count_mesh_instances(instance)
		instance.queue_free()
		if mesh_count <= 0:
			_fail("%s has no MeshInstance3D nodes." % prop_id)
			return
		print("%s prop: path='%s' meshes=%d" % [prop_id, path, mesh_count])

	var spec_file = FileAccess.open(
		"res://data/mapSpec_night_forest_expanded_candidate.json",
		FileAccess.READ
	)
	if spec_file == null:
		_fail("Could not open expanded Night map.")
		return
	var spec = map_spec_script.from_json(spec_file.get_as_text())
	if spec == null:
		_fail("Could not parse expanded Night map.")
		return

	var builder = world_builder_script.new()
	root.add_child(builder)
	builder.generate_world(spec, asset_catalog)

	var bushes = builder.find_children("*", "Area3D", true, false)
	if bushes.is_empty():
		_fail("Generated world has no bush Area3D nodes.")
		return

	for bush in bushes:
		var fallback_mesh := bush.get_node_or_null("MeshInstance3D") as MeshInstance3D
		if fallback_mesh == null:
			_fail("Generated bush is missing fallback MeshInstance3D.")
			return
		if fallback_mesh.visible:
			_fail("Generated bush fallback mesh stayed visible after catalog visual load.")
			return
		var visual := bush.get_node_or_null("CatalogPropVisual") as Node3D
		if visual == null:
			_fail("Generated bush is missing CatalogPropVisual child.")
			return
		if String(visual.get_meta("prop_id", "")) != "forest.bush":
			_fail("Generated bush visual prop_id mismatch.")
			return
		var state: Dictionary = bush.debug_state()
		if int(state.get("rustle_chunk_count", 0)) <= 0:
			_fail("Generated catalog bush did not register rustle chunks.")
			return

	var prop_counts := {}
	var catalog_visuals = builder.find_children("CatalogPropVisual", "Node3D", true, false)
	for visual in catalog_visuals:
		var prop_id := String(visual.get_meta("prop_id", ""))
		prop_counts[prop_id] = int(prop_counts.get(prop_id, 0)) + 1
	for prop_id in EXPECTED_WORLD_PROP_COUNTS:
		var expected_count := int(EXPECTED_WORLD_PROP_COUNTS[prop_id])
		var actual_count := int(prop_counts.get(prop_id, 0))
		if actual_count != expected_count:
			_fail("%s world count mismatch: expected %d, got %d." % [
				prop_id,
				expected_count,
				actual_count,
			])
			return

	var surface_container: Node = builder.get_node_or_null("GeneratedSurfaceZones")
	if surface_container == null or surface_container.get_child_count() <= 0:
		_fail("Expanded Night world did not build surface zones.")
		return
	if surface_container.get_child_count() > 3:
		_fail("Surface zones were not merged by material: %d render nodes." % (
			surface_container.get_child_count()
		))
		return
	for child in surface_container.get_children():
		if not (child is MeshInstance3D):
			_fail("Merged surface container contains a non-mesh child.")
			return
	var ground_feature_count := 0
	for feature in builder.get_minimap_features():
		if String(feature.get("type", "")).begins_with("ground."):
			ground_feature_count += 1
	if ground_feature_count != spec.surface_zones.size():
		_fail("Expected %d surface map features, got %d." % [
			spec.surface_zones.size(),
			ground_feature_count,
		])
		return

	var fire_visual: Node3D = null
	for visual in catalog_visuals:
		if String(visual.get_meta("prop_id", "")) == "landmark.fire_pit":
			fire_visual = visual
			break
	if fire_visual == null or not (fire_visual.get_parent() is CollisionObject3D):
		_fail("Fire pit visual is missing its collision proxy parent.")
		return
	var fire_parent := fire_visual.get_parent() as CollisionObject3D
	if fire_parent.collision_layer != 0:
		_fail("Visual-only fire pit must not block navigation.")
		return

	print("World prop asset smoke passed: visuals=%d surfaces=%d render_nodes=%d bushes=%d." % [
		catalog_visuals.size(),
		spec.surface_zones.size(),
		surface_container.get_child_count(),
		bushes.size(),
	])
	quit(0)


func _instantiate_prop_node(prop_id: String, path: String) -> Node3D:
	if not FileAccess.file_exists(path):
		_fail("%s runtime file missing: %s." % [prop_id, path])
		return null
	if ResourceLoader.exists(path):
		var resource = load(path)
		if resource is PackedScene:
			var instance = resource.instantiate()
			if instance is Node3D:
				return instance
			if instance:
				instance.queue_free()
			_fail("%s root is not Node3D." % prop_id)
			return null
	if path.get_extension().to_lower() == "glb":
		var document := GLTFDocument.new()
		var state := GLTFState.new()
		var error := document.append_from_file(path, state)
		if error != OK:
			_fail("%s raw GLB import failed from %s (error %d)." % [prop_id, path, error])
			return null
		var scene = document.generate_scene(state)
		if scene is Node3D:
			return scene
		if scene:
			scene.queue_free()
		_fail("%s raw GLB root is not Node3D." % prop_id)
		return null
	_fail("%s did not load as a prop scene from %s." % [prop_id, path])
	return null


func _count_mesh_instances(node: Node) -> int:
	var count := 1 if node is MeshInstance3D else 0
	for child in node.get_children():
		count += _count_mesh_instances(child)
	return count


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
