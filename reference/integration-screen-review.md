# Integrated screen baseline review

Reviewed on 2026-10-12 at integration revision `af0daf3`, using
`tools/ci/Dockerfile` image `6d73e190feac` and the pinned Godot 4.7.2 Linux
llvmpipe environment. This checkpoint combines #3, #6, #7 and #8.

The import and ten focused behavior phases passed. Exact comparison against the
previous baselines reported 17 unchanged images, six changed images and 23 new
images without baselines. The [original comparison](integration-screen-review/before-baseline-review.json)
and [phase results](integration-screen-review/checks.json) retain that result.

The integration owner inspected the complete new/changed scene set in theme and
screen contact sheets, alongside the ticket-specific source comparisons:

- The five themes preserve complete native/enlarged composition. Controlled
  crossings show rear occlusion, front overlap and the startup player pointer.
- HUD base/status scenes show the original counters, source panels and elimination
  dimming. Pause, arena, result and touch images change with the restored HUD.
- Difficulty and 1P/2P selection scenes show original artwork, selected/unselected
  robots and independent player confirmation. Back and touch instructions are
  documented platform additions.
- The equipped-feedback image changes only for the measured counter layout.
  Death/effect sheets and existing menu/help images remain unchanged.

After this inspection, the 46 captures were copied into the regression baseline
directory. Exact comparison of the reviewed capture set against those files passes
at zero tolerance. This verifies the reviewed files, not a second independent run;
CI and the final integrated run provide subsequent reproduction checks.

Original-runtime captures remain separate. Their known pixel differences are not
waived by accepting these port regressions. The current result image still shows
the old result panel; #9 replaces it in a later reviewed batch. Remaining effects,
safe-area layout and final desktop acceptance are also outstanding.
