extends SceneTree

const ITEMS = preload("res://src/core/ItemResourceCatalog.gd")
const SLOTS = preload("res://src/core/WeaponSlotManager.gd")
var failures: Array[String] = []

class Collector:
	extends Entity
	var slots := WeaponSlotManager.new()
	var blocked := ""
	func can_receive_ammo(family: String, amount: int) -> bool:
		return slots.can_receive_ammo(family, amount)
	func receive_ammo(family: String, amount: int) -> void:
		slots.receive_ammo(family, amount)
	func notify_survival_pickup_blocked(reason: String) -> void:
		blocked = reason


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var collector := Collector.new()
	collector.stats = StatsData.new()
	root.add_child(collector)
	collector.add_to_group("players")
	var pickup = ITEMS.PICKUP_SCENE.instantiate()
	root.add_child(pickup)
	pickup.init(ITEMS.AMMO_AR.duplicate(true), "retention_fixture")
	_check(not pickup.collect(collector), "Unowned ammo must be rejected.")
	_check(not pickup.is_queued_for_deletion(), "Unowned ammo disappeared.")
	_check(collector.blocked == "ammo_not_needed", "Rejected pickup gave no feedback.")
	var slots = collector.slots
	slots.receive_weapon(ITEMS.WEAPON_AR_WORN.weapon_stats)
	slots.switch_to(0)
	_check(pickup.collect(collector), "Ammo for an inactive owned gun must be accepted.")
	_check(pickup.is_queued_for_deletion() and slots.slot_reserve[1] == 15, "Accepted ammo was not transferred once.")
	# 재장전 중 업그레이드: 예약된 전송은 취소하고 예비탄을 보존한다.
	slots.switch_to(1)
	slots.slot_ammo[1] = 0
	_check(slots.start_reload(), "Fixture did not enter reload.")
	_check(slots.receive_weapon(ITEMS.WEAPON_AR.weapon_stats), "Upgrade rejected.")
	_check(slots.reload_timer == 0.0 and slots.slot_reserve[1] == 15, "Upgrade lost reserve or kept an old reload.")
	_check(slots.slot_ammo[1] == ITEMS.WEAPON_AR.weapon_stats.current_ammo, "Upgrade magazine changed.")
	slots.tick(10.0)
	_check(slots.slot_reserve[1] == 15, "Canceled reload consumed reserve later.")
	_check(not slots.receive_weapon(ITEMS.WEAPON_AR_WORN.weapon_stats), "Downgrade accepted.")
	slots.receive_weapon(ITEMS.WEAPON_SHOTGUN.weapon_stats)
	_check(slots.slot_reserve[2] == 0 and slots.slot_reserve[1] == 15, "New family inherited or erased other ammo.")
	slots.receive_ammo("ar", SLOTS.get_reserve_max("ar"))
	var full_pickup = ITEMS.PICKUP_SCENE.instantiate()
	root.add_child(full_pickup)
	full_pickup.init(ITEMS.AMMO_AR.duplicate(true), "retention_fixture")
	_check(not full_pickup.collect(collector) and not full_pickup.is_queued_for_deletion(), "Full reserve consumed a pack.")
	_check(not slots.can_receive_ammo("ar", 0) and not slots.can_receive_ammo("ar", -1), "Nonpositive ammo accepted.")
	var cap: int = SLOTS.get_reserve_max("ar")
	slots.receive_ammo("ar", -10)
	_check(slots.slot_reserve[1] == cap, "Negative ammo reduced reserve.")
	# 기존 부분 수집 규칙 유지: 잔여 용량만 채우고 한 묶음을 소비한다.
	slots.slot_reserve[1] = cap - 1
	_check(full_pickup.collect(collector) and slots.slot_reserve[1] == cap, "Partial capacity/cap contract changed.")
	# 플레이어만 변경한다. 봇의 기존 수집/경로 선택은 여기서 재설계하지 않는다.
	collector.remove_from_group("players")
	var bot_pickup = ITEMS.PICKUP_SCENE.instantiate()
	root.add_child(bot_pickup)
	bot_pickup.init(ITEMS.AMMO_RAILGUN.duplicate(true), "retention_fixture")
	_check(bot_pickup._can_player_collect(collector), "Player gate changed nonplayer pickup rules.")
	pickup.free()
	full_pickup.free()
	bot_pickup.free()
	collector.free()
	if not failures.is_empty():
		for failure in failures:
			push_error(failure)
		quit(1)
		return
	print("Player ammo retention passed: unowned/full, inactive gun, upgrade/reload, family isolation, cap, nonplayer unchanged.")
	quit(0)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
