extends Node3D

func _ready():
	# Visuals: Red glowing sphere that fades and shrinks
	var tween = create_tween()
	tween.tween_property($MeshInstance3D, "scale", Vector3.ZERO, 0.5)
	tween.parallel().tween_property($OmniLight3D, "light_energy", 0.0, 0.5)
	tween.tween_callback(queue_free)
