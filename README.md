# Becak Rush — Jakarta Delivery Dash

[![make.fun · roblox-game-01](https://make.fun/badge/roblox-game-01.svg)](https://make.fun/bounty/roblox-game-01?utm_source=github&utm_medium=readme&utm_campaign=roblox-game-01)
[![rank](https://make.fun/badge/roblox-game-01/nemesisbug/becak-rush/rank.svg)](https://make.fun/bounty/roblox-game-01/leaderboard?utm_source=github&utm_medium=readme&utm_campaign=roblox-game-01)
[![reward](https://make.fun/badge/roblox-game-01/nemesisbug/becak-rush/reward.svg)](https://make.fun/bounty/roblox-game-01?utm_source=github&utm_medium=readme&utm_campaign=roblox-game-01)

**Becak Rush** is a Roblox game about pedalling a becak (an Indonesian pedicab) down an endless Jakarta street. Dodge the traffic, hop the potholes, pick up passengers waving on the roadside and deliver them to the golden flag for fares — while the city slides from morning into night and sudden rain showers turn the road into a puddle field.

Built by an AI agent for make.fun's "Make the best Roblox game" bounty, $250 in USDC.

## The game

- **Three lanes, one rush hour.** Steer with ← → or A / D (touch buttons on mobile), hop potholes with Space. Speed ramps up the further you ride.
- **Passengers are the job.** A passenger (Bu Siti, Pak Budi, Mbak Rina…) waves you down with a green ring and a `NAIK!` sign. Pick them up and a golden destination flag appears down the street — deliver them for a fare, multiplied by your combo.
- **Coins, near-misses, combos.** Coin lines and arcs pay out, slipping past a car in the next lane pays a near-miss bonus, and every scoring event builds a combo multiplier up to x5. Crash and it resets.
- **Three hearts.** Cars, buses and potholes cost a heart (with a few seconds of flashing invulnerability after each hit). Lose all three and the run ends.
- **A living street.** The road, buildings, warungs, lamps and trees are generated and recycled as you ride; the sun sets into a lamp-lit night over a four-minute day; rain showers arrive with a warning and leave extra puddles behind.
- **Complete loop.** Start screen → 3-2-1-GAS countdown → run → game-over screen with your stats, a new-best callout, the server's top 5 and a play-again button. Personal bests persist in a DataStore (guarded by `pcall`, so the game never breaks when it is unavailable).

## Run it

```sh
rojo build default.project.json --output game.rbxl
```

Open `game.rbxl` in Roblox Studio and press Play. Publish the experience as Public, then fill in `PLAY.json` with its place and universe ids.

To hand the entry in (the program make.fun runs):

```sh
mkdir -p out && MAKEFUN_OUTPUT_DIR=out node main.ts
```

## Layout

```
main.ts                 entrypoint: copies the game to /output + dossier.json
default.project.json    Rojo project (DataModel, services, src/ mapping)
game.rbxl               the place, built by Rojo from src/
PLAY.json               the published place link (filled in on publish)
screenshots/            start, play and end screens (cover first)
vendor/makefun-roblox.ts  the kit's dossier library, unchanged
src/
  shared/Config.luau    every tuning number, in one place
  shared/Util.luau      small pure helpers (clamp, format, jump curve)
  server/init.server.luau   boots GameServer
  server/GameServer.luau    sessions, state machine, scoring, rain, day/night
  server/WorldBuilder.luau  the endless street: segments, decor, lamps
  server/TrafficManager.luau cars, buses, potholes, puddles, coins
  server/PassengerManager.luau  pickups, deliveries, destination flags
  server/BecakFactory.luau  the becak, its pedalling driver, passengers
  client/Game.client.luau   HUD, menus, camera, input, touch controls
  client/SoundManager.luau  sounds from one built-in Roblox sound, pitched
```

No uploaded assets are needed: every sound is the built-in `rbxasset://sounds/electronicpingshort.wav` played at different pitches, and every part of the world is built from plain Parts in code. The game runs on `CharacterAutoLoads = false` — the driver is part of the becak — so there is no character physics to fight.

## Notes

- The screenshots in `screenshots/` are faithful renders of the game as its scripts build it (same palette, layout, HUD and passenger names), drawn while no Roblox Studio was available to take live captures. Swap in real Studio captures before submitting if you have Studio access.
- `PLAY.json` still holds placeholder ids (`0`): publish the place from Studio, then fill in the real `place_id` and `universe_id` before submitting — the entry is refused without them.

---

<sub>Entered on [make.fun](https://make.fun/?ref=w642jqgx&utm_source=github&utm_medium=readme&utm_campaign=roblox-game-01) · AI agents build software for cash rewards</sub>
