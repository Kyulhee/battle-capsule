extends RefCounted

const SKIN_NODE_NAME := "ArchetypeSkin"

const ARCHETYPE_AGGRESSIVE := 0
const ARCHETYPE_DEFENSIVE := 1
const ARCHETYPE_SNIPER := 2
const ARCHETYPE_OPPORTUNIST := 3

static func apply_skin(bot: Node3D, archetype_id: int, _seed_value: int = 0, asset_catalog = null) -> Node3D:
	if not bot:
		return null
	var old_skin = bot.get_node_or_null(SKIN_NODE_NAME)
	if old_skin:
		old_skin.queue_free()

	var root = Node3D.new()
	root.name = SKIN_NODE_NAME
	bot.add_child(root)

	var spec = _spec_for_archetype(archetype_id)
	_apply_catalog_tints(spec, archetype_id, asset_catalog)
	_add_body_band(root, spec)
	_add_archetype_decal(root, archetype_id, spec)
	_add_forward_cue(root, spec)
	return root

static func _spec_for_archetype(archetype_id: int) -> Dictionary:
	match archetype_id:
		ARCHETYPE_DEFENSIVE:
			return {
				"body": Color(0.22, 0.36, 0.86),
				"accent": Color(0.05, 0.18, 0.95),
				"dark": Color(0.02, 0.04, 0.08),
			}
		ARCHETYPE_SNIPER:
			return {
				"body": Color(0.38, 0.22, 0.72),
				"accent": Color(0.18, 0.05, 0.30),
				"dark": Color(0.02, 0.01, 0.04),
			}
		ARCHETYPE_OPPORTUNIST:
			return {
				"body": Color(0.95, 0.68, 0.18),
				"accent": Color(0.03, 0.42, 0.13),
				"dark": Color(0.02, 0.07, 0.03),
			}
		_:
			return {
				"body": Color(0.85, 0.20, 0.18),
				"accent": Color(0.92, 0.05, 0.03),
				"dark": Color(0.08, 0.02, 0.01),
			}

static func _apply_catalog_tints(spec: Dictionary, archetype_id: int, asset_catalog) -> void:
	if not asset_catalog or not asset_catalog.has_method("get_cosmetic_tint"):
		return
	var cosmetic_id = _catalog_id_for_archetype(archetype_id)
	spec["body"] = asset_catalog.get_cosmetic_tint(cosmetic_id, "body_tint", spec["body"])
	spec["accent"] = asset_catalog.get_cosmetic_tint(cosmetic_id, "accent_tint", spec["accent"])
	spec["dark"] = spec["body"].darkened(0.72)

static func _catalog_id_for_archetype(archetype_id: int) -> String:
	match archetype_id:
		ARCHETYPE_DEFENSIVE:
			return "bot.defensive"
		ARCHETYPE_SNIPER:
			return "bot.sniper"
		ARCHETYPE_OPPORTUNIST:
			return "bot.opportunist"
	return "bot.aggressive"

static func _add_body_band(root: Node3D, spec: Dictionary) -> void:
	_add_box(root, "BodyTintBand", Vector3(0.0, 1.05, -0.552), Vector3(0.62, 0.105, 0.035), spec.body)
	_add_box(root, "BodyTintCore", Vector3(0.0, 1.20, -0.556), Vector3(0.34, 0.060, 0.034), spec.dark)

static func _add_archetype_decal(root: Node3D, archetype_id: int, spec: Dictionary) -> void:
	match archetype_id:
		ARCHETYPE_DEFENSIVE:
			_add_box(root, "GuardBand", Vector3(0.0, 1.58, -0.555), Vector3(0.52, 0.09, 0.035), spec.accent)
			_add_box(root, "GuardTop", Vector3(0.0, 1.73, -0.555), Vector3(0.36, 0.06, 0.035), spec.dark)
			_add_box(root, "GuardBottom", Vector3(0.0, 1.42, -0.555), Vector3(0.36, 0.06, 0.035), spec.dark)
		ARCHETYPE_SNIPER:
			_add_box(root, "SightVertical", Vector3(0.0, 1.58, -0.558), Vector3(0.055, 0.42, 0.035), spec.accent)
			_add_box(root, "SightHorizontal", Vector3(0.0, 1.58, -0.562), Vector3(0.34, 0.055, 0.035), spec.dark)
			_add_sphere(root, "SightDot", Vector3(0.0, 1.58, -0.588), 0.065, spec.accent)
		ARCHETYPE_OPPORTUNIST:
			_add_box(root, "SlashWide", Vector3(-0.02, 1.57, -0.558), Vector3(0.48, 0.075, 0.035), spec.accent, -28.0)
			_add_box(root, "SlashShort", Vector3(0.13, 1.40, -0.562), Vector3(0.22, 0.055, 0.035), spec.dark, -28.0)
			_add_sphere(root, "MarkDot", Vector3(-0.18, 1.72, -0.586), 0.055, spec.accent)
		_:
			_add_box(root, "ChevronLeft", Vector3(-0.10, 1.58, -0.558), Vector3(0.28, 0.075, 0.035), spec.accent, 28.0)
			_add_box(root, "ChevronRight", Vector3(0.10, 1.58, -0.558), Vector3(0.28, 0.075, 0.035), spec.accent, -28.0)
			_add_box(root, "RushBar", Vector3(0.0, 1.38, -0.562), Vector3(0.34, 0.055, 0.035), spec.dark)

static func _add_forward_cue(root: Node3D, spec: Dictionary) -> void:
	_add_box(root, "ForwardTab", Vector3(0.0, 1.88, -0.56), Vector3(0.18, 0.055, 0.04), spec.accent)

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

static func _make_material(color: Color) -> StandardMaterial3D:
	var mat = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.62
	return mat
