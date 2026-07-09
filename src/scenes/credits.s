;-------------------------------------------------------------------
; credits.s
;
; Scene: scrolling credits.
;
; Owns the credits scene's content (strings, layout, starting
; nametable positions) and behavior (per-frame vertical scroll via
; VDP scroll register / VSRAM). Uses text.s to lay out the initial
; text into the plane during init. Registered with the scene
; manager via sceneTable (init/update/render).
;-------------------------------------------------------------------

	section .text

	include ../include/macro.s

NAMETABLE_A_BASE	EQU	$C000

	xdef	creditsInit
	xdef	creditsUpdate
	xdef	creditsRender

	xref	initFont
	xref	writeStringToNametable
	xref	CRAM_WRITE_CMD
	xref	VSRAM_WRITE_CMD
	xref	VDP_CTRL
	xref	VDP_DATA

	xref	scroll_y

;---------------------------------------------------------------
; creditsInit
;
; Scene init for the scrolling credits screen. Loads font glyphs
; into VRAM, sets the foreground/background colors in CRAM, and
; writes each line of credits text into the nametable at its
; starting position. Assumes clean VRAM/CRAM state on entry, per
; the scene invariant.
;
; Input:  none
; Output: none
; Clobbers: d0, a0
;---------------------------------------------------------------
creditsInit:
	bsr	initFont

	move.l	#CRAM_WRITE_CMD,VDP_CTRL   	; set to write to CRAM (Palette 0 index 0)
	move.w	#$0000,VDP_DATA          		; black (transparency)
	move.w	#$0E0E,VDP_DATA          		; cyan

	vdpVramWrite NAMETABLE_A_BASE+6				; Magic value (6) calculated to put word
																				; on center of line 0
	lea	creditsLine0,a0										; 68K ASM LEARNING PROJECT - NO SGDK
	bsr	writeStringToNametable

	vdpVramWrite NAMETABLE_A_BASE+136			; Magic value (136) calculated to put word
																				; on center of line 1
	lea	creditsLine1,a0										; ================================
	bsr	writeStringToNametable

	vdpVramWrite NAMETABLE_A_BASE+276			; Magic value (276) calculated to put word
																				; on center of line 2
	lea	creditsLine2,a0										; CODE ... STAMPATRON
	bsr	writeStringToNametable

	vdpVramWrite NAMETABLE_A_BASE+406			; Magic value (406) calculated to put word
																				; on center of line 3
	lea	creditsLine3,a0										; GFX ... STAMPATRON
	bsr	writeStringToNametable

	vdpVramWrite NAMETABLE_A_BASE+524			; Magic value (524) calculated to put word
																				; on center of line 4
	lea	creditsLine4,a0										; MUSIC .... N/A (SILENT DEMO)
	bsr	writeStringToNametable

	vdpVramWrite NAMETABLE_A_BASE+802			; Magic value (802) calculated to put word
																				; on center of line 6
	lea	creditsLine6,a0										;	TOOLS
	bsr	writeStringToNametable

	vdpVramWrite NAMETABLE_A_BASE+912			; Magic value (912) calculated to put word
																				; on center of line 7
	lea	creditsLine7,a0										; VASM + M68K-ELF BINUTILS
	bsr	writeStringToNametable

	vdpVramWrite NAMETABLE_A_BASE+1038		; Magic value (1038) calculated to put word
																				; on center of line 8
	lea	creditsLine8,a0										; BLASTEM + GENESIS PLUS GX
	bsr	writeStringToNametable

	vdpVramWrite NAMETABLE_A_BASE+1314		; Magic value (1314) calculated to put word
																				; on center of line 10
	lea	creditsLine10,a0									; THANKS
	bsr	writeStringToNametable

	vdpVramWrite NAMETABLE_A_BASE+1414		; Magic value (1414) calculated to put word
																				; on center of line 11
	lea	creditsLine11,a0									; DHEPPER - FONT8X8 (PUBLIC DOMAIN)
	bsr	writeStringToNametable

	vdpVramWrite NAMETABLE_A_BASE+1548		; Magic value (1548) calculated to put word
																				; on center of line 12
	lea	creditsLine12,a0									; CHARLES MACDONALD - VDP DOCS
	bsr	writeStringToNametable

	vdpVramWrite NAMETABLE_A_BASE+1674		; Magic value (1674) calculated to put word
																				; on center of line 13
	lea	creditsLine13,a0									; THE SPRITESMIND.NET COMMUNITY
	bsr	writeStringToNametable

	vdpVramWrite NAMETABLE_A_BASE+1942		; Magic value (1942) calculated to put word
																				; on center of line 15
	lea	creditsLine15,a0									; THANKS FOR WATCHING
	bsr	writeStringToNametable

	vdpVramWrite NAMETABLE_A_BASE+2194		; Magic value (2194) calculated to put word
																				; on center of line 17
	lea	creditsLine17,a0									; SEE YOU NEXT MILESTONE
	bsr	writeStringToNametable
.done:
	rts

;---------------------------------------------------------------
; creditsUpdate
;
; Per-frame scene update. Advances the vertical scroll offset and
; writes it to VSRAM, producing the scrolling credits effect.
; Called once per frame after VBlank.
;
; Input:  none
; Output: none
; Clobbers: none (scroll_y is read/written directly)
;---------------------------------------------------------------
creditsUpdate:
	move.l  #VSRAM_WRITE_CMD,VDP_CTRL   ; point VDP at VSRAM
	move.w  scroll_y,VDP_DATA     			; write current scroll offset
	addq.w	#1,scroll_y									; increment scroll offset
.done:
	rts

;---------------------------------------------------------------
; creditsRender
;
; Per-frame scene render step. Currently a no-op: all visible
; output for this scene is driven by the VSRAM scroll write in
; creditsUpdate, with no additional per-frame drawing needed.
;
; Input:  none
; Output: none
; Clobbers: none
;---------------------------------------------------------------
creditsRender:
.done:
	rts

	section .rodata

;-------------------------------------------------------------------
; creditsLines
;
; Text content for the scrolling credits, one label per line of
; the display. The numeric suffix (N) corresponds to the line's
; row index in the layout — line 0 is the first row, line 1 the
; second, and so on. Blank/spacer rows in the layout have no
; associated text and are intentionally skipped, so the sequence
; of labels is not always contiguous (e.g. line 4 may be followed
; directly by line 6, with line 5 being a blank row).
;
; Each string is null-terminated for use with
; writeStringToNametable, and padded to an even address afterward
; (`even`) since odd-length string data would otherwise shift
; subsequent labels onto an odd address.
;-------------------------------------------------------------------
creditsLine0:
	dc.b	"68K ASM LEARNING PROJECT - NO SGDK",0
	even
creditsLine1:
	dc.b	"================================",0
	even
creditsLine2:
	dc.b	"CODE ... STAMPATRON",0
	even
creditsLine3:
	dc.b	"GFX ... STAMPATRON",0
	even
creditsLine4:
	dc.b	"MUSIC .... N/A (SILENT DEMO)",0
	even
creditsLine6:
	dc.b	"TOOLS",0
	even
creditsLine7:
	dc.b	"VASM + M68K-ELF BINUTILS",0
	even
creditsLine8:
	dc.b	"BLASTEM + GENESIS PLUS GX",0
	even
creditsLine10:
	dc.b	"THANKS",0
	even
creditsLine11:
	dc.b	"DHEPPER - FONT8X8 (PUBLIC DOMAIN)",0
	even
creditsLine12:
	dc.b	"CHARLES MACDONALD - VDP DOCS",0
	even
creditsLine13:
	dc.b	"THE SPRITESMIND.NET COMMUNITY",0
	even
creditsLine15:
	dc.b	"THANKS FOR WATCHING",0
	even
creditsLine17:
	dc.b	"SEE YOU NEXT MILESTONE",0
	even