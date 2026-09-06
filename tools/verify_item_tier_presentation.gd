extends SceneTree

const Display = preload("res://src/core/DropDisplayCatalog.gd")
const Format = preload("res://src/core/ItemDisplayFormatter.gd")
const Presentation = preload("res://src/entities/pickup/PickupPresentation.gd")
const Items = preload("res://src/core/ItemResourceCatalog.gd")
const Hud = preload("res://src/ui/player/PlayerHudBuilder.gd")
const Renderer = preload("res://src/ui/player/PlayerSlotHudRenderer.gd")
var failures: Array[String] = []

class Observer:
	extends Node3D
	var slots := WeaponSlotManager.new()
	var sensed := true
	func can_sense_item(_position: Vector3) -> bool:
		return sensed
	func get_weapon_pickup_comparison(stats: StatsData) -> String:
		return ItemDisplayFormatter.weapon_pickup_comparison(stats, slots)

func _init() -> void:
	_run.call_deferred()

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

func _run() -> void:
	var observer := Observer.new()
	root.add_child(observer)
	observer.add_to_group("players")
	var slots := observer.slots
	for item in [Items.WEAPON_AR_WORN, Items.WEAPON_AR, Items.WEAPON_SHOTGUN_WORN,
			Items.WEAPON_SHOTGUN, Items.WEAPON_RAILGUN, Items.BALLISTIC_VEST]:
		var copy: ItemData = item.duplicate(true)
		var before := Presentation.base_color(copy)
		var light_before := Presentation.visual_params(copy)
		copy.color = Color.RED
		copy.rarity = ItemData.Rarity.COMMON
		_check(Presentation.base_color(copy) == before, "Legacy color/rarity changed equipment tier color.")
		_check(Presentation.visual_params(copy) == light_before, "Legacy color/rarity changed equipment glow.")
		_check(Presentation.label_color(copy, true) == before.lightened(0.1), "Focus erased tier color.")
		_check(Format.pickup_name(copy).begins_with("["), "Equipment label missing tier/special badge.")
	_check(Presentation.base_color(Items.WEAPON_AR) == Presentation.base_color(Items.WEAPON_SHOTGUN), "Same tier differs by weapon family.")
	_check(Presentation.base_color(Items.WEAPON_SHOTGUN_WORN) == Display.TIER_GRAY, "Worn is not gray.")
	_check(Presentation.base_color(Items.WEAPON_SHOTGUN) == Display.TIER_GREEN, "Standard is not green.")
	_check(Presentation.base_color(Items.WEAPON_RAILGUN) == Display.SPECIAL_PURPLE, "Railgun is not special purple.")
	_check(Format.pickup_name(Items.WEAPON_RAILGUN) == "[특수] 레일건", "Special is incorrectly shown as a performance tier.")
	_check(Display.weapon_color("ar", 3) == Display.TIER_BLUE, "T3 is not blue.")
	_check(Presentation.base_color(Items.AMMO_RAILGUN) == Display.TIER_GRAY, "Ammo inherited its weapon's special tier.")
	_check(Format.pickup_detail(Items.AMMO_SHOTGUN).contains("호환: 산탄총"), "Ammo compatibility missing.")
	_check(Format.weapon_pickup_comparison(Items.WEAPON_SHOTGUN.weapon_stats, slots).contains("빈 슬롯"), "New weapon explanation missing.")
	slots.receive_weapon(Items.WEAPON_SHOTGUN_WORN.weapon_stats)
	_check(Format.weapon_pickup_comparison(Items.WEAPON_SHOTGUN.weapon_stats, slots).contains("T1 → T2"), "Upgrade comparison missing.")
	var pickup = Items.PICKUP_SCENE.instantiate()
	pickup.item = Items.WEAPON_SHOTGUN
	root.add_child(pickup)
	pickup.set_focused(true)
	_check(pickup._label.text.contains("[T2] 산탄총") and pickup._label.text.contains("T1 → T2"), "Real focused pickup does not show tier comparison.")
	observer.sensed = false
	pickup._update_visibility_for_player()
	_check(not pickup.visible and not pickup._label.visible, "New label leaked unseen loot.")
	observer.sensed = true
	var control := Control.new()
	root.add_child(control)
	control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var hud := Hud.build_slot_hud(control)
	var no_icon := func(_kind: String): return null
	slots.receive_weapon(Items.WEAPON_AR.weapon_stats)
	slots.receive_weapon(Items.WEAPON_RAILGUN.weapon_stats)
	slots.switch_to(1)
	Renderer.refresh(hud.slot_panels, hud.slot_icon_rects, hud.slot_ammo_labels, slots, no_icon)
	await process_frame
	await process_frame
	_check(hud.slot_panels[1].get_node("Content/TierLabel").text == "T1 노후", "HUD worn badge missing.")
	_check(hud.slot_panels[2].get_node("Content/TierLabel").text == "T2 표준", "HUD standard badge missing.")
	_check(hud.slot_panels[3].get_node("Content/TierLabel").text == "특수", "HUD special badge missing.")
	_check(hud.slot_panels[4].get_node("Content/TierLabel").text == "비어 있음", "HUD empty slot not cleared.")
	slots.slot_ammo[1] = 0
	slots.slot_reserve[1] = 0
	Renderer.refresh(hud.slot_panels, hud.slot_icon_rects, hud.slot_ammo_labels, slots, no_icon)
	_check(hud.slot_ammo_labels[1].modulate == Color.RED, "Tier styling hid no-ammo warning.")
	_check(hud.slot_panels[1].get_node("Content/SlotKey").text.contains("사용"), "Selected empty gun lost active state.")
	_check(hud.slot_panels[1].get_theme_stylebox("panel").border_color == Display.TIER_GRAY, "Selected empty gun lost tier stripe.")
	_check(slots.receive_weapon(Items.WEAPON_SHOTGUN.weapon_stats), "Existing upgrade contract changed.")
	Renderer.refresh(hud.slot_panels, hud.slot_icon_rects, hud.slot_ammo_labels, slots, no_icon)
	_check(hud.slot_panels[1].get_node("Content/TierLabel").text == "T2 표준", "Upgrade left stale HUD tier.")
	_check(Format.weapon_pickup_comparison(Items.WEAPON_SHOTGUN_WORN.weapon_stats, slots).contains("하위 등급"), "Downgrade explanation missing.")
	_check(not slots.can_receive_weapon(Items.WEAPON_SHOTGUN_WORN.weapon_stats), "Downgrade became collectible.")
	_check(Format.weapon_pickup_comparison(Items.WEAPON_SHOTGUN.weapon_stats, slots).contains("동급"), "Same-grade explanation missing.")
	var fourth := StatsData.new()
	fourth.weapon_type = "pistol"
	slots.receive_weapon(fourth)
	var new_type := StatsData.new()
	new_type.weapon_type = "test_other"
	_check(Format.weapon_pickup_comparison(new_type, slots).contains("교체:"), "Full inventory replacement missing.")
	slots.switch_to(0)
	_check(Format.weapon_pickup_comparison(new_type, slots).contains("선택 필요"), "Knife/full inventory explanation incorrect.")
	_check(Items.WEAPON_SHOTGUN.weapon_stats.weapon_tier == 2 and Items.WEAPON_SHOTGUN_WORN.weapon_stats.weapon_tier == 1, "Shared resource tier mutated.")
	control.free()
	pickup.free()
	observer.free()
	for failure in failures:
		push_error(failure)
	print("Item tier presentation: %d failures." % failures.size())
	quit(0 if failures.is_empty() else 1)
