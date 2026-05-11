class_name SupplyDropController
extends RefCounted

var telegraph_time: float = 8.0
var spawn_extent: float = 25.0
var cluster_consumable_count: int = 4
var cluster_spread: float = 2.5

func start_telegraph() -> Dictionary:
	return {
		"pos": Vector3(randf_range(-spawn_extent, spawn_extent), 1.0, randf_range(-spawn_extent, spawn_extent)),
		"timer": telegraph_time,
	}

func pillar_progress(timer: float) -> float:
	if telegraph_time <= 0.0:
		return 1.0
	return clampf(1.0 - (timer / telegraph_time), 0.0, 1.0)

func consumable_count() -> int:
	return max(0, cluster_consumable_count)

func random_cluster_offset() -> Vector3:
	return Vector3(
		randf_range(-cluster_spread, cluster_spread),
		0.0,
		randf_range(-cluster_spread, cluster_spread)
	)
