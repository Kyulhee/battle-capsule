extends SceneTree

const AUDIT = preload("res://tools/LootFlowAudit.gd")


func _init() -> void:
	var records := [
		_record("A", "weapon", "ar", 0, 0.0),
		_record("A", "weapon", "ar", 0, 1.0),
		_record("A", "ammo", "ar", 15, 3.0),
		_record("A", "weapon", "shotgun", 0, 0.0),
		_record("B", "ammo", "shotgun", 4, 0.0),
		_record("B", "ammo", "railgun", 2, 0.0),
		_record("A", "heal", "", 1, 0.0),
	]
	var before := records.duplicate(true)
	var result: Dictionary = AUDIT.summarize(records)
	var totals: Dictionary = result["totals"]
	var passed: bool = records == before \
		and totals["items"] == 7 and totals["weapons"] == 3 \
		and totals["ammo_packs"] == 3 \
		and totals["weapons_without_poi_ammo"] == 1 \
		and totals["weapons_without_nearby_ammo"] == 1 \
		and totals["ammo_without_poi_weapon"] == 2 \
		and totals["ammo_without_initial_weapon"] == 1 \
		and totals["ammo_rounds"] == {"ar": 15, "shotgun": 4, "railgun": 2}
	# 같은 POI지만 3m 밖인 재고, 0발 묶음, 빈 입력을 별도로 검증한다.
	var distant: Dictionary = AUDIT.summarize([
		_record("A", "weapon", "ar", 0, 0.0), _record("A", "ammo", "ar", 15, 3.01),
	])["totals"]
	var zero: Dictionary = AUDIT.summarize([
		_record("A", "weapon", "ar", 0, 0.0), _record("A", "ammo", "ar", 0, 0.0),
	])["totals"]
	passed = passed and distant["weapons_without_poi_ammo"] == 0 \
		and distant["weapons_without_nearby_ammo"] == 1 \
		and zero["weapons_without_poi_ammo"] == 1 \
		and AUDIT.summarize([])["totals"]["items"] == 0
	if not passed:
		push_error("Loot audit contract failed: %s" % JSON.stringify(result))
		quit(1)
		return
	print("Loot flow audit fixture passed: shared packs, POI boundary, distance, rounds, empty, immutable.")
	quit(0)


func _record(poi: String, kind: String, family: String, amount: int, x: float) -> Dictionary:
	return {"poi": poi, "kind": kind, "family": family, "amount": amount, "position": [x, 0.0]}
