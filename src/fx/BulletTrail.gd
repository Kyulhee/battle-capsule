extends Node3D

@export var duration: float = 0.2
@export var color: Color = Color(1.0, 0.8, 0.2) # Yellowish tracer

func init(from: Vector3, to: Vector3):
	global_position = from
	look_at(to)
	
	# Scale Z to match distance
	var dist = from.distance_to(to)
	$Mesh.mesh.size.z = dist
	$Mesh.position.z = -dist * 0.5
	
	# Tween fade
	var tween = create_tween()
	tween.tween_property($Mesh, "scale:x", 0.0, duration)
	tween.parallel().tween_property($Mesh, "scale:y", 0.0, duration)
	tween.tween_callback(queue_free)
