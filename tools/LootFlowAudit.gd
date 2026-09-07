extends RefCounted

# 초기 배치의 기하학적 진단이다. 경로 접근성이나 실제 습득을 보장하지 않는다.
# nearby/POI 지표는 존재 여부라 같은 탄약 묶음이 여러 총에 집계될 수 있다.
static func summarize(records: Array, nearby_radius: float = 3.0) -> Dictionary:
	var totals := _empty_counts()
	var by_poi := {}
	for record in records:
		var poi := String(record["poi"])
		if not by_poi.has(poi):
			by_poi[poi] = _empty_counts()
		var counts: Dictionary = by_poi[poi]
		counts["items"] += 1
		var kind := String(record["kind"])
		var family := String(record["family"])
		if kind == "weapon":
			counts["weapons"] += 1
			_increment(counts["weapon_families"], family, 1)
			var local_ammo := false
			var nearby_ammo := false
			for other in records:
				if other["kind"] != "ammo" or other["family"] != family \
						or other["poi"] != poi or int(other["amount"]) <= 0:
					continue
				local_ammo = true
				if _position(record).distance_to(_position(other)) <= nearby_radius:
					nearby_ammo = true
			counts["weapons_without_poi_ammo"] += int(not local_ammo)
			counts["weapons_without_nearby_ammo"] += int(not nearby_ammo)
		elif kind == "ammo":
			counts["ammo_packs"] += 1
			_increment(counts["ammo_families"], family, 1)
			_increment(counts["ammo_rounds"], family, int(record["amount"]))
			var local_weapon := false
			var global_weapon := false
			for other in records:
				if other["kind"] == "weapon" and other["family"] == family:
					global_weapon = true
					local_weapon = local_weapon or other["poi"] == poi
			counts["ammo_without_poi_weapon"] += int(not local_weapon)
			counts["ammo_without_initial_weapon"] += int(not global_weapon)
	for counts in by_poi.values():
		for key in totals:
			if totals[key] is Dictionary:
				for family in counts[key]:
					_increment(totals[key], family, int(counts[key][family]))
			else:
				totals[key] += counts[key]
	return {"totals": totals, "by_poi": by_poi, "nearby_radius_m": nearby_radius}


static func _empty_counts() -> Dictionary:
	return {
		"items": 0, "weapons": 0, "ammo_packs": 0,
		"weapons_without_poi_ammo": 0, "weapons_without_nearby_ammo": 0,
		"ammo_without_poi_weapon": 0, "ammo_without_initial_weapon": 0,
		"weapon_families": {}, "ammo_families": {}, "ammo_rounds": {},
	}


static func _position(record: Dictionary) -> Vector2:
	return Vector2(float(record["position"][0]), float(record["position"][1]))


static func _increment(counts: Dictionary, key: String, amount: int) -> void:
	counts[key] = int(counts.get(key, 0)) + amount
