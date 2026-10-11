# Bomb It 1 rebuild

A playable Godot rebuild using artwork, audio, and rules recovered from the
included SWF. Open `godot/project.godot` in Godot 4.7 and press **F6/F5** from the
main scene/project. No external asset downloads are needed.

## Playing

- **1 player:** arrows or WASD to move; Space for bombs/special weapons.
- **2 players:** P1 uses WASD + Space; P2 uses arrows + Enter. Each chooses a robot.
- **Pause:** Esc or P. **Sound:** M or the sound button. Focus loss pauses play.
- **Touch:** enabled on Android/iOS; the TOUCH button enables it on desktop.
  The left stick chooses one cardinal direction; the right button fires. Wide
  landscape windows put the controls beside the preserved 550×400 game area.
- Release fire between special-weapon shots. Ordinary bombs accept held fire.

The game includes five arena themes, the recovered board-generation algorithm,
four animated robots, three difficulty levels, AI opponents, normal upgrades,
pushable bombs, rockets, mines, grenades, gas, ice and fire weapons, music and
effects, scoring, lives, retry, campaign progression, and a saved local best score.
Easy/normal/hard campaigns contain 15/20/25 stages.

Simulation remains fixed at **35 Hz**. Heroes, moving bombs, and projectiles
interpolate between simulation positions at the display rate. Recovered Flash
timelines drive character deaths, pickup bobbing/removal, and rocket exhaust and
smoke. Input is shared by keyboard and touch.
This project has been tested on Windows; native iPhone export/signing and device
performance validation remain outstanding.

## Tests

Replace `godot` with your Godot executable if it is not on PATH:

```powershell
godot --headless --path godot --editor --import --quit
godot --headless --path godot --script res://tests/sim_check.gd
godot --headless --path godot --script res://tests/actors_check.gd
godot --headless --path godot --script res://tests/view_check.gd
godot --headless --path godot --script res://tests/timeline_check.gd
godot --headless --path godot --script res://tests/campaign_check.gd
godot --headless --path godot --script res://tests/special_check.gd
godot --headless --path godot --script res://tests/soak_check.gd
godot --path godot --script res://tests/ui_check.gd
godot --path godot --script res://tests/visual_timelines.gd
```

The UI harness uses a real renderer, exercises the game flow, and saves screenshots
under `reference/qa-*.png`. It disables preference writes. The soak test exercises
21,600 ticks across 18 seeded matches and checks inventory and explosion energy.
`tools/run_checks.ps1 -Godot <executable> -Visual` runs all of these checks.

See [the rebuild status](reference/rebuild-status.md) for source evidence,
implementation scope, and the remaining fidelity work. This is a playable rebuild,
not a claim of frame-exact Flash emulation.
