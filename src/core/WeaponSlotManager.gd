class_name WeaponSlotManager
extends RefCounted

const WeaponSlotTuningScript = preload("res://src/core/WeaponSlotTuning.gd")

signal slot_switched(slot: int, wdata, ammo: int)
signal reload_started()
signal reload_done()
signal inventory_changed()
signal gun_count_changed(count: int)

var weapon_slots: Array = [null, null, null, null, null]
var slot_ammo: Array    = [0, 0, 0, 0, 0]
var slot_reserve: Array = [0, 0, 0, 0, 0]
var active_slot: int    = 0

var reload_timer: float      = 0.0
var reload_total_time: float = 0.0
var reload_ammo_start: int   = 0
var reload_ammo_target: int  = 0

func can_receive_weapon(wstats: StatsData) -> bool:
	if wstats == null:
		return false
	for i in range(1, 5):
		if weapon_slots[i] != null and weapon_slots[i].weapon_type == wstats.weapon_type:
			return wstats.weapon_tier > weapon_slots[i].weapon_tier
	for i in range(1, 5):
		if weapon_slots[i] == null:
			return true
	return active_slot >= 1

func switch_to(slot: int) -> void:
	if slot < 0 or slot > 4: return
	reload_timer = 0.0
	active_slot = slot
	var wdata = weapon_slots[slot] if slot >= 1 else null
	var ammo  = slot_ammo[slot]  if slot >= 1 else 0
	slot_switched.emit(slot, wdata, ammo)

func receive_weapon(wstats: StatsData) -> bool:
	if not can_receive_weapon(wstats):
		return false
	for i in range(1, 5):
		if weapon_slots[i] != null and weapon_slots[i].weapon_type == wstats.weapon_type:
			weapon_slots[i] = wstats
			slot_ammo[i] = wstats.current_ammo
			slot_reserve[i] = 0
			switch_to(i)
			_emit_gun_count()
			return true
	for i in range(1, 5):
		if weapon_slots[i] == null:
			weapon_slots[i] = wstats
			slot_ammo[i]    = wstats.current_ammo
			slot_reserve[i] = 0
			switch_to(i)
			_emit_gun_count()
			return true
	if active_slot >= 1:
		weapon_slots[active_slot] = wstats
		slot_ammo[active_slot]    = wstats.current_ammo
		slot_reserve[active_slot] = 0
		switch_to(active_slot)
		_emit_gun_count()
		return true
	return false

func receive_ammo(weapon_type: String, amount: int) -> void:
	for i in range(1, 5):
		var wdata = weapon_slots[i]
		if wdata and wdata.weapon_type == weapon_type:
			slot_reserve[i] = min(slot_reserve[i] + amount, get_reserve_max(weapon_type))
			inventory_changed.emit()
			return

func consume_ammo() -> void:
	if active_slot >= 1 and slot_ammo[active_slot] > 0:
		slot_ammo[active_slot] -= 1

func try_auto_switch() -> void:
	for i in range(1, 5):
		if weapon_slots[i] != null and slot_ammo[i] > 0:
			switch_to(i); return
	for i in range(1, 5):
		if weapon_slots[i] != null and slot_reserve[i] > 0:
			switch_to(i); start_reload(); return
	switch_to(0)

func start_reload() -> bool:
	if active_slot == 0: return false
	var wdata = weapon_slots[active_slot]
	if not wdata: return false
	if slot_reserve[active_slot] <= 0: return false
	if slot_ammo[active_slot] >= wdata.max_ammo: return false
	if reload_timer > 0: return false
	var transfer   = min(slot_reserve[active_slot], wdata.max_ammo - slot_ammo[active_slot])
	reload_ammo_start  = slot_ammo[active_slot]
	reload_ammo_target = slot_ammo[active_slot] + transfer
	reload_total_time  = get_reload_time()
	reload_timer       = reload_total_time
	reload_started.emit()
	return true

func tick(delta: float) -> void:
	if reload_timer <= 0: return
	reload_timer -= delta
	if reload_timer <= 0:
		var wdata = weapon_slots[active_slot]
		if wdata:
			var transferred = reload_ammo_target - reload_ammo_start
			slot_ammo[active_slot]    = reload_ammo_target
			slot_reserve[active_slot] = max(0, slot_reserve[active_slot] - transferred)
		reload_done.emit()
		inventory_changed.emit()

func fill_all_ammo() -> void:
	for i in range(1, 5):
		if weapon_slots[i] != null:
			slot_ammo[i] = weapon_slots[i].max_ammo
			slot_reserve[i] = get_reserve_max(weapon_slots[i].weapon_type)
	inventory_changed.emit()

func clear_all_ammo() -> void:
	for i in range(1, 5):
		slot_ammo[i]    = 0
		slot_reserve[i] = 0
	inventory_changed.emit()

func clear_active_ammo() -> void:
	if active_slot >= 1:
		slot_ammo[active_slot]    = 0
		slot_reserve[active_slot] = 0
		inventory_changed.emit()

func get_reload_time() -> float:
	var wdata = weapon_slots[active_slot]
	if not wdata:
		return WeaponSlotTuningScript.NO_WEAPON_RELOAD_TIME
	return WeaponSlotTuningScript.reload_time(wdata.weapon_type)

static func get_reserve_max(wtype: String) -> int:
	return WeaponSlotTuningScript.reserve_max(wtype)

func _emit_gun_count() -> void:
	var count = 0
	for i in range(1, 5):
		if weapon_slots[i] != null: count += 1
	gun_count_changed.emit(count)
