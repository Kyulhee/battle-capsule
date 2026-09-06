extends RefCounted

const ItemDisplayFormatterScript = preload("res://src/core/ItemDisplayFormatter.gd")
const Display = preload("res://src/core/DropDisplayCatalog.gd")

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
		var wdata: StatsData = slots.weapon_slots[i] if has_weapon else null
		var tier_color := Display.weapon_color(wdata.weapon_type, wdata.weapon_tier) if wdata else Display.TIER_GRAY

		var style: StyleBoxFlat
		if i == slots.active_slot:
			style = active_style.duplicate()
		elif out_of_ammo:
			style = empty_style.duplicate()
		else:
			style = normal_style.duplicate()
		if has_weapon:
			style.border_color = tier_color
			style.border_width_bottom = 4
		panel.add_theme_stylebox_override("panel", style)
		panel.tooltip_text = ItemDisplayFormatterScript.weapon_display_name(wdata) if has_weapon else ("근접 무기" if i == 0 else "빈 슬롯")
		var tier_label := panel.get_node_or_null("Content/TierLabel") as Label
		if tier_label:
			tier_label.text = "%s %s" % [Display.weapon_badge(wdata.weapon_type, wdata.weapon_tier),
				Display.weapon_grade_name(wdata.weapon_type, wdata.weapon_tier)] if has_weapon else ("근접" if i == 0 else "비어 있음")
			if has_weapon and wdata.weapon_type == "railgun":
				tier_label.text = "특수"
			tier_label.modulate = tier_color
		var key_label := panel.get_node_or_null("Content/SlotKey") as Label
		if key_label:
			key_label.text = ("`" if i == 0 else str(i)) + (" · 사용" if i == slots.active_slot else "")
			key_label.modulate = Color.WHITE if i == slots.active_slot else Color(0.8, 0.8, 0.8)

		if i < slot_icon_rects.size():
			var icon_rect = slot_icon_rects[i] as TextureRect
			if icon_rect:
				icon_rect.modulate = tier_color if has_weapon else Color.WHITE
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
