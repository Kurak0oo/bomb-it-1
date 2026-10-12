# Pre-iPhone implementation integration

Spec: [#1](https://github.com/Kurak0oo/bomb-it-1/issues/1).
Branch: `integration/pre-iphone-completion`.
Review baseline: `f79737253316dc3d805dd56af1d2eea95a66033d`.

The user requested the remaining work up to, but excluding, real-iPhone testing.
This pass covers the 19 remaining tickets below. #15 and #24–#26 are already
implemented, with evidence in the earlier completion/menu reviews. #22 (native
iPhone acceptance) and #23 (final release sign-off) are outside this pass. The
parent spec remains open until those later gates are satisfied.

Independent #11 traces exposed two concrete ordering defects. The parent spec's
source-backed correction process adds #28 and #29 as separate, bounded tasks
before desktop acceptance. They do not change the 35 Hz rate, numerical balance,
seeded RNG or deterministic timer policy. CORE-01's one-twip Ruffle quantization
difference remains unverified against Adobe Flash and is not a correction target.

The nested interaction fixtures in #13 reproduce the earlier timing findings and
add real parent score/life/refund observations. Bounded follow-ups #30–#33 cover
push lifecycle, grenade endpoints, hit/refund accounting and local special-effect
callback eligibility. INTERACT-06's residual pulse energy remains an explicit
source/runtime uncertainty; the rebuild retains balanced cleanup.

The task graph is the tracker’s native blocking graph, captured on 2026-10-12.
Implementation occurs in ticket worktrees, merged into this branch by a merger
agent. Only demonstrated acceptance permits a closing reference in the draft PR;
partially implemented or externally blocked tickets stay open.

| Ticket | Blocked by | Current disposition |
|---|---|---|
| #2 Four death animations | None | Integrated in 65692e0; [source fixes and per-sample attribution](issue-02.md). Actual source/port images still differ in 32/40 samples; renderer controls are separate evidence |
| #3 Actor feedback | None | Integrated in 0dc29e1; [acceptance evidence](issue-03.md), 259 observations match and 56 exact image differences remain unwaived |
| #4 Ordinary effects | None | Integrated in d90a0cf; [305 lifecycle observations and source-backed fade fixes](issue-04.md). Actual exact images still differ in 94/134 samples |
| #5 Special-weapon presentation | #3, integrated | Implementer active |
| #6 Original menus/help | None | Integrated in cac441d; [acceptance evidence](issue-06.md), exact cross-runtime pixels remain unverified |
| #7 Difficulty/character selection | #6, integrated | Integrated in c036f3f; [acceptance evidence](issue-07.md), exact image and animation-phase parity remain unverified |
| #8 HUD/arena composition | None | Integrated in 3b91c43; [acceptance evidence](issue-08.md), font substitution and exact pixel differences retained |
| #9 Scores/outcome transitions | #6, integrated | Integrated in f26207e; [source timing, button states and twelve-route evidence](issue-09.md) |
| #10 Original audio | #3, integrated | Pending |
| #11 Movement/damage/firing traces | None | Integrated in 6d28b66; [independent evidence](issue-11.md), 69 field differences explicitly retained |
| #12 Pushing/grenade traces | #11, integrated | Integrated in a712245; [15-scenario evidence](issue-12.md), 309 field differences retained as MOTION-01–04 |
| #13 Interaction/ownership traces | #11, integrated | Integrated in ca793d7; [17-scenario nested-source evidence](issue-13.md), 134 differences retained and earlier timing controls reproduced |
| #14 Strict random replay | None | Pending |
| #16 Safe-area landscape layout | None | Integrated in 200706f; [physical-to-logical input and nine-layout evidence](issue-16.md), native device acceptance remains separate |
| #17 Interruptions/resume | #15, implemented | Integrated in 51e5b7d; [rendered interruption, stale input, audio suspension and interpolation evidence](issue-17.md) |
| #18 Smooth rendering | #17, integrated | Integrated in f9f2538; [schedule invariance, frame/input reporting and measured HUD improvement](issue-18.md). Final candidate performance remains #21 |
| #19 Windows package | None | Implementer active |
| #20 iPhone build/install | External Apple environment | Configuration can proceed; native build/install blocked |
| #21 Integrated desktop acceptance | #2–#19, #28–#33 | Pending integration and packaging |
| #28 Movement/special-fire ordering | #11, integrated | Integrated in fcbd85f; [28 exact command-boundary cases](issue-28.md), remaining CORE-01/02 differences preserved |
| #29 Bomb expiry/held-fire ordering | #11–#13, integrated | Integrated in 822b806; [4,840 exact expiry fields](issue-29.md), with separate [AI ordering repair](issue-28-ai.md) and active soak |
| #30 Push callback lifecycle | #12–#13, #29 integrated | Integrated in f27fc93; [7 cases / 6,048 exact fields](issue-30.md), with no additional production change |
| #31 Grenade endpoint | #12–#13 | Integrated in 5366c86; [18 endpoint cases and real-parent chain accounting](issue-31.md), all 17,792 fields exact; full motion profile now agrees |
| #32 Hit/refund accounting | #13, #29 | Implementer active on INTERACT-01/02 correction |
| #33 Special contact/callback eligibility | #13, #29 | Pending INTERACT-03/04/05 correction; residual-energy uncertainty excluded |

## Acceptance boundaries

Preserve accepted 35 Hz gameplay, the seeded RNG backend and deterministic timer.
New source discrepancies require independently observed evidence and explicitly
identified correction work. A visual mismatch is not permission to retune rules.

Continue testing at the user-approved public runner, symbol-inspection and
comparison commands, and rendered input/output boundaries. Run focused checks
per ticket, the full suite at integration, and separate Standards/Spec reviews
against this pass's baseline. Keep original-runtime evidence separate from port
regression baselines. Do not suppress unexplained differences or silently relax
comparison tolerances.

## External limits

The user has iPhones, likely generation 12 or newer, but no Mac/Xcode access.
Exact models, refresh modes and signing availability are not yet established.
An export preset or unsigned artifact cannot satisfy signed installation or
device-performance requirements. No Apple purchase, account enrollment, App Store
submission or simulated device pass is authorized or implied.

The remote main branch initially trails the local reviewed baseline by eight
commits. A PR to main therefore also carries those prior accepted changes;
their original reviews remain in the completion and menu review documents.
This pass's review uses the fixed baseline above to avoid reviewing them as new.
