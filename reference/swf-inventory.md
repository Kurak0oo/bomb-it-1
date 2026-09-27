# Bomb It 1 — Sprite 564 behavior

FFDec 26.3.0. Decompiled ActionScript is in `extracted/scripts-as`. P-code with `resolveConstants=0` is in `extracted/scripts-pcode`. The numbers below were checked against both.

```text
Canonical file: Bomb It 1.swf
Actual file size: 2319271 bytes
SHA-1: efba5da56762eae5b733a4999f21344736a42020
SHA-256: a780f395a61bae8d0ddf9c0dfc1b75780046461c4197d949523c6eedf5969b0b
SWF FileLength: 2505308 bytes
Compression: CWS / zlib
SWF version: 7
ActionScript: AS1/AS2
Stage: 550 × 400
Frame rate: 35
Root frames: 12
```

Sprite 564 is the `game` clip. Its three scripts are `DefineSprite_564/frame_1/DoAction.as` (functions and map setup), `frame_2/DoAction.as` (round start and the 35 fps loop), and `frame_3/DoAction.as` (`stop()` only).

`ffdec-as2-index.txt` lists 67 scripts. None are `DoInitAction`. One is a clip event (`DefineSprite_395` `on(release)`). Twenty are button actions. Seven are root `DoAction`s (frames 1, 3, 8, 9, 10, 11, 12). The rest are sprite `DoAction`s.

## The twelve values

| Value | Result |
|---|---|
| Tile width / height | 30 × 30 pixels. One variable, `d = 30`, is used for both axes. |
| Map rows / columns | 15 columns (`w`) by 13 rows (`h`). |
| Base movement | 5 pixels per 35 fps frame. `vLevel` starts at 6, which is frames per tile, so each frame steps `30 / 6`. |
| Movement collision | One tile at a time. The destination cell must be empty of bricks, and empty of bombs unless the glove can push that bomb. |
| Starting bomb count | 1 (`totalBomb`). |
| Bomb placement | The integer cell the hero is standing on when the step finishes: `_x = hero.x * 30`, `_y = hero.y * 30`. |
| Basic bomb fuse | 60 `onEnterFrame` ticks, skipped while paused. 60/35 seconds. A blast already on that cell detonates it early. |
| Basic blast range | `bombLevel` 1: the center cell plus 1 tile up, down, left, and right. |
| Blast blockers | The map edge and `unbreakAble` cells stop a ray before it enters. A destructible brick is destroyed and stops the ray there. |
| Explosion lifetime | The flame grows for `bombLevel` frames (1), then `delayTime = 10` more frames of hit detection. After that, a 20-alpha fade is visual only. |
| Player spawn | Tied to character id, not player slot. Default hero1 is tile (3, 3), local pixels (90, 90), stage pixels (183.1, 95.2). |
| 1P opponents | AI. `totalPlayer = 1` leaves heroes 2, 3, and 4 on the scripted branch. |

### Tile and map

Set in frame 1, confirmed in P-code as `w = 15`, `h = 13`, `d = 30`:

```5247:5252:extracted/scripts-pcode/scripts/DefineSprite_564/frame_1/DoAction.pcode
loc54ca:Push constant165, 15
SetVariable
Push constant172, 13
SetVariable
Push constant68, 30
SetVariable
```

Cells are `bgArea["bg" + y + "_" + x]` for `x` in `0 .. 14` and `y` in `0 .. 12`. Each cell is placed at `_x = x * 30`, `_y = y * 30`. The map is 450 × 390 local pixels.

`bgArea` and `brickArea` sit at local `(0, 0)` inside sprite 564. On the root `game` frame that sprite is placed at stage `(93.1, 5.2)` (`DOMDocument.xml`). Stage position of a cell is `(93.1 + x * 30, 5.2 + y * 30)`.

### Movement

`vLevel` is not pixels. It is how many simulation frames one tile takes. The hero object is created with `vLevel: 6` (frame 2 P-code, the `6` next to `bombLevel: 1` and `totalBomb: 1`).

While `moving` is true, the hero's own `onEnterFrame` does this, and it does not run while `pausing` is set:

```text
speed = slowTime != -1 ? slowVLevel : vLevel
movId starts at 0
each frame:
  movId += 1
  if movId < speed:
    t = movId / speed
    _x = (x + dx * t) * 30
    _y = (y + dy * t) * 30
  else:
    moving = false
    x += dx
    y += dy
    _x = x * 30
    _y = y * 30
```

At `vLevel = 6` the positions through one tile are 5, 10, 15, 20, 25, then 30 pixels. That is 5 pixels every 35 fps frame. The 飞鞋 pickup lowers `vLevel` by 1 while it is above 3, which is faster. The gas bomb sets `slowVLevel = 20` and `slowTime = 600`, which is 1.5 pixels per frame.

Direction comes from `game.onEnterFrame` in frame 2, and only when `moving` is false. Keys are tested in order and the first one that is down wins. There is no second try and no diagonal.

| Order | Key | Code | `xy` | Direction |
|---|---|---|---|---|
| 0 | Left | 37 | `[-1, 0]` | left |
| 1 | Up | 38 | `[0, -1]` | up |
| 2 | Right | 39 | `[1, 0]` | right |
| 3 | Down | 40 | `[0, 1]` | down |

Left beats Up beats Right beats Down. Left plus Right moves left. Up plus Down moves up. A new direction is not read until the current tile step finishes.

`movHero` turns the body to face that direction before it tests the destination. The destination cell is `(x + dx, y + dy)`. The move starts only when `brick == ""` and (`bomb == ""` or the hero has `pushBombAble` and `pushBomb` succeeds). Otherwise the hero stays on the current tile, already facing the blocked direction. There is no corner slide and no per-pixel correction. Collision is the destination cell's `brick` and `bomb` strings.

Hurt detection is separate. After the opening shield (`varShield`, about 60 frames), the loop takes `Math.round(_x / 30)` and `Math.round(_y / 30)` and calls `hurtHero` when that cell's `expEnergy > 0`.

### Bombs

`totalBomb` is set to 1 on `heroObj` and on the hero clip at round start. `putBomb` decrements it. `bombExp` increments it when the explosion starts, so a second basic bomb cannot be placed until the first one detonates.

`putBomb` runs from the gameplay loop only when the hero is not `moving`. Holding fire while walking sets `prevFire`, and the bomb is placed on the frame the step completes, on the tile just entered. The cell is `hero.x`, `hero.y` (integers). Pixel position is that cell times 30. There is no extra rounding. Placement is rejected when `totalBomb <= 0`, `puttAble` is false, or that cell already has a `bomb`, `grenade`, `rocket`, `mine`, or `gasBomb`. The basic bomb path does not clear `puttAble`. Only `putSpecial` does, and a key-up restores it. The basic bomb is therefore limited by the count of 1, not by a key-repeat lock.

The owner can leave the cell. The bomb test looks at the destination, not the cell being vacated. Coming back onto that cell is refused until the bomb is gone, unless the glove push succeeds.

The fuse is the property `delayTime: 60` on the bomb clip (frame 1 P-code, `Push constant67, 60`). The bomb's `onEnterFrame` decrements it once per frame and skips the decrement while paused. It calls `bombExp` when the counter reaches 0, or sooner when `bg.expEnergy > 0`. That second clause is the chain reaction. `bombExp` itself returns without exploding if the clip's pixel position is not exactly on its tile (`x != _x / 30`), so a bomb that is mid-push waits until it is aligned.

### Blast

`bombLevel` starts at 1. `bombExp` lights the center immediately and remembers four rays: left, up, right, down (`xy`). Each following `onEnterFrame` adds 1 to `expPos` and, for every ray that is still open, paints the cell at that distance.

A ray closes when:

- the next cell does not exist (map edge)
- the next cell's `brick == "unbreakAble"` (the flame never enters it)
- the cell just painted has any brick (the destructible is broken with `brickBreak`, and the flame stops on that cell)
- `expPos >= bombLevel`

With `bombLevel` 1 the flame reaches the four neighbors and no farther. A destructible neighbor is included and destroyed. An unbreakable neighbor is not included.

`expEnergy` on a lit cell is what hurts heroes. When `expPos` reaches `bombLevel`, the growth handler is replaced and `delayTime` is set to 10 (frame 1 P-code, `Push register1, constant67, 10` / `SetMember`). The new handler decrements that counter once per frame and, on the tick it hits 0, subtracts 1 from `expEnergy` on every lit cell. That is 10 simulation frames after growth finishes. For a basic bomb, growth is 1 frame, so the neighbors are created on that frame and cleared 10 frames later. The center was marked on the detonation tick, one frame before the neighbors. At 35 fps the 10-frame linger is 10/35 second.

The handler that runs after the clear only does `_alpha -= 20` until alpha is below 5, then removes the clip. Five fade frames, no damage. The `exp` symbol is `gotoAndStop`'d, so this lifetime is the script counter, not that symbol's timeline. `fireEffect` (40 frames) belongs to the fire-arrow weapon, not the basic bomb.

### Spawn and opponents

```text
heroXy = [[3, 3], [w - 4, 3], [3, h - 4], [w - 4, h - 4]]
        = [[3, 3], [11, 3], [3, 9], [11, 9]]
```

The index is `heroId - 1`. Character select starts at hero1 (`mov(p1, 1)` from `heroId` 0 in root frame 8).

| Character | Tile (x, y) | Local pixels | Stage pixels |
|---|---|---|---|
| hero1 | (3, 3) | (90, 90) | (183.1, 95.2) |
| hero2 | (11, 3) | (330, 90) | (423.1, 95.2) |
| hero3 | (3, 9) | (90, 270) | (183.1, 275.2) |
| hero4 | (11, 9) | (330, 270) | (423.1, 275.2) |

Round start clears the spawn cell and its four orthogonal neighbors of bricks, then places the hero there facing down.

The 1P button (`DefineButton2_462`) sets `totalPlayer = 1`. In the frame 2 loop, `heroNum <= totalPlayer` reads the keyboard. The `else` branch is the AI: when the cell is safe (`isSave`), about 20% of idle frames walk toward a scored neighbor and about 5% place a bomb; when the cell is unsafe, `escapeRate` of idle frames flee. `escapeRate` is 20 on easy, 60 on normal, and 100 on hard. Humans have `life = 3`. The other heroes have `life = 1`. In 1P those three are the opponents, and they are AI. The 2P button sets `totalPlayer = 2` (WASD + Space, arrows + Enter); only heroes 3 and 4 stay on the AI branch.

## Not recorded this pass

Ruffle reference videos were not captured. Frame counts above come from the `onEnterFrame` handlers, not from a screen recording.
