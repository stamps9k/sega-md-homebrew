; =============================================================================
; vdp.s — VDP hardware register addresses and initialisation routines
;
; initVdp writes vdpRegTable to the VDP control port with the display held
; off (REG1 bit 6 = 0), configuring plane/window/sprite table locations,
; H40 mode, and auto-increment.
;
; clearVdpRam clears all 64KB of VRAM and zeroes VSRAM (plane A/B vscroll),
; then re-enables the display (REG1 -> $8174) as its final step. Display is
; held off specifically for the VRAM clear itself, since it's 32768 words --
; doing that with the display on would spend the whole clear racing active
; scan for no reason.
;
; Display is back ON by the time clearVdpRam returns, i.e. before any
; scene's own init runs (see main.s). Any VDP work after this point --
; an effect's init, update, or render routine -- is therefore running with
; the display already on, and is responsible for completing its own
; VRAM/CRAM/nametable writes within a single VBlank window on its own.
; There's no display-off safety net past this point. Writes that spill
; into active scan don't corrupt VRAM (the FIFO stalls the CPU instead of
; losing data -- see key learnings) but they do show up as a visible
; glitch on screen for that frame. Keep this budget in mind as later
; milestones add heavier per-frame VDP writes (sprites, scrolling,
; combined effects) -- large transfers should use DMA and/or be checked
; against the VBlank window rather than assumed to fit.
; =============================================================================

	section	.text

	xdef	VDP_DATA
	xdef	VDP_CTRL
	xdef	CRAM_WRITE_CMD

	xdef	clearVdpRam
	xdef	initVdp

; -----------------------------------------------------------------------------
; Hardware register addresses
; -----------------------------------------------------------------------------
VDP_DATA        equ $C00000     ; VDP data port (word/longword access)
VDP_CTRL        equ $C00004     ; VDP control port
CRAM_WRITE_CMD  equ $C0000000		; CRAM write command (longword to control port). Sets VDP to write to CRAM starting at address 0

; -----------------------------------------------------------------------------
; initVdp
; Writes vdpRegTable to the VDP control port, configuring plane/window/sprite
; table locations, H40 mode, and auto-increment. REG1 in the table is set to
; display OFF -- the display is not enabled here; clearVdpRam turns it on
; once VRAM has been cleared.
; -----------------------------------------------------------------------------
initVdp:
	lea     vdpRegTable,a0
	move.w  #(vdpRegTableEnd-vdpRegTable)/2-1,d0
.loop:
	move.w  (a0)+,VDP_CTRL
	dbra    d0,.loop
.cleanUp:
	rts

; -----------------------------------------------------------------------------
; clearVdpRam
; Clears all 64KB of VRAM and zeroes VSRAM (plane A/B vscroll), then
; re-enables the display (REG1 -> $8174) as its final step. Display is held
; off only for the clear itself (32768 words -- too large to do with the
; display on). By the time this returns, the display is ON, so anything
; that runs after it (an effect's init/update/render) has no display-off
; safety net and must complete its own VDP writes within a single VBlank
; (see file header).
; -----------------------------------------------------------------------------
clearVdpRam:
.disableDis:
	move.w  #$8134,VDP_CTRL				; REG1: display off, V-int on, DMA on, Mode 5

	; Send VRAM write command for address $0000
	move.l  #$40000000,VDP_CTRL
	move.w  #$0000,d0           ; Value to write (blank tile)
	
	move.w  #$7FFF,d1           ; 32768 words = 65536 bytes = full VRAM
.clearVram:
	move.w  d0,VDP_DATA
	dbra    d1,.clearVram

	; Send VSRAM write command for address $0000
	move.l  #$40000010,VDP_CTRL   ; point VDP at VSRAM $0000
	move.w  #$0000,VDP_DATA       ; plane A vscroll = 0 (address auto-increments to $0002)
	move.w  #$0000,VDP_DATA       ; plane B vscroll = 0

.cleanUp:
	move.w  #$8174,VDP_CTRL				; REG1: display on, V-int on, DMA on, Mode 5
	rts

; -----------------------------------------------------------------------------
; VDP register table
; Written during initialisation with display disabled (REG1 bit 6 = 0).
; We enable the display separately at the end.
; -----------------------------------------------------------------------------
vdpRegTable:
	dc.w    $8004   ; REG  0: mode 1 — no H-int, no HV latch
	dc.w    $8134   ; REG  1: mode 2 — display OFF, V-int on, DMA on, Mode 5
	dc.w    $8230   ; REG  2: plane A name table -> VRAM $C000
	dc.w    $8328   ; REG  3: window name table  -> VRAM $A000
	dc.w    $8407   ; REG  4: plane B name table -> VRAM $E000
	dc.w    $855C   ; REG  5: sprite table       -> VRAM $B800
	dc.w    $8600   ; REG  6: unused
	dc.w    $8700   ; REG  7: background = palette 0, colour 0
	dc.w    $8800   ; REG  8: unused (H scroll)
	dc.w    $8900   ; REG  9: unused
	dc.w    $8A00   ; REG 10: H-interrupt counter (disabled)
	dc.w    $8B00   ; REG 11: mode 3 — full scroll, no ext int
	dc.w    $8C81   ; REG 12: mode 4 — H40 (320px wide), no interlace
	dc.w    $8D2F   ; REG 13: H-scroll table     -> VRAM $BC00
	dc.w    $8E00   ; REG 14: unused
	dc.w    $8F02   ; REG 15: auto-increment = 2 bytes
	dc.w    $9001   ; REG 16: scroll size 64x32 tiles
	dc.w    $9100   ; REG 17: window H position
	dc.w    $9200   ; REG 18: window V position
vdpRegTableEnd: