class_name DebugFlags
extends RefCounted

const ALL_FLAGS: Array[String] = [
	"ai",
	"perception",
	"damage",
	"loot",
	"zone",
	"nav"
]

var enabled: bool = false
var overlay_enabled: bool = false
var flags: Dictionary = {}

func load_from_cmdline(args: Array) -> void:
	enabled = false
	overlay_enabled = false
	flags.clear()
	for flag in ALL_FLAGS:
		flags[flag] = false

	for raw_arg in args:
		var arg = String(raw_arg).strip_edges()
		var lower = arg.to_lower()
		if lower == "debug" or lower == "debug=true" or lower == "debug=1":
			enabled = true
			overlay_enabled = true
		elif lower.begins_with("debug="):
			enabled = _parse_bool(lower.get_slice("=", 1), false)
			overlay_enabled = enabled
		elif lower.begins_with("debug_overlay="):
			overlay_enabled = _parse_bool(lower.get_slice("=", 1), overlay_enabled)
			enabled = enabled or overlay_enabled
		elif lower.begins_with("debug_flags="):
			enabled = true
			var value = lower.get_slice("=", 1)
			for token in value.split(",", false):
				var flag = token.strip_edges()
				if flags.has(flag):
					flags[flag] = true
				else:
					push_warning("DebugFlags: unknown flag '%s'" % flag)

static func _parse_bool(value: String, fallback: bool) -> bool:
	match value:
		"1", "true", "yes", "on":
			return true
		"0", "false", "no", "off":
			return false
		_:
			return fallback

func is_enabled(flag: String) -> bool:
	return enabled and bool(flags.get(flag, false))

func describe() -> String:
	if not enabled:
		return "off"
	var active: Array[String] = []
	for flag in ALL_FLAGS:
		if flags.get(flag, false):
			active.append(flag)
	if active.is_empty():
		return "overlay"
	return ",".join(PackedStringArray(active))
