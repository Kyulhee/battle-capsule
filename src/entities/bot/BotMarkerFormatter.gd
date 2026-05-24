extends RefCounted

const BOT_DOCTRINE = preload("res://src/entities/bot/BotDoctrine.gd")

const STATE_LABEL_SPECS := {
	"CHASE": {"text": "?", "color": Color(1.0, 0.90, 0.0)},
	"ATTACK": {"text": "!", "color": Color(1.0, 0.18, 0.12)},
	"DISENGAGE": {"text": "?", "color": Color(1.0, 0.60, 0.0)},
}

const ARCHETYPE_SPECS := {
	"AGGRESSIVE": {
		"prefix": "AGG",
		"catalog_id": "bot.aggressive",
		"fallback_color": Color(1.0, 0.22, 0.12),
	},
	"DEFENSIVE": {
		"prefix": "DEF",
		"catalog_id": "bot.defensive",
		"fallback_color": Color(0.25, 0.62, 1.0),
	},
	"SNIPER": {
		"prefix": "SNP",
		"catalog_id": "bot.sniper",
		"fallback_color": Color(0.88, 0.52, 1.0),
	},
	"OPPORTUNIST": {
		"prefix": "OPP",
		"catalog_id": "bot.opportunist",
		"fallback_color": Color(0.25, 1.0, 0.48),
	},
}

const FALLBACK_ARCHETYPE_SPEC := {
	"prefix": "BOT",
	"catalog_id": "bot.aggressive",
	"fallback_color": Color(1.0, 1.0, 1.0),
}

static func state_label_spec(state_name: String) -> Dictionary:
	var spec = STATE_LABEL_SPECS.get(state_name, {})
	if spec.is_empty():
		return {}
	return spec.duplicate()


static func archetype_marker_text(archetype_name: String, combat_plan: String) -> String:
	return "%s %s" % [archetype_prefix(archetype_name), combat_plan_marker(combat_plan)]


static func archetype_prefix(archetype_name: String) -> String:
	return _archetype_spec(archetype_name).get("prefix", "BOT")


static func archetype_catalog_id(archetype_name: String) -> String:
	return _archetype_spec(archetype_name).get("catalog_id", "bot.aggressive")


static func archetype_catalog_id_for_id(archetype_id: int) -> String:
	return archetype_catalog_id(BOT_DOCTRINE.archetype_name(archetype_id))


static func archetype_fallback_color(archetype_name: String) -> Color:
	return _archetype_spec(archetype_name).get("fallback_color", Color(1.0, 1.0, 1.0))


static func combat_plan_marker(combat_plan: String) -> String:
	match combat_plan:
		BOT_DOCTRINE.PLAN_ADVANCE:
			return "ADV"
		BOT_DOCTRINE.PLAN_KITE:
			return "KITE"
		BOT_DOCTRINE.PLAN_PEEK_COVER:
			return "PEEK"
		BOT_DOCTRINE.PLAN_REPOSITION:
			return "FLK"
		BOT_DOCTRINE.PLAN_HOLD_ANGLE:
			return "HOLD"
		_:
			return "STR"


static func _archetype_spec(archetype_name: String) -> Dictionary:
	return ARCHETYPE_SPECS.get(archetype_name, FALLBACK_ARCHETYPE_SPEC)
