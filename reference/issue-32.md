# #32 — shield hit credit and removed-owner allowance

The two accounting corrections restore independently observed source behavior. An eligible hit credits the other actor 1,000 in both score and kill score before armor absorbs damage; an expired bomb refunds only a still-present owner. The production diff changes only those two locations in `GameState`. Starting revision: `5366c86`. Life loss, armor consumption, shield duration, self-credit exclusion, live-owner capacity/refunds, 35 Hz timing, numeric balance, RNG and timer policy are unchanged.

## Independent source evidence

`accounting-v1` executes the original functions and complete frame-2 polling inside Sprite 564 with its real root parent. Eleven cases observe 528 ticks × 47 fields (24,816 fields). Eight existing interaction scenarios reproduce every original #13 field unchanged; the observer adds each root actor's `killScore`. Three further source controls cover self-shield, human shield consumption and the exact end of invulnerability. The original before/after captures are identical. The port moves from 342 differing fields to zero.

The source frame-2 bytecode remains 5,624 bytes with SHA-256 `b68c1872f3a1a9967dee94c3bae9d50ca9c52aab0caa357ea5d78de993e62a9b`; 16 original frame-1 function bodies remain preserved. Configuration, source/fixture/builder/harness hashes and execution scope are recorded and strictly validated. Only setup, input injection and observation are adapted; source damage/accounting logic is not reconstructed as an oracle.

At `shield_bomb` tick 1 the attacker receives 1,000 score and kill score, while the armored victim keeps three lives and receives shield 60. In `shield_invulnerability_boundary`, an additional attack still cannot credit or damage on ticks 59–61 (shield 2, 1, then 0); at tick 62 it credits the second attacker 1,000, reduces life to two and restores shield 60. Self damage and self-shield consumption never credit the victim. Human armor preserves life while the subsequent unarmored hit removes the human display actor, even when campaign lives remain. The repeated AI hit case preserves all three-life outcomes.

`dead_owner_refund` begins with matched capacity four and allowance three after one placement. The owner is removed before the expiry callback; at tick 4 the root allowance stays three. Original `bombExp` accesses the owner through the live display clip, so an absent actor cannot perform the increment. Live-owner refunds, grenade chain credit/refund and overlapping energy ownership in both creation orders remain exact.

## Public red/green and round transitions

The public `actors` suite first fails on shield score at tick 1. After only the credit correction it fails on the removed-owner allowance at tick 4; after both corrections the complete source gate passes. Strict comparison tests perturb real kill credit and refund fields and reject a missing score field or shifted immunity-boundary tick.

The public `campaign` suite now exercises a two-player session: the first human places a bomb, dies on a separate tile while the second keeps the round active, and the bomb expires without refund. The old refund implementation fails this check. A first draft put the damage on the bomb's own tile, correctly causing an earlier live-owner chain refund; that invalid setup was corrected before drawing a conclusion. The retained red log uses the separated-tile setup.

After both humans are removed, retry retains their remaining lives and accumulated totals and creates one bomb allowance/capacity. A subsequent winning round also resets a prior capacity of four to one on progression. This verifies the existing `GameSession` policy without changing it: original frame-2 setup lines 74–92 resets root `totalBomb` and each newly attached actor's `totalBomb` to one.

## Validation and limits

All 24 full headless phases pass, including 38 tooling tests, source ordering/expiry/push/grenade gates, simulation, campaign, view/timeline and pacing. The seeded 21,600-tick soak remains active with 511 bombs and 149 specials. Full motion remains exact. Existing interaction differences decrease from 106 to 47: 32 gas onset fields and one ice onset field belong to #33; 14 rocket/mine residual-energy fields remain INTERACT-06. All non-accounting core/interaction rows match the #31 controls. CORE-01 retains six one-twip observations.

INTERACT-06 deliberately retains balanced cleanup. Source clip identity/replacement is known, but Ruffle removed-clip dispatch is not independently established as Adobe Flash behavior; permanent invisible energy is not introduced. Ruffle 0.7.1 execution is independent source evidence, not certification of Flash runtime parity. No rendered geometry or image baseline changes are part of this correction.

Reproduce with `python tools/capture_core_reference.py --profile accounting-v1 --ffdec <FFDEC_HOME> --godot <Godot-4.7.2> --require-parity`. The public runner's `--suite actors --suite campaign` uses retained source rows without browser dependencies. [Evidence](issue-32-evidence) contains source/rebuilt captures, red logs, comparisons and full runner results.

Integration `69e8694` merged cleanly at `e0162db`. All 21 focused post-merge phases pass (tooling, actor/source accounting, campaign/session transitions, simulation/expiry/push, special/human command order/grenade and active soak). No shared baseline is modified.
