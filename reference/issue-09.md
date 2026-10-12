# Issue 9 — scores and outcome transitions

Starting revision: `3b91c43` (integration after HUD acceptance).

## Source behavior verified before implementation

Sprite 564 `gameover` installs `setInterval(..., 5500)` for win, lose and time-up
routes. Nonterminal rounds route to Sprite 603 frame `totalPlayer + 1`; completed
campaigns and exhausted human lives route to the root score page. Sprite 563 plays
its banner from frame 1, has no graphic through frame 6, uses the recovered
translation/squash sequence from frame 7, and stops at frame 70. Frame 70 also
installs the original key-up skip listener.

**There is no source score count-up.** Sprite 603 frame-1 function `f()`, called
by frames 2/3, immediately assigns `killScore`, `brickScore + toolScore`,
`timeScore`, `bonus`, `score` and `totalScore` into the corresponding dynamic
fields. Inventing a counting animation would contradict the recovered source.
The restored sheet therefore displays the completed numbers immediately.

The independent bytecode fixture preserves all 16 Sprite 564 function bodies
(21,432 bytes), executes `gameover` in its original movie-clip scope, and retains
the original 563/603 definitions and scripts. Only setup and observations are
controlled. In both 1P and 2P, Ruffle observed banner frame 70 at 1,968 ms and the
score sheet's first observation at 5,520 ms. The latter is the next sampled source
update after the 5,500 ms interval; it is not a new 193-tick timing rule. Score
remained 3,110 and total 4,110 throughout; the field appeared directly as 3,110.
The browser harness fails if the transition is earlier than 5,500 ms or later
than the next 40 ms observation window, or if any award/field changes during display.

## Implementation

`OriginalResults` replays the original banner matrices at 35 fps and uses a
5.5-second elapsed presentation deadline, independent of simulation ticks.
Key-up or direct touch can skip once frame 70 is reached. Original 1P/2P score
sheets show score components in recovered field bounds. The original game-over
and difficulty-specific well-done screens retain their artwork, name inputs and
score fields. Local replay/menu affordances are added at the bottom. Submit saves
locally; the old portal button explains that the portal is unavailable. No network
submission occurs. Names and local best scores use the existing preferences file.

The view never changes score totals. Existing award sites now retain an additional
read-only breakdown (kills, destruction, time and bonus); amounts and decision
rules are unchanged. `GameSession.next_round()` ignores calls with no pending
result or with no available continuation. The presentation also leaves after its
first continuation request, so repeated mouse releases/callbacks cannot rebuild
or advance the new round. Source outcome music stops on the score sheet; the final
score page returns to the original main-screen track.

On a time-up loss, Sprite 564 replaces each surviving human clip with `heroExp`
at the same depth (source `gameover`, line 111). Unlike `hurtHero`, this route does
not attach the separate Sprite 279 smoke. `HeroView.present_timeout_death()` latches
that presentation once and retires it after the existing 35-tick death timeline;
weapon/pointer/target visuals are hidden. Authoritative `HeroState.alive`, lives,
and scores remain session-owned and unchanged by this hook. Death geometry itself
uses the existing renderer and remains within issue 2's independent parity audit.

`ExportResultsArt.java` extracts static source display lists at 2x and dynamic-field
geometry directly from SWF tags. `prepare_results.py` also reads Symbol 563's XFL
matrices and records the preserved SWF hash. Filtering is explicitly linear;
imports remain lossless with no mipmaps. There is no generated replacement art.

## Checks and evidence

The approved public runner's campaign/rendered seams have red/green evidence:

- Repeated `next_round` formerly replaced the newly started state; it now does nothing.
- The old immediate result button formerly advanced before source readiness.
- A sampled-banner check caught an early frame-7 graphic; the corrected banner stays
  absent through source frame 6.
- 1P and 2P each exercise win, lose, time-up win/loss, retry/next stage,
  exhausted lives and completed campaign. Terminal replay and repeated continuation
  clicks are driven through viewport input.
- Exact 5.499/5.5-second and frame-70 skip boundaries are checked. Result display
  leaves simulation tick and awarded totals unchanged. A fresh main scene reloads
  the persisted best score from the runner's isolated `user://` directory.
- Time-up loss was red for missing hero replacement/retirement, then green for
  1P/2P. Captures show start, tick 10 and retirement; repeated result callbacks do
  not restart it, and authoritative alive/tick/score values remain unchanged.
- The 100-second source-win fixture yields score 3,110 / total 4,110 in both versions.

Reproduction (native visual runs use the integration exclusive wrapper):

```powershell
python tools/prepare_results.py --ffdec <ffdec-directory>
java --class-path '<ffdec>/ffdec.jar;<ffdec>/lib/*' tools/reference/BuildOutcomeReference.java 'Bomb It 1.swf' .artifacts/issue09-source/fixture.swf tools/reference/outcome_root.as tools/reference/outcome_game.as
node tools/reference/capture_outcomes.mjs .artifacts/issue09-source/fixture.swf .artifacts/issue09-source/capture
python tools/run_checks.py --godot <godot-executable> --suite campaign --suite sim --visual --output .artifacts/issue09-checks
python tools/compare_images.py reference/issue-09-capture/original/scores reference/issue-09-capture/rebuilt --output .artifacts/issue09-diff
```

Retained evidence: [12-case score/final matrix](issue-09-capture/matrix.png),
[time-up death start/tick-10/retirement](issue-09-capture/timeout-death.png),
[original trace](issue-09-capture/original/trace.json), source/runtime/script hashes,
source/rebuilt score images, exact diagnostic comparison, red logs and green logs.
The comparison intentionally exits 1; original and rebuilt images remain separate.

## Status and limitations

Functional transition matrix, idempotent continuation, read-only score display and
local-best persistence are implemented and verified through the public runner.
Original 5,500 ms timing and immediate binding are independently verified for the
named 1P/2P win fixture. Other outcome routes have source-code evidence and port
matrix coverage, not a full independent original-playback matrix.

Exact pixel parity is unverified: Ruffle device-font rendering differs from the
recovered embedded Arial Black used by Godot, and FFDec 2x extraction/sampling also
differs. Every differing pixel is retained, with no tolerance or blanket renderer
exception. Result buttons 566/614/442 now use the source up/over/down artwork with original
placement matrices and display-list order; source down matches up, while hover
adds the green outline. Rendered pointer tests exercise all three buttons. Exact
pixel comparison of the screen as a whole retains the font/sampling limitations.

The final logo does **not** have an animation: recursive inventory of Sprite 395,
394, 391, 389, 390 and 393 finds only one-frame symbols and one portal-release
callback. The prior uncertainty is resolved by this source inventory, with a
rendered stability check over two elapsed seconds; no movement was invented.

The accepted campaign award/revival policies remain unchanged, including the
existing revival deduction at next-round creation. This ticket does not claim an
independent full-match scoring or callback-order proof. Elapsed presentation time
under severe rendering stalls and physical iPhone interaction remain outside these
controlled captures. Shared Linux regression baselines are integration-owned;
`qa-result.png` now captures the outcome phase rather than an immediate generic dialog.

## Review against starting revision

Reviewed the change from `3b91c43` for score-award ownership, once-only transitions,
source field/player mappings, frame indexing, terminal routing, and interaction
with merged issue 7 selection. The rendered banner check caught a frame-index
error before handoff. Review also caught an unconditional weapon visibility override
in the timeout hook; the final hook only hides the indicator on that special route.
No gameplay timing, damage, RNG or award amounts were retuned. Integration merges
retain the independent selection/menu changes. Shared Linux baselines remain owned
by integration; exact original image comparison remains diagnostic and failing.

Final post-merge public-runner result: campaign, simulation, tooling and all nine
rendered phases passed (`issue09-handoff`, capture run `98b760d889f5`). The timeout
contact sheet was visually inspected: one/two human replacements, no separate
smoke column, and both disappear at retirement.

Source button feedback follow-up: the rendered seam failed for all three missing
hover/press changes before implementation. The exporter now splits each result
display list around button placements, preserving source labels/decorations above
their backplates; Godot uses source textures for normal, hover and pressed states.
[Recursive final-logo inventory](issue-09-capture/final-logo-inventory.json) records
the static source subtree, including its sole release script. Platform replay/menu
buttons retain their existing added presentation.

[Source up/over/down extraction](issue-09-capture/button-source-states.png) and
[rendered button feedback](issue-09-capture/button-feedback.png) were visually
inspected. Final button follow-up passed campaign and all nine rendered phases
(`issue09-feedback-final`, capture `6dbf518d05df`), including the static-logo check.
The updated exact score comparison still fails without tolerance; refreshed images
and difference masks are retained separately.
