WAV files placed here override the procedural fallback in SoundManager.gd.
All files must be 44100 Hz, 16-bit PCM mono .wav

Required filenames:
  shoot.wav       — gunshot
  hit.wav         — bullet hits entity
  impact_wall.wav — bullet hits wall/obstacle
  hurt.wav        — player takes damage (non-positional)
  death.wav       — entity death
  dry_fire.wav    — empty magazine click (non-positional)
  pickup.wav      — item collected
  heal.wav        — healing used (non-positional)

Recommended free sources (CC0 — commercial use OK, no attribution required):
  Kenney Impact Sounds   https://kenney.nl/assets/impact-sounds
  Kenney Interface Sounds https://kenney.nl/assets/interface-sounds
  Kenney Game Audio       https://kenney.nl/assets/game-audio

Suggested Kenney file mappings:
  shoot.wav        <- impactMetal_medium_000.ogg (convert to wav)  or  laserSmall_000.wav
  hit.wav          <- impactFlesh_medium_000.ogg
  impact_wall.wav  <- impactMetal_light_000.ogg
  hurt.wav         <- damage1.ogg
  death.wav        <- explosionCrunch_000.ogg
  dry_fire.wav     <- impactPlate_000.ogg
  pickup.wav       <- pickupCoin_000.ogg
  heal.wav         <- powerUp3.ogg
