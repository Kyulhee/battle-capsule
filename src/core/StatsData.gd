extends Resource
class_name StatsData

@export var move_speed: float = 5.0
@export var acceleration: float = 10.0
@export var friction: float = 10.0
@export var rotation_speed: float = 12.0
@export var max_health: float = 100.0

@export_group("Combat")
@export var attack_damage: float = 20.0
@export var fire_rate: float = 0.5 # Seconds between shots
@export var attack_range: float = 20.0
@export var vision_range: float = 25.0
@export var fov_angle: float = 120.0
@export var fov_near_range: float = 5.0
@export var fov_turn_speed: float = 10.0
@export var dwell_time_open: float = 0.3
@export var dwell_time_bush: float = 0.8
@export var detection_decay: float = 2.0 # Seconds to fully lose track

@export_group("Weapon Config")
@export var weapon_type: String = "pistol" # pistol, ar, shotgun
@export var pellet_count: int = 1 # 1 for standard, 5+ for shotgun
@export var max_shield: float = 100.0
@export var current_shield: float = 0.0

@export_group("Inventory")
@export var current_ammo: int = 20
@export var max_ammo: int = 100
@export var heal_items: int = 0
