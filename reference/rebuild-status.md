# Rebuild status

This supersedes the implementation-status sections of `core-stabilization.md`.
The callback-order caveats in that document still apply.

## Implemented

| Original plan | Current implementation |
|---|---|
| Fixed core | Pure state and command model; explicit 35 Hz physics callback; four actors and owner-specific bomb refunds; headless regression tests. |
| Original boards | Sprite 564 `ranMap`/`ranMapL` topology, original eight-neighbor checks, original shuffle algorithm, preserved insertion/loop-length quirk, center 2×2 obstacle, spawn exits, 60% brick population, five themes and sprite variants. A retry retains the solid topology and repopulates bricks. The old map is now only the regression fixture used by `setup_default`; gameplay uses `setup_round`. |
| AI | `isSave`, `getScore`, left/up/right/down traversal, random tie selection, 20% movement / 5% bombing branches, and difficulty escape rates 20/60/100. No new pathfinding behavior has been substituted. |
| Normal items | 65% drop opportunity, 80% normal branch, source thresholds 1/15/40/50/75, bomb allowance, power cap 10, speed floor 3 ticks/tile, extra life, shield, glove. AI pickup restrictions follow difficulty. |
| Special weapons | Rocket acceleration, owner-excluding proximity mines, two-tile grenade target and 19-frame body, gas slow 20 ticks/tile for 600 ticks, three-cell fire/ice growth every four ticks, expiry counter 48, ice stop time 300. Pickup quantities and release gating are carried through keyboard/touch commands. Stage weapon pairs rotate. |
| Visuals | 718 original exported sprite frames plus recovered bitmap/vector shapes; all four robots and nested walk cycles; bomb and brick timelines; original scenery, floor variants, flame colors, weapon/effect artwork; original `calDepth=(y*15+(15-x))*10` with object offsets. XFL transforms drive character death compositions, pickup idle/removal, and rocket exhaust/smoke. Persistent nodes and cached textures avoid rebuilding effects every tick. |
| Game flow | Menu, help, individual 1P/2P character selection, difficulty, 180-second round, pause/resume/focus pause, outcomes, scores, lives, stage retry/progression, 15/20/25-stage campaigns, and local best score. Original soundtrack and effect samples are used. |
| Smoothness and touch | Display-rate interpolation of heroes, moving bombs and projectiles with unchanged 35 Hz logic; cardinal multitouch stick plus bomb button; touch button edges; landscape gutters; original game aspect retained; no interpolation across a new scene or pause. Deaths and transient effects finish after a round ends without advancing gameplay. |

## Evidence

- `extracted/scripts-as/scripts/DefineSprite_564/frame_1/DoAction.as`: map,
  `putBomb`, `putSpecial`, `hurtHero`, `brickBreak`, `addBrickExp`, `movHero`,
  `isSave`, `getScore`, `calDepth`, and outcome/scoring logic.
- Sprite 564 frame 2: brick population, actor initialization, AI branches, fire
  polling and key-up behavior.
- `frame_8/DoAction.as` and `frame_9/DoAction.as`: players, initial lives, weapon
  catalog, and campaign lengths.
- `DefineSprite_527/frame_1/DoAction.as`: 180-second timer.
- `xfl/Bomb It 1/LIBRARY/Symbol *.xml`: body transforms, frame counts, and labels.
- `reference/sprite-bounds.json`: SWF registration bounds obtained with FFDec.

`tools/SpriteBounds.java` reproduces the bounds using FFDec's local Java API.
`tools/prepare_assets.py` copies recovered frames and audio into the Godot project
and builds the manifest. No artwork was generated or redrawn to replace the SWF.

## Remaining fidelity and release work

The playable systems are implemented, but **exact equivalence is not established**:

1. Flash's ordering of parent/child `onEnterFrame` callbacks and newly created
   clips still needs trace comparison. Movement-start, damage versus growth/expiry,
   grenade endpoint, and animation transition ticks remain parity-sensitive.
   Controlled Ruffle captures now agree with the port's 40-update death, level-one
   explosion-energy and brick-blocking traces. This narrows the uncertainty for
   those fixtures; it does not establish full-match or Adobe Flash Player parity.
2. `OriginalRng` reproduces the random(n) interface and supports recorded values.
   Its seeded backend is Godot's RNG, not Flash's unrecovered generator. Stage
   setup/audio random calls and cross-stage random-state continuation are not yet
   identical, so equal seeds are not asserted to produce the original SWF map.
3. The timer is deterministic simulation time. The original polls a wall clock
   every 500 ms. Severe stalls can therefore change elapsed-time correspondence.
4. Menu/select/help/HUD/results controls are rebuilt with Godot controls over
   recovered art. They are not exact reproductions of all root-screen timelines,
   typography, rollover states, score-counting animations, or original 5.5-second
   outcome transitions. High scores are local, not a recreation of the old portal.
5. Death, pickup and rocket compositions now replay recovered XFL placement,
   scale, rotation and opacity. The hero shadow uses the original embedded bitmap;
   the invented shield outline is removed (the source indicates possession in the
   HUD). Remaining details include the floating equipped-weapon indicator,
   surviving-hit smoke, nested idle clips, and reference playback comparison of
   effect creation/removal boundaries. A rocket removed by impact within a tick
   cannot currently emit its last smoke sample. Raster exports retain their source
   resolution, so large windows cannot recover vector detail. See
   `visual-fidelity.md` for the completed animation pass.
6. Special weapons follow source logic but still need reference traces for mixed
   weapon collisions, moving-bomb edge cases, multi-life AI scoring/shields, and
   overlap ownership. The tests validate the port, not an independent SWF oracle.
7. Windows rendering and simulated multitouch were checked. Native desktop UI
   automation could not connect to its helper. iPhone hardware latency, safe-area
   insets, sustained frame pacing, native builds, signing, and store packaging
   have not been verified. No release executable or iOS package is claimed.

## Validation performed

Godot 4.7.2: original simulation regressions, actor ownership, persistent view
nodes, 30 seeded map connectivity checks, campaign/timeout/retry, item caps,
shield consumption, all six special weapons, input release gating, and UI flow.
The soak test exercised 21,600 ticks, 504 ordinary bombs and 151 special-weapon
uses across 18 seeded matches without negative energy or invalid bomb inventory
(counts are fixtures of the tested revision and may change as parity improves).
Rendered screenshots were inspected for the menu, selection, arena, pause,
results, help, and wide touch layout.
The animation suite also checks pickup phase/removal, all four death variants,
idempotent synchronization, rocket trail cleanup, interpolation, and end-of-round
animation without state advancement. UI checks verify HUD button bounds. Rendered
death/effect contact sheets are saved alongside the game screenshots.
CI and original-bytecode capture commands are documented in `tooling.md`.
