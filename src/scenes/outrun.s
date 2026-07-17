;===============================================================================
; outrun.s
;
; OutRun-style pseudo-3D ground effect (Milestone 3).
;
; Draws a horizon split (sky above, perspective-compressed
; two-colour ground bands below) using a precomputed per-row
; colour table and the generic H-Blank dispatcher in hblank.s.
; Band spacing follows a reciprocal Z-map so bands compress
; toward the horizon, matching the classic road/ground raster
; look, and scroll toward the camera via a phase accumulator
; driven by SCROLL_SPEED.
;
; Follows the scene invariant: outrunInit assumes clean
; VRAM/CRAM, same as every other scene.
;===============================================================================

	section .text

	xref	CRAM_WRITE_CMD
	xref	CRAM_WRITE_CMD_PAL1
	xref	VDP_CTRL
	xref	VDP_DATA
	xref	VSRAM_WRITE_CMD

	xref	hblank_line
	xref	hblankInit

	xdef	outrunInit
	xdef	outrunUpdate
	xdef	outrunRender
	xdef	color_table

; ------------------------------------------------------------------------------
; EQU constants
;
; NOTE on vasm and whitespace: the mot syntax module treats
; anything after the operand field, once it hits a whitespace,
; as a trailing comment (see syntax_mot.texi) unless the
; assembler is invoked with -spaces. "32 * 256" silently
; assembles as just "32". Every multi-token expression
; below is written with no internal whitespace.
; ------------------------------------------------------------------------------
NAMETABLE_A_BASE	EQU	$C000
HORIZON_LINE	EQU	56				; scanline where ground begins (sky/ground split)
VISIBLE_ROWS EQU 56 				; Number of ground scanlines below the horizon
COLOR_THRESHOLD	EQU	32*256	; Theshold for when to swap colors in the palette
Z_MAP_K EQU 128*256					; Customisable value for z_map calculation
SCROLL_SPEED	EQU	256				; Larger = faster apparent forward motion

;===============================================================
; World data - OutRun scene
; Single solid 4bpp tile + base palette colours.
; No movement yet, so this is the entire asset footprint.
;===============================================================

	section .rodata          ; adjust to match your existing convention if this differs

; tileSolid
;	One 8x8 4bpp tile, every pixel = palette index 1.
;	Reused for both sky and ground regions - the visual
;	distinction comes entirely from which CRAM colour is
;	loaded at index 1 when each region is drawn/cycled,
;	not from the tile graphic itself.
tileSolid:
	dc.b $11,$11,$11,$11
	dc.b $11,$11,$11,$11
	dc.b $11,$11,$11,$11
	dc.b $11,$11,$11,$11
	dc.b $11,$11,$11,$11
	dc.b $11,$11,$11,$11
	dc.b $11,$11,$11,$11
	dc.b $11,$11,$11,$11

; outrunPalette
;	Base colours for this scene. skyColor is written once
;	at init and never touched again. groundColorA/B are
;	not written directly to CRAM here - outrunInit reads
;	them when building color_table, and outrunHblank
;	writes whichever one applies to each row at runtime.
skyColor:      dc.w $0E80    ; light blue placeholder
groundColorA:	dc.w $0444    ; Ground Color A - dark grey placeholder
groundColorB:	dc.w $0888    ; Ground Color B - light grey 

	section .bss

phase_accum:			ds.w    1
color_table:			ds.w	56	; table of color indices. Used to create name table 
														; every frame.
reciprical_table:	ds.w	56	; table of z depths for each scanline. Computationally 
														; expensive so generated during init and referenced when
														;	generating the color_table during program lifetime.

	section .text

	include ../include/macro.s

; ------------------------------------------------------------------------------
; zMapInit (populate_recipricals)
;	Computes the 56-word reciprocal distance table.
;	recip(row) = Z_MAP_K / ((row*2)+1)   -- row = 0..55
;	The (row*2)+1 divisor accounts for HBlank firing on
;	every other real scanline (see hblank.s / REG10), so
;	each table row spans two real scanlines of ground.
;	Called once at effect init. Never touched at runtime --
;	DIVU is too expensive to run per-frame, let alone per
;	H-Blank.
;	Clobbers: d0-d2, a0
; ------------------------------------------------------------------------------
populate_recipricals:
	lea	reciprical_table,a0
	moveq   #0,d1                   ; d1 = table row index (0-based)
.loop:
	move.l  #Z_MAP_K,d0             ; dividend
	move.w  d1,d2
	add.w   d2,d2                   ; d2 = row*2 (real scanline offset)
	addq.w  #1,d2                   ; divisor = (row*2)+1
	divu.w  d2,d0                   ; d0.w = quotient
	move.w  d0,(a0)+                ; store word, low word only
	addq.w  #1,d1
	cmp.w   #VISIBLE_ROWS,d1
	bne.s   .loop
.done:
	rts

; ------------------------------------------------------------------------------
; populate_color_table
;	Rebuilds the 56-word color_table from the static
;	reciprical_table, seeded from the current phase_accum.
;	Multiple threshold crossings within a single row (near
;	the horizon, where recip(row) can be several multiples
;	of COLOR_THRESHOLD) are resolved by parity of the
;	crossing count, not a single flip -- see PHASE_WRAP
;	comment above for why parity, and why it must wrap at
;	2x COLOR_THRESHOLD, not 1x.
;
;	Pure function of phase_accum: reads it, never writes it.
;	phase_accum is owned exclusively by outrunUpdate -- this
;	routine must not save anything back to it, even a
;	"leftover remainder". (Previous bug: doing so replaced
;	the intended small per-frame step with the full table-sum
;	mod threshold, causing a near-full-range jump every frame.)
;
;	Called once per frame, from outrunUpdate. No DIVU at
;	runtime -- pure adds and compares against the precomputed
;	table.
;	Clobbers: d0-d4, a0-a1
; ------------------------------------------------------------------------------
populate_color_table:
	lea     reciprical_table,a0
	lea     color_table,a1
	move.w  phase_accum,d1         ; carry accumulator across frames
	moveq   #0,d3                  ; d3 = current color select (0/1)
	move.w  #VISIBLE_ROWS-1,d4       ; loop counter for dbra

.rowLoop:
	move.w  (a0)+,d0                ; d0 = recip(row)
	add.w   d0,d1                   ; accumulate distance
	moveq   #0,d2                   ; d2 = crossing count this row
.crossLoop:
	cmp.w   #COLOR_THRESHOLD,d1
	blo.s   .noCross
	sub.w   #COLOR_THRESHOLD,d1
	addq.w  #1,d2
	bra.s   .crossLoop
.noCross:
	btst    #0,d2                   ; odd crossing count -> toggle
	beq.s   .writeColor
	eor.w   #1,d3
.writeColor:
	tst.w   d3
	beq.s   .colorA
	move.w  groundColorB,(a1)+
	bra.s   .nextRow
.colorA:
	move.w  groundColorA,(a1)+
.nextRow:
	dbra    d4,.rowLoop
.done:
	rts


; ------------------------------------------------------------------------------
; outrunInit
;	Scene entry point. Fills the plane with a single solid
;	tile (clean-VRAM invariant), sets up the ground/sky
;	palette entries, builds the Z-map and the initial
;	color_table, registers outrunHblank with hblankSetHandler,
;	and calls hblankInit to arm the interrupt.
; ------------------------------------------------------------------------------
outrunInit:
.writePalette1:
	move.l	#CRAM_WRITE_CMD_PAL1,VDP_CTRL	;	Give command to write to cram
	move.w	#$0E0E,VDP_DATA	;	Set the background color to purple for easy spotting of transparancy
	move.w	skyColor,VDP_DATA
.writePalette2:
	move.l	#CRAM_WRITE_CMD,VDP_CTRL	;	Give command to write to cram
	move.w	#$0E0E,VDP_DATA	;	Set the background color to purple for easy spotting of transparancy
	move.w	groundColorA,VDP_DATA

	move.w	#63,d0	;	Set the tile write loop length
	lea	tileSolid,a0	;	Starting address to write from
	move.l	#$40200000,VDP_CTRL	;	Give command to write to VRAM at $0020 
															; ($0000 purposefely left blank so that any 
															; uninitialised data has no tile shown)
.writeTile:
	move.l	(a0)+,d4
	move.l	d4,VDP_DATA
	dbra	d0,.writeTile

.writePhase:
	move.w	#0,phase_accum

	jsr	populate_recipricals
	jsr populate_color_table

.tmp_moved_from_update:
	move.w  #$8F02,VDP_CTRL        ; VDP register 15 (autoincrement) = 2
.writeNameTable:
	move.l	#$40000003,VDP_CTRL	;	Give command to write to PlaneA NameTable
	move.w	#13,d0	;	Set the outer sky loop length
	move.w	#63,d1	;	Set the inner sky loop length
.writeSkyOuter:
.writeSkyInner:
	move.w	#$2001,VDP_DATA				; Write tile 0 in palatte 1 (sky palette)
	dbra	d1,.writeSkyInner
	move.w	#63,d1	; Reset the inner nametable loop length for next row
	dbra	d0,.writeSkyOuter

	move.w	#17,d0	;	Set the outer sky loop length
	move.w	#63,d1	;	Set the inner sky loop length
.writeGroundOuter:
.writeGroundInner:
	move.w	#$0001,VDP_DATA				;	Write tile 0 in palette 0 (ground palette)
	dbra	d1,.writeGroundInner
	move.w	#63,d1	; Reset the inner nametable loop length for next row
	dbra	d0,.writeGroundOuter
	jsr	populate_color_table
.redirectVdp:
	move.w  #$8F00,VDP_CTRL        ; reg 15 (autoincrement) = 0 again
	move.l  #$C0020000,VDP_CTRL    ; re-latch CRAM address (palette line 0, index 1)

.setHblankRoutine:
	lea	outrunHblank,a0
	jsr	hblankSetHandler
	jsr hblankInit
	move.w  #$8F00,VDP_CTRL        ; reg 15 = 0
	move.l  #$C0020000,VDP_CTRL    ; latch CRAM address — LAST VDP_CTRL write in this routine
.done:
	rts

; ------------------------------------------------------------------------------
; outrunUpdate
;	Per-frame main loop hook. Advances phase_accum by
;	SCROLL_SPEED (with wraparound at PHASE_WRAP -- see the
;	comment on that constant for why it isn't COLOR_THRESHOLD),
;	then rebuilds color_table from the new phase. This is the
;	only routine permitted to write phase_accum.
;	Clobbers: d0
; ------------------------------------------------------------------------------
outrunUpdate:
	move.w  phase_accum,d0
	sub.w   #SCROLL_SPEED,d0
	bpl.s   .noWrap
	add.w   #COLOR_THRESHOLD*2,d0
.noWrap:
	move.w  d0,phase_accum
	jsr     populate_color_table
.done:
	rts

; ------------------------------------------------------------------------------
; outrunRender
;	Present but essentially empty - all visual work for this
;	scene happens in outrunHblank, not in a per-frame render
;	pass.
; ------------------------------------------------------------------------------
outrunRender:
.done:
	rts

; ------------------------------------------------------------------------------
; outrunHblank
;	Handler registered with hblank.s, called once per H-Blank
;	via hblank_handler. Above HORIZON_LINE, does nothing (still
;	in the sky). At or below it, looks up the current row's
;	precomputed colour in color_table and writes it to CRAM.
;	Contains no decision-making beyond the horizon check - the
;	colour itself is always a precomputed table read, never
;	calculated live.
;	Clobbers: d0, a0 (both saved/restored by hblankInterrupt)
; ------------------------------------------------------------------------------
outrunHblank:
	; Empirically-tuned delay: pushes the CRAM write past line N+1's
	; blanking window so it lands in N+2's window instead. Re-tune if the instruction
	; sequence around this call changes.
	insertNOPs	56

	move.w  hblank_line,d0
	cmp.w   #(HORIZON_LINE-0),d0
	blo.s   .done                   ; still in sky region
	sub.w   #(HORIZON_LINE-0),d0
	cmp.w   #VISIBLE_ROWS,d0
	bhs.s   .done                   ; past bottom of ground band

	add.w   d0,d0                   ; word index -> byte offset
	lea     color_table,a0
	move.w  (a0,d0.w),VDP_DATA

.done:
	rts
