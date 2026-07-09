;-------------------------------------------------------------------
; text.s
;
; Generic text rendering support.
;
; Provides font tile data and a routine to write a string of
; characters into the nametable at a given plane position. Contains
; no knowledge of scrolling, timing, or content — purely a shared
; primitive for putting characters on screen. Consumed by scene
; files that need to display text (e.g. credits.s).
;-------------------------------------------------------------------

	section .text

	include	../include/macro.s

	xref	fontData
	xref	FONT_FIRST_CHAR
	xref	FONT_DATA_LOOP_COUNT
	xref	VDP_CTRL
	xref	VDP_DATA

	xdef	initFont
	xdef	writeStringToNametable

FONT_BASE_TILE  EQU  1      ; VRAM tile index where glyphs are loaded.
														; Reserves FONT_NUM_CHARS tiles starting here —
														; callers must not place other tiles in this range.

;---------------------------------------------------------------
; initFont
;
; Loads the font glyph tile data (fontData) into VRAM, starting at
; FONT_BASE_TILE. Must be called before writeStringToNametable is
; used, since it depends on these tiles already being resident.
; Assumes clean VRAM state on entry, per the scene invariant.
;
; Input:  none
; Output: none
; Clobbers: d0, a0
;---------------------------------------------------------------
initFont:
	vdpVramWrite	FONT_BASE_TILE*32 ; $0000 purposefully left blank so uninitialised
																	; data references show no tile
	lea	fontData,a0
	move.w	#FONT_DATA_LOOP_COUNT,d0
.loop:
	move.w  (a0)+,VDP_DATA
	dbra    d0,.loop
.done:
	rts

;---------------------------------------------------------------
; writeStringToNametable
;
; Writes a null-terminated ASCII string into the nametable as a
; sequence of tile indices, starting at whatever VRAM address the
; VDP write-pointer currently points to (caller must set this via
; VDP_CTRL before calling). Assumes palette 0, no flip/priority.
;
; Input:  a0.l = pointer to null-terminated ASCII string
; Output: none
; Clobbers: d0, a0
;---------------------------------------------------------------
writeStringToNametable:
.loop:
	move.b	(a0)+,d0		; read next character
	beq.s	.done			; hit null terminator -> stop

	sub.b	#FONT_FIRST_CHAR,d0	; d0 = glyph offset (0-94)
	ext.w	d0			; byte -> word
	add.w	#FONT_BASE_TILE,d0	; d0 = tile index

	move.w	d0,VDP_DATA		; write nametable entry (palette 0)
	bra.s	.loop
.done:
	rts
	