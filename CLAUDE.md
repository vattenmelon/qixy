# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

QIXY is a Commodore 64 game written in 6502 assembly language - a modern recreation of the classic arcade game Qix. The entire game is contained in a single assembly source file (`qixy.asm`) that compiles to a `.prg` executable.

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
- `$C000-$C0FF`: Trail buffer (safe location above BASIC)
- `$C100-$C1FF`: Game field state buffer

### Title Screen (VIC Bank 1)
- `$5C00-$5FE7`: Screen RAM for title (1000 bytes)
- `$6000-$7F3F`: Bitmap data (8000 bytes)
- Title color data stored at TITLE_COLORS label, copied to `$D800` at runtime

### Key Constants
- Playfield boundaries defined as FIELD_LEFT (1), FIELD_TOP (3), FIELD_RIGHT (38), FIELD_BOTTOM (22)
- Game uses zero page extensively (`$02-$42`) for performance-critical variables
- Hardware registers mapped to standard C64 addresses (VIC-II at `$D000`, SID at `$D400`, CIA at `$DC00/$DD00`)

## Graphics Pipeline

The title screen uses a custom asset generation workflow:

1. **Input**: PNG image (320x200) or auto-generated sample
2. **Conversion**: `tools/convert_title.py` converts to C64 multicolor bitmap format
3. **Output**: `title_data.asm` contains bitmap data, screen RAM, and color RAM
4. **Build**: Main `qixy.asm` includes `title_data.asm` at assembly time

**To update title graphics:**
```bash
cd tools
python convert_title.py title.png  # Or run without args for sample
cd ..
./build.sh
```

## Game Architecture

### State Machine
Game state controlled by GAME_STATE variable:
- 0 = title screen
- 1 = playing
- 2 = dying
- 3 = level complete
- 4 = game over

### Core Systems
- **Player movement**: Joystick port 2 input, sprite-based with trail drawing
- **Enemy AI**: Qix (bouncing enemy) and Sparx (border patrol)
- **Territory claiming**: Flood-fill algorithm runs incrementally to avoid frame drops
- **Collision detection**: Monitors trail intersections and sprite overlaps
- **Audio**: SID chip sound effects with music state machine
- **Scoring**: Multi-byte score tracking with percentage-based level progression (75% target)

### Performance Considerations
- Fill operations run incrementally (8 stack ops per frame, 32 scan ops per frame)
- Keeps game responsive during expensive flood-fill calculations
- Tuned for ~20000 cycles per frame on C64 hardware

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
