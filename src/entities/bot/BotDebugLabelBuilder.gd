extends RefCounted

static func build_labels(owner: Node) -> Dictionary:
	var state_label = Label3D.new()
	state_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	state_label.double_sided = true
	state_label.font_size = 52
	state_label.pixel_size = 0.006
	state_label.outline_size = 10
	state_label.position = Vector3(0, 2.4, 0)
	state_label.visible = false
	owner.add_child(state_label)

	var archetype_marker = Label3D.new()
	archetype_marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	archetype_marker.double_sided = true
	archetype_marker.font_size = 38
	archetype_marker.pixel_size = 0.006
	archetype_marker.outline_size = 8
	archetype_marker.position = Vector3(0, 2.85, 0)
	archetype_marker.visible = false
	owner.add_child(archetype_marker)

	return {
		"state_label": state_label,
		"archetype_marker": archetype_marker,
	}
