extends SceneTree


class FakePlayer:
	extends Node3D

	var sensed := true

	func can_sense_item(_position: Vector3) -> bool:
		return sensed


const PickupPresentationScript = preload("res://src/entities/pickup/PickupPresentation.gd")


func _init():
	call_deferred("_run")


func _run() -> void:
	if not _verify_pickup_light_lod():
		quit(1)
		return

	print("Pickup light LOD smoke passed.")
	quit(0)


func _verify_pickup_light_lod() -> bool:
	var scene: PackedScene = load("res://src/entities/pickup/Pickup.tscn")
	if scene == null:
		return _fail("Pickup.tscn could not be loaded.")

	var player := FakePlayer.new()
	player.add_to_group("players")
	root.add_child(player)

	var item := ItemData.new()
	item.type = ItemData.Type.AMMO
	item.item_name = "LOD Test Ammo"
	item.ammo_weapon_type = "pistol"
	item.amount = 12
	item.color = Color(1.0, 0.55, 0.15, 1.0)

	var pickup = scene.instantiate()
	pickup.item = item
	pickup.position = Vector3.ZERO
	root.add_child(pickup)

	var light := pickup.get_node_or_null("OmniLight3D") as OmniLight3D
	if light == null:
		return _fail("Pickup scene is missing OmniLight3D.")

	player.sensed = true
	player.global_position = Vector3(0.0, 0.0, PickupPresentationScript.LIGHT_LOD_FULL_DISTANCE - 2.0)
	pickup._update_visibility_for_player()
	if not pickup.visible:
		return _fail("Sensed pickup should stay visible.")
	if not light.visible:
		return _fail("Near sensed pickup light should be visible.")
	var base_energy := light.light_energy
	var base_range := light.omni_range
	if base_energy <= 0.0 or base_range <= 0.0:
		return _fail("Pickup light did not keep a valid base energy/range.")

	player.global_position = Vector3(0.0, 0.0, PickupPresentationScript.LIGHT_LOD_FULL_DISTANCE + 4.0)
	pickup._update_visibility_for_player()
	if not light.visible:
		return _fail("Mid-distance sensed pickup light should stay dimly visible.")
	if light.light_energy >= base_energy * 0.8:
		return _fail("Mid-distance pickup light was not dimmed.")
	if light.omni_range >= base_range:
		return _fail("Mid-distance pickup light range was not reduced.")

	player.global_position = Vector3(0.0, 0.0, PickupPresentationScript.LIGHT_LOD_DIM_DISTANCE + 6.0)
	pickup._update_visibility_for_player()
	if not pickup.visible:
		return _fail("Far sensed pickup body should remain visible even when light is culled.")
	if light.visible:
		return _fail("Far sensed pickup light should be culled.")

	pickup.set_focused(true)
	if not light.visible:
		return _fail("Focused sensed pickup should restore its light for readability.")
	if absf(light.light_energy - base_energy) > 0.01:
		return _fail("Focused pickup light did not restore base energy.")

	pickup.set_focused(false)
	player.sensed = false
	pickup._update_visibility_for_player()
	if pickup.visible:
		return _fail("Unsensed pickup should be hidden.")
	if light.visible:
		return _fail("Unsensed pickup light should be hidden.")

	return true


func _fail(message: String) -> bool:
	push_error(message)
	return false
