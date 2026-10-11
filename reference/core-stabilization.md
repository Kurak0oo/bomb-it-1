# Core stabilization

Historical stabilization snapshot. See [rebuild-status.md](rebuild-status.md) for
the subsequently implemented maps, AI, weapons, animation, game flow, and touch.

The engine drives one `GameState.tick` per `_physics_process`, at an explicit
35 Hz. There is no render-frame accumulator or application-level time discard.
Godot still limits catch-up under sustained overload; this is not a promise of
unlimited wall-clock catch-up. Interpolation is explicitly disabled until parity
is established. The existing explicit 550×400 viewport, `canvas_items` stretch,
`keep` aspect, and nearest texture filtering remain in place. Art imports use
lossless compression and no mipmaps. The main scene only attaches `main.gd`.

`scripts/simulation` contains only state, rules, and commands. It does not load
textures, poll input, or create scene nodes. `GameView` reads state and retains
bomb, explosion, pop, and hero nodes until their corresponding state disappears.
`KeyboardInput` produces commands; `main.gd` connects these boundaries.

Hero IDs and command slots are zero-based; character IDs are one-based, matching
the recovered character numbering. All four heroes have independent movement,
damage, and bomb inventories. A bomb refunds its recorded owner even if that
hero died. Missing commands mean idle. Slots 1–3 are marked AI but have no AI
implementation. All four currently use the same placeholder character artwork.
The default fixture clears spawn cells and adjacent bricks. It is not `ranMap`.
Lives and item-related state fields are reserved; full life/respawn and item
effects are not implemented. Collision still checks terrain/bombs, with no
invented hero occupancy blocking.

## Evidence and outstanding parity questions

Paths below are relative to `extracted/scripts-as/scripts`; matching P-code is
under `extracted/scripts-pcode/scripts` with the `.pcode` extension.

| Mechanic | Recovered evidence | Status |
|---|---|---|
| Movement start | `DefineSprite_564/frame_1/DoAction.as`, `movHero`: sets `movId=0` and installs a handler; that handler increments before moving. P-code function starts at line 3932 and confirms these operations. | Six motion updates are established. Whether a newly installed handler executes in the same Flash frame still needs runtime callback-order verification. The regression preserves the prototype's no-motion decision tick. |
| Damage coordinates | `DefineSprite_564/frame_2/DoAction.as`, game loop: `Math.round(_y/d)` and `Math.round(_x/d)` select the damage cell before calling `hurtHero`. | Rounded physical position is supported, not an arbitrary hypothesis. Damage relative to other clip callbacks still needs runtime verification. |
| Fire input | Frame 2 polls `Key.isDown(fireKey)` and queues `prevFire` while moving. Frame 1 `putBomb` does not clear `puttAble`; `putSpecial` does. Frame 2 `onKeyUp` restores it. | Held/queued ordinary fire is supported. Commands expose pressed and released edges for the later special-weapon port, without changing normal bombs to edge-only input. |
| Explosion linger | Frame 1 `bombExp`: growth installs a new handler with `delayTime=10`; the handler pre-decrements and removes energy at zero; a separate handler fades by 20. | Counter clears ten updates after growth. Exact lethal checks on the transition frame depend on callback ordering and remain unverified. No guessed extra linger tick was added. |
| Brick blocking | Frame 1 `brickBreak`, called by ordinary explosions, clears `bg.brick` immediately. `addBrickExp` also clears it immediately but belongs to other effect paths. `DefineSprite_248_brickExp/frame_11/DoAction.as` only removes the clip. | Immediate logical unblocking is supported. The visual pop lifetime remains a prototype timing fixture. |

The preserved simulation order is heroes → explosion growth/expiry → bomb
fuses/chains → damage → pop expiry. Flash spreads these operations across clip
callbacks and performs damage before input decisions in its game callback.
Therefore the tests are regression fixtures, **not proof of full SWF parity**.
Movement-start, movement-completion/decision, damage/growth/expiry ordering, and
new clip callback activation require a Flash/Ruffle trace before changing them.

## Validation

From this repository, with a Godot 4.7 executable on PATH:

```powershell
godot --headless --path godot --editor --import --quit
godot --headless --path godot --script res://tests/sim_check.gd
godot --headless --path godot --script res://tests/actors_check.gd
godot --headless --path godot --script res://tests/view_check.gd
```

`sim_check` retains the existing movement, fuse, brick, shield, damage-coordinate,
chain and linger fixtures. `actors_check` exercises independent actors, held fire,
ownership, refunds after death, overlapping energy and engine tick settings.
`view_check` exercises persistent nodes and cleanup without advancing state on
view synchronization. These run headlessly; visual fidelity is not asserted.

Next: capture callback-order traces and turn them into parity fixtures before
porting map generation or AI. Animation timelines and `calDepth` remain deferred.
