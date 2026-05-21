class_name LootSpawner
extends RefCounted

var loot_count: int = 40
var hotspots: Array[Dictionary] = []

func configure_count(value: int) -> void:
	loot_count = max(0, value)

func register_from_map_spec(map_spec) -> void:
	hotspots.clear()
	if not map_spec:
		return
	for poi in map_spec.pois:
		var poi_pos = poi.get("pos", [0.0, 0.0])
		hotspots.append({
			"pos": Vector2(float(poi_pos[0]), float(poi_pos[1])),
			"radius": maxf(float(poi.get("radius", 8.0)), 2.0),
			"density": clampf(float(poi.get("item_density", 0.5)), 0.05, 1.5),
			"rare_bias": clampf(float(poi.get("rare_bias", 0.0)), 0.0, 1.0),
			"role": String(poi.get("role", "")),
		})

func has_hotspots() -> bool:
	return not hotspots.is_empty()

func spawn_count(prob: float, count_mult: int = 1) -> int:
	return max(0, int(loot_count * prob * count_mult))

func initial_weapon_chance(hotspot: Dictionary) -> float:
	var density = float(hotspot.get("density", 0.5))
	var rare_bias = float(hotspot.get("rare_bias", 0.0))
	return clampf(0.01 + density * 0.045 + rare_bias * 0.035, 0.02, 0.08)

func initial_consumable_count(hotspot: Dictionary) -> int:
	var density = float(hotspot.get("density", 0.5))
	return int(clamp(round(1.0 + density * 2.5), 2.0, 5.0))

func choose_hotspot() -> Dictionary:
	if hotspots.is_empty():
		return {}
	var total_weight = 0.0
	for hotspot in hotspots:
		total_weight += maxf(float(hotspot.get("density", 1.0)), 0.05)
	var ticket = randf() * total_weight
	for hotspot in hotspots:
		ticket -= maxf(float(hotspot.get("density", 1.0)), 0.05)
		if ticket <= 0.0:
			return hotspot
	return hotspots[hotspots.size() - 1]

func random_position(hotspot: Dictionary, clear_check: Callable = Callable()) -> Vector2:
	var center: Vector2 = hotspot.get("pos", Vector2.ZERO)
	var spread = minf(maxf(float(hotspot.get("radius", 8.0)) * 0.6, 3.0), 11.0)
	for _attempt in range(10):
		var angle = randf() * TAU
		var dist = randf_range(0.0, spread)
		var candidate = center + Vector2(cos(angle), sin(angle)) * dist
		if not clear_check.is_valid() or bool(clear_check.call(candidate, 1.0)):
			return candidate
	return center
