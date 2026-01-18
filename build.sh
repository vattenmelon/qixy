#!/bin/bash
# QIXY Build Script for Commodore 64
# Usage: ./build.sh [assembler]
# Assemblers: acme (default), 64tass

ASSEMBLER=${1:-acme}
SOURCE="qixy.asm"
OUTPUT="qixy.prg"

echo "Building QIXY with $ASSEMBLER..."

case $ASSEMBLER in
    acme)
        if command -v acme &> /dev/null; then
            acme -f cbm -o "$OUTPUT" "$SOURCE"
        else
            echo "Error: ACME assembler not found"
            echo "Install with: brew install acme (macOS) or apt install acme (Linux)"
            exit 1
        fi
        ;;
    64tass)
        if command -v 64tass &> /dev/null; then
            64tass -C -a -o "$OUTPUT" "$SOURCE"
        else
            echo "Error: 64tass assembler not found"
            echo "Install from: http://tass64.sourceforge.net/"
            exit 1
        fi
        ;;
    *)
        echo "Unknown assembler: $ASSEMBLER"
        echo "Supported: acme, 64tass"
        exit 1
        ;;
esac

if [ -f "$OUTPUT" ]; then
    echo "Build successful: $OUTPUT"
    ls -la "$OUTPUT"

    # Create D64 disk image if c1541 is available
    if command -v c1541 &> /dev/null; then
        echo ""
        echo "Creating D64 disk image..."
        c1541 -format "qixy,qx" d64 qixy.d64
        c1541 -attach qixy.d64 -write "$OUTPUT" "qixy,prg"
        echo "Disk image created: qixy.d64"
    fi
else
    echo "Build failed!"
    exit 1
fi
