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
) -> tuple[int, int, float, float]:
    half = world_size * 0.5
    samples = 0
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
            samples += 1
            distance_sum += nearest
            if nearest > camera_half_width:
                beyond_camera += 1
            if nearest > 17.2:
                beyond_detection += 1
            x += grid_step
        z += grid_step
    return samples, beyond_camera, beyond_detection, distance_sum / max(1, samples)


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
        f">{camera_width * 0.5:.1f}m={100.0 * beyond_camera / max(1, samples):.1f}%, "
        f">17.2m={100.0 * beyond_detection / max(1, samples):.1f}%"
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
