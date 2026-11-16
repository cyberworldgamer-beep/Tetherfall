# TETHERFALL

**Ride the wreckage. Feed the gate.**

A zero-gravity tether-swing salvage game built in **Godot 4.4** with GDScript only.
You fly **KITE-7**, a salvage drone with no brakes worth mentioning. Fire a tether
into an asteroid and the rock becomes your anchor: reel in, build momentum, and
sling yourself through a collapsing Kessler belt. Harvest aether cores and punch
them through the salvage gate before the contract clock runs dry.

---

## Run it

Godot 4.4.1 is installed for this project at:

```
C:\Godot\Godot_v4.4.1-stable_win64.exe
```

Launch the game:

```powershell
& C:\Godot\Godot_v4.4.1-stable_win64.exe --path C:\Projects\Tetherfall
```

Headless smoke test (no window):

```powershell
& C:\Godot\Godot_v4.4.1-stable_win64_console.exe --headless --path C:\Projects\Tetherfall res://tests/gameplay_smoke.tscn
```

The main scene is `res://scenes/main_menu.tscn`. 1600x900 window, 1920x1080
design viewport, Forward+ renderer.

---

## Controls

| Input | Action |
| --- | --- |
| Mouse | Aim camera / reticle |
| **Left mouse / F** | Fire tether at the highlighted rock or gate |
| **Right mouse / X** | Release tether |
| **Mouse wheel** | Reel tether in / out |
| **W / S** (or ↑ / ↓) | Forward / reverse thrust |
| **A / D** (or ← / →) | Strafe |
| **Space / Ctrl** | Ascend / descend |
| **Shift** | Boost (drains the boost bar) |
| **Esc** | Pause (settings available mid-run) |
| **R** | Restart from the results screen |
| **H** | Toggle contextual hints |

---

## The loop

1. **Scavenge** glowing aether cores drifting around the belt.
2. **Tether** to any asteroid (or the gate ring) for a momentum-preserving anchor.
   The rope is a distance constraint, not a teleport: your existing velocity is
   preserved and redirected.
3. **Deliver** the cargo through the gate aperture. Each core banks points and
   buys **+12 s**; a full three-core load buys extra time and repairs one hull.
4. **Chain** deliveries within 22 seconds to raise the multiplier up to **x8**.
   Damage, heat and boundary violations reset it.
5. **Survive** the dying star: stellar heat near the core, periodic solar flares,
   ion mines, and a hard boundary that recalls you to the sector.

A run starts with **120 seconds**, 3 hull points and 3 cargo slots. The clock caps
at 180 seconds. Heavy loads repair the hull, so the risk/reward is deliberate:
stay out longer for a bigger chain, or bank early and keep the run alive.

### Systems worth knowing

- **Custom star gravity** pulls the drone toward the star and scales with distance.
  It is applied as a force in `_integrate_forces` so the RigidBody solver stays in
  charge of collisions.
- **Tether constraint** is enforced inside `_integrate_forces`: once taut, the
  inward radial velocity is cancelled and a capped pull is applied along the rope
  until the distance is restored. Tangential velocity is untouched, which is the
  whole game.
- **Solar flare** pulses shove everything outward on a timer, with a charge-up
  warning on the star surface and a screen-shake/impulse release.
- **Heat** builds inside the 27 m stellar radius and scorches a hull point at
  full heat.
- **Mines** arm after a short delay and detonate on contact, applying radial
  damage and kick.
- **Asteroid field** is procedurally generated per run seed with convex collision
  hulls, faceted meshes, emissive crystal veins and hand-placed anchor rocks near
  the opening lane.
- **Screen shake, speed FOV, space dust, boost trails, pickup/deposit/explosion
  particles, gate energy field and corona shaders** provide the presentation layer.

---

## Modes and persistence

- **Free Run** — random seed, standard contract.
- **Daily Contract** — deterministic seed from the current date, separate record.

Settings and profile are saved to `user://settings.cfg` and `user://profile.cfg`
(Godot's per-user app data folder). The profile tracks best score, daily best,
runs, total cores, deposits, best chain and longest flight.

---

## Project layout

```
project.godot                  autoloads, renderer, zero gravity, input defaults
scenes/
  main_menu.tscn               menu, daily contract, settings, flight manual
  game.tscn                    complete run scene
  player.tscn  camera_rig.tscn
  star.tscn  gate.tscn  core.tscn  mine.tscn
  ui/hud.tscn  ui/pause_menu.tscn  ui/game_over.tscn
  ui/settings_panel.tscn  ui/controls_panel.tscn
scripts/
  autoload/                    GameConfig, AudioManager, UITheme
  world/                       AsteroidField, DyingStar, SalvageGate, AetherCore, IonMine
  player/                      PlayerDrone physics, DroneVisual, CameraRig
  ui/                          menu, HUD, pause, results, settings, controls, menu art
  fx/                          shared particle/shockwave effects
  game.gd                      run director: scoring, chain, clock, flares, spawns
shaders/                       nebula sky, menu background, star surface, corona,
                               gate field, shockwave, vignette
assets/fonts                   Orbitron + Rajdhani
assets/audio                   generated music loops and SFX
tools/generate_audio.py        procedural soundtrack/audio generator
tests/gameplay_smoke.tscn      headless assertion suite
tests/visual_capture.tscn      menu/gameplay/pause/results screenshot capture
screenshots/                   latest verified captures
```

---

## Verification

- Godot 4.4.1 headless editor import: no parse errors, no missing resources.
- Headless run of `game.tscn`: no runtime script errors.
- **`tests/gameplay_smoke.tscn`: 39/39 assertions pass**, covering:
  - scene boot, initial cores/mines/asteroids, state machine;
  - tether attach, aim data, real rope distance constraint, release;
  - core pickup, cargo capacity, HUD sync;
  - first and second gate deposits, score/time awards, chain increments;
  - mine detonation damage and consumption;
  - hull damage and chain reset;
  - pause/resume (tree + overlay + state);
  - hull-failure results screen + profile submission;
  - clock-expiry results screen.
- Visual captures are regenerated with `tests/visual_capture.tscn` and reviewed at
  1600x900: `screenshots/menu.png`, `gameplay.png`, `pause.png`, `gameover.png`.

Note: forced headless exits report `ObjectDB instances leaked at exit` /
`N resources still in use at exit`. This is Godot's exit-time cleanup noise for
resources still referenced by the running test scene; it is not a gameplay error
and does not occur when exiting normally through the menus.

---

Built for momentum. No placeholders, no filler systems.