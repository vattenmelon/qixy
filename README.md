# QIXY - A Modern Qix Clone for Commodore 64

A faithful recreation of the classic arcade game Qix, designed for the Commodore 64 with a modern aesthetic featuring colorful neon graphics and smooth gameplay.

## Gameplay

In QIXY, you control a marker that moves around a rectangular playfield. Your goal is to claim territory by drawing lines that section off portions of the field. But beware - enemies are hunting you!

### Controls
- **Joystick (Port 2)**: Move in any direction
- **Fire Button**: Press fire while stepping off an edge to start drawing into open territory. What you do with fire *while* drawing sets the draw mode (see Scoring):
  - **Hold fire** → **slow draw**: half speed, but the area you enclose is worth **double** points.
  - **Release fire** → **fast draw**: normal speed, normal points — use it to dash back to safety.

### Enemies
- **Qix**: The main enemy that bounces around inside the unclaimed area. If it touches your trail while you're drawing, you lose a life! A **second Qix** (a free-flying triangle) joins from level 6 — seal it inside claimed territory to destroy it.
- **Sparx**: Enemies that patrol the borders — avoid them at all costs! They get faster as the levels climb (reaching full speed at level 25), and a **third Sparx** circling the opposite way joins from level 8.

### The Fuse
Don't dawdle while drawing! If you stop part-way through a line, a **spark ignites at the base of your trail and races up it toward you** — if it catches your head, you lose a life. Keep moving to outrun it; laying any new tile puts it out. Once you commit to a draw, you're committed.

### Objective
Claim the target percentage of the playfield to advance to the next level. The target starts at **70%** and rises **+2% per level** (capped at 90%). Levels are endless — they keep getting harder, and your run ends only when you run out of lives.

### Scoring
Your score comes from three places:

- **Claiming territory** — every tile you enclose scores points as it fills:
  - **1 point per tile** on a fast draw (fire released).
  - **2 points per tile** on a slow draw (fire held for the *entire* trail). Releasing fire even once during that trail drops it back to 1×.
- **Level-completion bonus** — clearing a level awards **`(level + overshoot) × 100` points**, where *overshoot* is how many percent past the target you finished. So both reaching higher levels *and* saving a big region for one large finishing claim pay off (e.g. clearing level 5 at 85% with a 75% target = `(5 + 10) × 100` = **1500**).
- **Extra lives** (not points, but score-driven) — you earn a spare life **every 5,000 points**, and an immediate bonus life for any **single claim that covers ≥ 50%** of the field.

The score is shown as six digits in the HUD (maximum 999,999) and the top five runs are kept on a persistent high-score table.

## Building

### Requirements
You need one of the following 6502 cross-assemblers:
- **ACME** (recommended): https://sourceforge.net/projects/acme-crossass/
- **64tass**: http://tass64.sourceforge.net/

Optional but recommended for faster disk loading:
- **Exomizer**: https://bitbucket.org/magli143/exomizer/wiki/Home (`brew install exomizer`)

### macOS
```bash
# Install ACME via Homebrew
brew install acme

# Build the game
./build.sh

# Or use make
make
```

### Linux
```bash
# Install ACME (Debian/Ubuntu)
sudo apt install acme

# Build the game
./build.sh
```

### Windows
```batch
# With ACME in your PATH
acme -f cbm -o qixy.prg qixy.asm
```

## Running

### VICE Emulator
The easiest way to play is with the VICE emulator:

1. Download VICE from https://vice-emu.sourceforge.io/
2. Build the game (see above)
3. Run: `x64sc qixy.prg` or `make run`

### Faster Loading (Exomizer)

The raw `qixy.prg` is ~50KB, and about 40% of it is zero-fill from gaps in the
memory map (e.g. the empty RAM between the game code and the title screen at
`$5C00`). On a real 1541 that's a ~2-minute load.

If **Exomizer** is installed, the build automatically produces
`qixy_crunched.prg` — a self-decrunching, auto-running version that is roughly
half the size (~22KB) with the zero gaps removed:

```bash
./build.sh          # builds qixy.prg, then crunches to qixy_crunched.prg
make crunch         # same, via make
```

The crunched file loads and decrunches in RAM in about a second, then boots
normally — no extra steps needed. If Exomizer is not installed, the build skips
this step and everything falls back to the raw `qixy.prg`.

> `make run` injects the raw `.prg` straight into emulator RAM (already
> instant), so crunching only affects `make rundisk` and real hardware.

### Creating a D64 Disk Image
For use with SD2IEC, Ultimate 64, or other hardware:

```bash
# Requires c1541 from VICE
make disk
```

This creates `qixy.d64`, which can be transferred to real hardware. When
Exomizer is installed, the disk ships the crunched build (`qixy_crunched.prg`,
~89 blocks instead of ~196) for the faster load described above.

### Real Commodore 64 Hardware
1. Create the D64 disk image (see above)
2. Transfer to your storage device (SD2IEC, Ultimate 64, etc.)
3. Load and run:
```
LOAD"QIXY",8,1
RUN
```

Or use the SYS command directly:
```
LOAD"QIXY",8,1
SYS 2064
```

## Technical Details

- **Platform**: Commodore 64 (PAL/NTSC); detects and adapts to C128 (uses its 2 MHz mode) and Ultimate (U64 / U2+) hardware
- **Language**: 6502 Assembly
- **Graphics**: Custom character set with hardware sprites
- **Sound**: SID chip effects
- **Memory**: Starts at $0810 with BASIC stub

### Memory Map
- `$0801-$080F`: BASIC stub (SYS 2064)
- `$0810-$1FFF`: Game code and data
- `$2000-$27FF`: Custom character set
- `$2800-$2BFF`: Sprite data
- `$0400-$07E7`: Screen RAM
- `$C320-$C5EF`: Machine-detection + C128-acceleration module

### Features
- Smooth sprite-based player and enemies
- Animated color cycling (modern neon aesthetic)
- SID sound effects
- Multiple levels with increasing difficulty
- Score tracking with lives system
- Flood-fill based territory claiming
- Detects the host (PAL/NTSC, C64/C128, Ultimate 64 / Ultimate-II+) and shows it on the high-score screen
- Uses the C128's 2 MHz mode (in the border/vblank, where safe) for faster territory fills

## Files

- `qixy.asm` - Main source code
- `qixy.prg` - Assembled C64 executable
- `qixy_crunched.prg` - Exomizer-crunched, self-decrunching build (faster loading)
- `qixy.d64` - Disk image for hardware/emulator (ships the crunched build)
- `Makefile` - Build automation
- `build.sh` - Shell build script
- `README.md` - This file

## License

This is a fan-made recreation for educational and entertainment purposes.
Original Qix game copyright Taito Corporation.

## Credits

- Programming: Claude Code
- Original Game Design: Taito Corporation (1981)
