extends RefCounted

const SKIN_NODE_NAME := "ArchetypeSkin"

const ARCHETYPE_AGGRESSIVE := 0
const ARCHETYPE_DEFENSIVE := 1
const ARCHETYPE_SNIPER := 2
const ARCHETYPE_OPPORTUNIST := 3

static func apply_skin(bot: Node3D, archetype_id: int, seed_value: int = 0) -> Node3D:
	if not bot:
		return null
	var old_skin = bot.get_node_or_null(SKIN_NODE_NAME)
	if old_skin:
		old_skin.queue_free()

	var rng = RandomNumberGenerator.new()
	rng.seed = abs(seed_value * 7919 + archetype_id * 104729)

	var root = Node3D.new()
	root.name = SKIN_NODE_NAME
	bot.add_child(root)

	var spec = _spec_for_archetype(archetype_id)
	_add_face_panel(root, spec)
	_add_archetype_face(root, archetype_id, spec)
	_add_head_variant(root, rng.randi_range(0, 4), spec)
	_add_forward_cue(root, spec)
	return root

static func _spec_for_archetype(archetype_id: int) -> Dictionary:
	match archetype_id:
		ARCHETYPE_DEFENSIVE:
			return {
				"body": Color(0.25, 0.48, 1.0),
				"accent": Color(0.05, 0.18, 0.95),
				"dark": Color(0.02, 0.04, 0.08),
				"face": Color(1.0, 0.83, 0.46),
				"hair": Color(0.14, 0.09, 0.04),
			}
		ARCHETYPE_SNIPER:
			return {
				"body": Color(0.58, 0.34, 0.86),
				"accent": Color(0.18, 0.05, 0.30),
				"dark": Color(0.02, 0.01, 0.04),
				"face": Color(0.94, 0.78, 0.45),
				"hair": Color(0.06, 0.05, 0.08),
			}
		ARCHETYPE_OPPORTUNIST:
			return {
				"body": Color(0.25, 0.78, 0.35),
				"accent": Color(0.03, 0.42, 0.13),
				"dark": Color(0.02, 0.07, 0.03),
				"face": Color(1.0, 0.84, 0.45),
				"hair": Color(0.20, 0.12, 0.04),
			}
		_:
			return {
				"body": Color(1.0, 0.32, 0.22),
				"accent": Color(0.92, 0.05, 0.03),
				"dark": Color(0.08, 0.02, 0.01),
				"face": Color(1.0, 0.82, 0.42),
				"hair": Color(0.10, 0.06, 0.02),
			}

static func _add_face_panel(root: Node3D, spec: Dictionary) -> void:
	_add_box(root, "FacePanel", Vector3(0.0, 1.50, -0.535), Vector3(0.50, 0.42, 0.035), spec.face)

static func _add_archetype_face(root: Node3D, archetype_id: int, spec: Dictionary) -> void:
	match archetype_id:
		ARCHETYPE_DEFENSIVE:
			_add_box(root, "LeftGoggle", Vector3(-0.13, 1.56, -0.565), Vector3(0.16, 0.09, 0.035), spec.dark)
			_add_box(root, "RightGoggle", Vector3(0.13, 1.56, -0.565), Vector3(0.16, 0.09, 0.035), spec.dark)
			_add_box(root, "GoggleBridge", Vector3(0.0, 1.56, -0.568), Vector3(0.08, 0.035, 0.035), spec.accent)
			_add_box(root, "CalmMouth", Vector3(0.0, 1.36, -0.565), Vector3(0.22, 0.035, 0.035), spec.dark)
			_add_box(root, "BrowPlate", Vector3(0.0, 1.71, -0.56), Vector3(0.42, 0.055, 0.035), spec.accent)
		ARCHETYPE_SNIPER:
			_add_box(root, "Visor", Vector3(0.0, 1.58, -0.565), Vector3(0.42, 0.105, 0.035), spec.dark)
			_add_box(root, "Lens", Vector3(0.14, 1.58, -0.59), Vector3(0.13, 0.075, 0.035), spec.accent)
			_add_box(root, "FocusLine", Vector3(-0.10, 1.36, -0.565), Vector3(0.18, 0.035, 0.035), spec.dark, -8.0)
			_add_box(root, "ForeheadSight", Vector3(0.0, 1.75, -0.56), Vector3(0.08, 0.16, 0.035), spec.accent)
		ARCHETYPE_OPPORTUNIST:
			_add_box(root, "LeftEye", Vector3(-0.13, 1.57, -0.565), Vector3(0.105, 0.075, 0.035), spec.dark, 8.0)
			_add_box(root, "RightEye", Vector3(0.13, 1.57, -0.565), Vector3(0.105, 0.075, 0.035), spec.dark, -8.0)
			_add_box(root, "SmirkA", Vector3(-0.045, 1.36, -0.565), Vector3(0.13, 0.035, 0.035), spec.dark, -8.0)
			_add_box(root, "SmirkB", Vector3(0.08, 1.37, -0.565), Vector3(0.12, 0.035, 0.035), spec.dark, 10.0)
			_add_box(root, "GreenMask", Vector3(0.0, 1.48, -0.558), Vector3(0.44, 0.05, 0.035), spec.accent)
		_:
			_add_box(root, "LeftAngryEye", Vector3(-0.13, 1.56, -0.565), Vector3(0.13, 0.065, 0.035), spec.dark, -15.0)
			_add_box(root, "RightAngryEye", Vector3(0.13, 1.56, -0.565), Vector3(0.13, 0.065, 0.035), spec.dark, 15.0)
			_add_box(root, "Frown", Vector3(0.0, 1.35, -0.565), Vector3(0.22, 0.035, 0.035), spec.dark, 7.0)
			_add_box(root, "WarPaint", Vector3(0.0, 1.69, -0.56), Vector3(0.38, 0.05, 0.035), spec.accent)

static func _add_head_variant(root: Node3D, variant: int, spec: Dictionary) -> void:
	match variant:
		0:
			_add_cylinder(root, "CapTop", Vector3(0.0, 2.07, 0.0), 0.42, 0.13, spec.hair)
			_add_box(root, "CapBrim", Vector3(0.0, 2.02, -0.42), Vector3(0.48, 0.055, 0.22), spec.hair)
		1:
			_add_box(root, "HairSweepA", Vector3(-0.12, 2.05, -0.15), Vector3(0.34, 0.16, 0.34), spec.hair, -8.0)
			_add_box(root, "HairSweepB", Vector3(0.16, 2.02, -0.11), Vector3(0.24, 0.12, 0.28), spec.hair, 12.0)
		2:
			_add_box(root, "HeadBand", Vector3(0.0, 1.93, -0.20), Vector3(0.58, 0.08, 0.12), spec.accent)
			_add_sphere(root, "LeftEarpiece", Vector3(-0.44, 1.88, 0.0), 0.11, spec.dark)
			_add_sphere(root, "RightEarpiece", Vector3(0.44, 1.88, 0.0), 0.11, spec.dark)
		3:
			_add_box(root, "FlatHair", Vector3(0.0, 2.03, -0.02), Vector3(0.58, 0.12, 0.46), spec.hair)
			_add_box(root, "SideLock", Vector3(-0.34, 1.86, -0.14), Vector3(0.12, 0.28, 0.18), spec.hair)
		_:
			_add_sphere(root, "TopKnot", Vector3(0.0, 2.13, -0.04), 0.15, spec.hair)
			_add_box(root, "TinyBrim", Vector3(0.0, 2.01, -0.38), Vector3(0.36, 0.05, 0.15), spec.hair)

static func _add_forward_cue(root: Node3D, spec: Dictionary) -> void:
	_add_box(root, "NoseCue", Vector3(0.0, 1.46, -0.595), Vector3(0.045, 0.11, 0.055), spec.accent)

static func _add_box(root: Node3D, name: String, pos: Vector3, size: Vector3, color: Color, rot_z_deg: float = 0.0) -> MeshInstance3D:
	var mesh = BoxMesh.new()
	mesh.size = size
	var mat = _make_material(color)
	mesh.material = mat
	var inst = MeshInstance3D.new()
	inst.name = name
	inst.mesh = mesh
	inst.material_override = mat
	inst.position = pos
	inst.rotation_degrees = Vector3(0.0, 0.0, rot_z_deg)
	root.add_child(inst)
	return inst

static func _add_sphere(root: Node3D, name: String, pos: Vector3, radius: float, color: Color) -> MeshInstance3D:
	var mesh = SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 12
	mesh.rings = 6
	var mat = _make_material(color)
	mesh.material = mat
	var inst = MeshInstance3D.new()
	inst.name = name
	inst.mesh = mesh
	inst.material_override = mat
	inst.position = pos
	root.add_child(inst)
	return inst

static func _add_cylinder(root: Node3D, name: String, pos: Vector3, radius: float, height: float, color: Color) -> MeshInstance3D:
	var mesh = CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 16
	var mat = _make_material(color)
	mesh.material = mat
	var inst = MeshInstance3D.new()
	inst.name = name
	inst.mesh = mesh
	inst.material_override = mat
	inst.position = pos
	root.add_child(inst)
	return inst

static func _make_material(color: Color) -> StandardMaterial3D:
	var mat = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.62
	return mat
