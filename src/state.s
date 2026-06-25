	section .bss

; State variables for the demo
vblank_flag:	ds.b	1 ; vblank triggered flag
hblank_flag:	ds.b	1	;hblank flag. Unused but reserved for later effects
frame_count:	ds.w	1	; current frame count
color_state:	ds.w	1	; current color index (0-5)

	section .text

initState:
	move.b	#0,vblank_flag
	move.b	#0,hblank_flag
	move.w	#0,frame_count
	move.w	#1,color_state
	rts
