# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

QIXY is a Commodore 64 game written in 6502 assembly language - a modern recreation of the classic arcade game Qix. The game is primarily contained in a single ~6000-line assembly source file (`qixy.asm`) plus a generated `title_data.asm` for the title screen graphics, compiling to a `.prg` executable.

## Build Commands

**Build the game:**
```bash
./build.sh          # Uses ACME (default)
make                # Also uses ACME
make ASSEMBLER=64tass   # Use 64tass instead
```

**Run in emulator:**
```bash
make run            # Builds and runs in x64sc (VICE emulator)
```

**Create disk image:**
```bash
make disk           # Creates qixy.d64 (requires c1541 from VICE)
make rundisk        # Build disk image and run in VICE
```

**Clean build artifacts:**
```bash
make clean
```

## Architecture & Memory Layout

### Core Game Structure
- **Single source file**: `qixy.asm` contains all game code
- **BASIC stub**: Starts at `$0801` with entry point at `$0810` (SYS 2064)
- **Assembler**: ACME is the primary/recommended assembler; 64tass is also supported

### Memory Map
- `$0801-$080F`: BASIC stub (SYS 2064)
- `$0810-$1FFF`: Game code and data
- `$2000-$27FF`: Custom character set (gameplay)
- `$2800-$2BFF`: Sprite data
- `$0400-$07E7`: Screen RAM (gameplay)
- `$D800-$DBE7`: Color RAM
- `$C000-$C07F`: Trail buffer X coordinates (max 128 segments)
- `$C080-$C0FF`: Trail buffer Y coordinates
- `$C100-$C1FF`: Flood fill stack X (256 entries)
- `$C200-$C2FF`: Flood fill stack Y (256 entries)
- `$C320-$C5EF`: Machine-detection + C128-acceleration module (code/data placed in the zero-fill RAM gap above the runtime buffers; costs no `.prg` bytes and is squeezed away by the disk cruncher)
- `$C600-$C63B`: High score table (5 entries, 12 bytes each)

### Title Screen (VIC Bank 1)
- `$5C00-$5FE7`: Screen RAM for title (1000 bytes)
- `$6000-$7F3F`: Bitmap data (8000 bytes)
- Title color data stored at TITLE_COLORS label, copied to `$D800` at runtime

### Gameplay Sprites (VIC Bank 1)
Gameplay runs in VIC Bank 1: bitmap at `$4000`, screen/colour at `$6000`, sprite pointers at `$63F8`. Sprite shapes are copied from the `$2800` bank-0 source up to `$6400+` once per game by `COPY_SPRITES_TO_BANK1`. Sprite slots:
- 144–147 (`$6400-$64FF`): player, main Qix, two Sparx
- 154–155 (`$6680-$66FF`): the 2 QIX2 plasma-star twinkle frames (`QIX2_FRAMES`, shipped under BASIC ROM in the `$BE6C` module tail; `INSTALL_QIX2_FRAMES` in the `$C320` module banks `$01=$36` around the copy)
- 156 (`$6700`): trapped-Qix explosion burst
- 157–160 (`$6740-$683F`): the 4 animated plasma-orb frames (`QIX_FRAMES`)
- Sprite 1 (main Qix) and, from L6+, sprite 4 (second Qix) run **multicolor** (`$D01C` bit set per-sprite) with shared MC0 = orange rim (`$D025`), MC1 = white-hot core (`$D026`). The multicolor bit is cleared at the title re-enable and, for sprite 4, during its hires explosion burst.

### Key Constants
- Playfield boundaries defined as FIELD_LEFT (1), FIELD_TOP (3), FIELD_RIGHT (38), FIELD_BOTTOM (23)
- Game uses zero page extensively (`$02-$44`) for performance-critical variables
- Hardware registers mapped to standard C64 addresses (VIC-II at `$D000`, SID at `$D400`, CIA at `$DC00/$DD00`)

## Graphics Pipeline

The title screen uses a custom asset generation workflow:

1. **Input**: PNG image (320x200) or auto-generated sample
2. **Conversion**: `tools/convert_title.py` converts to C64 multicolor bitmap format
3. **Output**: `title_data.asm` contains bitmap data, screen RAM, and color RAM
4. **Build**: Main `qixy.asm` includes `title_data.asm` at assembly time

Additional tools in `tools/`:
- `generate_title.py` - Generate title artwork programmatically
- `add_title_text.py` / `add_text_to_png.py` - Add text overlays to title images
- `add_credits_320.py` - Add credits text to 320x200 title image

**To update title graphics:**
```bash
cd tools
python convert_title.py title.png  # Or run without args for sample
cd ..
./build.sh
```

Note: `build.sh` also automatically creates a D64 disk image if `c1541` is available.

## Game Architecture

### State Machine
Game state controlled by GAME_STATE variable (`$1C`):
- 0 = title screen
- 1 = playing
- 2 = dying
- 3 = level complete
- 4 = game over
- 5 = high score entry
- 6 = high score display

### Core Systems
- **Player movement**: Joystick port 2 input, sprite-based with trail drawing. **Slow-draw vs fast-draw** (risk/reward): fire is required to *start* a draw; keeping fire held while drawing = a SLOW draw (half move speed via `DRAW_MOVE_THRESHOLD`, threshold 6 vs 3) whose enclosed area scores **2×**; releasing fire mid-draw = a FAST draw at normal speed and 1× score. The bonus only applies if the whole trail stayed slow (`DRAW_SLOW` flag, cleared on any fire-released step), latched at claim time into `CLAIM_SCORE_STEP` (1 or 2) which `ADD_CLAIM_SCORE` adds per claimed tile.
- **Enemy AI**: Qix (bouncing enemy) and Sparx (border patrol). The Sparx speed is level-scaled by `SET_SPARX_SPEED` using a fixed-point accumulator (`SPARX_RATE`/`SPARX_ACC`, like the Qix): the per-frame rate ramps smoothly from 64 (a move every 4 frames = original speed) at level 1 to 85 (every ~3 frames = the player's own pace) at level 25 via `SPARX_RATE_TBL`, then holds. So Sparx reach full speed only at level 25 and never outrun the player. A second Qix joins at L6+, a third (reverse) Sparx at L8+. **Sparx rendering**: an 8-point starburst (`SPARK_SHAPE`) drawn with VIC 2× hardware expansion on sprites 2/3/5 (`$D017`/`$D01D` bits set once in `INIT_SPRITES`; every other expand-reg write is a read-modify-write on bits 4/6, so the sparx bits persist), re-centred on the tile via `CALC_SPARX_X` (4px left; lives in the `$C320` module tail) and a Y offset of 48 instead of 50. Sparx walk borders and **settled** lines only — `SPARX_TRAIL_OK` (in the `$2460` block) rejects trail/corner chars (131–136, checked as a range) that are part of the line the player is drawing right now (scans `TRAIL_BUFFER` while `PLAYER_DRAWING` is set); the fuse, not the Sparx, is the threat on a stalled live line.
- **Qix rendering**: both Qixes are animated multicolor enemies sharing the palette MC0 = orange rim, MC1 = white-hot core. The **main Qix** is a round **plasma orb** with a spinning core bar (4 frames `QIX_FRAMES`, cycled by pointer every 4 frames in `UPDATE_SPRITES`), body colour cycling via `QIX_COLORS`. The **second Qix** (`DRAW_QIX2_ORB`) is a spiky 4-pointed **plasma star** with its own 2 frames (`QIX2_FRAMES`, slots 154-155): the star stretches tall then wide every 4 frames — a twinkling squash-and-stretch pulse — with a green/white body flash, dropping multicolor for its hires explosion burst. Regenerate frames with `tools/qix2gen.py`, don't hand-edit.
- **The fuse** (`UPDATE_FUSE`, called each playing frame after `UPDATE_PLAYER`): if you stop laying trail mid-draw for `FUSE_STALL_DELAY` (30) frames, a spark ignites at the trail start (index 0) and crawls toward your head one tile every `FUSE_ADVANCE_RATE` (6) frames; reaching the head calls `PLAYER_DEATH`. Laying any new tile snuffs it (`FUSE_SNUFF`). Rendered by recolouring the trail cell, flashing red (`$20`) / orange (`$80`) fire colours over the pink trail (`$A0`) via `SET_BITMAP_COLOR` (`FUSE_PAINT`) — deliberately distinct from the trail shimmer's white pulse; state at `$C6E8-$C6EC`.
- **Territory claiming**: Flood-fill algorithm runs incrementally to avoid frame drops. On **photo levels** (every 3rd level; `PHOTO_LEVEL` flag at `$61`), `PAINT_CLAIM_BITMAP` **reveals the level image** in claimed cells (see Level backgrounds below). On **starfield levels** it paints **textures**: a **fast** claim gets a pseudo-random material (`TEX_BRICK`/`GRID`/`SLATS`/`DOTS`/`CHECKER` — low byte picked once per claim in `COMPLETE_CLAIM` via `RANDOM` into `FILL_TEXTURE` = `$C6ED`, so the whole region shares one material) in its cycling `CLAIM_COLORS` hue over black; a **slow** (2×) draw gets the diagonal two-tone weave (`SLOW_PATTERN`) over the darker `CLAIM_COLORS_BG` partner, so the bonus is visible at a glance. All patterns share one page and are drawn by the self-modifying `FILL_BITMAP_CELL_PATTERN` (`A` = pattern low byte).
- **Playfield frame**: drawn once per level by `DRAW_PLAYFIELD` → `DRAW_BORDER_TILE` → `DRAW_BEVEL_CELL` as a raised **3-tone neon bezel** (white highlight on top/left, light-blue face, blue shadow on bottom/right) using a hires bevel pattern (`BEVEL_H`/`BEVEL_V`) plus per-edge 2-colour cells (`BEVEL_LIGHTCOL`/`BEVEL_DARKCOL`). Level backgrounds are interior-packed (36×19 cells), so they never overwrite the frame.
- **Level backgrounds — ghost & reveal (Volfied-style)**: `PAINT_LEVEL_INTERIOR` (in the under-BASIC module, called from `PREP_K` when the level-intro card times out) fills the interior per level. **Every 3rd level (3, 6, 9, 12, …) is a photo level** (`PHOTO_LEVEL=$61` set to 1): one of FOUR rotating images (`LEVEL` mod 12: 3 → `OVERLAY_LEVEL2_BG`, 6 → `OVERLAY_LEVEL4_BG`, 9 → `DECOMPRESS_LEVEL10_BG`, 0 → the **knekkebrød email**, which is TYPESET AT RUNTIME by `KNEKKE_K` — no image data: the painter + strings ship at `$C000-$C2FF` in the prg's boot-trash window and are copied to `$F80C` under the KERNAL by `INSTALL_KNEKKE` at boot, then run at `$01=$35`; the source `knekkebrød.jpeg` is a text document that 288×152 pixels cannot photograph legibly. Note: `CARD_PRINT` strings are `$00`-terminated, so a literal `@` (screen code 0) must be drawn as a lone glyph. Because a ghost of TEXT would be readable before any claiming, knekke levels set `PHOTO_LEVEL=2` and `PREP_K` covers the field with the **starfield** instead of the ghost — the email only exists in the stages until revealed), after which `STASH_K` copies every interior cell (8 bitmap bytes + colour) to the stages (`BITMAP_STAGE=$E000`, `COLOR_STAGE=$F560` — RAM under the KERNAL; stores write through the ROM, reads run at `$01=$35` inside the stubs' `sei` window, while the prep path uses `$36` since the overlays `cli` internally; the module code sits at `$BE6C`, in the true ~420-byte gap after the level-4 image data which ends at `$BE5B`) and **ghosts** the field to `$B0` (dark-grey etching over black). **Claiming a cell reveals it**: `PAINT_CLAIM_BITMAP` branches to `REVEAL_K` on photo levels, restoring the staged bitmap+colour — the capture flash resolves into the picture (restoring the bitmap is essential: the flash paints cells solid `$FF` first; it also heals trail/fuse scribbles). The stash reads the painted screen, so it is source-agnostic (works for the RLE level-10 image too). The prep runs with the display blanked (`PREP_K`) so the image never flashes un-ghosted, and on level complete `REVEAL_ALL` floods the whole interior with the finished image under the banner (the payoff). **All other levels** get `DRAW_STARFIELD` — a sparse faint dot field (dim grey dots over black; 4-entry `STAR_PATTERNS` with a 5-in-8 empty remap) — and keep the classic claim **textures**. Starfield code/data live in the `$3880` gap. Gotcha that bit here: the `mod` subtract-loops exit on `CMP` flags — re-test A (`tax`) before branching on Z.
- **Collision detection**: Monitors trail intersections and sprite overlaps
- **Audio**: SID chip sound effects with music state machine (normal and sad/game-over modes)
- **Scoring**: Multi-byte score tracking (1 pt/claimed tile, or 2 for a slow draw — see Player movement) with percentage-based level progression. Clearing a level awards a completion bonus of `(LEVEL + overshoot) × 100` points (`ADD_LEVEL_BONUS`), where overshoot = how many % past the target you finished — rewarding both higher levels and a big saved-for-last claim — **plus a time bonus** of 10 points per second left on the level timer (`ADD_TIME_BONUS`, fall-through tail of `ADD_LEVEL_BONUS`; latches `TIME_BONUS` for the banner, adds via `ADD_CLAIM_SCORE` with a borrowed step of 10). `DRAW_CLEAR_CARD` shows both lines ("BONUS 0900" / "TIME BONUS 350"); the cheat skip awards neither. The bonus code lives in the **$CE00 window** ($CE00-$CE5F), reclaimed by moving the pause underlay scratch (`PAUSE_SAVE`) to the unused cassette buffer `$033C-$0395`; the `TIMEB_TXT` string sits in the $3B00 block where `ADD_LEVEL_BONUS` used to be. Clear target starts at 70% and rises +2%/level to a 90% cap (`TARGET_PERCENT`). Levels are **endless** — `LEVEL` keeps climbing past 10 (no wrap). Both enemy speeds ramp over levels 1→25 and hold there: Qix via `QIX_SPEED_TBL` (rate 11→64 = 0.17→1.0 tile/frame, `SET_QIX_SPEED`), Sparx via `SPARX_RATE_TBL`.
- **Level timer**: 60 seconds (`TIMER_SECONDS`) to clear each level or lose a life. Read-out is `TIME: NN` in HUD row 0 (label at col 14, bold LED-inset digits at cols 20-21), white normally, **red once ≤10 s remain**. Ticks only in the playing state (pause, death, intro card all freeze it); one second = 50 frames PAL / 60 NTSC via `VIDEO_STD`. Reset to 60 by `INIT_LEVEL` and on respawn (both via `RESET_TIMER_HUD`); at zero `UPDATE_TIMER` draws the red `00` and jumps to `PLAYER_DEATH`. Core (vars `TIME_LEFT`/`TIME_SUB` + tick) lives in the `$C320` module tail; the per-second two-digit redraw (`DRAW_TIMER`) and colour helper sit in the `$2C00` segment. The main loop reaches the tick via the `SCORE_LIFE_AND_TIMER` trampoline — the `@playing` block's state-dispatch branches are at the edge of branch range, so no bytes can be added to that block directly.
- **Lives**: start with 3. Extra lives are awarded both for a single claim covering ≥50% of the field *and* every 5000 points (`CHECK_SCORE_LIFE`, threshold in `NEXTLIFE_LO/MID/HI`). Post-start/respawn invincibility is `GRACE_TIMER` = 60 frames (~1s).
- **High scores**: Persistent high score table with name entry (5 entries stored at `$C600`)
- **Machine detection** (`DETECT_MACHINE`, runs once at startup): identifies the host and stores the result in `MACHINE_TYPE`/`VIDEO_STD`, shown as a line under the high-score credits (e.g. `C128 - PAL`):
  - **Video standard**: PAL vs NTSC via VIC raster-line count
  - **C64 vs C128**: the VIC-IIe extra registers `$D02F`/`$D030` read `$FF` on a plain C64; both must be implemented to read as a C128
  - **Ultimate**: the UCI identification register `$DF1D` reads `$C9` (open-bus `$DF` on a real C64). A bounded UCI `GET_HWINFO` handshake (`$04 $28 $00`) then reads the ASCII model name and scans for "64" to tell an Ultimate 64 from an Ultimate-II+ cartridge

### Performance Considerations
- Fill operations run incrementally; the per-frame op counts are runtime variables (`FLOOD_OPS`/`SCAN_OPS`) seeded each boot from the C64 defaults (`FLOOD_OPS_PER_FRAME = 8`, `SCAN_OPS_PER_FRAME = 32`)
- Fill state machine has 6 phases: inactive, trail conversion, flood fill, claim, restore, calculate percentage
- Keeps game responsive during expensive flood-fill calculations
- Tuned for ~20000 cycles per frame on C64 hardware

### C128 2 MHz Acceleration
When `DETECT_MACHINE` finds a C128, `INIT_CPU_SPEED` enables it (gated entirely on `MACHINE_TYPE == 1`; C64/Ultimate hosts are byte-for-byte unchanged):
- **Clean 2 MHz**: a raster IRQ (`IRQ_C128_RASTER`, chained in front of the KERNAL handler via `$0314`) switches the CPU to 2 MHz over the border/vertical-blank and back to 1 MHz for the visible display. 2 MHz during active display corrupts the VIC-II picture, so it is only used where the VIC is not fetching (lines `RASTER_2MHZ_ON = 251` .. `RASTER_2MHZ_OFF = 40`). CIA interrupts pass through to the KERNAL, so keyboard/jiffy are unaffected.
- **Faster fills**: the reclaimed ~1/3-frame of CPU is spent on higher incremental-fill rates (`C128_FLOOD_OPS = 128`, `C128_SCAN_OPS = 224`) so territory claims complete in a few frames. These two constants are the dial — lower them if a real C128 hitches during large claims at high levels.
- Note: assumes the SID stays clocked at ~1 MHz on the C128 in fast mode (consensus; why C128 BASIC `FAST` keeps sound correct). The 2 MHz effect itself needs a real C128 to confirm — VICE's x64sc has no VIC-IIe 2 MHz mode.

## Important Editing Guidelines

**When modifying assembly:**
1. Always run `./build.sh` to verify the code assembles
2. Use `make run` to test changes in VICE emulator
3. Do not change BASIC stub or start address without updating README and Makefile
4. Respect the documented memory map - addresses are tightly coupled to game logic

**When changing graphics:**
1. Edit `title_data.asm` directly or regenerate from PNG
2. Run `tools/convert_title.py` if creating new title screen
3. Rebuild with `./build.sh`
4. Verify with `make run`

**Assembler-specific notes:**
- Code uses ACME syntax (default)
- ca65 requires pre-converted source (`qixy_ca65.asm`) - do not auto-convert
- 64tass supported via Makefile but may have syntax differences

## Testing & Debugging

Use VICE emulator (`x64sc`) with debug features:
1. Build: `./build.sh`
2. Run: `make run`
3. Use VICE's monitor (Alt+H) for breakpoints and memory inspection
4. Check assembler output for address conflicts or size issues
