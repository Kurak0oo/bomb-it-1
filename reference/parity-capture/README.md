# Controlled original-bytecode comparison

Captured on 2026-10-11 with Ruffle 0.7.1 / its pinned Chromium and Godot 4.7.2.
`original.json` contains the runtime versions, package integrity, SWF and harness
hashes. `rebuilt.json` is the independently observed Godot fixture.

All fields match across 40 updates each for character death, level-one explosion
energy, and a brick in the right explosion arm. This is a narrow reference test,
not proof of full-game or Adobe Flash Player equivalence.

Seven of nine sampled death images differ pixel-for-pixel; the final two empty
frames match. `image-comparison.json` records pixel counts. The frame-seven
triptych shows original / rebuilt / difference mask. It demonstrates that matching
state timing does not imply identical rendering. Gameplay has not been adjusted
to hide those differences.

Reproduce with the commands in `../tooling.md`. Complete captures and runtime logs
are run artifacts; this directory retains the small reviewed evidence bundle.
