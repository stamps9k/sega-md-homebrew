; =============================================================================
; state.s — Shared RAM state for the main loop and scene manager
; =============================================================================

	section .bss

	xdef	initState
	xdef	vblank_flag
	xdef	frame_count 
	xdef	previous_joy_status
	xdef	current_joy_status
	xdef	color_state
	xdef	active_effect

; State variables stored in RAM for the demo.
vblank_flag:	ds.b	1	; vblank triggered flag
hblank_flag:	ds.b	1	; hblank flag. Unused but reserved for later effects
previous_joy_status:	ds.b	1	; previous joypad status
current_joy_status:	ds.b	1	; current joypad status
frame_count:	ds.w	1	; current frame count
color_state:	ds.w	1	; current color index (0-7)
active_effect:	ds.w	1	; index of the currently active scene

	section .text

; -----------------------------------------------------------------------------
; initState
; Zeroes all shared RAM state. Called once during startup before the main
; loop begins.
; -----------------------------------------------------------------------------
initState:
	move.b	#0,vblank_flag
	move.b	#0,hblank_flag
	move.b	#0,previous_joy_status
	move.b	#0,current_joy_status	
	move.w	#0,frame_count
	move.w	#0,color_state
	move.w	#0,active_effect

	rts
