extends RefCounted
class_name MissionBadgeStore

const VersionedJsonStoreScript = preload("res://src/core/VersionedJsonStore.gd")
const ACHIEVEMENTS_PATH = "user://achievements.json"
const ACHIEVEMENTS_SCHEMA_VERSION := 1


static func save_badge(mission_id: String, path: String = ACHIEVEMENTS_PATH) -> bool:
	if mission_id.is_empty():
		return false
	var data := load_achievements(path)
	var badges: Array = data.get("badges", [])
	if mission_id in badges:
		return true
	badges.append(mission_id)
	data["badges"] = badges
	if not VersionedJsonStoreScript.save_dictionary(
		path,
		data,
		ACHIEVEMENTS_SCHEMA_VERSION
	):
		push_error("MissionBadgeStore: failed to save achievements.")
		return false
	return true


static func has_badge(mission_id: String, path: String = ACHIEVEMENTS_PATH) -> bool:
	var data = load_achievements(path)
	return data.get("badges", []).has(mission_id)


static func load_achievements(path: String = ACHIEVEMENTS_PATH) -> Dictionary:
	var loaded := VersionedJsonStoreScript.load_dictionary(
		path,
		ACHIEVEMENTS_SCHEMA_VERSION,
		{"badges": []}
	)
	var normalized := loaded.duplicate(true)
	var raw_badges = normalized.get("badges", [])
	var badges: Array = []
	if raw_badges is Array:
		for badge in raw_badges:
			var badge_id := String(badge)
			if not badge_id.is_empty() and not badge_id in badges:
				badges.append(badge_id)
	normalized["badges"] = badges
	if normalized != loaded:
		if not VersionedJsonStoreScript.save_dictionary(
			path,
			normalized,
			ACHIEVEMENTS_SCHEMA_VERSION
		):
			push_warning("MissionBadgeStore: normalized achievements could not be persisted.")
	return normalized
