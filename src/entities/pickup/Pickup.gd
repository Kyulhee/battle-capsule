extends Area3D
class_name Pickup

@export var item: ItemData

const ItemDisplayFormatterScript = preload("res://src/core/ItemDisplayFormatter.gd")
const LABEL_NAME_RANGE := 3.2
const LABEL_CLUSTER_RADIUS := 2.2

var _label: Label3D = null
var _icon_decal: MeshInstance3D = null
var _focus_marker: MeshInstance3D = null
var _catalog_icon_cache: Dictionary = {}
var _los_timer: float = 0.0
var _focused: bool = false

func _ready():
	add_to_group("pickups")
	_update_visuals()
	_update_visibility_for_player()

func _process(delta: float):
	_los_timer -= delta
	if _los_timer > 0.0: return
	_los_timer = 0.1
	_update_visibility_for_player()

func _update_visibility_for_player():
	var player = get_tree().get_first_node_in_group("players")
	var sensed = player != null and player.has_method("can_sense_item") and player.can_sense_item(global_position)
	visible = sensed
	_refresh_label_for_player(player, sensed)
	_update_focus_marker_visibility(sensed)

func set_focused(value: bool) -> void:
	if _focused == value:
		return
	_focused = value
	_refresh_label_for_player()
	_update_focus_marker_visibility(visible)

func init(data: ItemData):
	item = data
	if is_inside_tree():
		_update_visuals()

func _update_visuals():
	if item and has_node("MeshInstance3D"):
		var mesh_inst = $MeshInstance3D
		var mat = StandardMaterial3D.new()
		var base_color = _base_color_for_item()
		var visual_params = _visual_params_for_item()
		mat.albedo_color = base_color
		mat.emission_enabled = true
		mat.emission = base_color * visual_params.get("emission", 0.22)
		mesh_inst.material_override = mat
		mesh_inst.transform = Transform3D.IDENTITY
		match item.type:
			ItemData.Type.WEAPON:
				var box = BoxMesh.new()
				box.size = Vector3(0.96, 0.12, 0.58)
				mesh_inst.mesh = box
				mesh_inst.position = Vector3(0, 0.11, 0)
			ItemData.Type.AMMO:
				var ammo_disc = CylinderMesh.new()
				ammo_disc.top_radius = 0.40
				ammo_disc.bottom_radius = 0.40
				ammo_disc.height = 0.11
				ammo_disc.radial_segments = 18
				mesh_inst.mesh = ammo_disc
				mesh_inst.position = Vector3(0, 0.105, 0)
			ItemData.Type.HEAL:
				var med_plate = BoxMesh.new()
				med_plate.size = Vector3(0.64, 0.12, 0.64)
				mesh_inst.mesh = med_plate
				mesh_inst.position = Vector3(0, 0.11, 0)
			ItemData.Type.ARMOR:
				var armor_plate = CylinderMesh.new()
				armor_plate.top_radius = 0.46
				armor_plate.bottom_radius = 0.46
				armor_plate.height = 0.11
				armor_plate.radial_segments = 8
				mesh_inst.mesh = armor_plate
				mesh_inst.position = Vector3(0, 0.105, 0)
		if has_node("OmniLight3D"):
			var light = $OmniLight3D
			light.light_color = base_color
			light.light_energy = visual_params.get("light_energy", 0.8)
			light.omni_range = visual_params.get("light_range", 2.2)
		_update_focus_marker(base_color)
	_update_icon_decal()

	_update_label_node()

func _update_label_node() -> void:
	if is_instance_valid(_label):
		_label.queue_free()
		_label = null
	if not item: return

	var label = Label3D.new()
	label.name = "PickupLabel"
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = false
	label.font_size = 26
	label.pixel_size = 0.005
	label.position = Vector3(0, 1.1, 0)
	label.outline_size = 6
	label.visible = false  # hidden until LOS confirmed
	add_child(label)
	_label = label
	_refresh_label_for_player()

func _refresh_label_for_player(player: Node3D = null, sensed: bool = false) -> void:
	if not is_instance_valid(_label):
		return
	if not item:
		_label.visible = false
		return
	if player == null:
		player = get_tree().get_first_node_in_group("players")
		sensed = player != null and player.has_method("can_sense_item") and player.can_sense_item(global_position)
	if not sensed:
		_label.visible = false
		return

	var dist = player.global_position.distance_to(global_position)
	if _focused:
		_label.text = _label_detail_text()
		_label.modulate = _label_color(true)
		_label.scale = Vector3(1.08, 1.08, 1.08)
		_label.visible = true
	elif dist <= LABEL_NAME_RANGE and _should_show_cluster_label(player, dist):
		_label.text = _label_name_text()
		_label.modulate = _label_color(false)
		_label.scale = Vector3.ONE
		_label.visible = true
	else:
		_label.visible = false

func _base_color_for_item() -> Color:
	if not item:
		return Color.WHITE
	match item.type:
		ItemData.Type.WEAPON:
			return item.color.darkened(0.10)
		ItemData.Type.AMMO:
			return item.color.lightened(0.08)
		ItemData.Type.HEAL:
			return Color(0.25, 0.95, 0.45, 1.0) if item.rarity != ItemData.Rarity.RARE else Color(0.30, 1.0, 0.72, 1.0)
		ItemData.Type.ARMOR:
			return Color(0.35, 0.62, 1.0, 1.0)
	return item.color

func _visual_params_for_item() -> Dictionary:
	if not item:
		return {"emission": 0.18, "light_energy": 0.6, "light_range": 2.0}
	var high_value_color = _is_high_value_color(item.color)
	match item.type:
		ItemData.Type.WEAPON:
			if high_value_color:
				return {"emission": 0.36, "light_energy": 1.35, "light_range": 2.8}
			return {"emission": 0.18, "light_energy": 0.75, "light_range": 2.1}
		ItemData.Type.AMMO:
			if high_value_color:
				return {"emission": 0.22, "light_energy": 0.8, "light_range": 2.0}
			return {"emission": 0.10, "light_energy": 0.45, "light_range": 1.6}
		ItemData.Type.HEAL:
			if item.rarity == ItemData.Rarity.RARE:
				return {"emission": 0.34, "light_energy": 1.25, "light_range": 2.5}
			return {"emission": 0.20, "light_energy": 0.75, "light_range": 2.0}
		ItemData.Type.ARMOR:
			return {"emission": 0.34, "light_energy": 1.25, "light_range": 2.5}
	return {"emission": 0.18, "light_energy": 0.6, "light_range": 2.0}

func _is_high_value_color(color: Color) -> bool:
	var is_purple = color.r >= 0.65 and color.b >= 0.65
	var is_orange = color.r >= 0.85 and color.g >= 0.35 and color.g <= 0.75 and color.b <= 0.30
	var is_cyan = color.g >= 0.55 and color.b >= 0.75
	return is_purple or is_orange or is_cyan

func _update_focus_marker(base_color: Color) -> void:
	if not is_instance_valid(_focus_marker):
		_focus_marker = MeshInstance3D.new()
		_focus_marker.name = "FocusMarker"
		var disc = CylinderMesh.new()
		disc.top_radius = 0.54
		disc.bottom_radius = 0.54
		disc.height = 0.012
		disc.radial_segments = 36
		_focus_marker.mesh = disc
		_focus_marker.position = Vector3(0.0, 0.025, 0.0)
		add_child(_focus_marker)
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(base_color.r, base_color.g, base_color.b, 0.10)
	mat.emission_enabled = true
	mat.emission = base_color * 0.08
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_focus_marker.material_override = mat
	_focus_marker.visible = false

func _update_focus_marker_visibility(sensed: bool) -> void:
	if is_instance_valid(_focus_marker):
		_focus_marker.visible = sensed and _focused

func _label_prefix() -> String:
	return ItemDisplayFormatterScript.pickup_prefix(item)

func _label_name_text() -> String:
	return ItemDisplayFormatterScript.pickup_name(item)

func _label_detail_text() -> String:
	return ItemDisplayFormatterScript.pickup_detail(item)

func _label_color(is_focused: bool) -> Color:
	if is_focused:
		return Color(1.0, 0.95, 0.55) if item.rarity == ItemData.Rarity.RARE else Color(1.0, 1.0, 0.86)
	return Color(1.0, 0.86, 0.22) if item.rarity == ItemData.Rarity.RARE else Color(0.88, 0.90, 0.86)

func _should_show_cluster_label(player: Node3D, own_dist: float) -> bool:
	var own_key = _cluster_key()
	for other in get_tree().get_nodes_in_group("pickups"):
		if other == self or not other is Pickup:
			continue
		if not other.item or other._cluster_key() != own_key:
			continue
		if global_position.distance_to(other.global_position) > LABEL_CLUSTER_RADIUS:
			continue
		if player.has_method("can_sense_item") and not player.can_sense_item(other.global_position):
			continue
		var other_dist = player.global_position.distance_to(other.global_position)
		if other_dist < own_dist - 0.05:
			return false
	return true

func _cluster_key() -> String:
	if not item:
		return ""
	match item.type:
		ItemData.Type.WEAPON:
			if item.weapon_stats:
				return "weapon:%s" % item.weapon_stats.weapon_type
		ItemData.Type.AMMO:
			return "ammo:%s" % item.ammo_weapon_type
		ItemData.Type.HEAL:
			return "heal:%d" % item.rarity
		ItemData.Type.ARMOR:
			return "armor"
	return "%d:%s" % [item.type, item.item_name]

func _update_icon_decal():
	if is_instance_valid(_icon_decal):
		_icon_decal.queue_free()
		_icon_decal = null
	if not item:
		return

	var texture = _load_catalog_icon(_icon_id_for_item())
	if not texture:
		return

	var plane = PlaneMesh.new()
	plane.size = _icon_plane_size_for_item()

	var mat = StandardMaterial3D.new()
	mat.albedo_texture = texture
	mat.albedo_color = Color(1.0, 1.0, 1.0, 0.96)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	var decal = MeshInstance3D.new()
	decal.name = "PickupIcon"
	decal.mesh = plane
	decal.material_override = mat
	decal.position = Vector3(0.0, _icon_plane_y_for_item(), 0.0)
	add_child(decal)
	_icon_decal = decal

func _icon_plane_size_for_item() -> Vector2:
	if not item:
		return Vector2(0.48, 0.48)
	match item.type:
		ItemData.Type.WEAPON:
			return Vector2(0.72, 0.44)
		ItemData.Type.AMMO:
			return Vector2(0.52, 0.52)
		ItemData.Type.HEAL:
			return Vector2(0.50, 0.50)
		ItemData.Type.ARMOR:
			return Vector2(0.56, 0.56)
	return Vector2(0.48, 0.48)

func _icon_plane_y_for_item() -> float:
	if not item:
		return 0.18
	match item.type:
		ItemData.Type.WEAPON:
			return 0.176
		ItemData.Type.AMMO:
			return 0.166
		ItemData.Type.HEAL:
			return 0.176
		ItemData.Type.ARMOR:
			return 0.166
	return 0.18

func _icon_id_for_item() -> String:
	if not item:
		return ""
	match item.type:
		ItemData.Type.WEAPON:
			if item.weapon_stats:
				return "weapon.%s" % item.weapon_stats.weapon_type
		ItemData.Type.AMMO:
			if item.ammo_weapon_type != "":
				return "ammo.%s" % item.ammo_weapon_type
		ItemData.Type.HEAL:
			return "item.medkit" if item.rarity == ItemData.Rarity.RARE else "item.heal"
		ItemData.Type.ARMOR:
			return "item.armor"
	return ""

func _load_catalog_icon(icon_id: String) -> Texture2D:
	if icon_id == "":
		return null
	if _catalog_icon_cache.has(icon_id):
		return _catalog_icon_cache[icon_id]

	var texture: Texture2D = null
	var main = get_tree().root.get_node_or_null("Main")
	if main:
		var catalog = main.get("asset_catalog")
		if catalog and catalog.has_method("get_path"):
			var path = catalog.get_path("icons", icon_id, "")
			if path != "" and ResourceLoader.exists(path):
				var loaded = load(path)
				if loaded is Texture2D:
					texture = loaded
			elif path != "" and FileAccess.file_exists(path):
				var image = Image.new()
				if image.load(path) == OK:
					texture = ImageTexture.create_from_image(image)

	_catalog_icon_cache[icon_id] = texture
	return texture

func collect(collector: Entity) -> bool:
	if not item: return false

	print(collector.name, " collected ", item.item_name)
	_debug_log("loot", "%s collected %s type=%s pos=(%.1f,%.1f)" % [
		collector.display_name if collector.display_name != "" else collector.name,
		item.item_name,
		ItemData.Type.keys()[item.type],
		global_position.x,
		global_position.z,
	])

	if has_node("/root/Telemetry"):
		var type_name = ItemData.Type.keys()[item.type].to_lower()
		var item_key = item.item_name
		if type_name == "weapon":
			if item_key.to_lower() == "ar": item_key = "assault_rifle"
		get_node("/root/Telemetry").log_pickup(item_key, type_name, item.rarity == ItemData.Rarity.RARE)

	match item.type:
		ItemData.Type.AMMO:
			if item.ammo_weapon_type != "" and collector.has_method("receive_ammo"):
				collector.receive_ammo(item.ammo_weapon_type, item.amount)
			else:
				# Bot fallback or legacy generic ammo
				collector.stats.current_ammo = min(collector.stats.max_ammo, collector.stats.current_ammo + item.amount)
			print("Collected Ammo: ", item.amount, " (", item.ammo_weapon_type, ")")
		ItemData.Type.HEAL:
			var _main = collector.get_tree().root.get_node_or_null("Main")
			if _main and _main.heal_pickup_banned and collector.is_in_group("players"):
				return false  # 힐 픽업 금지 패널티 중
			if item.rarity == ItemData.Rarity.RARE:
				collector.stats.advanced_heals += item.amount
				print("Collected MedKit: ", item.amount)
			else:
				collector.stats.heal_items += item.amount
				print("Collected Heal: ", item.amount)
		ItemData.Type.ARMOR:
			if collector.has_method("receive_shield"):
				collector.receive_shield(item.amount)
			else:
				collector.current_shield = min(collector.stats.max_shield, collector.current_shield + item.amount)
				collector.shield_changed.emit(collector.current_shield, collector.stats.max_shield)
			print("Collected Armor: ", item.amount)
		ItemData.Type.WEAPON:
			if item.weapon_stats:
				if collector.has_method("receive_weapon"):
					if not collector.receive_weapon(item.weapon_stats):
						return false  # duplicate weapon type — leave on ground
				else:
					# Bot fallback: direct stats copy
					collector.stats.weapon_type   = item.weapon_stats.weapon_type
					collector.stats.pellet_count  = item.weapon_stats.pellet_count
					collector.stats.attack_damage = item.weapon_stats.attack_damage
					collector.stats.fire_rate     = item.weapon_stats.fire_rate
					collector.stats.attack_range  = item.weapon_stats.attack_range
					if item.weapon_stats.max_ammo > 0:
						collector.stats.max_ammo = item.weapon_stats.max_ammo
					collector.stats.current_ammo = item.weapon_stats.current_ammo
				print("Picked up weapon: ", item.item_name)

	queue_free()
	return true

func _debug_log(flag: String, message: String) -> void:
	var main = get_tree().root.get_node_or_null("Main")
	if main and main.has_method("debug_log"):
		main.debug_log(flag, message)
