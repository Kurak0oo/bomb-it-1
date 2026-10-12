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
  it is not a claim that the two runtimes have identical font metrics. Horizontal
  glyph placement and raster differences remain in the exact comparison.
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
  [rebuilt observations](feedback-capture/rebuilt/trace.json): 241 updates across
  pointer, idle, walk, weapons, scenery depth, and surviving-hit scenes.
- [Trace comparison](feedback-capture/trace-comparison.json): all observed body
  frames, pointer visibility/label placement, and life values match. Pointer
  placement is observed from the rendered layer transform in twips; body frame
  is observed from the selected texture, not calculated from a duplicate timer.
- [Exact image report](feedback-capture/image-comparison/report.json): all 48
  sampled images differ. Source and port PNGs plus all full-frame difference
  images are retained separately. No tick shifts, crops, tolerance changes or
  port-baseline replacements were used to establish parity.
- Representative comparisons: [startup pointer](feedback-capture/image-comparison/qa-pointer-frame-00-diff.png),
  [all weapons](feedback-capture/image-comparison/qa-weapons-frame-00-diff.png),
  [scenery occlusion](feedback-capture/image-comparison/qa-depth-frame-00-diff.png),
  [surviving hit](feedback-capture/image-comparison/qa-hit-frame-00-diff.png).
  The before-correction weapon captures are in `count-baseline-before`.

## Status and limitations

**Implemented; independently verified for the named timing/state fixtures. Exact
appearance acceptance remains open.** Source and port show the same pointer
selection, loop, removal, body poses, weapon choices, and foreground scenery order.
The raster exports are visibly softer than original playback, and count glyph
placement/weight differs. The evidence does not isolate every changed pixel to
the renderer, so the 48 image failures remain failures; they are not waived.

This is Ruffle 0.7.1/Chromium original-symbol evidence compared with Godot 4.7.2
Windows OpenGL, not Adobe Flash Player or iPhone certification. The controlled
fixtures do not prove full-match callback ordering. Shared Linux regression
baselines are owned by integration: expected changes are the human pointer during
the first 150 updates and the corrected floating count baseline.

Review against `f797372`: production changes are limited to asset preparation,
timeline child selection, HeroView/GameView presentation wiring, and label layout.
Simulation files and accepted mechanics are unchanged. The capture fixtures and
runner logs explicitly retain remaining appearance failures.
