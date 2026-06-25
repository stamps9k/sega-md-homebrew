colorsTable: 
	dc.w    $000E		; Red: B=0 ($E), G=0, R=7
	dc.w    $00E0		; Green: B=0, G=7 ($E), R=0
	dc.w    $0E00		; Blue: B=7 ($E), G=0, R=0
	dc.w    $00EE		; Cyan: B=7 ($E), G=7 ($E), R=0
	dc.w    $0EEE		; Magenta: B=7 ($E), G=0, R=7 ($E)
	dc.w    $0EE0		; Yellow: B=0, G=7 ($E), R=7 ($E)
	dc.w    $000E		; Red: B=0 ($E), G=0, R=7
	dc.w    $00E0		; Green: B=0, G=7 ($E), R=0
colorsTableEnd:

cycleColors:
.logic:
	move.w frame_count,d0
	andi.w #%0000000000111111,d0
	bne .done
.cycle:
	move.w  color_state,d0			; load the index into d0
	addq.w 	#1,d0								; increment the background index
	and.w #%00000111,d0					; and against top bits to do modulo 8 (colors array size)
	move.w 	d0,color_state			; store the new background index 
.draw:
	move.l  #$C0000000,VDP_CTRL	; CRAM write, address 0
	move.w  color_state,d0			; load the index into d0
	lsl.w   #1,d0								; scale index by 2 (word-sized entries)
	lea     colorsTable,a0			; load base address of table into a0
	move.w  (a0,d0.w),d1				; d1 = colors[color_state]
	move.w  d1,VDP_DATA					; set background color
.done:
	rts