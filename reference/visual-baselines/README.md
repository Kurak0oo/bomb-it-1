# Rendered regression baselines

Reviewed captures from `tools/ci/Dockerfile`, 2026-10-12. These preserve the
current rebuilt presentation; they do not claim pixel parity with Flash.

- Godot: 4.7.2 stable, Compatibility renderer, Linux x86_64.
- Ubuntu: 24.04; software renderer: llvmpipe, LLVM 20.1.2, 256 bits.
- `libgl1-mesa-dri` and `libglx-mesa0`: 25.2.8-0ubuntu0.24.04.4.
- `xvfb`: 2:21.1.12-1ubuntu1.8; `libxkbcommon0`: 1.6.0-1build1.
- Pillow: 12.3.0; `LP_NUM_THREADS=1`.

There are 97 exact-comparison captures. The preceding reviewed batch integrates
outcomes, score/button routes, timeout deaths, nine safe-area layouts, death/shadow
corrections and a two-player interruption surface. Of the previous 46 images,
41 remain unchanged, five have reviewed changes, and 48 are new. See
[the integration review](../integration-screen-review.md) for retained comparisons
and the deterministic result-capture correction. Remaining effect changes and
desktop acceptance are pending; these are regression baselines for this
implementation checkpoint, not release certification. The latest batch preserves
all 94 images exactly and adds three inspected ordinary-effect captures for the
pickup loop, pickup removal and flame fade. No tolerance is relaxed.
`runtime.json` is emitted by the capture harness. Follow `../tooling.md` to
reproduce captures and review baseline updates. Windows/GPU captures remain useful
diagnostics but should not replace these Linux software-rendered baselines.
