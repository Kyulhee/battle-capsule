extends RefCounted
class_name MissionBadgeStore

const ACHIEVEMENTS_PATH = "user://achievements.json"


static func save_badge(mission_id: String) -> void:
	var data = load_achievements()
	if not data.has("badges"):
		data["badges"] = []
	if not mission_id in data["badges"]:
		data["badges"].append(mission_id)
	var f = FileAccess.open(ACHIEVEMENTS_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data, "\t"))
		f.close()


static func has_badge(mission_id: String) -> bool:
	var data = load_achievements()
	return data.get("badges", []).has(mission_id)


static func load_achievements() -> Dictionary:
	if not FileAccess.file_exists(ACHIEVEMENTS_PATH):
		return {}
	var f = FileAccess.open(ACHIEVEMENTS_PATH, FileAccess.READ)
	if not f:
		return {}
	var result = JSON.parse_string(f.get_as_text())
	f.close()
	return result if result is Dictionary else {}
