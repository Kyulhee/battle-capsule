extends RefCounted

const BOT_VISUAL_KIT = preload("res://src/entities/bot/BotVisualKit.gd")

var _skin_root: Node3D = null


func apply(bot: Node3D, archetype_id: int, asset_catalog = null) -> void:
	if not bot:
		return
	_skin_root = BOT_VISUAL_KIT.apply_skin(bot, archetype_id, bot.get_instance_id(), asset_catalog)
	sync(bot)


func sync(bot: Node3D) -> void:
	if not _skin_root or not bot:
		return
	var body_mesh = bot.get_node_or_null("MeshInstance3D")
	_skin_root.visible = body_mesh != null and body_mesh.visible and not bool(bot.get("is_dead"))
	if bool(bot.get("is_crouching")):
		_skin_root.position = Vector3(0.0, 0.08, 0.0)
		_skin_root.scale = Vector3(0.92, 0.72, 0.92)
	else:
		_skin_root.position = Vector3.ZERO
		_skin_root.scale = Vector3.ONE


func hide() -> void:
	if _skin_root:
		_skin_root.visible = false
