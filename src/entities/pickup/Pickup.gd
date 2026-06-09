extends Area3D
class_name Pickup

@export var item: ItemData

const ItemDisplayFormatterScript = preload("res://src/core/ItemDisplayFormatter.gd")
const PickupPresentationScript = preload("res://src/entities/pickup/PickupPresentation.gd")
const PickupIconResolverScript = preload("res://src/entities/pickup/PickupIconResolver.gd")

var _label: Label3D = null
var _icon_decal: MeshInstance3D = null
var _focus_marker: MeshInstance3D = null
var _icon_resolver = PickupIconResolverScript.new()
var _los_timer: float = 0.0
var _focused: bool = false
var _light: OmniLight3D = null
var _light_base_energy: float = 0.0
var _light_base_range: float = 0.0

func _ready():
	add_to_group("pickups")
	_update_visuals()
	_update_visibility_for_player()

func _process(delta: float):
	_los_timer -= delta
	if _los_timer > 0.0: return
	_los_timer = PickupPresentationScript.VISIBILITY_REFRESH_INTERVAL
	_update_visibility_for_player()

func _update_visibility_for_player():
	var player = get_tree().get_first_node_in_group("players")
	var sensed = player != null and player.has_method("can_sense_item") and player.can_sense_item(global_position)
	visible = sensed
	_refresh_label_for_player(player, sensed)
	_update_focus_marker_visibility(sensed)
	_update_light_lod(player, sensed)

func set_focused(value: bool) -> void:
	if _focused == value:
		return
	_focused = value
	_refresh_label_for_player()
	_update_focus_marker_visibility(visible)
	_update_light_lod(get_tree().get_first_node_in_group("players"), visible)

func init(data: ItemData):
	item = data
	if is_inside_tree():
		_update_visuals()

func _update_visuals():
	if item and has_node("MeshInstance3D"):
		var mesh_inst = $MeshInstance3D
		var mat = StandardMaterial3D.new()
		var base_color = PickupPresentationScript.base_color(item)
		var visual_params = PickupPresentationScript.visual_params(item)
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
			_light = $OmniLight3D
			_light.light_color = base_color
			_light_base_energy = visual_params.get("light_energy", 0.8)
			_light_base_range = visual_params.get("light_range", 2.2)
			_light.light_energy = _light_base_energy
			_light.omni_range = _light_base_range
		_update_focus_marker(base_color)
	_update_icon_decal()

	_update_label_node()

func _update_light_lod(player: Node = null, sensed: bool = false) -> void:
	if not is_instance_valid(_light):
		return
	if not sensed or not (player is Node3D):
		_light.visible = false
		return

	var player_3d := player as Node3D
	var dist := player_3d.global_position.distance_to(global_position)
	if _focused or dist <= PickupPresentationScript.LIGHT_LOD_FULL_DISTANCE:
		_light.visible = true
		_light.light_energy = _light_base_energy
		_light.omni_range = _light_base_range
	elif dist <= PickupPresentationScript.LIGHT_LOD_DIM_DISTANCE:
		_light.visible = true
		_light.light_energy = _light_base_energy * PickupPresentationScript.LIGHT_LOD_DIM_ENERGY_MULT
		_light.omni_range = _light_base_range * PickupPresentationScript.LIGHT_LOD_DIM_RANGE_MULT
	else:
		_light.visible = false

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
		_label.modulate = PickupPresentationScript.label_color(item, true)
		_label.scale = PickupPresentationScript.FOCUSED_LABEL_SCALE
		_label.visible = true
	elif dist <= PickupPresentationScript.LABEL_NAME_RANGE and _should_show_cluster_label(player, dist):
		_label.text = _label_name_text()
		_label.modulate = PickupPresentationScript.label_color(item, false)
		_label.scale = PickupPresentationScript.NORMAL_LABEL_SCALE
		_label.visible = true
	else:
		_label.visible = false

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

func _should_show_cluster_label(player: Node3D, own_dist: float) -> bool:
	var own_key = _cluster_key()
	for other in get_tree().get_nodes_in_group("pickups"):
		if other == self or not other is Pickup:
			continue
		if not other.item or other._cluster_key() != own_key:
			continue
		if global_position.distance_to(other.global_position) > PickupPresentationScript.LABEL_CLUSTER_RADIUS:
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

	var texture = _icon_resolver.texture_for_item(item, _asset_catalog())
	if not texture:
		return

	var plane = PlaneMesh.new()
	plane.size = PickupPresentationScript.icon_plane_size(item)

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
	decal.position = Vector3(0.0, PickupPresentationScript.icon_plane_y(item), 0.0)
	add_child(decal)
	_icon_decal = decal

func _asset_catalog():
	var main = get_tree().root.get_node_or_null("Main")
	if main:
		return main.get("asset_catalog")
	return null

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

	_log_pickup_location("collect")
	queue_free()
	return true

func _log_pickup_location(event_name: String) -> void:
	if not item or not has_node("/root/Telemetry"):
		return
	var tel = get_node("/root/Telemetry")
	if not tel.has_method("log_pickup_location"):
		return
	tel.log_pickup_location(
		event_name,
		ItemData.Type.keys()[item.type].to_lower(),
		_strategic_position_context()
	)

func log_spawn_location() -> void:
	_log_pickup_location("spawn")

func _strategic_position_context() -> Dictionary:
	var context := {
		"poi_role": "open",
		"poi_name": "none",
		"route_role": "off_route",
		"route_id": "off_route",
	}
	var main = get_tree().root.get_node_or_null("Main")
	if not main:
		return context
	var definition = main.get("map_definition")
	if definition and definition.has_method("describe_strategic_position"):
		return definition.describe_strategic_position(Vector2(global_position.x, global_position.z))
	return context

func _debug_log(flag: String, message: String) -> void:
	var main = get_tree().root.get_node_or_null("Main")
	if main and main.has_method("debug_log"):
		main.debug_log(flag, message)
