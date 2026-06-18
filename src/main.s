; =============================================================================
; main.s — Hello World: initialise the VDP and set a background colour
;
; Proper hardware initialisation order:
;   1. Disable interrupts
;   2. Initialise TMSS (stops the Mega Drive logo lockout chip)
;   3. Take the Z80 bus and hold reset (prevents Z80 interfering with VDP)
;   4. Initialise VDP registers
;   5. Clear VRAM
;   6. Set background colour in CRAM
;   7. Enable display
;   8. Loop forever
; =============================================================================

; -----------------------------------------------------------------------------
; Hardware register addresses
; -----------------------------------------------------------------------------
VDP_DATA        equ $C00000     ; VDP data port (word/longword access)
VDP_CTRL        equ $C00004     ; VDP control port
Z80_BUS         equ $A11100     ; Z80 bus request register
Z80_RESET       equ $A11200     ; Z80 reset register
TMSS_SEGA       equ $A14000     ; TMSS "SEGA" register
TMSS_MODE       equ $A14100     ; TMSS mode register
VERSION_REG     equ $A10001     ; Hardware version register

; CRAM write command (longword to control port)
; Sets VDP to write to CRAM starting at address 0
CRAM_WRITE_CMD  equ $C0000000

    xdef    EntryPoint

EntryPoint:

    ; -------------------------------------------------------------------------
    ; 1. Disable all interrupts at the CPU level
    ; -------------------------------------------------------------------------
    move.w  #$2700,SR

    ; -------------------------------------------------------------------------
    ; 2. TMSS initialisation
    ; The TMSS (Trademark Security System) is present on later hardware
    ; revisions. We check the version register — if bit 0 is set, TMSS is
    ; present and we must write "SEGA" to $A14000 to unlock the VDP.
    ; Skipping this on a TMSS machine causes VDP access to be blocked entirely.
    ; -------------------------------------------------------------------------
    move.b  VERSION_REG,D0      ; Read hardware version
    andi.b  #$0F,D0             ; Mask to version nibble
    beq     .noTMSS             ; Version 0 = no TMSS
    move.l  #'SEGA',TMSS_SEGA  ; Write "SEGA" to unlock VDP
.noTMSS:

    ; -------------------------------------------------------------------------
    ; 3. Take the Z80 bus
    ; While the Z80 is running it can interfere with VDP access.
    ; We request the bus and hold the Z80 in reset during initialisation.
    ; -------------------------------------------------------------------------
    move.w  #$0100,Z80_BUS      ; Request Z80 bus
    move.w  #$0100,Z80_RESET    ; Assert Z80 reset

.waitZ80:
    btst    #8,Z80_BUS          ; Wait until bus request is acknowledged
    bne     .waitZ80

    ; -------------------------------------------------------------------------
    ; 4. Initialise VDP registers
    ; Write each register value from our table to the VDP control port.
    ; -------------------------------------------------------------------------
    lea     VDPRegTable,A0
    move.w  #(VDPRegTableEnd-VDPRegTable)/2-1,D0

.initVDP:
    move.w  (A0)+,VDP_CTRL
    dbra    D0,.initVDP

    ; -------------------------------------------------------------------------
    ; 5. Clear VRAM
    ; Set VDP to auto-increment by 2, then write $0000 across all 64KB of VRAM.
    ; Without this, garbage tile data can corrupt the display even when the
    ; background colour is set correctly.
    ; -------------------------------------------------------------------------

    ; Send VRAM write command for address $0000
    move.l  #$40000000,VDP_CTRL

    move.w  #$0000,D0           ; Value to write (blank tile)
    move.w  #$7FFF,D1           ; 32768 words = 65536 bytes = full VRAM

.clearVRAM:
    move.w  D0,VDP_DATA
    dbra    D1,.clearVRAM

    ; -------------------------------------------------------------------------
    ; 6. Set background colour in CRAM
    ; CRAM entry 0 (palette 0, colour 0) is the background colour.
    ; Mega Drive colour format: 0000 BBB0 GGG0 RRR0
    ; We write a solid blue: B=7, G=0, R=0 = $0E00
    ; -------------------------------------------------------------------------
    move.l  #CRAM_WRITE_CMD,VDP_CTRL   ; CRAM write, address 0
    move.w  #$0E00,VDP_DATA            ; Blue: B=7 ($E), G=0, R=0

    ; -------------------------------------------------------------------------
    ; 7. Enable the display
    ; Set bit 6 of VDP register 1 to turn the display on.
    ; We set it last so nothing is visible during initialisation.
    ; -------------------------------------------------------------------------
    move.w  #$8174,VDP_CTRL     ; REG1: display on, V-int on, DMA on, Mode 5

    ; -------------------------------------------------------------------------
    ; 8. Loop forever
    ; -------------------------------------------------------------------------
.halt:
    bra     .halt

; -----------------------------------------------------------------------------
; VDP register table
; Written during initialisation with display disabled (REG1 bit 6 = 0).
; We enable the display separately at the end.
; -----------------------------------------------------------------------------
VDPRegTable:
    dc.w    $8004   ; REG  0: mode 1 — no H-int, no HV latch
    dc.w    $8134   ; REG  1: mode 2 — display OFF, V-int on, DMA on, Mode 5
    dc.w    $8230   ; REG  2: plane A name table -> VRAM $C000
    dc.w    $8328   ; REG  3: window name table  -> VRAM $A000
    dc.w    $8407   ; REG  4: plane B name table -> VRAM $E000
    dc.w    $8500   ; REG  5: sprite table       -> VRAM $0000
    dc.w    $8600   ; REG  6: unused
    dc.w    $8700   ; REG  7: background = palette 0, colour 0
    dc.w    $8800   ; REG  8: unused (H scroll)
    dc.w    $8900   ; REG  9: unused
    dc.w    $8A00   ; REG 10: H-interrupt counter (disabled)
    dc.w    $8B00   ; REG 11: mode 3 — full scroll, no ext int
    dc.w    $8C81   ; REG 12: mode 4 — H40 (320px wide), no interlace
    dc.w    $8D2E   ; REG 13: H-scroll table     -> VRAM $B800
    dc.w    $8E00   ; REG 14: unused
    dc.w    $8F02   ; REG 15: auto-increment = 2 bytes
    dc.w    $9001   ; REG 16: scroll size 64x32 tiles
    dc.w    $9100   ; REG 17: window H position
    dc.w    $9200   ; REG 18: window V position
VDPRegTableEnd: