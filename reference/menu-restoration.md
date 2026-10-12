# Original title and help screens

Scope: [#24](https://github.com/Kurak0oo/bomb-it-1/issues/24),
[#25](https://github.com/Kurak0oo/bomb-it-1/issues/25), and
[#26](https://github.com/Kurak0oo/bomb-it-1/issues/26), the three approved slices
of #6. Review baseline: `0d3b2d18b67db1dcffc5c8468c110e0976748c25`, the repository
state at the start of this implementation. Earlier game changes are excluded.

## Source and routes

The original SWF's stopped root frames supply the composition, lettering,
decorations, button registration points and Up/Over/Down artwork. Root frames
3, 4, 6 and 7 are `menu`, `menu2`, `howtoplay` and `toolInstruction`. These screens
use static root graphics; no invented title animation or simulation clock is added.

| Screen | Original button/action | Rebuilt destination |
|---|---|---|
| Title | 439 Start Game → `menu2` | Player-count screen |
| Title | 440 How to Play → `howtoplay` | Controls help |
| Player count | 462 / 463 → `menu3`, one / two players | Existing setup, with chosen count |
| Controls | 473 Power Ups → `toolInstruction` | Power-up guide |
| Guide | 440 How to Play → `howtoplay` | Controls help |
| Both help pages | 439 Start Game → `menu2` | Player-count screen |
| All four screens | 460 sound clip | Toggle saved sound preference |

`xfl/Bomb It 1/DOMDocument.xml`, the corresponding Symbol XML files, and extracted
button actions provide source evidence. `tools/ExportMenuArt.java` renders the SWF
display list in segments around its interactive placements. This preserves the
original lettering and candy decorations **above** each button's changing
background. The committed manifest records the source SHA-256, original root
frames, registration bounds and transforms. Art is extracted at 2× resolution,
imported losslessly and rendered with linear filtering. No replacement artwork
or generated typography is used for the original screen content.

`OriginalMenu` owns presentation and release-based navigation. `main.gd` handles
destinations, player count and preferences. Simulation code and 35 Hz settings
are unchanged. Setup, HUD, outcomes and full score screens remain separate work
under #7–#9.

## Deliberate additions and limits

- Back and Escape return to title; Back from existing setup returns to player
  count. The original help links and Start destinations remain available.
- Tab/arrows choose a button; Enter/Space activate on release. M toggles sound.
  Mouse and touch use the same source button states. Echo, orphan releases,
  double-click/double-tap follow-ups and touch-emulated mouse events cannot skip
  screens. An explicit keyboard/mouse/touch owner prevents another device from
  stealing or completing a held press. Focus loss and touch cancellation discard
  pending activation.
- Touch hit regions are 44 logical pixels high, including Back and sound, and
  do not overlap. Artwork retains its original dimensions. The 550×400 stage
  stays centered and aspect-preserved in an enlarged landscape viewport.
- Controls help keeps the original 1P/2P keyboard diagram. A small added line
  explains WASD/Esc/M on desktop, or the actual left stick/Bomb controls and
  special-weapon release behavior on touch platforms. It does not imply a
  second on-screen touch controller.
- Quality stays BEST; the old Flash quality-cycle control is not active.
  Highscores displays the saved local best. More Games and Free Games show an
  unavailable notice. The source portal/logo art is retained; no external
  portal or online score service is invoked.
- Two-times raster extraction does not preserve unlimited vector resolution.
  Ruffle/FFDec/Godot rasterization and compositing differences remain. This pass
  does not claim pixel identity, Adobe Flash equivalence, or iPhone hardware
  validation.

## Reference evidence

`tools/reference/capture_menus.mjs` loads the **unmodified** original SWF in the
pinned Ruffle 0.7.1 runtime. Actual pointer events follow the original routes.
It records title, player count, both help pages, representative hover/pressed
states, and the guide at 1600×800 (centered 1100×800 stage). Browser time advances
explicitly; external requests are blocked. Metadata records source/harness
hashes, runtime, browser and package integrity. It never imports port artwork.

Retained evidence is in `menu-capture/`: original and rebuilt images, exact
comparison results, runtime metadata, and validation results. All 11 paired
images still have changed pixels at zero tolerance. Visible additions include
Back and platform hints; smaller color/edge/compositing differences are not
fully attributed. The enlarged comparison also includes the harness's outer
background. No tolerance was increased or difference waived to claim parity.

Linux images in `visual-baselines/` are reviewed **port regression baselines**,
separate from the original reference images. The changed title/help captures and
new menu-state captures are intentional. Four existing captures also show small
text glyph edge/position differences after the new screen sequence: arena 192,
pause 192, result 248 and touch 27 pixels. Inspection found no changed playfield
or actor pixels. Restoring the baseline main/UI scripts in the same container
reproduced the prior images exactly, isolating this to the changed UI path rather
than the container version. The precise font-rendering cause remains unproven;
these reviewed port baselines include the differences. The other four existing
images are identical. `baseline-change-review.json` retains the original counts.

## Validation

The pre-agreed test boundaries remain the public check runner, symbol-inspection
and comparison commands, and rendered input/output. `menu_render_check.gd`
delivers keyboard, pointer and touch events through Godot's input boundary. It
checks navigation, count/sound retention, cancellation, repeat suppression,
wide-screen input, and absence of simulation behind help. It captures original
composition, button states, touch instructions and saved-best presentation.

Red failures were observed before implementing title/player-count routing,
help/guide routing and double-click/double-tap suppression; those cases pass
after implementation. Review exposed cross-device capture theft; its mixed-input
rendered regression failed before exclusive press ownership was added. Existing
rendered input tests now follow the extra title
screen. One existing assertion incorrectly counted AI-owned bombs as replayed
human input; it now checks human ownership without changing game behavior.

All 17 full-suite phases passed on Windows, including nine tooling tests and the
21,600-tick soak. The first fresh-project import exited with Godot access violation
`3221225477` while importing fonts; rerunning import completed, then the whole
suite passed. Both results are retained in `menu-capture/validation.json`.
Fresh Linux imports and focused rendered checks also passed. Reproduction
commands are in `tooling.md`; review is recorded in `menu-review.md`.
