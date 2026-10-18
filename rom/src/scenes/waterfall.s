; ==============================================================================
; waterfall.s
;
; Milestone 1 effect: vertical gradient tile with continuous
; palette rotation to simulate a flowing waterfall.
;
; init    - loads gradient tile(s) and tilemap into VRAM,
;           sets initial palette
; update  - rotates the waterfall's CRAM palette range
; render  - (likely empty/minimal; rotation is the visual)
; ==============================================================================

	; ----------------------------------------------------------------------------
	; External definitions
	; ----------------------------------------------------------------------------
	xdef	waterfallInit
	xdef	waterfallUpdate
	xdef	waterfallRender

	; ----------------------------------------------------------------------------
	; External references
	; ----------------------------------------------------------------------------
	; from state.s
	xref	waterfall_state

	; from vdp.s
	xref	CRAM_WRITE_CMD
	xref	VDP_CTRL
	xref	VDP_DATA

	section .rodata

; ------------------------------------------------------------------------------
; waterfallTile
;
; Single 8x8 tile defining the vertical gradient strip used by
; the waterfall effect. Each row is a flat band using one
; palette index, so the gradient runs top-to-bottom across the
; tile. Palette rotation in waterfallUpdate cycles these eight
; indices each frame, making the static rows appear to flow
; downward.
;
; Row 0 (top)    -> index 1 (lightest/foam)
; Row 7 (bottom) -> index 8 (darkest)
; ------------------------------------------------------------------------------
waterfallTile:
	; Tile 0
	dc.l		$11111111							; row 0 - index 1
	dc.l		$22222222							; row 1 - index 2
	dc.l		$33333333							; row 2 - index 3
	dc.l		$44444444							; row 3 - index 4
	dc.l		$55555555							; row 4 - index 5
	dc.l		$66666666							; row 5 - index 6
	dc.l		$77777777							; row 6 - index 7
	dc.l		$88888888							; row 7 - index 8

	; Tile 1
	dc.l		$88888888							; row 7 - index 8
	dc.l		$11111111							; row 0 - index 1
	dc.l		$22222222							; row 1 - index 2
	dc.l		$33333333							; row 2 - index 3
	dc.l		$44444444							; row 3 - index 4
	dc.l		$55555555							; row 4 - index 5
	dc.l		$66666666							; row 5 - index 6
	dc.l		$77777777							; row 6 - index 7

	;	Tile 2
	dc.l		$77777777							; row 6 - index 7
	dc.l		$88888888							; row 7 - index 8
	dc.l		$11111111							; row 0 - index 1
	dc.l		$22222222							; row 1 - index 2
	dc.l		$33333333							; row 2 - index 3
	dc.l		$44444444							; row 3 - index 4
	dc.l		$55555555							; row 4 - index 5
	dc.l		$66666666							; row 5 - index 6

	;	Tile 3
	dc.l		$66666666							; row 5 - index 6
	dc.l		$77777777							; row 6 - index 7
	dc.l		$88888888							; row 7 - index 8
	dc.l		$11111111							; row 0 - index 1
	dc.l		$22222222							; row 1 - index 2
	dc.l		$33333333							; row 2 - index 3
	dc.l		$44444444							; row 3 - index 4
	dc.l		$55555555							; row 4 - index 5

	;	Tile 4
	dc.l		$55555555							; row 4 - index 5
	dc.l		$66666666							; row 5 - index 6
	dc.l		$77777777							; row 6 - index 7
	dc.l		$88888888							; row 7 - index 8
	dc.l		$11111111							; row 0 - index 1
	dc.l		$22222222							; row 1 - index 2
	dc.l		$33333333							; row 2 - index 3
	dc.l		$44444444							; row 3 - index 4

	;	Tile 5
	dc.l		$44444444							; row 3 - index 4
	dc.l		$55555555							; row 4 - index 5
	dc.l		$66666666							; row 5 - index 6
	dc.l		$77777777							; row 6 - index 7
	dc.l		$88888888							; row 7 - index 8
	dc.l		$11111111							; row 0 - index 1
	dc.l		$22222222							; row 1 - index 2
	dc.l		$33333333							; row 2 - index 3

	;	Tile 6
	dc.l		$33333333							; row 2 - index 3
	dc.l		$44444444							; row 3 - index 4
	dc.l		$55555555							; row 4 - index 5
	dc.l		$66666666							; row 5 - index 6
	dc.l		$77777777							; row 6 - index 7
	dc.l		$88888888							; row 7 - index 8
	dc.l		$11111111							; row 0 - index 1
	dc.l		$22222222							; row 1 - index 2

	;	Tile 7
	dc.l		$22222222							; row 1 - index 2
	dc.l		$33333333							; row 2 - index 3
	dc.l		$44444444							; row 3 - index 4
	dc.l		$55555555							; row 4 - index 5
	dc.l		$66666666							; row 5 - index 6
	dc.l		$77777777							; row 6 - index 7
	dc.l		$88888888							; row 7 - index 8
	dc.l		$11111111							; row 0 - index 1

; ------------------------------------------------------------------------------
; waterfallPalette
;
; 16-entry palette for the waterfall effect.
; Indices 1-8: blue gradient, lightest (foam) to darkest
;              (deep water) - this is the visible effect.
; Indices 9-15: deliberately jarring magenta shades, visually
;              unrelated to the blue gradient. Acts as a debug
;              tripwire - if these colors ever appear on
;              screen, a tile or sprite is referencing the
;              wrong palette index range.
; Format: $0BGR (9-bit color, even nibbles only).
; ------------------------------------------------------------------------------
waterfallPalette:
	dc.w		$0EEC									; index 1  - lightest foam
	dc.w		$0EC8									; index 2
	dc.w		$0EA4									; index 3
	dc.w		$0E80									; index 4
	dc.w		$0C60									; index 5
	dc.w		$0A40									; index 6
	dc.w		$0820									; index 7
	dc.w		$0600									; index 8  - darkest

	dc.w		$0E0E									; index 9  - sentinel (magenta)
	dc.w		$0C0C									; index 10
	dc.w		$0A0A									; index 11
	dc.w		$0808									; index 12
	dc.w		$0606									; index 13
	dc.w		$0404									; index 14
	dc.w		$0202									; index 15

	section .text

; ------------------------------------------------------------------------------
; waterfallInit
;
; One-time setup for the waterfall effect:
;   1. Writes waterfallPalette to CRAM indices 1-15 (index 0
;      is set separately to magenta as a transparency/debug
;      tripwire -- see waterfallPalette comment above).
;   2. Writes the 8 waterfallTile variants to VRAM starting at
;      $0020 (VRAM $0000 is deliberately left blank).
;   3. Fills plane A's nametable (the full 64x32 tile plane
;      configured by REG16, not just the visible 40x28 area)
;      with a repeating 0-7 tile pattern, giving each column a
;      different starting row in the gradient.
;
; Called once when the scene becomes active (see scene_manager.s).
; Runs with the display already on (see vdp.s) and is not
; synchronised to VBlank -- this is a large enough write (over
; 2000 words total) that it can produce a visible glitch on the
; frame this first runs. Known tradeoff for now; revisit with
; DMA if it becomes a problem.
; ------------------------------------------------------------------------------
waterfallInit:
	move.w	#14,d0										;	Set the palette write loop length
	lea			waterfallPalette,a0				;	Starting address to write from
	move.l	#CRAM_WRITE_CMD,VDP_CTRL	;	Give command to write to cram
	move.w	#$0E0E,VDP_DATA						;	Set the background color to purple 
																		; for easy spotting of transparancy
.writePalette:
	move.w	(a0)+,d1
	move.w	d1,VDP_DATA
	dbra		d0,.writePalette

.writeTile:
	move.w	#63,d0								;	Set the tile write loop length
	lea			waterfallTile,a0			;	Starting address to write from
	move.l	#$40200000,VDP_CTRL		;	Give command to write to VRAM at $0020 
																; ($0000 purposefely left blank so that 
																; any uninitialised data has no tile shown)
.tileLoop:
	move.l	(a0)+,d4
	move.l	d4,VDP_DATA
	dbra	d0,.tileLoop

.writeNameTable:
	move.w	#31,d0								;	Set the outer nametable loop length
	move.w	#7,d1									;	Set the inner nametable loop length
	move.l	#$40000003,VDP_CTRL		;	Give command to write to PlaneA NameTable
.loopOuter:
.loopInner:
	move.w	#$0001,VDP_DATA				;	Write tile 0
	move.w	#$0002,VDP_DATA				;	Write tile 1
	move.w	#$0003,VDP_DATA				;	Write tile 2
	move.w	#$0004,VDP_DATA				;	Write tile 3
	move.w	#$0005,VDP_DATA				;	Write tile 4
	move.w	#$0006,VDP_DATA				;	Write tile 5
	move.w	#$0007,VDP_DATA				;	Write tile 6
	move.w	#$0008,VDP_DATA				;	Write tile 7
	dbra		d1,.loopInner

	move.w	#7,d1									; Reset the inner nametable loop length for next row
	dbra		d0,.loopOuter
.done:
	rts

; ------------------------------------------------------------------------------
; waterfallUpdate
;
; Advances waterfall_state by 1 each call (mod 8), tracking the
; current rotation position of the palette. This is the "logic"
; half of the effect; waterfallRender does the actual CRAM write.
;
; Leaves the updated value in d1 on return. waterfallRender
; relies on this instead of reloading waterfall_state itself --
; this only works because updateScene calls update and render
; back-to-back with nothing else touching d1 in between (see
; scene_manager.s). If that call order ever changes, or if a
; future scene's update start needing d1 for something else in
; between, this coupling breaks silently.
; ------------------------------------------------------------------------------
waterfallUpdate:
	move.w	waterfall_state,d1		; Tracking of position in palette last drawn
	addq.w	#1,d1									;	Increment the starting waterfall pointer
	and.w		#%00000111,d1					; and against bottom bits to do modulo 8 
																; (colors array size)
	move.w	d1,waterfall_state		; store the new background index 
.done:
	rts

; ------------------------------------------------------------------------------
; waterfallRender
;
; Writes a rotated view of waterfallPalette to CRAM indices
; 1-8, creating the flowing/rotating gradient effect. Does NOT
; reload waterfall_state itself -- it relies on d1 already
; holding the value waterfallUpdate just wrote there (see
; waterfallUpdate's header comment for why this coupling exists
; and when it would break).
;
; Walks backwards from d1's position (subq before use) so the
; rotation direction matches the gradient scrolling downward.
; ------------------------------------------------------------------------------
waterfallRender:
	move.w	#7,d0									;	Loop counter
	lea			waterfallPalette,a0		; load base address of table into a0
	move.l	#$C0020000,VDP_CTRL		;	Give command to write to cram
.writePalette:
	subq.w	#1,d1									; decrement the palette position pointer
	and.w		#%00000111,d1					; and against bottom bits to do modulo 8 
																; (palette array size)
	move.w	d1,d2									; move the new position to d2 for expanding to word size
	lsl.w		#1,d2									; scale index by 2 (word-sized entries) 
	move.w	(a0,d2.w),d3					; d3 = waterfallPalette[waterfall_state]
	move.w	d3,VDP_DATA						; set background color
	dbra		d0,.writePalette
.done:
	rts
