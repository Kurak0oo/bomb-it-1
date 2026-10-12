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

The task graph is the tracker’s native blocking graph, captured on 2026-10-12.
Implementation occurs in ticket worktrees, merged into this branch by a merger
agent. Only demonstrated acceptance permits a closing reference in the draft PR;
partially implemented or externally blocked tickets stay open.

| Ticket | Blocked by | Current disposition |
|---|---|---|
| #2 Four death animations | None | Implementer active; correct or independently explain remaining original-image differences |
| #3 Actor feedback | None | Integrated in 0dc29e1; [acceptance evidence](issue-03.md), 259 observations match and 56 exact image differences remain unwaived |
| #4 Ordinary effects | None | Pending |
| #5 Special-weapon presentation | #3, integrated | Pending |
| #6 Original menus/help | None | Integrated in cac441d; [acceptance evidence](issue-06.md), exact cross-runtime pixels remain unverified |
| #7 Difficulty/character selection | #6, integrated | Integrated in c036f3f; [acceptance evidence](issue-07.md), exact image and animation-phase parity remain unverified |
| #8 HUD/arena composition | None | Integrated in 3b91c43; [acceptance evidence](issue-08.md), font substitution and exact pixel differences retained |
| #9 Scores/outcome transitions | #6, integrated | Integrated in f26207e; [source timing, button states and twelve-route evidence](issue-09.md) |
| #10 Original audio | #3, integrated | Pending |
| #11 Movement/damage/firing traces | None | Integrated in 6d28b66; [independent evidence](issue-11.md), 69 field differences explicitly retained |
| #12 Pushing/grenade traces | #11, integrated | Integrated in a712245; [15-scenario evidence](issue-12.md), 309 field differences retained as MOTION-01–04 |
| #13 Interaction/ownership traces | #11, integrated | Implementer active |
| #14 Strict random replay | None | Pending |
| #16 Safe-area landscape layout | None | Implementer active |
| #17 Interruptions/resume | #15, implemented | Pending remaining verification |
| #18 Smooth rendering | #17 | Pending |
| #19 Windows package | None | Pending |
| #20 iPhone build/install | External Apple environment | Configuration can proceed; native build/install blocked |
| #21 Integrated desktop acceptance | #2–#19, #28–#29 | Pending integration and packaging |
| #28 Movement/special-fire ordering | #11, integrated | Pending separately reviewed CORE-03 correction |
| #29 Bomb expiry/held-fire ordering | #11–#13 | Pending separately reviewed CORE-02 correction |

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
