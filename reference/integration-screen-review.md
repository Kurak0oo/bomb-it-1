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

## Outcomes, layouts, deaths and lifecycle checkpoint

The next reviewed batch uses integration `d008b249`, Docker image `c0fdbd77c5de`
and capture ID `19ef7c074164` in the same pinned Linux renderer. Import, view,
timeline and all eleven rendered behavior phases pass. Comparison against the
46-image baseline reports 41 unchanged, five changed and 48 new captures. The
[phase results](integration-screen-review/lifecycle-outcomes/checks.json),
[original comparison](integration-screen-review/lifecycle-outcomes/before-baseline-review.json)
and [review record](integration-screen-review/lifecycle-outcomes/review.json)
retain the evidence.

The earlier `833bf0d` batch supplied 92 reviewed candidates: complete synthetic
safe-area layouts, twelve outcome routes, twelve score routes, result button
states and timeout death boundaries. Its uncontrolled `qa-result` animation
sample was rejected. #17 now fixes that capture at source frame 70; the settled
banner is centered and complete. Of those 92 candidates, 87 reproduce exactly.
The five changed candidates contain the #2 source alpha/shadow corrections in
death sheets, pickup shadows, HUD status and timeout deaths. The integration
owner inspected each difference image, the corrected result and the new complete
two-player interruption pause surface before accepting the 94-image baseline.

The Linux run also exposed and verified a test-helper correction: stop automatic
physics at its boundary before awaiting a display frame. Strict tick counts and
a forced 100 ms stall pass without changing the production timer. See
[lifecycle evidence](issue-17.md).

These files capture the current port presentation at zero tolerance. Their
acceptance does not waive original-runtime pixel differences or certify physical
iPhone layout, timing or performance. Subsequent CI checks reproduction; effect
work and final desktop acceptance still remain.

Fresh [CI run 38241510869](https://github.com/Kurak0oo/bomb-it-1/actions/runs/38241510869)
at `bef7a92` passes both jobs and reproduces all 94 images exactly. The
[job record](integration-screen-review/lifecycle-outcomes/ci.json) is retained.
This checkpoint is not final acceptance: later #29 regression work identified an
AI command-ordering defect introduced by #28, requiring independent source coverage
and an active-bomb soak assertion before completion.

## Ordinary effects and scheduling checkpoint

Integration `581395fe` (image `a6211dc5d5fb`, capture `258423e93aef`) passes import,
view, timeline and all twelve rendered behavior phases. All 94 previous images
reproduce exactly. Three new inspected images cover the six normal pickups'
79-update loop, overlapping-fill removal fade and final flame fade. They are
added at zero tolerance, bringing the baseline to 97 images. [Results and exact
comparison](integration-screen-review/ordinary-effects/checks.json) and the
[review record](integration-screen-review/ordinary-effects/review.json) retain
this checkpoint.

The flame assertion now renders an independent source-alpha control on the same
backend: both Linux and Windows detect the old fade and accept the corrected
48/256 alpha. Original-runtime comparisons remain separate and retain their
pixel differences. The clean container also verifies the report runner without
Git: revision is explicitly unknown inside the image, with both code fingerprints
retained; the integration revision and image ID above identify the captured build.

This checkpoint includes the independently verified AI repair, expiry scheduling,
push acceptance and HUD loop correction. Full desktop acceptance and remaining
special-effect work are still pending.

Fresh [CI run 38246634284](https://github.com/Kurak0oo/bomb-it-1/actions/runs/38246634284)
at `4f27cc5` passes both headless and rendered jobs and reproduces all 97 images
exactly. Its [job record](integration-screen-review/ordinary-effects/ci.json) is retained.
