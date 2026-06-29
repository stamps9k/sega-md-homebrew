; =============================================================================
; macro.s — Shared assembler macros
;
; Macros are expanded inline at the point of use (no call/return overhead),
; so this is the home for small, frequently-repeated instruction sequences
; rather than full subroutines. Pulled in via include wherever needed.
;
; Currently defines: justPressed
; =============================================================================

; -----------------------------------------------------------------------------
; justPressed
; Computes "just pressed" buttons from current/previous joypad state.
; Result (1 = just pressed this frame) is written to the register given
; as the third argument.
;
; Usage:
;   justPressed current_joy_status,previous_joy_status,d2
; -----------------------------------------------------------------------------
justPressed: macro
	move.b	\1,\3          ; current
	eor.b	\2,\3          ; XOR against previous
	and.b	\1,\3          ; AND against current -> \3 = just-pressed byte
	endm