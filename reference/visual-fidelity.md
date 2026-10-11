# Visual fidelity pass

The accepted simulation is unchanged. Presentation uses original 35-fps timeline
data while movement interpolates at the display rate.

## Source-backed changes

- **Character death:** Sprite 237 attaches a downward-facing hero and brick burst
  on frame 1, replaces the hero with Sprite 236's character silhouette on frame 6,
  and removes itself on frame 36. Its XFL provides the silhouette fade and shadow.
  `hurtHero` separately attaches Sprite 279 smoke above the scenery. `HeroView`
  composes these parts, including the correct silhouette for each character.
  Symbol 236's body (233/235) and eyes (234) now draw separately: flattening them
  into one PNG incorrectly kept the eyes white during the silhouette fade.
  `HeroView` explicitly uses the same linear filtering as its normal `GameView`
  parent, so standalone reference/contact-sheet fixtures exercise gameplay rendering.
- **Surviving hits:** `hurtHero` starts Symbol 279 at frame 20 for surviving AI
  damage. A presentation event now starts that smoke and removes it at frame 36;
  armor absorption and invulnerability retain their existing gameplay behavior.
- **Equipped weapon:** Symbol 299's nested item placement, multiplication signs
  and recovered count font now accompany the actor while charges remain.
  Original-runtime comparison of text rasterization/depth is still outstanding.
- **Pickups:** Sprite 326 contains an 80-frame idle loop and a removal label at
  frame 81; frame 101 removes the clip. Nested Sprite 293 chooses the item. The
  view preserves each pickup's own phase and replays source transforms and alpha,
  including the shadow, after the item leaves authoritative state.
- **Rockets:** Sprite 305 combines the directional rocket shape with animated
  Sprite 304 exhaust. Sprite 313 places Sprite 312 smoke in each direction;
  Sprite 312's frame 22 removes its parent. Trail nodes outlive the projectile
  and expire independently. Repeated view synchronization cannot duplicate them.
  Impact now carries a final smoke-position event before removing the projectile,
  following `putSpecial`'s creation-before-collision order.
- **Gas:** Sprite 315 stops at frame 101. The view clamps at that frame instead
  of restarting its first 80 frames.
- **Shadows:** Shape 2 embeds the original robot-shadow PNG. The extraction tool
  copies its bytes and preserves its registration point. Shapes 232 and 286 use
  recovered SVGs for effect shadows and the rocket body.
- **Smooth movement:** Bomb and projectile positions interpolate between fixed
  updates, like heroes. Pause and result screens render the latest position.
  Deaths, retiring pickups and smoke can finish during results through a separate
  presentation counter; this cannot advance bombs, AI, scores or the round timer.
- **HUD:** Compact buttons override style minima and apply their dimensions after
  theme initialization, preventing overlap at the bottom of the 550×400 game area.

`tools/prepare_assets.py` reproduces assets and the manifest from the extraction.
`OriginalTimeline` uses persistent layers and recovered 2D matrices, including
mirroring and rotation. XFL graphic matrices are normalized from twips to match
the exported pixel-based SVGs. It executes no ActionScript.

## Verification

Godot 4.7.2: simulation, actors, persistent views, timeline transitions, campaign,
special weapons, 21,600-tick soak, and rendered UI checks. Timeline checks cover
creation/removal boundaries against recovered frame scripts, interpolation, and
independence from authoritative state.

`tests/visual_timelines.gd` renders representative frames for inspection:

- [Four character deaths](qa-death-timelines.png)
- [Pickups and directional rockets](qa-effect-timelines.png)

These are port regression checks, not independent Flash playback comparison.
The parent/child callback timing caveat remains. Remaining screen fidelity,
visual details and native iPhone validation are tracked in `rebuild-status.md`.
