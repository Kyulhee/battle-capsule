extends Label


const BuildInfoScript = preload("res://src/core/BuildInfo.gd")


func _ready() -> void:
	text = BuildInfoScript.DISPLAY_VERSION
