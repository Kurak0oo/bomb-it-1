# Project navigation

- Preservation work: read `reference/rebuild-status.md` for source evidence and remaining parity uncertainties.
- Animation work: read `reference/visual-fidelity.md`; inspect source symbols with `python tools/inspect_symbol.py <id> --frames <frame> ...`.
- Validation: use `tools/run_checks.ps1` or `python tools/run_checks.py --help`; environment and reference-capture setup is in `reference/tooling.md`.
- Code navigation: an optional CodeGraph database may exist under `godot/.codegraph`. Run CodeGraph from `godot` when it contains indexed code; fall back to source search when it reports nothing indexed. Index creation remains the user's decision.
