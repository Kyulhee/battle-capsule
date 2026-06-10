# Battle Capsule

<p align="center">
  <img src="assets/icons/artifacts/red_trigger.png" width="72" alt="Red Trigger">
  <img src="assets/icons/artifacts/ghost_grass.png" width="72" alt="Ghost Grass">
  <img src="assets/icons/artifacts/zone_battery.png" width="72" alt="Zone Battery">
</p>

<p align="center">
  <strong>쿼터뷰 배틀로얄 프로토타입</strong><br>
  루팅, 은신, 자기장 압박, 아티팩트 선택이 짧은 생존전 안에서 충돌하는 Godot 게임입니다.
</p>

<p align="center">
  <a href="https://godotengine.org/"><img alt="Godot 4.6.2" src="https://img.shields.io/badge/Godot-4.6.2-478CBF?style=for-the-badge&logo=godot-engine&logoColor=white"></a>
  <a href="https://github.com/Kyulhee/battle-capsule/releases/tag/v2.0.0-pre-expansion"><img alt="Stable build" src="https://img.shields.io/badge/stable-v2.0.0_pre--expansion-2EA043?style=for-the-badge"></a>
  <a href="https://github.com/Kyulhee/battle-capsule/releases"><img alt="Downloads" src="https://img.shields.io/badge/downloads-Windows%20%7C%20macOS-111111?style=for-the-badge"></a>
</p>

---

## Download

Current stable build: **v2.0.0-pre-expansion**

| Platform | Download | Notes |
|---|---|---|
| Windows | [BattleRoyalePrototype_v2.0.0-pre-expansion_win64.zip](https://github.com/Kyulhee/battle-capsule/releases/download/v2.0.0-pre-expansion/BattleRoyalePrototype_v2.0.0-pre-expansion_win64.zip) | Smoke tested locally |
| macOS | [BattleRoyalePrototype_v2.0.0-pre-expansion_macos.zip](https://github.com/Kyulhee/battle-capsule/releases/download/v2.0.0-pre-expansion/BattleRoyalePrototype_v2.0.0-pre-expansion_macos.zip) | Cross-exported; first launch may require Privacy & Security approval |

> This is a stable pre-expansion snapshot. The 99-player/night-map work remains in development probes and is not promoted as the default game mode yet.

## Game Snapshot

Battle Capsule currently plays as a compact solo battle-royale match: one player drops into a forest arena with bots, finds weapons and supplies, chooses one artifact, and survives while the zone closes in.

| Pillar | In Game |
|---|---|
| Survival pressure | A shrinking blue zone forces movement and late-game conflict |
| Loot route choices | Weapons, ammo, heals, armor, and supply capsules create risk/reward paths |
| Readable stealth | Bushes, crouching, visibility, and night readability are active design axes |
| Artifact identity | Each artifact adds a strong advantage with a matching drawback |
| AI scaling work | Perception and sensory LOD are being prepared for larger match experiments |

## Artifacts

| Artifact | Role |
|---|---|
| <img src="assets/icons/artifacts/red_trigger.png" width="32" alt=""> **Red Trigger** | Strong shotgun pressure, higher reveal risk |
| <img src="assets/icons/artifacts/armor_sponge.png" width="32" alt=""> **Armor Sponge** | Converts recovery into shield, slows as shield grows |
| <img src="assets/icons/artifacts/silent_core.png" width="32" alt=""> **Silent Core** | Stealth movement identity with first-shot constraints |
| <img src="assets/icons/artifacts/zone_battery.png" width="32" alt=""> **Zone Battery** | Stronger near-zone play and blue plasma feedback |
| <img src="assets/icons/artifacts/emergency_shell.png" width="32" alt=""> **Escape Capsule** | Emergency recovery with a real follow-up cost |
| <img src="assets/icons/artifacts/ghost_grass.png" width="32" alt=""> **Ghost Grass** | Bush-based invisibility with vulnerability windows |

## Current Development Direction

The project is moving from a compact prototype toward a longer **10-15 minute night battle-royale** structure. The current plan is deliberately staged:

1. Keep the released build stable before large expansion work.
2. Use POI-scale probes and structural telemetry before promoting any 99-player map.
3. Add night readability, flashlight, battery, and bot awareness systems incrementally.
4. Treat scale telemetry as a safety gate, not as final balance.

See [docs/MASTERPLAN.md](docs/MASTERPLAN.md) and [docs/NIGHT_BR_PACING_PLAN.md](docs/NIGHT_BR_PACING_PLAN.md) for the active roadmap.

## Controls

<details>
<summary>Show controls</summary>

| Key | Action |
|---|---|
| `WASD` | Move |
| Mouse | Aim |
| Left Click | Fire or melee |
| `F` | Pick up nearby item |
| `Q` | Use heal |
| `C` | Toggle crouch |
| `R` | Reload from reserve ammo |
| `` ` `` | Knife slot |
| `1`-`4` | Weapon slots |
| `Space` | Jump |
| `Esc` | Pause/menu |

</details>

## Weapons And Items

<details>
<summary>Show equipment table</summary>

| Weapon | Magazine | Reserve | Role |
|---|---:|---:|---|
| Knife | - | - | Always available fallback |
| Pistol | 15 | 30 | Default weapon |
| AR | 30 | 60 | Reliable sustained fire |
| Shotgun | 6 | 12 | Close-range burst |
| Railgun | 2 | 4 | Slow, high-damage precision |

| Item | Effect |
|---|---|
| Heal | Restores HP |
| Advanced heal | Larger recovery |
| Armor | Adds shield |
| Ammo | Adds reserve ammo for matching weapon |
| Supply capsule | Drops rare combat options after zone progress |

</details>

## Project Docs

| Document | Purpose |
|---|---|
| [docs/DOCS_INDEX.md](docs/DOCS_INDEX.md) | Where to start reading |
| [docs/MASTERPLAN.md](docs/MASTERPLAN.md) | Current roadmap and scope boundaries |
| [docs/DEVLOG.md](docs/DEVLOG.md) | Recent verified work |
| [docs/TESTING.md](docs/TESTING.md) | Verification commands and telemetry interpretation |
| [docs/ASSET_STATUS.md](docs/ASSET_STATUS.md) | Integrated and deferred assets |
| [docs/RELEASE.md](docs/RELEASE.md) | Build and release process |

## Development

Requirements:

- Godot **4.6.2**
- Windows export is the primary smoke-tested target
- macOS export is produced from Godot and should be verified on actual Mac hardware before broad public distribution

Useful local checks:

```powershell
.\Godot_v4.6.2-stable_win64_console.exe --headless --script res://tools/verify_ai_lod_perception.gd
.\Godot_v4.6.2-stable_win64_console.exe --headless --script res://tools/verify_pickup_light_lod.gd
.\Godot_v4.6.2-stable_win64_console.exe --headless --script res://tools/verify_player_night_readability.gd
```

## Known Notes

- Some configured generated asset paths may be missing in local builds; fallbacks remain active.
- Current WIP branches may contain unpromoted 99-player/night-map probes.
- The latest public stable baseline is pinned by the GitHub tag `v2.0.0-pre-expansion`.
