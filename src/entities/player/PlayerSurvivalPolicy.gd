extends RefCounted


const COMBAT_LOCK_MSEC := 6000
const MEDKIT_MAX_COUNT := 1
const MEDKIT_HEAL_AMOUNT := 50.0
const INJURED_HEALTH_RATIO := 0.50
const CRITICAL_HEALTH_RATIO := 0.25
const INJURED_MOVE_MULT := 0.92
const CRITICAL_MOVE_MULT := 0.82


static func is_in_combat(now_msec: int, last_combat_msec: int) -> bool:
	return last_combat_msec >= 0 \
		and now_msec >= last_combat_msec \
		and now_msec - last_combat_msec < COMBAT_LOCK_MSEC


static func can_collect_medkit(current_count: int) -> bool:
	return current_count < MEDKIT_MAX_COUNT


static func clamped_medkit_count(current_count: int, received_count: int) -> int:
	return clampi(current_count + maxi(0, received_count), 0, MEDKIT_MAX_COUNT)


static func medkit_heal_amount(
	is_hell: bool,
	scarcity_mult: float = 1.0,
	heal_mult: float = 1.0
) -> float:
	var difficulty_mult := 0.55 if is_hell else 1.0
	return MEDKIT_HEAL_AMOUNT \
		* difficulty_mult \
		* maxf(0.0, scarcity_mult) \
		* maxf(0.0, heal_mult)


static func health_movement_multiplier(current_health: float, max_health: float) -> float:
	if max_health <= 0.0:
		return CRITICAL_MOVE_MULT
	var health_ratio := clampf(current_health / max_health, 0.0, 1.0)
	if health_ratio <= CRITICAL_HEALTH_RATIO:
		return CRITICAL_MOVE_MULT
	if health_ratio <= INJURED_HEALTH_RATIO:
		return INJURED_MOVE_MULT
	return 1.0
