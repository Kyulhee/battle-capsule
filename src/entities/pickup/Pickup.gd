extends Area3D
class_name Pickup

@export var item: ItemData

var _label: Label3D = null
var _los_timer: float = 0.0

func _ready():
	add_to_group("pickups")
	_update_visuals()

func _process(delta: float):
	if not _label: return
	_los_timer -= delta
	if _los_timer > 0.0: return
	_los_timer = 0.1
	var player = get_tree().get_first_node_in_group("players") as Node3D
	if not player:
		_label.visible = false
		return
	var space = get_world_3d().direct_space_state
	var from = player.global_position + Vector3(0, 0.8, 0)
	var to   = global_position + Vector3(0, 0.5, 0)
	var query = PhysicsRayQueryParameters3D.create(from, to, 1)
	query.exclude = [player.get_rid()]
	var hit = space.intersect_ray(query)
	_label.visible = hit.is_empty()

func init(data: ItemData):
	item = data
	if is_inside_tree():
		_update_visuals()

func _update_visuals():
	if item and has_node("MeshInstance3D"):
		var mesh_inst = $MeshInstance3D
		var mat = StandardMaterial3D.new()
		mat.albedo_color = item.color
		mat.emission_enabled = true
		mat.emission = item.color * 0.5
		mesh_inst.material_override = mat
		mesh_inst.transform = Transform3D.IDENTITY
		match item.type:
			ItemData.Type.WEAPON:
				var box = BoxMesh.new(); box.size = Vector3(0.75, 0.12, 0.45)
				mesh_inst.mesh = box
				mesh_inst.position = Vector3(0, 0.12, 0)
			ItemData.Type.AMMO:
				var sphere = SphereMesh.new(); sphere.radius = 0.15; sphere.height = 0.3
				mesh_inst.mesh = sphere
				mesh_inst.position = Vector3(0, 0.18, 0)
			ItemData.Type.HEAL:
				# Capsule = pill shape, universally understood as medicine
				var cap = CapsuleMesh.new(); cap.radius = 0.14; cap.height = 0.42
				mesh_inst.mesh = cap
				mesh_inst.position = Vector3(0, 0.25, 0)
			ItemData.Type.ARMOR:
				# Thin disc = armour plate
				var cyl = CylinderMesh.new()
				cyl.top_radius = 0.28; cyl.bottom_radius = 0.28; cyl.height = 0.07
				mesh_inst.mesh = cyl
				mesh_inst.position = Vector3(0, 0.07, 0)
		if has_node("OmniLight3D"):
			$OmniLight3D.light_color = item.color

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
