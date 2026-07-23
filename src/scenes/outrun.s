; ==============================================================================
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
; ==============================================================================

	include ../include/macro.s

	; ----------------------------------------------------------------------------
	; External definitions
	; ----------------------------------------------------------------------------
	xdef	outrunInit
	xdef	outrunUpdate
	xdef	outrunRender
	
	; ----------------------------------------------------------------------------
	; External references
	; ----------------------------------------------------------------------------
	; from h_blank.s
	xref	hblankInit
	xref	hblank_line
	
	; from vdp.s
	xref	CRAM_WRITE_CMD
	xref	CRAM_WRITE_CMD_PAL1
	xref	VDP_CTRL
	xref	VDP_DATA
	xref	VSRAM_WRITE_CMD

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
Z_MAP_K 					EQU		128*256		; Customisable value for z_map calculation

VISIBLE_ROWS			EQU		56				; Number of ground scanlines below the horizon
HORIZON_LINE			EQU		56				; scanline where ground begins (sky/ground split)

COLOR_THRESHOLD		EQU		32*256		; Threshold for when to swap colors in the palette
SCROLL_SPEED			EQU		256				; Larger = faster apparent forward motion

ROAD_MAX_HW				EQU		100				; The maximum half width value for the road
CENTER_X					EQU		160				; Center point of the screen in px for MD

NAMETABLE_A_BASE	EQU		$C000

	section .rodata

; ------------------------------------------------------------------------------
; tileGrass
;	One 8x8 4bpp tile, every pixel = palette index 1.
;	Reused for both sky and grass regions - the visual
;	distinction comes entirely from which CRAM colour is
;	loaded at index 1 when each region is drawn/cycled,
;	not from the tile graphic itself.
; ------------------------------------------------------------------------------
tileGrass:
	dc.b		$11,$11,$11,$11
	dc.b		$11,$11,$11,$11
	dc.b		$11,$11,$11,$11
	dc.b		$11,$11,$11,$11
	dc.b		$11,$11,$11,$11
	dc.b		$11,$11,$11,$11
	dc.b		$11,$11,$11,$11
	dc.b		$11,$11,$11,$11

; ------------------------------------------------------------------------------
; tileRoad
;	One 8x8 4bpp tile, every pixel = palette index 2.
;	palette index 2 is set aside for the road.
; ------------------------------------------------------------------------------
tileRoad:
	dc.b		$22,$22,$22,$22
	dc.b		$22,$22,$22,$22
	dc.b		$22,$22,$22,$22
	dc.b		$22,$22,$22,$22
	dc.b		$22,$22,$22,$22
	dc.b		$22,$22,$22,$22
	dc.b		$22,$22,$22,$22
	dc.b		$22,$22,$22,$22

edgeTilesStart:
	dc.b		$12,$22,$22,$22
	dc.b		$12,$22,$22,$22
	dc.b		$12,$22,$22,$22
	dc.b		$12,$22,$22,$22
	dc.b		$12,$22,$22,$22
	dc.b		$12,$22,$22,$22
	dc.b		$12,$22,$22,$22
	dc.b		$12,$22,$22,$22

	dc.b		$11,$22,$22,$22
	dc.b		$11,$22,$22,$22
	dc.b		$11,$22,$22,$22
	dc.b		$11,$22,$22,$22
	dc.b		$11,$22,$22,$22
	dc.b		$11,$22,$22,$22
	dc.b		$11,$22,$22,$22
	dc.b		$11,$22,$22,$22

	dc.b		$11,$12,$22,$22
	dc.b		$11,$12,$22,$22
	dc.b		$11,$12,$22,$22
	dc.b		$11,$12,$22,$22
	dc.b		$11,$12,$22,$22
	dc.b		$11,$12,$22,$22
	dc.b		$11,$12,$22,$22
	dc.b		$11,$12,$22,$22

	dc.b		$11,$11,$22,$22
	dc.b		$11,$11,$22,$22
	dc.b		$11,$11,$22,$22
	dc.b		$11,$11,$22,$22
	dc.b		$11,$11,$22,$22
	dc.b		$11,$11,$22,$22
	dc.b		$11,$11,$22,$22
	dc.b		$11,$11,$22,$22

	dc.b		$11,$11,$12,$22
	dc.b		$11,$11,$12,$22
	dc.b		$11,$11,$12,$22
	dc.b		$11,$11,$12,$22
	dc.b		$11,$11,$12,$22
	dc.b		$11,$11,$12,$22
	dc.b		$11,$11,$12,$22
	dc.b		$11,$11,$12,$22

	dc.b		$11,$11,$11,$22
	dc.b		$11,$11,$11,$22
	dc.b		$11,$11,$11,$22
	dc.b		$11,$11,$11,$22
	dc.b		$11,$11,$11,$22
	dc.b		$11,$11,$11,$22
	dc.b		$11,$11,$11,$22
	dc.b		$11,$11,$11,$22

	dc.b		$11,$11,$11,$12
	dc.b		$11,$11,$11,$12
	dc.b		$11,$11,$11,$12
	dc.b		$11,$11,$11,$12
	dc.b		$11,$11,$11,$12
	dc.b		$11,$11,$11,$12
	dc.b		$11,$11,$11,$12
	dc.b		$11,$11,$11,$12
edgeTilesEnd:

; ------------------------------------------------------------------------------
; outrunPalette
;	Base colours for this scene. skyColor is written once
;	at init and never touched again. groundColorA/B are
;	not written directly to CRAM here - outrunInit reads
;	them when building color_table, and outrunHblank
;	writes whichever one applies to each row at runtime.
; ------------------------------------------------------------------------------
skyColor:			
	dc.w		$0E80									; Sky single color - light blue
groundColorA:
	dc.w		$0888									; Ground Color A - dark grey
groundColorB:	
	dc.w		$0444									; Ground Color B - light grey
grassColorA:
	dc.w		$00E0									; Grass color A - bright green
grassColorB:
	dc.w		$0080									; Grass color B - dark green

	section .bss

phase_accum:
	ds.w		1
color_table:
	ds.w		112										; table of color indices, 2 entries per line
																; (grass, ground). Rebuilt once per frame by
																; populate_color_table; read every other line by
																; outrunHblank to write CRAM.
reciprical_table:
	ds.w		56										; table of z depths for each scanline.
																; Computationally expensive so generated during
																; init and referenced when generating the
																; color_table during program lifetime.
width_map_table:
	ds.w		14										; table of halfWidth values
																; (half the road width) for a given distance.

	section .text

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
	move.w	#$0E0E,VDP_DATA								;	Set the background color to purple for 
																				; easy spotting of transparency
	move.w	skyColor,VDP_DATA
.writePalette2:
	move.l	#CRAM_WRITE_CMD,VDP_CTRL	;	Give command to write to cram
	move.w	#$0E0E,VDP_DATA						;	Set the background color to purple for
																		; easy spotting of transperancy
	move.w	groundColorA,VDP_DATA
	move.l	#$40200000,VDP_CTRL				;	Give command to write to VRAM at $0020 
																		; ($0000 purposefely left blank so that any 
																		; uninitialised data has no tile shown)

.writeGrassTile:	
	move.w	#7,d0									;	Set the tile write loop length
	lea			tileGrass,a0					; Starting address to write from
.grassLoop:
	move.l	(a0)+,d4
	move.l	d4,VDP_DATA
	dbra		d0,.grassLoop

.writeRoadTile:
	move.w	#7,d0									;	Set the tile write loop length
	lea			tileRoad,a0						;	Starting address to write from
.roadLoop:
	move.l	(a0)+,d4
	move.l	d4,VDP_DATA
	dbra		d0,.roadLoop

.writeEdgeTiles:
	move.w	#55,d0								;	Set the tile write loop length (8 x 7)
	lea			edgeTilesStart,a0			;	Starting address to write from
.edgeLoop:
	move.l	(a0)+,d4
	move.l	d4,VDP_DATA
	dbra		d0,.edgeLoop
	
.writePhase:
	move.w	#0,phase_accum

.populateTables:
	bsr			populateRecipricals
	bsr 		populateColorTable
	bsr			populateWidthMap

.writeNameTable:
	move.l	#$40000003,VDP_CTRL		;	Give command to write to PlaneA NameTable
	move.l	#13,d0								;	Set the outer sky loop length
	move.l	#63,d1								;	Set the inner sky loop length
.writeSkyOuter:
.writeSkyInner:
	move.w	#$2001,VDP_DATA				; Write tile 0 in palette 1 (sky palette)
	dbra		d1,.writeSkyInner
	move.w	#63,d1								; Reset the inner nametable loop length
	dbra		d0,.writeSkyOuter

.writeGroundTiles:
	lea			width_map_table,a0
	move.w	#13,d0	;	Set the loop length 
.groundOuterLoop:
	move.w	(a0)+,d1							; Load the width map entry for use in calculations
	move.w	#CENTER_X,d2
	sub.w		d1,d2									; Left edge
	move.w	#CENTER_X,d3
	add.w		d1,d3									; Right edge
	move.w	d2,d4
	lsr.w		#3,d4									; leftTileCol
	move.w	d3,d5
	lsr.w		#3,d5									; rightTileCol
	sub.w		d4,d5
	move.w	d2,d6
	andi.w	#%0000000000000111,d6	; leftOffset
	cmp.w		#0,d6
	beq.s		.roadCountReady				; offset==0: count is already correct
	subq.w	#1,d5									; offset!=0: exclude both edge-tile columns
.roadCountReady:
	subq.w	#1,d4
.groundLeftLoop:
	move.w	#$0001,VDP_DATA				; Write tile 1 in palette 0 (ground palette)
	dbra		d4,.groundLeftLoop
.groundEdgeLeft:
	cmp.w		#0,d6
	beq.s		.roadSetup
	move.w	d6,d7
	add.w		#2,d7
	move.w	d7,VDP_DATA	
.roadSetup:
	cmp.w		#0,d5
	beq.s		.groundEdgeRight	
	subq.w	#1,d5
.groundRoadLoop:
	move.w	#$0002,VDP_DATA				; Write tile 2 in palette 0 (ground palette)
	dbra		d5,.groundRoadLoop
.groundEdgeRight:
	cmp.w		#0,d6
	beq.s		.groundRight
	move.w	d6,d7
	add.w		#2,d7
	ori.w		#$0800,d7
	move.w	d7,VDP_DATA						; same tile, H-flipped
.groundRight:
	move.w	d3,d5	
	lsr.w		#3,d5									; rightTileCol
	move.w	#64,d4
	sub.w		d5,d4									; 64 - rightTileCol
	cmp.w		#0,d6
	beq.s		.groundRightReady			; offset==0: rightTileCol is pure grass, count already correct
	subq.w	#1,d4									; offset!=0: exclude the edge tile's column
.groundRightReady:
	subq.w	#1,d4									; dbra pre-decrement
.groundRightLoop:
	move.w	#$0001,VDP_DATA				; Write tile 1 in palette 0 (ground palette)
	dbra		d4,.groundRightLoop
	dbra		d0,.groundOuterLoop

.redirectVdp:
	move.l  #$C0020000,VDP_CTRL		; re-latch CRAM address (palette line 0, index 1)
.setHblankRoutine:
	lea			outrunHblank,a0
	jsr			hblankSetHandler
	jsr			hblankInit
	move.l	#$C0020000,VDP_CTRL		; latch CRAM address — LAST VDP_CTRL write in this routine
.done:
	rts

; ------------------------------------------------------------------------------
; populateRecipricals
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
populateRecipricals:
	lea			reciprical_table,a0
	moveq   #0,d1									; d1 = table row index (0-based)
.loop:
	move.l	#Z_MAP_K,d0						; dividend
	move.w	d1,d2
	add.w		d2,d2									; d2 = row*2 (real scanline offset)
	addq.w	#1,d2									; divisor = (row*2)+1
	divu.w	d2,d0									; d0.w = quotient
	move.w	d0,(a0)+							; store word, low word only
	addq.w	#1,d1
	cmp.w		#VISIBLE_ROWS,d1
	bne.s		.loop
.done:
	rts

; ------------------------------------------------------------------------------
; populateColorTable
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
populateColorTable:
	lea			reciprical_table,a0
	lea			color_table,a1
	move.w	phase_accum,d1				; carry accumulator across frames
	moveq		#0,d3									; d3 = current color select (0/1)
	move.w	#VISIBLE_ROWS-1,d4		; loop counter for dbra

.rowLoop:
	move.w	(a0)+,d0							; d0 = recip(row)
	add.w		d0,d1									; accumulate distance
	moveq		#0,d2									; d2 = crossing count this row
.crossLoop:
	cmp.w		#COLOR_THRESHOLD,d1
	blo.s		.noCross
	sub.w		#COLOR_THRESHOLD,d1
	addq.w	#1,d2
	bra.s		.crossLoop
.noCross:
	btst		#0,d2									; odd crossing count -> toggle
	beq.s		.writeColor
	eor.w		#1,d3
.writeColor:
	tst.w		d3
	beq.s		.colorA
	move.w	grassColorB,(a1)+
	move.w	groundColorB,(a1)+
	bra.s		.nextRow
.colorA:
	move.w	grassColorA,(a1)+
	move.w 	groundColorA,(a1)+
.nextRow:
	dbra		d4,.rowLoop
.done:
	rts

; ------------------------------------------------------------------------------
; populateWidthMap
;	Computes the 14-word width_map_table, one halfWidth value per
;	visible road row: halfWidth(r') = ROAD_MAX_HW * (r'+1) / 14,
;	r' = 0..13. Produces a linear taper from a single half-width
;	at the horizon out to ROAD_MAX_HW at the bottom row -- see
;	project notes for why linear (not reciprocal) is correct here:
;	screen-space road width and scanline offset from horizon are
;	both proportional to 1/z, so their ratio is linear.
;	Called once at effect init. Never touched at runtime -- DIVU
;	is too expensive to run per-frame, let alone per H-Blank.
;	Clobbers: d0-d1, a0
; ------------------------------------------------------------------------------
populateWidthMap:
	lea			width_map_table,a0
	move.l	#0,d0									; d0 set aside for r'
.loop:
	move.l	d0,d1									; Put r' into d1
	addq.w	#1,d1									; Calculate (r'+1)
	mulu.w	#ROAD_MAX_HW,d1				; ROAD_MAX_HW * (r'+1)
	divu.w	#14,d1								; d1.w stores result
	move.w	d1,(a0)+							; store word, low word only
	addq.w	#1,d0
	cmp.w		#14,d0
	bne.s		.loop
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
	move.w	phase_accum,d0
	sub.w		#SCROLL_SPEED,d0
	bpl.s		.noWrap
	add.w		#COLOR_THRESHOLD*2,d0
.noWrap:
	move.w	d0,phase_accum
	bsr			populateColorTable
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

	move.w	hblank_line,d0
	cmp.w		#(HORIZON_LINE-0),d0
	blo.s		.done									; still in sky region
	sub.w		#(HORIZON_LINE-0),d0
	cmp.w		#VISIBLE_ROWS,d0
	bhs.s		.done									; past bottom of ground band
	move.l	#$C0020000,VDP_CTRL		; Point VDP at CRAM
	move.w	d0,d1									; hblank_line to separate register for calcs
	lsl.w		#2,d1									; word index -> byte offset
	lea			color_table,a0
	move.w	(a0,d1.w),VDP_DATA
	add.w		#2,d1									; word index -> byte offset for second entry
	move.w	(a0,d1.w),VDP_DATA
.done:
	rts
