class_name ItemResourceCatalog
extends RefCounted

const PICKUP_SCENE: PackedScene = preload("res://src/entities/pickup/Pickup.tscn")

const AMMO_AR: ItemData = preload("res://src/items/ammo_ar.tres")
const AMMO_SHOTGUN: ItemData = preload("res://src/items/ammo_shotgun.tres")
const AMMO_RAILGUN: ItemData = preload("res://src/items/ammo_railgun.tres")
const HEAL_PICKUP: ItemData = preload("res://src/items/heal_pickup.tres")
const HEAL_ADVANCED_PICKUP: ItemData = preload("res://src/items/heal_advanced_pickup.tres")
const WEAPON_AR: ItemData = preload("res://src/items/weapon_ar.tres")
const WEAPON_SHOTGUN: ItemData = preload("res://src/items/weapon_shotgun.tres")
const WEAPON_RAILGUN: ItemData = preload("res://src/items/weapon_railgun.tres")
const ARMOR_PICKUP: ItemData = preload("res://src/items/armor_pickup.tres")

static func pickup_scene() -> PackedScene:
	return PICKUP_SCENE

static func default_item_templates() -> Array[ItemData]:
	return [
		AMMO_AR,
		AMMO_SHOTGUN,
		AMMO_RAILGUN,
		HEAL_PICKUP,
		WEAPON_AR,
		WEAPON_SHOTGUN,
		ARMOR_PICKUP,
	]

static func extra_consumable_templates() -> Array[ItemData]:
	return [
		HEAL_ADVANCED_PICKUP,
	]

static func supply_railgun_item() -> ItemData:
	return WEAPON_RAILGUN
