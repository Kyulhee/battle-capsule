class_name PlayerArtifactVisuals
extends RefCounted

const ROOT_NAME := "ArtifactVisualRoot"
const RED_TRIGGER_COLOR := Color(1.0, 0.08, 0.04, 0.42)
const ARMOR_COLOR := Color(0.35, 0.62, 1.0, 0.78)
const SILENT_COLOR := Color(0.60, 1.0, 0.72, 0.18)
const ZONE_BATTERY_COLOR := Color(0.18, 0.72, 1.0, 0.48)
const EMERGENCY_COLOR := Color(1.0, 0.72, 0.28, 0.88)
const GHOST_GRASS_COLOR := Color(0.48, 1.0, 0.42, 0.28)

var _host: Node3D = null
var _root: Node3D = null
var _artifact_id: String = ""
var _visual_id: String = ""
var _artifact_color: Color = Color.WHITE
var _time: float = 0.0
var _emergency_pack_spent: bool = false

var _red_ring: MeshInstance3D = null
var _red_light: OmniLight3D = null
var _armor_plates: Array = []
var _silent_echoes: Array = []
var _zone_nodes: Array = []
var _zone_light: OmniLight3D = null
var _emergency_pack: Node3D = null
var _rupture_shards: Array = []
var _ghost_nodes: Array = []


func attach(host: Node3D) -> void:
	_host = host
	if not _is_valid(_host):
		return
	if _is_valid(_root):
		return
	_root = Node3D.new()
	_root.name = ROOT_NAME
	_root.process_mode = Node.PROCESS_MODE_PAUSABLE
	_host.add_child(_root)


func configure(artifact: Dictionary) -> void:
	_clear_visuals()
	_artifact_id = String(artifact.get("id", ""))
	_visual_id = String(artifact.get("visual_id", _artifact_id))
	_artifact_color = artifact.get("color", Color.WHITE)
	_emergency_pack_spent = false
	if _visual_id == "" or not _is_valid(_root):
		return

	match _visual_id:
		"red_trigger":
			_create_red_trigger()
		"armor_sponge":
			_create_armor_sponge()
		"silent_core":
			_create_silent_core()
		"zone_battery":
			_create_zone_battery()
		"emergency_shell":
			_create_emergency_shell()
		"ghost_grass":
			_create_ghost_grass()


func tick(delta: float, context: Dictionary) -> void:
	if not _is_valid(_root):
		return
	_time += delta
	match _visual_id:
		"red_trigger":
			_update_red_trigger(context)
		"armor_sponge":
			_update_armor_sponge(context)
		"silent_core":
			_update_silent_core(context)
		"zone_battery":
			_update_zone_battery(context)
		"emergency_shell":
			_update_emergency_shell(context)
		"ghost_grass":
			_update_ghost_grass(context)
	_update_rupture_shards(delta)


func on_artifact_event(event: String) -> void:
	if event == "emergency_shell_triggered" and _visual_id == "emergency_shell":
		_trigger_emergency_shell_break()


func debug_state() -> Dictionary:
	return {
		"artifact_id": _artifact_id,
		"visual_id": _visual_id,
		"red_trigger_visible": _is_visible(_red_ring),
		"armor_visible_count": _visible_count(_armor_plates),
		"silent_visible_count": _visible_count(_silent_echoes),
		"zone_battery_visible": _visible_count(_zone_nodes) > 0,
		"emergency_pack_visible": _is_visible(_emergency_pack),
		"rupture_count": _rupture_shards.size(),
		"ghost_grass_visible": _visible_count(_ghost_nodes) > 0,
	}


func _create_red_trigger() -> void:
	var torus = TorusMesh.new()
	torus.inner_radius = 0.72
	torus.outer_radius = 0.82
	_red_ring = _mesh_node("RedTriggerGlow", torus, RED_TRIGGER_COLOR, Vector3(0.0, 0.08, 0.0))
	_red_ring.visible = false
	_red_light = OmniLight3D.new()
	_red_light.name = "RedTriggerLight"
	_red_light.position = Vector3(0.0, 1.0, 0.0)
	_red_light.light_color = Color(1.0, 0.1, 0.05)
	_red_light.omni_range = 3.6
	_red_light.light_energy = 0.0
	_red_light.visible = false
	_root.add_child(_red_light)


func _create_armor_sponge() -> void:
	_add_armor_plate("ArmorChest", Vector3(0.72, 0.58, 0.08), Vector3(0.0, 1.17, -0.48))
	_add_armor_plate("ArmorBack", Vector3(0.64, 0.48, 0.08), Vector3(0.0, 1.20, 0.50))
	_add_armor_plate("ArmorShoulderL", Vector3(0.24, 0.16, 0.42), Vector3(-0.52, 1.55, -0.02))
	_add_armor_plate("ArmorShoulderR", Vector3(0.24, 0.16, 0.42), Vector3(0.52, 1.55, -0.02))
	_add_armor_plate("ArmorBelt", Vector3(0.78, 0.12, 0.16), Vector3(0.0, 0.76, -0.38))


func _create_silent_core() -> void:
	for i in range(3):
		var mesh = CapsuleMesh.new()
		mesh.radius = 0.48 + 0.05 * i
		mesh.height = 1.85
		var echo = _mesh_node(
			"SilentEcho%d" % i,
			mesh,
			Color(SILENT_COLOR.r, SILENT_COLOR.g, SILENT_COLOR.b, maxf(0.05, SILENT_COLOR.a - 0.04 * i)),
			Vector3(0.0, 1.0, 0.24 + 0.20 * i)
		)
		echo.visible = false
		_silent_echoes.append(echo)


func _create_zone_battery() -> void:
	for i in range(2):
		var torus = TorusMesh.new()
		torus.inner_radius = 0.58 + 0.12 * i
		torus.outer_radius = 0.62 + 0.12 * i
		var ring = _mesh_node(
			"ZoneBatteryRing%d" % i,
			torus,
			Color(ZONE_BATTERY_COLOR.r, ZONE_BATTERY_COLOR.g, ZONE_BATTERY_COLOR.b, 0.26),
			Vector3(0.0, 0.18 + 0.48 * i, 0.0)
		)
		ring.visible = false
		_zone_nodes.append(ring)

	for i in range(4):
		var arc_mesh = BoxMesh.new()
		arc_mesh.size = Vector3(0.06, 0.08, 0.78)
		var arc = _mesh_node(
			"ZoneBatteryArc%d" % i,
			arc_mesh,
			Color(ZONE_BATTERY_COLOR.r, ZONE_BATTERY_COLOR.g, ZONE_BATTERY_COLOR.b, 0.36),
			Vector3(0.0, 0.76 + 0.12 * (i % 2), 0.0)
		)
		arc.visible = false
		_zone_nodes.append(arc)

	_zone_light = OmniLight3D.new()
	_zone_light.name = "ZoneBatteryLight"
	_zone_light.position = Vector3(0.0, 1.0, 0.0)
	_zone_light.light_color = Color(0.15, 0.70, 1.0)
	_zone_light.omni_range = 4.0
	_zone_light.light_energy = 0.0
	_zone_light.visible = false
	_root.add_child(_zone_light)


func _create_emergency_shell() -> void:
	_emergency_pack = Node3D.new()
	_emergency_pack.name = "EmergencyShellPack"
	_emergency_pack.position = Vector3(0.0, 1.18, 0.58)
	_root.add_child(_emergency_pack)

	var body = BoxMesh.new()
	body.size = Vector3(0.42, 0.58, 0.16)
	var body_node = _mesh_node("PackBody", body, EMERGENCY_COLOR, Vector3.ZERO, _emergency_pack)
	var cross_v = BoxMesh.new()
	cross_v.size = Vector3(0.09, 0.42, 0.18)
	_mesh_node("PackCrossV", cross_v, Color(1.0, 0.18, 0.12, 0.95), Vector3(0.0, 0.0, -0.02), _emergency_pack)
	var cross_h = BoxMesh.new()
	cross_h.size = Vector3(0.32, 0.08, 0.18)
	_mesh_node("PackCrossH", cross_h, Color(1.0, 0.18, 0.12, 0.95), Vector3(0.0, 0.0, -0.03), _emergency_pack)
	body_node.visible = true


func _create_ghost_grass() -> void:
	var torus = TorusMesh.new()
	torus.inner_radius = 0.66
	torus.outer_radius = 0.72
	var ring = _mesh_node("GhostGrassWake", torus, GHOST_GRASS_COLOR, Vector3(0.0, 0.10, 0.0))
	ring.visible = false
	_ghost_nodes.append(ring)
	for i in range(5):
		var mote_mesh = CylinderMesh.new()
		mote_mesh.top_radius = 0.025
		mote_mesh.bottom_radius = 0.045
		mote_mesh.height = 0.38
		mote_mesh.radial_segments = 8
		var angle = float(i) / 5.0 * PI * 2.0
		var mote = _mesh_node(
			"GhostGrassMote%d" % i,
			mote_mesh,
			Color(GHOST_GRASS_COLOR.r, GHOST_GRASS_COLOR.g, GHOST_GRASS_COLOR.b, 0.34),
			Vector3(cos(angle) * 0.58, 0.22, sin(angle) * 0.58)
		)
		mote.visible = false
		_ghost_nodes.append(mote)


func _update_red_trigger(context: Dictionary) -> void:
	var active = not bool(context.get("is_dead", false)) and String(context.get("weapon_type", "")) == "shotgun"
	if _is_valid(_red_ring):
		_red_ring.visible = active
		if active:
			var pulse = 0.5 + 0.5 * sin(_time * 8.0)
			_red_ring.scale = Vector3.ONE * (1.0 + 0.08 * pulse)
			_set_mesh_alpha(_red_ring, 0.28 + 0.18 * pulse)
	if _is_valid(_red_light):
		_red_light.visible = active
		_red_light.light_energy = 1.0 + 1.1 * (0.5 + 0.5 * sin(_time * 7.0)) if active else 0.0


func _update_armor_sponge(context: Dictionary) -> void:
	var ratio = clampf(float(context.get("shield_ratio", 0.0)), 0.0, 1.0)
	var visible_count = ceili(ratio * float(_armor_plates.size()))
	if ratio <= 0.01:
		visible_count = 0
	for i in range(_armor_plates.size()):
		var plate = _armor_plates[i]
		var active = i < visible_count and not bool(context.get("is_dead", false))
		if _is_valid(plate):
			plate.visible = active
			if active:
				_set_mesh_alpha(plate, 0.50 + 0.35 * ratio)


func _update_silent_core(context: Dictionary) -> void:
	var moving = float(context.get("move_speed", 0.0)) > 3.5 and not bool(context.get("is_crouching", false))
	var active = moving and not bool(context.get("is_dead", false))
	for i in range(_silent_echoes.size()):
		var echo = _silent_echoes[i]
		if not _is_valid(echo):
			continue
		echo.visible = active
		if active:
			var phase = _time * 5.0 - float(i) * 0.75
			echo.position.z = 0.22 + 0.22 * float(i) + 0.04 * sin(phase)
			_set_mesh_alpha(echo, maxf(0.04, 0.16 - 0.035 * i + 0.035 * sin(phase)))


func _update_zone_battery(context: Dictionary) -> void:
	var near_zone = bool(context.get("zone_battery_near", false))
	var charging = bool(context.get("zone_battery_charging", false))
	var active = near_zone and not bool(context.get("is_dead", false))
	var intensity = 1.0 if charging else 0.45
	for i in range(_zone_nodes.size()):
		var node = _zone_nodes[i]
		if not _is_valid(node):
			continue
		node.visible = active
		if active:
			node.rotation.y = _time * (1.4 + 0.18 * i)
			node.rotation.x = 0.20 * sin(_time * 3.0 + i)
			_set_mesh_alpha(node, (0.18 + 0.10 * sin(_time * 5.0 + i)) * intensity)
	if _is_valid(_zone_light):
		_zone_light.visible = active
		_zone_light.light_energy = 1.8 * intensity if active else 0.0


func _update_emergency_shell(context: Dictionary) -> void:
	if _is_valid(_emergency_pack):
		_emergency_pack.visible = not _emergency_pack_spent and not bool(context.get("is_dead", false))


func _update_ghost_grass(context: Dictionary) -> void:
	var active = bool(context.get("ghost_grass_active", false)) and not bool(context.get("is_dead", false))
	for i in range(_ghost_nodes.size()):
		var node = _ghost_nodes[i]
		if not _is_valid(node):
			continue
		node.visible = active
		if active:
			node.rotation.y = _time * (1.2 + i * 0.08)
			if i > 0:
				node.position.y = 0.20 + 0.10 * sin(_time * 5.0 + i)
			_set_mesh_alpha(node, 0.16 + 0.12 * sin(_time * 4.0 + i))


func _trigger_emergency_shell_break() -> void:
	if _emergency_pack_spent:
		return
	_emergency_pack_spent = true
	if _is_valid(_emergency_pack):
		_emergency_pack.visible = false
	for i in range(8):
		var shard_mesh = BoxMesh.new()
		shard_mesh.size = Vector3(0.08, 0.04, 0.18)
		var shard = _mesh_node("EmergencyShellShard%d" % i, shard_mesh, Color(1.0, 0.55, 0.18, 0.78), Vector3(0.0, 1.2, 0.58))
		var angle = float(i) / 8.0 * PI * 2.0
		shard.rotation = Vector3(randf() * PI, randf() * PI, randf() * PI)
		_rupture_shards.append({
			"node": shard,
			"life": 0.55 + 0.04 * i,
			"velocity": Vector3(cos(angle) * 0.85, 0.55 + 0.08 * (i % 3), sin(angle) * 0.65 + 0.20),
		})


func _update_rupture_shards(delta: float) -> void:
	var i = _rupture_shards.size() - 1
	while i >= 0:
		var shard_state: Dictionary = _rupture_shards[i]
		var shard = shard_state.get("node")
		var life = float(shard_state.get("life", 0.0)) - delta
		shard_state["life"] = life
		if life <= 0.0 or not _is_valid(shard):
			if _is_valid(shard):
				shard.queue_free()
			_rupture_shards.remove_at(i)
		else:
			shard.position += shard_state.get("velocity", Vector3.ZERO) * delta
			shard.rotation += Vector3(4.0, 2.5, 3.0) * delta
			_set_mesh_alpha(shard, clampf(life / 0.55, 0.0, 1.0) * 0.72)
		i -= 1


func _add_armor_plate(name: String, size: Vector3, position: Vector3) -> void:
	var mesh = BoxMesh.new()
	mesh.size = size
	var plate = _mesh_node(name, mesh, ARMOR_COLOR, position)
	plate.visible = false
	_armor_plates.append(plate)


func _mesh_node(
	name: String,
	mesh: Mesh,
	color: Color,
	position: Vector3,
	parent: Node3D = null
) -> MeshInstance3D:
	var node = MeshInstance3D.new()
	node.name = name
	node.mesh = mesh
	node.material_override = _material(color)
	node.position = position
	var target_parent = parent if parent != null else _root
	target_parent.add_child(node)
	return node


func _material(color: Color) -> StandardMaterial3D:
	var mat = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = Color(color.r, color.g, color.b, 1.0)
	mat.emission_energy_multiplier = 1.1
	if color.a < 0.99:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return mat


func _set_mesh_alpha(mesh: MeshInstance3D, alpha: float) -> void:
	if not _is_valid(mesh):
		return
	var mat = mesh.material_override
	if mat is BaseMaterial3D:
		var c = mat.albedo_color
		c.a = clampf(alpha, 0.0, 1.0)
		mat.albedo_color = c


func _clear_visuals() -> void:
	if _is_valid(_root):
		for child in _root.get_children():
			child.free()
	_red_ring = null
	_red_light = null
	_armor_plates.clear()
	_silent_echoes.clear()
	_zone_nodes.clear()
	_zone_light = null
	_emergency_pack = null
	_rupture_shards.clear()
	_ghost_nodes.clear()


func _is_visible(node) -> bool:
	return _is_valid(node) and bool(node.visible)


func _visible_count(nodes: Array) -> int:
	var count = 0
	for node in nodes:
		if _is_visible(node):
			count += 1
	return count


func _is_valid(node) -> bool:
	return node != null and is_instance_valid(node)
