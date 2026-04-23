extends Resource
class_name ItemData

enum Type { WEAPON, AMMO, HEAL, ARMOR }
enum Rarity { COMMON, RARE }

@export var type: Type = Type.AMMO
@export var rarity: Rarity = Rarity.COMMON
@export var item_name: String = "Item"
@export var amount: int = 10
@export var weapon_stats: StatsData # Used if it's a weapon type
@export var color: Color = Color.WHITE
