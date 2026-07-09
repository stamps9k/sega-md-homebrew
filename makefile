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

SRCS := $(wildcard src/*.s src/assets/*.s src/core/*.s src/scenes/*.s src/lib/*.s)
BUILD_OBJS := $(patsubst src/%.s,build/%.o,$(SRCS))

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

build/%.o: src/%.s
	@mkdir -p $(@D)
	$(AS) $(ASFLAGS) -o $@ $<

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
	test -f rom.ld && rm -rf ./build/* ./pkg/*