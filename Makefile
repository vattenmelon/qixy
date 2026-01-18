# QIXY - Makefile for building Commodore 64 Qix Clone
# Supports ACME, 64tass, and ca65 assemblers

# Default assembler (change to your preference)
ASSEMBLER ?= acme

# Output file
OUTPUT = qixy.prg
SOURCE = qixy.asm

# D64 disk image
DISKIMAGE = qixy.d64

# VICE emulator
VICE = x64sc
VICE_OPTS = -autostartprgmode 1

.PHONY: all clean run disk

all: $(OUTPUT)

# Build with ACME
ifeq ($(ASSEMBLER),acme)
$(OUTPUT): $(SOURCE)
	acme -f cbm -o $(OUTPUT) $(SOURCE)
endif

# Build with 64tass
ifeq ($(ASSEMBLER),64tass)
$(OUTPUT): $(SOURCE)
	64tass -C -a -o $(OUTPUT) $(SOURCE)
endif

# Build with ca65/cl65 (requires conversion of syntax)
ifeq ($(ASSEMBLER),ca65)
$(OUTPUT): qixy_ca65.asm
	cl65 -t c64 -o $(OUTPUT) qixy_ca65.asm
endif

# Create D64 disk image (requires c1541 from VICE)
disk: $(OUTPUT)
	c1541 -format "qixy,qx" d64 $(DISKIMAGE)
	c1541 -attach $(DISKIMAGE) -write $(OUTPUT) "qixy,prg"
	@echo "Created $(DISKIMAGE)"

# Run in VICE emulator
run: $(OUTPUT)
	$(VICE) $(VICE_OPTS) $(OUTPUT)

# Run from disk image
rundisk: disk
	$(VICE) $(VICE_OPTS) -8 $(DISKIMAGE)

# Clean build artifacts
clean:
	rm -f $(OUTPUT) $(DISKIMAGE) *.o

# Help
help:
	@echo "QIXY Build System"
	@echo ""
	@echo "Targets:"
	@echo "  all      - Build the PRG file (default)"
	@echo "  disk     - Create a D64 disk image"
	@echo "  run      - Build and run in VICE"
	@echo "  rundisk  - Build disk image and run in VICE"
	@echo "  clean    - Remove build artifacts"
	@echo ""
	@echo "Variables:"
	@echo "  ASSEMBLER - Set assembler: acme (default), 64tass, ca65"
	@echo ""
	@echo "Examples:"
	@echo "  make                      # Build with ACME"
	@echo "  make ASSEMBLER=64tass     # Build with 64tass"
	@echo "  make run                  # Build and run in VICE"
	@echo "  make disk                 # Create D64 for real hardware"
