# #7: difficulty and character selection

Starting revision: `cac441dfa89a74bfe831696f9131bccf0cbe2106`.
Implementation: `729009b`; integration merge: `b013acb` (retains #8's HUD).
This replaces the combined reconstructed setup panel with original root frame 5
(`menu3`, difficulty) followed by frame 8 (`select`, character selection).
The existing GameSession and 35 Hz gameplay are unchanged.

## Acceptance and source evidence

| Requirement | Implementation and verification |
|---|---|
| Both human choices, source restrictions, all difficulties | Easy/Normal/Hard retain the original artwork, lettering and button states. 1P uses arrows/Space; 2P uses WASD/Space and arrows/Enter independently. Moving wraps through four robots and skips the other human's choice. Confirmation locks that player and waits for the other. Rendered checks enter sessions with selected characters 3/4 and verify both humans' starting lives. All three difficulties are exercised. |
| Back/forward/start and mouse/keyboard/touch targets | Back/Escape follows selection → difficulty → player count → title. Forward navigation retains choices within setup; starting another player-count selection resets to source defaults 1/2. Mouse/touch can select robots and activate the visible Space/Enter artwork. Repeated key releases, echo, double taps and cancelled touch cannot start a second session or confirm both humans. |
| Compare selected/unselected presentation; accepted session handoff | Original lineup, backdrop, shadows, colored 1P/2P markers, selection arrows, eye animation and player-specific instruction diagrams are source-derived. Six original/port snapshot pairs include initial, changed and confirmed selections. The exact comparator reports differences in all six; see the limitations below. Actual rendered input starts the existing GameSession with the chosen humans, difficulty and characters. |
| Focused checks, evidence and review | The public runner passes view, campaign and all rendered phases after merging current integration. The source comparison and red/green logs are retained in [issue-07-evidence](issue-07-evidence). Scope review below identifies the remaining limits. |

Source definitions:

- `xfl/Bomb It 1/DOMDocument.xml`: root frame 5 and 8 display lists and placements.
- `extracted/scripts-as/scripts/DefineButton2_469`, `_466`, `_467`: release actions
  set `varHard` to easy/normal/hard and `gotoAndStop("select")`.
- `extracted/scripts-as/scripts/frame_8/DoAction.as`: default character choices,
  duplicate exclusion, wraparound, both keyboard maps, confirmation locking,
  two-human completion gate and eye-animation triggers.
- Symbol 210: 60-frame marker bob; children 200/209 supply character-colored
  arrows and 1P/2P labels. Confirmation stops the marker on frame 1.
- Symbol 509: blank stopped frame 1 and 13 subsequent blink frames. A selection
  change requests playback after two updates, repeated after 100 updates.
- Symbol 519: original instruction diagram selected by player count. The four
  static robot bodies are Symbols 489/494/499/504.

`tools/ExportMenuArt.java` now extracts the two added root display lists and
their dynamic source components at 2×. It records pointer transforms, bounds,
frame counts and the original SWF hash in the menu manifest. Assets are lossless
source renders with explicit linear filtering; no replacement art was generated.
`OriginalSelection` replays these presentation frames at 35 Hz independently of
GameSession. Its rendered check also observes animation changing the screen
without player input; normal screenshot fixtures stop at a reproducible frame.

## Validation and retained comparisons

The TDD skill was used at the already approved public runner and rendered
input/output seams. [Difficulty red](issue-07-evidence/difficulty-red.log) fails
against the old combined panel. [Selection red](issue-07-evidence/selection-red.log)
fails on duplicate exclusion, locking and the independent second confirmation.
[Navigation red](issue-07-evidence/navigation-red.log) fails on visual-order
keyboard difficulty navigation. Each passes after its corresponding change.

The old rendered input fixtures now traverse the added difficulty screen. The
older UI test's private character-selection calls were replaced by the new
rendered coverage, including mouse, keyboard and synthetic touch. Current
[checks](issue-07-evidence/checks.json) and [selection log](issue-07-evidence/selection-render.log)
record the passing merged result. Native rendering was serialized with the
integration workflow's shared Windows lock.

`tools/reference/capture_selection.mjs` runs the unchanged SWF in Ruffle 0.7.1
and follows its actual buttons and key-release handlers. Original and rebuilt
images and runtime metadata are retained separately:
[original](issue-07-evidence/original), [rebuilt](issue-07-evidence/rebuilt).
[Comparison report](issue-07-evidence/image-comparison.json) reports every pixel
difference without a tolerance allowance; the [selection triptych](issue-07-evidence/selection-comparison.png)
shows the source, rebuild and exact difference image.

```powershell
java --class-path '<ffdec>/ffdec.jar;<ffdec>/lib/*' tools/ExportMenuArt.java 'Bomb It 1.swf' godot/art/original/menus
node tools/reference/capture_selection.mjs 'Bomb It 1.swf' .artifacts/issue07/original
python tools/run_checks.py --godot <Godot-4.7.2> --suite view --suite campaign --visual --output .artifacts/issue07/checks
python tools/compare_images.py reference/issue-07-evidence/original reference/issue-07-evidence/rebuilt --output .artifacts/issue07/comparison
python tools/inspect_symbol.py 210 --frames 1 2 60
python tools/inspect_symbol.py 509 --frames 1 2 14
```

The image comparison intentionally exits 1. The phase log paths identify the
originating checkout; retained summaries and logs do not require those paths to
remain available.

## Review and limitations

Implementation review against the starting revision and subsequent integration
merge found no gameplay changes or lost HUD work. The only merge conflict was
the public runner's phase list; both selection and HUD checks remain enabled.
Review also reduced the P2 confirmation target to a non-overlapping 44-pixel
height so it does not intersect Back. The integration owner performs the final
cross-ticket review and owns shared regression-baseline updates.

The six comparisons are selected-state composition evidence, **not tick-aligned
animation parity**. Original snapshots advance browser time between input and
capture; regression snapshots stop the rebuilt selection timeline. Visible eye
and marker animation phases therefore differ. No image was shifted in time to
manufacture agreement. Color, edge and compositing differences also remain
incompletely attributed and cannot be dismissed as proven renderer-only effects.

Back/Escape, keyboard difficulty navigation, Enter as an additional 1P confirm,
direct mouse/touch selection and the small touch instruction line are platform
additions. On touch, P1 chooses and confirms first, then P2 can choose and confirm;
keyboard players remain independent as in the source. Returning to difficulty
clears confirmation locks but keeps choices; a fresh player-count selection
resets them. The source has keyboard-only character selection and no Back route.

This completes the #7 implementation and comparison-evidence scope. Exact image
or callback-phase equivalence, Adobe Flash Player equivalence and physical
iPhone interaction remain unverified. Original captures are never port
regression baselines. No baseline was updated by this ticket.
