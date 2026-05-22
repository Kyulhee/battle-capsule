extends RefCounted

const ItemDisplayFormatterScript = preload("res://src/core/ItemDisplayFormatter.gd")

static func refresh(slot_panels: Array, slot_icon_rects: Array, slot_ammo_labels: Array, slots: WeaponSlotManager, icon_provider: Callable) -> void:
	if slot_panels.is_empty():
		return

	var active_style = StyleBoxFlat.new()
	active_style.bg_color = Color(0.25, 0.25, 0.25, 0.9)
	active_style.border_color = Color.WHITE
	active_style.set_border_width_all(2)
	active_style.set_corner_radius_all(4)

	var normal_style = StyleBoxFlat.new()
	normal_style.bg_color = Color(0.12, 0.12, 0.12, 0.8)
	normal_style.set_corner_radius_all(4)

	var empty_style = StyleBoxFlat.new()
	empty_style.bg_color = Color(0.25, 0.05, 0.05, 0.85)
	empty_style.set_corner_radius_all(4)

	for i in range(slot_panels.size()):
		var panel = slot_panels[i] as PanelContainer
		if not panel:
			continue
		var has_weapon = i >= 1 and i < slots.weapon_slots.size() and slots.weapon_slots[i] != null
		var out_of_ammo = has_weapon and slots.slot_ammo[i] <= 0 and slots.slot_reserve[i] <= 0

		if i == slots.active_slot:
			panel.add_theme_stylebox_override("panel", active_style)
		elif out_of_ammo:
			panel.add_theme_stylebox_override("panel", empty_style)
		else:
			panel.add_theme_stylebox_override("panel", normal_style)

		if i < slot_icon_rects.size():
			var icon_rect = slot_icon_rects[i] as TextureRect
			if icon_rect:
				if i == 0:
					icon_rect.texture = icon_provider.call("knife") as Texture2D
				elif not has_weapon:
					icon_rect.texture = icon_provider.call("") as Texture2D
				else:
					icon_rect.texture = icon_provider.call(slots.weapon_slots[i].weapon_type) as Texture2D

		if i >= slot_ammo_labels.size():
			continue
		var ammo_label = slot_ammo_labels[i] as Label
		if not ammo_label:
			continue
		if i == 0:
			ammo_label.text = ""
			ammo_label.modulate = Color.WHITE
		elif not has_weapon:
			ammo_label.text = ""
		else:
			var ammo = slots.slot_ammo[i]
			var max_ammo = slots.weapon_slots[i].max_ammo
			var reserve = slots.slot_reserve[i]
			ammo_label.text = ItemDisplayFormatterScript.slot_ammo_text(ammo, max_ammo, reserve)
			if ammo <= 0 and reserve <= 0:
				ammo_label.modulate = Color.RED
			elif ammo <= max_ammo / 4:
				ammo_label.modulate = Color.YELLOW
			else:
				ammo_label.modulate = Color.WHITE
