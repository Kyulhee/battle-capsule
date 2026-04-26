extends Area3D
class_name Pickup

@export var item: ItemData

func _ready():
	add_to_group("pickups")
	_update_visuals()

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
		# Shape and transform per type
		mesh_inst.transform = Transform3D.IDENTITY
		match item.type:
			ItemData.Type.WEAPON:
				var box = BoxMesh.new(); box.size = Vector3(0.75, 0.12, 0.45)
				mesh_inst.mesh = box
				mesh_inst.position = Vector3(0, 0.12, 0)
			ItemData.Type.AMMO:
				var sphere = SphereMesh.new(); sphere.radius = 0.18; sphere.height = 0.36
				mesh_inst.mesh = sphere
				mesh_inst.position = Vector3(0, 0.2, 0)
			ItemData.Type.HEAL:
				var box = BoxMesh.new(); box.size = Vector3(0.32, 0.42, 0.32)
				mesh_inst.mesh = box
				mesh_inst.position = Vector3(0, 0.28, 0)
			ItemData.Type.ARMOR:
				var box = BoxMesh.new(); box.size = Vector3(0.5, 0.08, 0.5)
				mesh_inst.mesh = box
				mesh_inst.position = Vector3(0, 0.08, 0)
		# Light color matches item
		if has_node("OmniLight3D"):
			$OmniLight3D.light_color = item.color

	var existing = get_node_or_null("PickupLabel")
	if existing: existing.queue_free()
	var existing_icon = get_node_or_null("PickupIcon")
	if existing_icon: existing_icon.queue_free()
	if not item: return

	var sprite = Sprite3D.new()
	sprite.name = "PickupIcon"
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.no_depth_test = true
	sprite.pixel_size = 0.028
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.texture = _make_pickup_icon()
	sprite.position = Vector3(0, 0.72, 0)
	add_child(sprite)

	var label = Label3D.new()
	label.name = "PickupLabel"
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.font_size = 24
	label.pixel_size = 0.005
	label.position = Vector3(0, 1.2, 0)
	label.outline_size = 6

	var display_text = item.item_name
	if item.type == ItemData.Type.WEAPON and item.weapon_stats:
		display_text += "\n%d/%d" % [item.weapon_stats.current_ammo, item.weapon_stats.max_ammo]
	elif item.type == ItemData.Type.AMMO and item.ammo_weapon_type != "":
		display_text += "\n+%d" % item.amount

	label.text = display_text
	label.modulate = Color.GOLD if item.rarity == ItemData.Rarity.RARE else Color.WHITE
	add_child(label)

func _make_pickup_icon() -> ImageTexture:
	var W := 20; var H := 20
	var img := Image.create(W, H, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	match item.type:
		ItemData.Type.HEAL:
			var c = Color(1.0, 0.85, 0.1) if item.rarity == ItemData.Rarity.RARE else Color(0.95, 0.15, 0.15)
			for x in range(2, 18):
				img.set_pixel(x, 8,  c); img.set_pixel(x, 9,  c)
				img.set_pixel(x, 10, c); img.set_pixel(x, 11, c)
			for y in range(2, 18):
				img.set_pixel(8,  y, c); img.set_pixel(9,  y, c)
				img.set_pixel(10, y, c); img.set_pixel(11, y, c)
		ItemData.Type.ARMOR:
			var c = Color(0.45, 0.78, 1.0)
			for y in range(2, 12):
				for x in range(3, 17): img.set_pixel(x, y, c)
			for y in range(12, 19):
				var margin = y - 11
				for x in range(3 + margin, 17 - margin):
					img.set_pixel(x, y, c)
		ItemData.Type.AMMO:
			var c = item.color
			for y in range(9, 18):
				for x in range(7, 13): img.set_pixel(x, y, c)
			for y in range(3, 9):
				var shrink = 9 - y
				for x in range(7 + shrink / 2, 13 - shrink / 2):
					img.set_pixel(x, y, c)
			for x in range(6, 14): img.set_pixel(x, 17, c); img.set_pixel(x, 18, c)
		ItemData.Type.WEAPON:
			var c = item.color
			for x in range(1, 15):
				img.set_pixel(x, 8, c); img.set_pixel(x, 9, c)
			for x in range(14, 19):
				for y in range(8, 13): img.set_pixel(x, y, c)
			for x in range(5, 9):
				for y in range(9, 17): img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)

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
			if item.rarity == ItemData.Rarity.RARE:
				collector.stats.advanced_heals += item.amount
				print("Collected MedKit: ", item.amount)
			else:
				collector.stats.heal_items += item.amount
				print("Collected Heal: ", item.amount)
		ItemData.Type.ARMOR:
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
