# Actor feedback — issue #3

Starting revision: `f797372`. Integration was an ancestor before implementation.
This slice restores the missing startup player pointer and corrects the equipped
count baseline. It does not change simulation, damage, shield, RNG, or outcome rules.

## Source and changes

- Sprite 564 frame 2 attaches `p_pointer` to humans at dynamic depth 0, selects
  `p` by `heroId + (heroNum - 1) * 4`, selects `arrow` by character, and removes
  it after 150 unpaused updates. Symbol 210 contains a 60-frame looping timeline;
  Symbols 209 and 200 contain the eight player labels and four colored arrows.
  Those recovered frames and XFL placements now play in `HeroView` while the
  human is idle or moving. New game views use the round tick, so synchronization
  does not advance the animation. The actor's alpha and depth apply to its pointer.
- `movHero` and frame-2 actor setup stop the nested body while idle. Inspection
  of all four actor SWF display lists confirms only a shadow and a 12-frame body
  clip; its children are static shapes. No invented idle body motion was added.
  Independent captures cover all four characters facing all four directions.
- Source `specialToolViewer` also occupies dynamic depth 0. Equipping therefore
  replaces the pointer permanently, including when charges run out before update
  150. The view remembers this replacement without changing authoritative state.
- Symbol 299's counter uses device TextFields, unlike Godot's top-aligned Label.
  The independent count-1 fixture at actor registration `(60,100)` exposed the
  visible dark glyph at y=54..64 in the old port versus y=59..69 in Ruffle. Its
  baseline is now five pixels lower. This is a measured presentation correction;
  it is not a claim that the two runtimes have identical font metrics.
- A second dark-background fixture isolates `1`, `2`, `10`, `11`, `12`, `20`.
  The original TextField reports widths 9, 9, 18, 18, 18, 18 at size 15. Font 295
  has `fontFlagsHasLayout=false`: the SWF contains no advance table. FFDec's TTF
  export synthesized proportional advances (520 units for `1`, 711 for `2`,
  at 1024 units/em). This caused the trailing zero to shift when `10` became
  `20`. Counter glyphs now use the independently measured 9-pixel advance;
  their source field origins and recovered outlines remain unchanged. The
  rendered trailing-zero comparison failed before and passes after this fix.
- Existing `hurtHero` smoke transport remains unchanged: surviving AI damage starts
  Symbol 279 at frame 20; frame 36 removes it. The new independent fixture calls
  original `hurtHero` bytecode. Its first post-creation observation is frame 21,
  with the smoke gone by observation 15. Life stays at one while presentation
  finishes, including after the simulation stops advancing.

The source is preserved in `extracted/scripts-as/scripts/DefineSprite_564/`
and `xfl/Bomb It 1/LIBRARY/Symbol {200,209,210,279,299}.xml`. Reproduce recovered
assets with `python tools/prepare_assets.py`; no replacement artwork was drawn.

## Verification and retained evidence

The public `run_checks.py --suite view --suite timeline --visual` route exercises
idle pointer motion, the second human pointer, update-150 retirement, permanent
weapon replacement, idempotent synchronization, and the count baseline. The first
pointer run failed for missing bob/removal, then passed after implementation.
The count-baseline assertion likewise failed before its correction and passed
afterward. Tooling, actors, timeline and all existing rendered suites passed.
Red/green logs are under [feedback-capture/checks](feedback-capture/checks).

Independent capture command (use the native-render lock on shared Windows hosts):

```powershell
python tools/capture_feedback.py --ffdec <ffdec-directory> --godot <godot-executable> --output .artifacts/feedback-reference
```

The builder retains original character definitions and original function bytecode.
The fixture calls original `hurtHero`; it plays original pointer/body/weapon
timelines. The pointer lifetime callback is copied from source frame-2 setup into
the controlled fixture, rather than executing the complete round setup. That
distinction is recorded in capture provenance. Browser time advances explicitly;
skipped observations fail. `--require-parity` fails on any trace or image difference.

- [Original observations](feedback-capture/original/trace.json) and
  [rebuilt observations](feedback-capture/rebuilt/trace.json): 259 updates across
  pointer, idle, walk, weapons, scenery depth, surviving-hit, and numeric-layout scenes.
- [Trace comparison](feedback-capture/trace-comparison.json): all observed body
  frames, pointer visibility/label placement, and life values match. Pointer
  placement is observed from the rendered layer transform in twips; body frame
  is observed from the selected texture, not calculated from a duplicate timer.
- [Exact image report](feedback-capture/image-comparison/report.json): all 56
  sampled images differ. Source and port PNGs plus all full-frame difference
  images are retained separately. No tick shifts, crops, tolerance changes or
  port-baseline replacements were used to establish parity.
- Representative comparisons: [startup pointer](feedback-capture/image-comparison/qa-pointer-frame-00-diff.png),
  [all weapons](feedback-capture/image-comparison/qa-weapons-frame-00-diff.png),
  [scenery occlusion](feedback-capture/image-comparison/qa-depth-frame-00-diff.png),
  [surviving hit](feedback-capture/image-comparison/qa-hit-frame-00-diff.png).
  The before-correction weapon captures are in `count-baseline-before`.
- [Original numeric measurements](feedback-capture/original/counts.log),
  [SWF font flags/bounds](feedback-capture/count-layout/source-font-metrics.txt),
  and [glyph bounds](feedback-capture/count-layout/glyph-bounds.json) isolate the
  horizontal issue. Enlarged diagnostic strips show [source](feedback-capture/count-layout/source-glyphs.png),
  [before](feedback-capture/count-layout/before-glyphs.png), and
  [after](feedback-capture/count-layout/after-glyphs.png). These diagnostic crops
  are not used to mask the full-frame comparison. Single-digit `2` starts at
  the same x in both runtimes; the narrower source `1` lies inside the thicker
  port glyph. A uniform x shift would therefore be incorrect. The remaining
  single-glyph bounds differences are demonstrated outline/weight differences;
  the known multi-digit registration defect is corrected.

The measured numeric advance is specific to the source size-15 device field.
Other sizes, including the HUD's size-10 fields, should be measured independently
rather than inheriting an assumed scale. The source probe uses
`getInstanceAtDepth(-16368)` for Symbol 299's white TextField and reads its
`textWidth`, `textHeight`, font and size directly.

## Status and limitations

**Issue #3's placement, depth, timing and visibility criteria pass for the named
fixtures. The parent project's exact pixel parity remains unclaimed.** Source and port show
the same pointer selection, loop, removal, body poses, weapon choices, and
foreground scenery order. Counter field origins, baseline and tabular advance
now match the measured source layout; no known uniform registration error remains.
The raster exports are visibly softer than original playback, and the source
device TextField draws thinner glyphs than the recovered embedded font outlines.
The evidence does not isolate every changed pixel to the renderer, so the 56 image
failures remain failures; they are not waived.

| Required criterion | Result and evidence |
|---|---|
| Surviving smoke starts at the source frame | Pass: source `hurtHero` starts 279 at 20, rendered damage emits the smoke, independent post-creation boundary images cover playback and removal. Life remains one in the independent fixture. |
| Equipped and nested placement/depth | Pass for all six weapons, four character directions, eight player-pointer variants, and the scenery-occlusion fixture. Counter source registration/baseline and directly observed tabular advance are reproduced. |
| Timing and visibility | Pass: body stops while idle; pointer loops at 60 frames, disappears on update 150, and stays replaced after weapon exhaustion. Repeated synchronization does not advance it. Source/port observations match for all 259 recorded updates. |
| Read-only event transport | Pass: the rendered hit fixture drives actual state damage; presentation then finishes while life and simulation remain unchanged. No simulation file was modified. |
| Focused checks and review | Pass: three rendered red/green corrections, tooling/actors/timeline checks, all merged rendered phases, and scoped review against `f797372`. |

This is Ruffle 0.7.1/Chromium original-symbol evidence compared with Godot 4.7.2
Windows OpenGL, not Adobe Flash Player or iPhone certification. The controlled
fixtures do not prove full-match callback ordering. Shared Linux regression
baselines are owned by integration: expected changes are the human pointer during
the first 150 updates and the corrected floating count baseline.

Review against `f797372`: production changes are limited to asset preparation,
timeline child selection, HeroView/GameView presentation wiring, and label layout.
Simulation files and accepted mechanics are unchanged. The capture fixtures and
runner logs explicitly retain remaining appearance failures.
