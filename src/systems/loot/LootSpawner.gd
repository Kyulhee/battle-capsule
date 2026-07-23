class_name LootSpawner
extends RefCounted

var loot_count: int = 40
var hotspot_density_mult: float = 1.0
var rare_bias_mult: float = 1.0
var initial_non_pistol_weapon_weight_mult: float = 1.0
var role_weapon_chance_mult: Dictionary = {}
var role_wave_weapon_chance_mult: Dictionary = {}
var role_initial_weapon_chance: Dictionary = {}
var role_initial_weapon_pool: Dictionary = {}
var role_initial_equipment_chance: Dictionary = {}
var hotspots: Array[Dictionary] = []

func configure_count(value: int) -> void:
	loot_count = max(0, value)

func configure_density_multiplier(value: float) -> void:
	hotspot_density_mult = maxf(0.0, value)

func configure_rare_bias_multiplier(value: float) -> void:
	rare_bias_mult = maxf(0.0, value)

func configure_initial_non_pistol_weapon_weight_multiplier(value: float) -> void:
	initial_non_pistol_weapon_weight_mult = maxf(0.0, value)

func configure_role_weapon_chance_multipliers(values: Dictionary) -> void:
	role_weapon_chance_mult.clear()
	_configure_role_float_multipliers(role_weapon_chance_mult, values)

func configure_role_wave_weapon_chance_multipliers(values: Dictionary) -> void:
	role_wave_weapon_chance_mult.clear()
	_configure_role_float_multipliers(role_wave_weapon_chance_mult, values)

func configure_role_initial_weapon_chances(values: Dictionary) -> void:
	role_initial_weapon_chance.clear()
	_configure_role_float_multipliers(role_initial_weapon_chance, values)

func configure_role_initial_weapon_pools(values: Dictionary) -> void:
	role_initial_weapon_pool.clear()
	for key in values.keys():
		var role := String(key).strip_edges()
		var pool := String(values[key]).strip_edges().to_lower()
		if not role.is_empty() and not pool.is_empty():
			role_initial_weapon_pool[role] = pool

func configure_role_initial_equipment_chances(values: Dictionary) -> void:
	role_initial_equipment_chance.clear()
	_configure_role_float_multipliers(role_initial_equipment_chance, values)

func _configure_role_float_multipliers(target: Dictionary, values: Dictionary) -> void:
	for key in values.keys():
		var role := String(key).strip_edges()
		if role.is_empty():
			continue
		target[role] = maxf(0.0, float(values[key]))

func register_from_map_spec(map_spec) -> void:
	hotspots.clear()
	if not map_spec:
		return
	for poi in map_spec.pois:
		var poi_pos = poi.get("pos", [0.0, 0.0])
		hotspots.append({
			"pos": Vector2(float(poi_pos[0]), float(poi_pos[1])),
			"radius": maxf(float(poi.get("radius", 8.0)), 2.0),
			"density": clampf(float(poi.get("item_density", 0.5)) * hotspot_density_mult, 0.05, 1.5),
			"rare_bias": clampf(float(poi.get("rare_bias", 0.0)) * rare_bias_mult, 0.0, 1.0),
			"role": String(poi.get("role", "")),
		})

func has_hotspots() -> bool:
	return not hotspots.is_empty()

func spawn_count(prob: float, count_mult: int = 1) -> int:
	return max(0, int(loot_count * prob * count_mult))

func initial_weapon_chance(hotspot: Dictionary) -> float:
	var role := String(hotspot.get("role", ""))
	if role_initial_weapon_chance.has(role):
		return clampf(float(role_initial_weapon_chance[role]), 0.0, 1.0)
	var density = float(hotspot.get("density", 0.5))
	var rare_bias = float(hotspot.get("rare_bias", 0.0))
	var chance := clampf(0.01 + density * 0.045 + rare_bias * 0.035, 0.02, 0.08)
	return clampf(chance * _role_weapon_chance_multiplier(hotspot), 0.0, 0.08)

func choose_initial_weapon_template(weapon_templates: Array, hotspot: Dictionary = {}):
	var role := String(hotspot.get("role", ""))
	var pool := String(role_initial_weapon_pool.get(role, "legacy"))
	var pooled := _weapon_templates_for_pool(weapon_templates, pool)
	if not pooled.is_empty():
		return pooled[randi() % pooled.size()]
	return _weighted_weapon_template(weapon_templates, initial_non_pistol_weapon_weight_mult)

func choose_wave_weapon_template(weapon_templates: Array):
	var field_grade := _weapon_templates_for_pool(weapon_templates, "field")
	if field_grade.is_empty():
		return _weighted_weapon_template(weapon_templates, 1.0)
	return field_grade[randi() % field_grade.size()]

func initial_equipment_chance(hotspot: Dictionary) -> float:
	var role := String(hotspot.get("role", ""))
	return clampf(float(role_initial_equipment_chance.get(role, 0.0)), 0.0, 1.0)

func wave_weapon_chance(hotspot: Dictionary) -> float:
	var chance := float(hotspot.get("rare_bias", 0.0))
	return clampf(chance * _role_wave_weapon_chance_multiplier(hotspot), 0.0, 1.0)

func _role_weapon_chance_multiplier(hotspot: Dictionary) -> float:
	var role := String(hotspot.get("role", ""))
	if role_weapon_chance_mult.has(role):
		return maxf(0.0, float(role_weapon_chance_mult[role]))
	return 1.0

func _role_wave_weapon_chance_multiplier(hotspot: Dictionary) -> float:
	var role := String(hotspot.get("role", ""))
	if role_wave_weapon_chance_mult.has(role):
		return maxf(0.0, float(role_wave_weapon_chance_mult[role]))
	return 1.0

func _weighted_weapon_template(weapon_templates: Array, non_pistol_mult: float):
	if weapon_templates.is_empty():
		return null
	var weights: Array[float] = []
	var total_weight := 0.0
	for template in weapon_templates:
		var weight := 1.0
		if _weapon_type(template) != "pistol":
			weight *= non_pistol_mult
		weight = maxf(0.0, weight)
		weights.append(weight)
		total_weight += weight
	if total_weight <= 0.0:
		return null
	var ticket := randf() * total_weight
	for idx in range(weapon_templates.size()):
		ticket -= weights[idx]
		if ticket <= 0.0:
			return weapon_templates[idx]
	return weapon_templates[weapon_templates.size() - 1]

func _weapon_type(template) -> String:
	if template == null or template.weapon_stats == null:
		return ""
	return String(template.weapon_stats.weapon_type)

func _weapon_templates_for_pool(weapon_templates: Array, pool: String) -> Array:
	var result: Array = []
	for template in weapon_templates:
		if template == null or template.weapon_stats == null:
			continue
		var tier := int(template.weapon_stats.weapon_tier)
		if pool == "scavenged" and tier == 1:
			result.append(template)
		elif pool == "field" and tier == 2:
			result.append(template)
		elif pool == "supply" and tier >= 3:
			result.append(template)
	return result

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
