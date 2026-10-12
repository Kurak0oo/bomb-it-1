# #29 — expiry and child callback ordering

An existing bomb now expires, refunds and supplies explosion energy before parent command polling. Held Fire places its replacement in that same update. The source-backed implementation snapshots live effect callbacks in reverse creation order; newly created callbacks first run on the next update. Hero movement/timer preparation and damage/accounting are otherwise unchanged. There are no scenario-specific branches, numeric timing changes, RNG changes or ownership changes.

## Independent boundary evidence

`expiry-v1` runs all preserved original frame-1 functions and the unchanged frame-2 polling/release tag inside original Sprite 564, with a real root parent. Eleven cases observe 440 ticks × 11 fields (4,840 fields). The original source rows are identical before/after implementation. The expanded pre-fix comparison has 86 differences; the final comparison has zero. Original polling provenance remains 5,624 bytes, SHA-256 `b68c1872f3a1a9967dee94c3bae9d50ca9c52aab0caa357ea5d78de993e62a9b`.

- Held ordinary fire expires/refires at tick 60 with a new fuse 60; the released newborn counts 59 at tick 1 and 1 at tick 59.
- A newborn on existing energy survives its birth update and chains on the next callback; holding Fire can replace it again in that update. Release restores the allowance and energy clears.
- A bomb created after an explosion runs before that older explosion's growth: it remains fuse 59 on growth tick 1 and chains at tick 2. Existing older neighbor bombs chain on growth tick 1, tested in both insertion orders.
- A bomb created after an existing rocket survives the rocket's impact update and chains next update; a bomb created before that rocket chains in the impact update. Fire's explicit source `bombExp` call still detonates immediately, even if that bomb's own callback already ran.

These controls distinguish a creation-ordered callback snapshot from merely moving a global bomb phase. Setup explicitly initializes both owners' capacity/allowance and registers initially existing effects; only setup, commands and observations are authored by the fixture. Expected rows are captured from source execution.

## Controls and retained limitations

| Profile | Before → after differing fields | Interpretation |
| --- | --- | --- |
| Core | 37 → 6 | CORE-02 fixed; six CORE-01 one-twip observations retained. |
| Motion | 309 → 72 | All seven pushed-bomb cases now exact, including activation, fuse expiry, source/reserved energy and vacated-cell alignment. Only grenade endpoint cases remain (#31). #30 still audits its own coverage. |
| Interaction | 134 → 132 | Rocket→mine onset/refund now matches as a natural scheduling consequence. Gas onset, ice onset (#33), shield credit/dead-owner refunds (#32), and grenade endpoints (#31) remain. All previously exact cases remain exact. |
| Human command order | 0 → 0 | All 28 #28 cases preserved. |
| AI command order | 0 | Seven forced-decision cases pass after the separately committed #28 regression repair. |

INTERACT-06 is deliberately retained: Ruffle's same-name clip replacement leaves residual energy after tick 18 in the rocket→mine fixture. The rebuild clears both contributions at tick 18. Source identity/replacement is established; original Flash removed-clip dispatch is not. This change does not reproduce permanent invisible danger. Full hero/effect callback interleaving and Adobe Flash parity are not claimed; accepted hero preparation and damage ordering remain bounded by these controls.

## Validation and reproduction

The public `sim` runner now includes exact independent expiry comparison. Public comparison tests perturb real tick-60 allowance and tick numbering, and reject missing original-bytecode provenance. The runner failed at ordinary_hold tick 60 before correction. All 17 final headless phases pass, including 21,600 soak ticks with 508 bombs and 151 specials, bounded inventory and nonnegative energy. The soak activity assertion and AI correction are explained separately in [issue-28-ai.md](issue-28-ai.md).

Run `python tools/capture_core_reference.py --profile expiry-v1 --ffdec <FFDEC_HOME> --godot <Godot-4.7.2> --require-parity`; `python tools/run_checks.py --godot <Godot-4.7.2>` exercises the retained reference without browser dependencies. [Evidence](issue-29-evidence) retains source/rebuild captures, pre/post comparisons, fresh core/motion/interaction/order control captures, red log and final runner logs. Ruffle 0.7.1 is an independent execution of the source, not Adobe Flash certification. No shared visual baseline is changed.

Integration `e12f8b0` was merged without conflicts at `4f001a7`. All nine post-merge focused phases pass (import, simulation/expiry, actors/AI, specials/human order, soak and timeline). The serialized native Windows feedback check returned `FEEDBACK_RENDER_OK` on Godot 4.7.2/OpenGL. Shared visual baselines remain root-owned.
