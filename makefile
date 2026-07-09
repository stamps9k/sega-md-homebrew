# =============================================================================
# Makefile — Megadrive Hello World
#
# Produces: hello.bin — a raw Megadrive ROM image
#
# Tools (must be on PATH inside the container):
#   vasmm68k_mot  — assembler
#   m68k-elf-ld   — linker
#   m68k-elf-objcopy — strip ELF to raw binary
# =============================================================================

TARGET      = hello

SRCS        = header.s main.s vdp.s state.s joypad.s scene_manager.s color_cycle.s waterfall.s credits.s dhepper.s text.s
OBJS        = $(SRCS:.s=.o)
BUILD_OBJS  = $(addprefix build/,$(OBJS))

AS          = vasmm68k_mot
LD          = m68k-elf-ld
OBJCOPY     = m68k-elf-objcopy

# -Felf       : output ELF object files
# -m68000     : target the base 68000 (no extensions)
# -opt-fconst : optimise PC-relative references
ASFLAGS     = -Felf -m68000 -opt-fconst

# Linker script places everything at the correct ROM addresses
LDFLAGS     = -T rom.ld

.PHONY: all clean

all: $(TARGET).bin

# Assemble each source file to an ELF object
build/%.o: src/%.s | build
	$(AS) $(ASFLAGS) -o $@ $<

# Ensure the build directory exists before assembling
build:
	mkdir -p build

# Link all objects into a single ELF
$(TARGET).elf: $(BUILD_OBJS) | pkg
	$(LD) $(LDFLAGS) -o pkg/$@ $^ -Map=build/output.map

# Ensure the pkg directory exists before assembling
pkg:
	mkdir -p pkg

# Strip ELF headers to produce a raw binary ROM
$(TARGET).bin: $(TARGET).elf
	$(OBJCOPY) -O binary pkg/$< pkg/$@
	@echo ""
	@echo "Built pkg/$(TARGET).bin ($$(wc -c < pkg/$(TARGET).bin | tr -d ' ') bytes)"

# Dump build for debugging
dis: $(TARGET).elf
	m68k-elf-objdump -d pkg/$(TARGET).elf > build/dis.txt

clean:
	rm -f $(BUILD_OBJS) build/dis.txt build/output.map pkg/$(TARGET).elf pkg/$(TARGET).bin