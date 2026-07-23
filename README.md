# [Project Name] — Mega Drive / Genesis Demoscene ROM

An interactive Sega Mega Drive / Genesis demoscene-style ROM, written in raw
68000 assembly. This is not a game and does not use SGDK — it's a hand-built
demo where the controller lets the user tweak graphics and rotate between
effects.

## Status

| Milestone | Description                          | Status        |
|-----------|---------------------------------------|---------------|
| 0         | Scene manager / joypad handling        | ✅ Complete    |
| 1         | Waterfall palette-cycling              | ✅ Complete    |
| 2         | Text / credits                         | ✅ Complete    |
| 3         | Raster effect via HBlank (OutRun road) | 🚧 In progress |
| 4         | Sprites                                | ⬜ Planned     |
| 5         | Scrolling planes                       | ⬜ Planned     |
| 6         | Combined effects                       | ⬜ Planned     |

## Toolchain

- **Assembler:** `vasmm68k_mot` (Motorola syntax, v2.0)
- **Linker / objcopy:** `m68k-elf-ld`, `m68k-elf-objcopy` (binutils v2.46.1)
- **Build environment:** Docker (Alpine 3.24), custom `Makefile`, `rom.ld` linker script
- **Primary emulator/debugger:** BlastEm
- **Cross-verification emulator:** Genesis Plus GX (via RetroArch)

## Project Structure

```
src/
  core/        engine-level systems (scene manager, HBlank dispatch, etc.)
  scenes/      per-scene content (outrun.s, etc.)
  lib/         shared reusable routines
  include/     shared constants / macros
assets/        raw art, tile, and palette data
build/         intermediate objects (generated, not committed)
pkg/           final ROM output (generated, not committed)
```

## Coding Standards

All conventions for naming, formatting, file structure, linkage, and review
process are formally documented in **[CODING_STANDARDS.md](./CODING_STANDARDS.md)**.
This is the enforced standard for the project — code review checks against it
directly, and any exception should update the doc rather than diverge silently
from it.

## Key References

- [plutiedev.com](https://plutiedev.com)
- [SpritesMind.Net](https://www.spritesmind.net)
- Charles MacDonald's `genvdp.txt`
- M68000 Programmer's Reference Manual (NXP)

## Hardware Notes (Deferred / Future Work)

- Cold-boot RAM-zeroing assumptions are not yet handled — real hardware does
  not guarantee zeroed RAM at boot, and this needs explicit `clr` passes
  before real-hardware testing is viable.
- Testing on real hardware is a future milestone; development and
  verification currently rely on BlastEm and Genesis Plus GX.