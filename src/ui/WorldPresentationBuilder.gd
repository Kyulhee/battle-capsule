class_name WorldPresentationBuilder
extends RefCounted

const ZONE_RING_INNER_RADIUS := 0.98
const ZONE_RING_OUTER_RADIUS := 1.0
const ZONE_RING_HEIGHT := 0.1
const ZONE_RING_COLOR := Color(0.2, 0.6, 1.0, 0.8)
const ZONE_RING_EMISSION := Color(0.2, 0.6, 1.0)
const SUPPLY_PILLAR_START_Y := 50.0
const SUPPLY_PILLAR_END_Y := 0.0

static func create_zone_ring() -> MeshInstance3D:
	var ring = MeshInstance3D.new()
	var torus = TorusMesh.new()
	torus.inner_radius = ZONE_RING_INNER_RADIUS
	torus.outer_radius = ZONE_RING_OUTER_RADIUS
	ring.mesh = torus

	var material = StandardMaterial3D.new()
	material.albedo_color = ZONE_RING_COLOR
	material.emission_enabled = true
	material.emission = ZONE_RING_EMISSION
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring.mesh.surface_set_material(0, material)
	ring.position.y = ZONE_RING_HEIGHT
	return ring

static func sync_zone_ring(ring: MeshInstance3D, zone) -> void:
	if not ring or not zone:
		return
	ring.scale = Vector3(zone.current_radius, 1.0, zone.current_radius)
	ring.position.x = zone.current_center.x
	ring.position.z = zone.current_center.y

static func update_supply_pillar_drop(pillar: MeshInstance3D, progress: float) -> void:
	if not pillar:
		return
	pillar.global_position.y = lerp(SUPPLY_PILLAR_START_Y, SUPPLY_PILLAR_END_Y, progress)
