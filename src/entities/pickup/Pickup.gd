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
		var mat = StandardMaterial3D.new()
		mat.albedo_color = item.color
		$MeshInstance3D.material_override = mat

	var existing = get_node_or_null("PickupLabel")
	if existing: existing.queue_free()
	if not item: return

	var label = Label3D.new()
	label.name = "PickupLabel"
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.font_size = 28
	label.pixel_size = 0.005
	label.position = Vector3(0, 1.2, 0)
	label.outline_size = 6

	var display_text = item.item_name
	if item.type == ItemData.Type.WEAPON and item.weapon_stats:
		display_text += "\n%d/%d" % [item.weapon_stats.current_ammo, item.weapon_stats.max_ammo]

	label.text = display_text
	label.modulate = Color.GOLD if item.rarity == ItemData.Rarity.RARE else Color.WHITE
	add_child(label)

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
			var ammo_by_weapon: Dictionary = {"shotgun": 6, "ar": 24, "railgun": 3}
			var actual_ammo = ammo_by_weapon.get(collector.stats.weapon_type, item.amount)
			collector.stats.current_ammo = min(collector.stats.max_ammo, collector.stats.current_ammo + actual_ammo)
			print("Collected Ammo: ", actual_ammo, " (", collector.stats.weapon_type, ")")
		ItemData.Type.HEAL:
			collector.stats.heal_items += item.amount
			print("Collected Heal: ", item.amount)
		ItemData.Type.ARMOR:
			collector.current_shield = min(collector.stats.max_shield, collector.current_shield + item.amount)
			collector.shield_changed.emit(collector.current_shield, collector.stats.max_shield)
			print("Collected Armor: ", item.amount)
		ItemData.Type.WEAPON:
			if item.weapon_stats:
				collector.stats.weapon_type = item.weapon_stats.weapon_type
				collector.stats.pellet_count = item.weapon_stats.pellet_count
				collector.stats.attack_damage = item.weapon_stats.attack_damage
				collector.stats.fire_rate = item.weapon_stats.fire_rate
				collector.stats.attack_range = item.weapon_stats.attack_range
				if item.weapon_stats.max_ammo > 0:
					collector.stats.max_ammo = item.weapon_stats.max_ammo
				collector.stats.current_ammo = item.weapon_stats.current_ammo
				print("Swapped Weapon to: ", item.item_name, " (ammo: ", item.weapon_stats.current_ammo, ")")
				if collector.has_method("_on_health_changed"):
					collector._on_health_changed(collector.current_health, collector.stats.max_health)

	queue_free()
	return true
