# QIXY - A Modern Qix Clone for Commodore 64

A faithful recreation of the classic arcade game Qix, designed for the Commodore 64 with a modern aesthetic featuring colorful neon graphics and smooth gameplay.

## Gameplay

In QIXY, you control a marker that moves around a rectangular playfield. Your goal is to claim territory by drawing lines that section off portions of the field. But beware - enemies are hunting you!

### Controls
- **Joystick (Port 2)**: Move in any direction
- **Fire Button**: Hold to draw lines in unclaimed territory

### Enemies
- **Qix**: The main enemy that bounces around inside the unclaimed area. If it touches your trail while you're drawing, you lose a life!
- **Sparx**: Two enemies that patrol the borders. Avoid them at all costs!

### Objective
Claim at least 75% of the playfield to advance to the next level. The more you claim, the higher your score!

## Building

### Requirements
You need one of the following 6502 cross-assemblers:
- **ACME** (recommended): https://sourceforge.net/projects/acme-crossass/
- **64tass**: http://tass64.sourceforge.net/

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

### Creating a D64 Disk Image
For use with SD2IEC, Ultimate 64, or other hardware:

```bash
# Requires c1541 from VICE
make disk
```

This creates `qixy.d64` which can be transferred to real hardware.

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

- **Platform**: Commodore 64 (PAL/NTSC compatible)
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

### Features
- Smooth sprite-based player and enemies
- Animated color cycling (modern neon aesthetic)
- SID sound effects
- Multiple levels with increasing difficulty
- Score tracking with lives system
- Flood-fill based territory claiming

## Files

- `qixy.asm` - Main source code
- `Makefile` - Build automation
- `build.sh` - Shell build script
- `README.md` - This file

## License

This is a fan-made recreation for educational and entertainment purposes.
Original Qix game copyright Taito Corporation.

## Credits

- Programming: Claude Code
- Original Game Design: Taito Corporation (1981)
