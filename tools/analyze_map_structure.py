from __future__ import annotations

import argparse
import json
import math
from collections import Counter
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[1]


def load_map(path: Path) -> dict[str, Any]:
    with path.open("r", encoding="utf-8") as handle:
        data = json.load(handle)
    if not isinstance(data, dict):
        raise ValueError("Map JSON root must be an object.")
    return data


def merged_match(data: dict[str, Any], preset: str) -> dict[str, Any]:
    match = dict(data.get("match", {}))
    if preset:
        presets = data.get("scale_presets", {})
        if preset not in presets:
            raise ValueError(f"Unknown scale preset: {preset}")
        match.update(presets[preset].get("match", {}))
    return match


def obstacle_half_extents(obstacle: dict[str, Any]) -> tuple[float, float]:
    scale = obstacle.get("scale", [1.0, 1.0, 1.0])
    sx = float(scale[0])
    sz = float(scale[2])
    if obstacle.get("type") == "bush_patch":
        return sx * 1.5, sz * 1.5
    return sx, sz


def obstacle_area(obstacle: dict[str, Any]) -> float:
    hx, hz = obstacle_half_extents(obstacle)
    if obstacle.get("type") == "bush_patch":
        return math.pi * hx * hz
    if obstacle.get("type") == "rock_cluster":
        radius = max(hx, hz) * 1.6
        return math.pi * radius * radius
    return 4.0 * hx * hz


def point_to_obstacle_distance(x: float, z: float, obstacle: dict[str, Any]) -> float:
    pos = obstacle.get("pos", [0.0, 0.0])
    dx = x - float(pos[0])
    dz = z - float(pos[1])
    angle = math.radians(-float(obstacle.get("rot", 0.0)))
    local_x = dx * math.cos(angle) - dz * math.sin(angle)
    local_z = dx * math.sin(angle) + dz * math.cos(angle)
    hx, hz = obstacle_half_extents(obstacle)

    if obstacle.get("type") == "bush_patch":
        normalized = math.hypot(local_x / max(hx, 0.001), local_z / max(hz, 0.001))
        return max(0.0, normalized - 1.0) * min(hx, hz)

    outside_x = max(abs(local_x) - hx, 0.0)
    outside_z = max(abs(local_z) - hz, 0.0)
    return math.hypot(outside_x, outside_z)


def nearest_poi_distances(pois: list[dict[str, Any]]) -> list[float]:
    distances: list[float] = []
    for index, poi in enumerate(pois):
        pos = poi.get("pos", [0.0, 0.0])
        nearest = math.inf
        for other_index, other in enumerate(pois):
            if other_index == index:
                continue
            other_pos = other.get("pos", [0.0, 0.0])
            nearest = min(
                nearest,
                math.hypot(float(pos[0]) - float(other_pos[0]), float(pos[1]) - float(other_pos[1])),
            )
        if nearest < math.inf:
            distances.append(nearest)
    return distances


def empty_grid_metrics(
    world_size: float,
    obstacles: list[dict[str, Any]],
    grid_step: float,
    camera_half_width: float,
) -> tuple[list[tuple[float, float, float]], int, int, float]:
    half = world_size * 0.5
    samples: list[tuple[float, float, float]] = []
    beyond_camera = 0
    beyond_detection = 0
    distance_sum = 0.0
    z = -half + grid_step * 0.5
    while z < half:
        x = -half + grid_step * 0.5
        while x < half:
            nearest = min(
                (point_to_obstacle_distance(x, z, obstacle) for obstacle in obstacles),
                default=world_size,
            )
            samples.append((x, z, nearest))
            distance_sum += nearest
            if nearest > camera_half_width:
                beyond_camera += 1
            if nearest > 17.2:
                beyond_detection += 1
            x += grid_step
        z += grid_step
    return samples, beyond_camera, beyond_detection, distance_sum / max(1, len(samples))


def radial_empty_metrics(
    samples: list[tuple[float, float, float]],
    world_size: float,
    open_threshold: float,
) -> list[tuple[str, float, float]]:
    half = world_size * 0.5
    bands = [
        ("inner", 0.0, half / 3.0),
        ("middle", half / 3.0, half * 2.0 / 3.0),
        ("outer", half * 2.0 / 3.0, math.inf),
    ]
    result: list[tuple[str, float, float]] = []
    for name, minimum, maximum in bands:
        distances = [
            nearest
            for x, z, nearest in samples
            if minimum <= math.hypot(x, z) < maximum
        ]
        if not distances:
            continue
        result.append(
            (
                name,
                sum(distances) / len(distances),
                sum(distance > open_threshold for distance in distances) / len(distances),
            )
        )
    return result


def top_empty_cells(
    samples: list[tuple[float, float, float]],
    count: int = 8,
    minimum_spacing: float = 20.0,
) -> list[tuple[float, float, float]]:
    selected: list[tuple[float, float, float]] = []
    for candidate in sorted(samples, key=lambda sample: sample[2], reverse=True):
        if all(
            math.hypot(candidate[0] - chosen[0], candidate[1] - chosen[1]) >= minimum_spacing
            for chosen in selected
        ):
            selected.append(candidate)
        if len(selected) >= count:
            break
    return selected


def poi_context_metrics(
    poi: dict[str, Any],
    physical_obstacles: list[dict[str, Any]],
    concealment_obstacles: list[dict[str, Any]],
    open_threshold: float,
    sample_step: float = 4.0,
) -> dict[str, Any]:
    raw_position = poi.get("pos", [0.0, 0.0])
    center = (float(raw_position[0]), float(raw_position[1]))
    radius = max(1.0, float(poi.get("radius", 1.0)))
    local_samples: list[tuple[float, float]] = []
    z = center[1] - radius
    while z <= center[1] + radius:
        x = center[0] - radius
        while x <= center[0] + radius:
            if math.hypot(x - center[0], z - center[1]) <= radius:
                local_samples.append((x, z))
            x += sample_step
        z += sample_step

    physical_distances = [
        min(
            (point_to_obstacle_distance(x, z, obstacle) for obstacle in physical_obstacles),
            default=open_threshold * 2.0,
        )
        for x, z in local_samples
    ]
    concealment_distances = [
        min(
            (point_to_obstacle_distance(x, z, obstacle) for obstacle in concealment_obstacles),
            default=open_threshold * 2.0,
        )
        for x, z in local_samples
    ]
    boundary_samples = [
        (
            center[0] + math.cos(index * math.tau / 16.0) * radius,
            center[1] + math.sin(index * math.tau / 16.0) * radius,
        )
        for index in range(16)
    ]
    blocked_boundary = sum(
        min(
            (point_to_obstacle_distance(x, z, obstacle) for obstacle in physical_obstacles),
            default=open_threshold * 2.0,
        )
        <= 2.5
        for x, z in boundary_samples
    )
    nearby_physical = sum(
        point_to_obstacle_distance(center[0], center[1], obstacle) <= radius + 6.0
        for obstacle in physical_obstacles
    )
    nearby_concealment = sum(
        point_to_obstacle_distance(center[0], center[1], obstacle) <= radius + 4.0
        for obstacle in concealment_obstacles
    )
    return {
        "name": str(poi.get("name", "Unnamed POI")),
        "role": str(poi.get("role", "")),
        "item_density": float(poi.get("item_density", 0.0)),
        "nearby_physical": nearby_physical,
        "nearby_concealment": nearby_concealment,
        "open_ratio": sum(distance > open_threshold for distance in physical_distances)
        / max(1, len(physical_distances)),
        "concealment_ratio": sum(distance <= 2.5 for distance in concealment_distances)
        / max(1, len(concealment_distances)),
        "blocked_boundary_ratio": blocked_boundary / len(boundary_samples),
    }


def analyze(args: argparse.Namespace) -> None:
    path = Path(args.map)
    if not path.is_absolute():
        path = ROOT / path
    data = load_map(path)
    metadata = data.get("metadata", {})
    world_size = float(metadata.get("world_size", 0.0))
    world_area = world_size * world_size
    obstacles = [item for item in data.get("obstacles", []) if isinstance(item, dict)]
    pois = [item for item in data.get("pois", []) if isinstance(item, dict)]
    match = merged_match(data, args.preset)
    participants = int(match.get("bot_count", 0)) + 1
    spawn_radius = float(match.get("spawn_radius", 0.0))
    spawn_area = math.pi * spawn_radius * spawn_radius
    physical_obstacles = [item for item in obstacles if item.get("type") != "bush_patch"]
    concealment_obstacles = [item for item in obstacles if item.get("type") == "bush_patch"]
    physical_coverage = sum(obstacle_area(obstacle) for obstacle in physical_obstacles)
    concealment_coverage = sum(obstacle_area(obstacle) for obstacle in concealment_obstacles)
    coverage_sum = physical_coverage + concealment_coverage
    poi_area_sum = sum(math.pi * float(poi.get("radius", 0.0)) ** 2 for poi in pois)
    poi_distances = nearest_poi_distances(pois)
    camera_width = args.camera_height * args.aspect
    samples, beyond_camera, beyond_detection, avg_empty_distance = empty_grid_metrics(
        world_size,
        obstacles,
        args.grid_step,
        camera_width * 0.5,
    )

    print(f"Map: {metadata.get('name', path.stem)} ({path.name})")
    print(
        f"World: {world_size:.0f}m x {world_size:.0f}m, "
        f"cross={world_size / args.player_speed:.1f}s, "
        f"diagonal={world_size * math.sqrt(2.0) / args.player_speed:.1f}s"
    )
    print(
        f"Camera: {args.camera_height:.1f}m x {camera_width:.1f}m; "
        f"world spans {world_size / max(camera_width, 0.001):.1f} camera widths"
    )
    print(
        f"Preset: {args.preset or 'base'}, bots={participants - 1}, "
        f"loot={int(match.get('loot_count', 0))}, spawn={spawn_radius:.1f}m, "
        f"spawn area/participant={spawn_area / max(1, participants):.1f}m2"
    )
    print(
        f"Obstacles: {len(obstacles)}, types={dict(sorted(Counter(str(item.get('type', 'unknown')) for item in obstacles).items()))}"
    )
    print(
        f"Obstacle footprint sum: {coverage_sum:.1f}m2 "
        f"({100.0 * coverage_sum / max(world_area, 1.0):.2f}% before overlap); "
        f"physical={100.0 * physical_coverage / max(world_area, 1.0):.2f}%, "
        f"concealment={100.0 * concealment_coverage / max(world_area, 1.0):.2f}%"
    )
    print(
        f"POIs: {len(pois)}, circle sum={poi_area_sum:.1f}m2 "
        f"({100.0 * poi_area_sum / max(world_area, 1.0):.2f}% before overlap)"
    )
    if poi_distances:
        print(
            f"POI nearest spacing: min={min(poi_distances):.1f}m "
            f"avg={sum(poi_distances) / len(poi_distances):.1f}m "
            f"max={max(poi_distances):.1f}m"
        )
    print(
        f"Empty grid ({args.grid_step:.0f}m): avg obstacle-edge distance={avg_empty_distance:.1f}m, "
        f">{camera_width * 0.5:.1f}m={100.0 * beyond_camera / max(1, len(samples)):.1f}%, "
        f">17.2m={100.0 * beyond_detection / max(1, len(samples)):.1f}%"
    )
    radial_metrics = radial_empty_metrics(samples, world_size, camera_width * 0.5)
    print(
        "Radial empty bands: "
        + ", ".join(
            f"{name}=avg {average:.1f}m/open {open_ratio * 100.0:.1f}%"
            for name, average, open_ratio in radial_metrics
        )
    )
    print(
        "Top empty cells: "
        + ", ".join(
            f"({x:.0f},{z:.0f}) {distance:.1f}m"
            for x, z, distance in top_empty_cells(samples)
        )
    )

    poi_contexts = [
        poi_context_metrics(
            poi,
            physical_obstacles,
            concealment_obstacles,
            camera_width * 0.5,
        )
        for poi in pois
    ]
    weighted_density = sum(context["item_density"] for context in poi_contexts)
    weighted_open = sum(
        context["item_density"] * context["open_ratio"] for context in poi_contexts
    ) / max(0.001, weighted_density)
    print(f"Loot-weighted POI open ratio: {weighted_open * 100.0:.1f}%")
    print("POI tactical context:")
    for context in sorted(
        poi_contexts,
        key=lambda item: (item["item_density"], item["open_ratio"]),
        reverse=True,
    ):
        print(
            "  "
            f"{context['name']}: role={context['role']} loot={context['item_density']:.2f} "
            f"physical={context['nearby_physical']} concealment={context['nearby_concealment']} "
            f"open={context['open_ratio'] * 100.0:.1f}% "
            f"concealed={context['concealment_ratio'] * 100.0:.1f}% "
            f"blocked_edge={context['blocked_boundary_ratio'] * 100.0:.1f}%"
        )


def main() -> int:
    parser = argparse.ArgumentParser(description="Report comparable spatial metrics for a map spec.")
    parser.add_argument("map", help="Map JSON path, relative to repository root or absolute.")
    parser.add_argument("--preset", default="", help="Optional scale preset used for participant density.")
    parser.add_argument("--player-speed", type=float, default=6.0)
    parser.add_argument("--camera-height", type=float, default=12.0)
    parser.add_argument("--aspect", type=float, default=16.0 / 9.0)
    parser.add_argument("--grid-step", type=float, default=10.0)
    args = parser.parse_args()
    analyze(args)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
