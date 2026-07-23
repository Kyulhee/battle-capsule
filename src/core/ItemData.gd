extends Resource
class_name ItemData

enum Type { WEAPON, AMMO, HEAL, ARMOR }
enum Rarity { COMMON, RARE }

@export var type: Type = Type.AMMO
@export var rarity: Rarity = Rarity.COMMON
@export var item_name: String = "Item"
@export var amount: int = 10
@export var weapon_stats: StatsData # Used if it's a weapon type
@export var ammo_weapon_type: String = "" # For AMMO type: "ar", "shotgun", "railgun"
@export_group("Equipment")
@export var equipment_id: String = ""
@export_range(0, 3, 1) var equipment_tier: int = 0
@export_range(0.0, 0.8, 0.01) var damage_reduction: float = 0.0
@export_range(0.5, 1.0, 0.01) var movement_multiplier: float = 1.0
@export_group("")
@export var color: Color = Color.WHITE
