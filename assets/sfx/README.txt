Battle Capsule 오디오 자산

런타임 형식:
- WAV
- OGG
- mono
- 44.1 kHz
- 16-bit PCM

무기 발사음 4종:
- 출처: OpenGameArt "Gunshot Sounds" by Tabasco
- 원본 URL: https://opengameart.org/content/gunshot-sounds
- 라이선스: CC0
- pistol: cz.wav 단발
- ar: sks.wav 단발
- shotgun: shotty.wav 단발
- railgun: mosin.wav 단발
- 처리: 단발 구간 절단, mono 변환, 44.1 kHz 재표본화, 42-55 Hz
  high-pass, 11.5-13.5 kHz low-pass, 끝부분 fade, peak 0.45-0.60

칼 휘두르기 3종:
- 출처: OpenGameArt "Swishes Sound Pack" by artisticdude
- 원본 URL: https://opengameart.org/content/swishes-sound-pack
- 라이선스: CC0
- melee: swish-1.wav, swish-4.wav, swish-7.wav
- 런타임: 직전 변형을 피해서 선택하고 -7.5 dB로 재생

칼 피격:
- 출처: OpenGameArt/LPC "Impact" by qubodup
- 원본 URL: https://lpc.opengameart.org/content/impact
- 라이선스: CC0
- melee hit: qubodupImpactMeat01.ogg
- 런타임: 실제 명중할 때만 -4.5 dB로 재생

발걸음 3종:
- 출처: Kenney Impact Sounds / RPG Audio
- 라이선스: CC0
- grass: footstep_grass_000.ogg
- dirt: footstep00.ogg
- stone: footstep_concrete_000.ogg

런타임 계약:
- data/asset_catalog.json에 ID와 경로를 등록한다.
- SoundManager는 성공한 스트림을 ID별로 캐시한다.
- 무기음은 ID별 volume_db와 ±2% pitch variation을 적용한다.
- 권총은 AR보다 작게 재생하고, 앉기 발걸음은 -10 dB를 추가 감쇠한다.
- tools/verify_audio_catalog_assets.gd가 파일, 길이, 캐시와 playback
  profile을 검증한다.
