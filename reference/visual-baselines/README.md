# Rendered regression baselines

Reviewed captures from `tools/ci/Dockerfile`, 2026-10-12. These preserve the
current rebuilt presentation; they do not claim pixel parity with Flash.

- Godot: 4.7.2 stable, Compatibility renderer, Linux x86_64.
- Ubuntu: 24.04; software renderer: llvmpipe, LLVM 20.1.2, 256 bits.
- `libgl1-mesa-dri` and `libglx-mesa0`: 25.2.8-0ubuntu0.24.04.4.
- `xvfb`: 2:21.1.12-1ubuntu1.8; `libxkbcommon0`: 1.6.0-1build1.
- Pillow: 12.3.0; `LP_NUM_THREADS=1`.

There are 46 exact-comparison captures: seven UI screens, two animation sheets,
one actor-feedback image, 13 menu/help images, six difficulty/selection images,
and 17 HUD/theme images. The latest reviewed batch integrates original HUD,
selection and actor-feedback work: 17 previous images are unchanged, six have
expected changes, and 23 are new. See [the integration review](../integration-screen-review.md).
Outcome and remaining effect changes are still pending; these are regression
baselines for this implementation checkpoint, not release certification.
`runtime.json` is emitted by the capture harness. Follow `../tooling.md` to
reproduce captures and review baseline updates. Windows/GPU captures remain useful
diagnostics but should not replace these Linux software-rendered baselines.
