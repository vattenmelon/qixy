# QIXY — Copilot instructions for code changes

Purpose: help an AI coding agent be immediately productive on this Commodore 64 assembly project.

- **Big picture**: QIXY is a Commodore 64 game written in 6502 assembly. The single primary source is `qixy.asm` which assembles into `qixy.prg`. The build system supports multiple 6502 assemblers (ACME, 64tass, optional ca65) via `build.sh` and `Makefile`.

- **Primary files**:
  - `qixy.asm` — main game source (6502 assembly).
  - `Makefile` and `build.sh` — canonical build and run workflows.
  - `qixy.prg`, `qixy.d64` — build outputs; D64 created if `c1541` is available.
  - `title_data.asm`, `tools/convert_title.py` — title/asset generation pipeline.

- **Build / run flows (use these exact commands)**:
  - Build (default assembler ACME): `./build.sh` or `make`
  - Build with alternate assembler: `make ASSEMBLER=64tass` or `./build.sh 64tass`
  - Run in VICE emulator: `make run` (uses `x64sc` with autostart)
  - Create disk image: `make disk` (requires `c1541` from VICE)

- **Assembler conventions**:
  - ACME is the recommended/default assembler; code and Makefile are set up for ACME syntax.
  - `ca65` is supported only via a converted source `qixy_ca65.asm` (if present); do not attempt automatic conversion unless explicit.

- **Project-specific patterns**:
  - Memory layout and important addresses are documented in `README.md` (BASIC stub at `$0801`, game entry at `$0810`, SYS 2064).
  - Graphics and sprites live in custom character/sprite data blocks — changing visuals often requires editing `title_data.asm` and running `tools/convert_title.py` to regenerate binary data.
  - Keep low-level register/memory changes minimal and local: the game tightly couples code to addresses in the README memory map.

- **Editing guidance for agents**:
  - When modifying assembly, always run the build (`./build.sh`) and verify `qixy.prg` is produced before proposing runtime changes.
  - If changing graphics or title data, update `title_data.asm` and run `tools/convert_title.py` (inspect output artifacts) before rebuilding.
  - Use `make run` to sanity-check behavior in VICE; prefer this over manual emulator invocation.
  - Avoid changing the BASIC stub or the start address unless the change is intentional and the address adjustments are propagated to README and the Makefile.

- **Debugging tips**:
  - Use the emulator (`x64sc`) with break/trace features when available; reproduce the issue with `make run` and the most recent `qixy.prg`.
  - To debug build problems, run `./build.sh` with the assembler argument to surface assembler-specific errors.

- **Examples to include in commits/PRs**:
  - "Fix sprite collision: adjust sprite table offset in `qixy.asm` and verify with `make run`."
  - "Update title art: edited `title_data.asm`, regenerated assets with `tools/convert_title.py`, rebuilt with `./build.sh` and created `qixy.d64` via `make disk`."

- **What not to do automatically**:
  - Don't attempt to port syntax automatically between assemblers without human review.
  - Don't change the memory map or entry points without explicit tests and README updates.

If any of these assumptions are wrong (preferred assembler, emulator flags, or asset pipeline), tell me what to change and I will update this file.
