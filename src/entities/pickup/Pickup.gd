extends Area3D
class_name Pickup

@export var item: ItemData

var _label: Label3D = null
var _icon_decal: MeshInstance3D = null
var _catalog_icon_cache: Dictionary = {}
var _los_timer: float = 0.0

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
	if _label:
		_label.visible = sensed

func init(data: ItemData):
	item = data
	if is_inside_tree():
		_update_visuals()

func _update_visuals():
	if item and has_node("MeshInstance3D"):
		var mesh_inst = $MeshInstance3D
		var mat = StandardMaterial3D.new()
		var base_color = _base_color_for_item()
		mat.albedo_color = base_color
		mat.emission_enabled = true
		mat.emission = base_color * 0.42
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
			$OmniLight3D.light_color = base_color
	_update_icon_decal()

	var existing = get_node_or_null("PickupLabel")
	if existing:
		existing.queue_free()
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

	# Unicode prefix makes type immediately clear without adding a separate node
	var prefix = ""
	match item.type:
		ItemData.Type.HEAL:
			prefix = ("◆ " if item.rarity == ItemData.Rarity.RARE else "♥ ")
		ItemData.Type.ARMOR:
			prefix = "◈ "
		ItemData.Type.AMMO:
			prefix = "● "
		ItemData.Type.WEAPON:
			prefix = ""  # name alone is distinctive enough

	var display_text = prefix + item.item_name
	if item.type == ItemData.Type.WEAPON and item.weapon_stats:
		display_text += "\n%d/%d" % [item.weapon_stats.current_ammo, item.weapon_stats.max_ammo]
	elif item.type == ItemData.Type.AMMO and item.ammo_weapon_type != "":
		display_text += " +%d" % item.amount

	label.text = display_text
	label.modulate = Color.GOLD if item.rarity == ItemData.Rarity.RARE else Color.WHITE
	add_child(label)
	_label = label

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
