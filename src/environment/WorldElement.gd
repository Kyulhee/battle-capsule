extends StaticBody3D
class_name WorldElement

enum Type { ROCK, TREE, LOG }
@export var type: Type = Type.ROCK

@onready var mesh_instance = $MeshInstance3D

func _ready():
	add_to_group("obstacles")
	_apply_type_visuals()

func _apply_type_visuals():
	if not mesh_instance: return
	
	var mat = StandardMaterial3D.new()
	match type:
		Type.ROCK:
			mat.albedo_color = Color(0.3, 0.3, 0.35)
		Type.TREE:
			mat.albedo_color = Color(0.2, 0.15, 0.1)
		Type.LOG:
			mat.albedo_color = Color(0.25, 0.2, 0.15)
			
	mesh_instance.set_surface_override_material(0, mat)
