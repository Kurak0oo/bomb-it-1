# #33 — local special contact callbacks

Gas now receives its original same-update parent decrement. Each ice cell has a separate contact callback, first eligible after birth and retained through its own lifetime even after the ray parent retires. Contact observes the actor position before that update's movement callback; stop countdown occurs in parent polling after contact, and only when movement has completed. Starting revision: `66ee589`.

The 600 gas value, 300 ice value, movement speeds, 35 Hz update rate, projectile/ray ages, damage, score, RNG and timer policy are unchanged. `SpecialState.age`, `painted`, `born` and GameView lifetime inputs are preserved. `IceContactState` models the independently observed child callback; it is not a visible extra special and does not extend the ray controller or its collision cleanup. No blanket reversal of hero/effect phases is introduced.

## Source execution and public red/green

`contact-v1` has 14 scenarios, 2,675 contiguous ticks and 48 fields per tick (128,400 fields). It extends gas through expiry; observes all three ice cells through countdown, approach and departure; preserves rocket/bomb, bomb/gas, fire/bomb, fire ownership, fire/ice and ordinary mine controls; and bounds rocket/mine activation in both creation orders. The starting implementation differs in 1,967 fields; the correction is exact. A separate `icewalk-v1` scenario observes 316 ticks × 48 fields (15,168 fields) while an actor leaves during active freezing and resumes held movement after countdown; it is also exact.

Both profiles execute original Sprite 564 with a real root parent. All 16 original frame-1 function bodies and complete frame-2 polling remain preserved; the latter is 5,624 bytes with SHA-256 `b68c1872f3a1a9967dee94c3bae9d50ca9c52aab0caa357ea5d78de993e62a9b`. Fixture extensions configure a human input probe and observe its position/cell/moving state; they call original polling and its installed movement callbacks. They do not calculate source contact, decrement, release or expiry expectations.

The public `special` runner first failed on gas tick 0 (599 source / 600 rebuild). After the isolated decrement correction, all 606 gas observations passed. The expanded source gate then failed on ice birth tick 3 (zero source / 300 rebuild). The separate child callback, pre-move contact positions and parent stop countdown make it green. Comparison tests perturb actual gas expiry, final-child contact and moving-resume fields, and reject shared missing fields or a shifted birth tick.

## Exact boundaries

Gas contact sets 600 before parent polling records 599 on tick 0; ticks 598 and 599 record one and zero, and the trace remains zero through tick 605.

| Initially installed ice ray cell | Birth | First contact | Last contact | First countdown below 299 | Zero |
| --- | ---: | ---: | ---: | ---: | ---: |
| First | 3 | 4 | 42 | 43 | 341 |
| Second | 7 | 8 | 46 | 47 | 345 |
| Third | 11 | 12 | 50 | 51 | 349 |

Stationary humans show 299 on each contact update: the child sets 300, then original parent polling decrements it. The ray parent retires on tick 48, while its last contact child still runs on ticks 49 and 50. The child's frame-40 `removeMovieClip` action and independent trace support its separate lifetime. Collision-cell cleanup remains the ray parent's existing operation.

An approaching actor starts walking on tick 0. Ice observes its pre-move position, so it is not frozen on tick 5 despite ending that update within range. Tick 6 freezes it, completes its step and records 299. It reaches zero on tick 341 and resumes held movement on 342.

The moving-away probe starts on tick 2. Contact on tick 4 sets 300 while the actor continues its existing step; the counter stays 300 through tick 7. Completion on tick 8 begins countdown at 299. Tick 307 reaches zero, held input resumes movement on 308, release on 309 allows that first tile to finish on 314. All observations through tick 315 match.

## Creation order and retained uncertainties

No additional rocket/mine production change was necessary after #29. A mine created before the rocket sees its pulse in tick 8; with reversed creation order the mine survives tick 8 and triggers on tick 9. Energy ownership and both activation sequences match exactly through tick 17.

The separate `dispatch-v1` diagnostic retains both complete 32-tick runs. At tick 18, the original-order source keeps energy one while the rebuild clears it; reversed order keeps source energy two versus rebuild one, then source one versus rebuild zero from tick 19. These 28 field differences remain explicit. Original same-name clip replacement is known; Ruffle's removed-clip dispatch is not independently established as Adobe Flash behavior. Balanced rebuild cleanup is retained, with no permanent invisible danger introduced.

A longer 325-tick moving-away run is retained under `long-walk-core01` with its original configuration and raw captures. Its only difference is the already known CORE-01 one-twip quantization on the second post-thaw tile: tick 315 gives 4,899 versus 4,900 twips. No coordinate correction is made. The separately defined acceptance fixture supplies release after the first resumed step, identically to both runtimes; it does not trim or relabel recorded samples. Historical first-slice and long-walk configurations are retained alongside their captures and are distinct from the final registered profile configurations.

## Collector reliability and validation

Two initial extended runs were rejected because Ruffle dispatched ticks 0 and 1 before the first suspension. Their failure logs are retained. The collector now permits at most three fresh-page attempts for precisely that initial two-tick batch. Each accepted scenario is a complete contiguous capture from a fresh page. Every rejected attempt writes its observed batch and console log; non-startup errors and third-attempt failures remain fatal. No sample stitching, shifting or dropped ticks is permitted. The public `--audit-sample-batch <diagnostic.json>` command replays the same live batch policy. Its tests prove mid-sequence gaps/extra updates fail immediately, startup retry is bounded, and a valid contiguous batch passes. Browser dependencies are not needed for this audit command. Two synthetic fault SWFs also exercise the actual public browser collector: repeated initial double-dispatch fails after exactly three fresh-page attempts, while a mid-sequence gap fails immediately after one. Their scripts, configurations, rejected batches, logs and hashes are retained under `collector`; they validate the harness and are not gameplay oracles.

All 26 headless phases pass, including 45 tooling tests, source accounting/ordering/expiry/push/grenade gates, campaign, view/timeline and pacing. The seeded active soak completes 21,600 ticks with 514 bombs and 149 specials. Full motion remains exact, core retains its same six CORE-01 fields, and full interaction differences fall 47 to 14, all INTERACT-06. Only gas/ice rows change from the #32 control capture. No shared image baseline is changed; Ruffle 0.7.1 remains independent source execution rather than Flash certification.

Reproduce with `python tools/capture_core_reference.py --profile contact-v1 --ffdec <FFDEC_HOME> --godot <Godot-4.7.2> --timeout 600 --require-parity`, and similarly `icewalk-v1`. `dispatch-v1` deliberately reports retained diagnostic differences. The public runner's `--suite special` verifies both passing source profiles without browser dependencies. [Evidence](issue-33-evidence) retains original/rebuilt captures, exact before/after comparisons, red logs, controls, raw uncertainties and runner results.

A fresh complete source repeat reproduces every one of the 2,675 contact rows unchanged and passes strict parity. Eight carried-forward source controls also reproduce their corresponding #13 fields.

Collector reliability is isolated in commit `d48a749`; mechanics/source evidence is `b3323b6`. Integration `423b60e` merged cleanly at `1a9ac7d`. All 21 focused post-merge phases pass, including both contact gates, human/AI ordering, accounting, expiry/push/grenade controls, tooling and active soak.
