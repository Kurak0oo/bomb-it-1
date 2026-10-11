# Rendered regression baselines

Reviewed captures from `tools/ci/Dockerfile`, 2026-10-11. These preserve the
current rebuilt presentation; they do not claim pixel parity with Flash.

- Godot: 4.7.2 stable, Compatibility renderer, Linux x86_64.
- Ubuntu: 24.04; software renderer: llvmpipe, LLVM 20.1.2, 256 bits.
- `libgl1-mesa-dri` and `libglx-mesa0`: 25.2.8-0ubuntu0.24.04.4.
- `xvfb`: 2:21.1.12-1ubuntu1.8; `libxkbcommon0`: 1.6.0-1build1.
- Pillow: 12.3.0; `LP_NUM_THREADS=1`.

Seven UI screens and two animation sheets are checked with exact pixel comparison.
`runtime.json` is emitted by the capture harness. Follow `../tooling.md` to
reproduce captures and review baseline updates. Windows/GPU captures remain useful
diagnostics but should not replace these Linux software-rendered baselines.
