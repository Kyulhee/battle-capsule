extends "res://src/Main.gd"

# 실제 Main의 시계/갱신 분기를 호출하고 부수 효과만 격리한다.
var damage_elapsed := 0.0
var pressure_elapsed := 0.0
var supply_activations := 0

func _ready(): pass
func _check_match_end(): pass
func handle_damage_tick(delta): damage_elapsed += delta
func _process_pressure_mission(delta: float): pressure_elapsed += delta
func telegraph_supply_zone():
	supply_telegraphed = true
	supply_timer = 0.25
func activate_supply_zone():
	supply_spawned = true
	supply_activations += 1
