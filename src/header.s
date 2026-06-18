; =============================================================================
; header.s — Sega Megadrive ROM header and 68000 vector table
;
; The 68000 expects the first two longwords of the address space to be:
;   $000000 : Initial stack pointer (SSP)
;   $000004 : Initial program counter (entry point)
;
; The Megadrive additionally requires a metadata block at $000100 containing
; console name, copyright, ROM name, checksums, memory map etc.
; Without this the hardware (and most emulators) will refuse to boot.
; =============================================================================

    ; -------------------------------------------------------------------------
    ; 68000 Vector Table ($000000 - $0000FF)
    ; Each entry is a longword (4 bytes) address.
    ; The CPU reads these on reset and exception.
    ; -------------------------------------------------------------------------

    dc.l    $00FFE000           ; Initial SSP (stack grows down from top of RAM)
    dc.l    EntryPoint          ; Initial PC — where execution begins

    ; Exception vectors — all point to a simple halt loop for now
    dc.l    BusError            ; Bus error
    dc.l    AddressError        ; Address error
    dc.l    IllegalInstr        ; Illegal instruction
    dc.l    DivByZero           ; Division by zero
    dc.l    ChkInstr            ; CHK instruction
    dc.l    TrapV               ; TRAPV instruction
    dc.l    PrivViolation       ; Privilege violation
    dc.l    Trace               ; Trace
    dc.l    Line1010            ; Line 1010 emulator
    dc.l    Line1111            ; Line 1111 emulator
    dc.l    ErrorHandler        ; Reserved
    dc.l    ErrorHandler        ; Reserved
    dc.l    ErrorHandler        ; Reserved
    dc.l    ErrorHandler        ; Reserved
    dc.l    ErrorHandler        ; Reserved
    dc.l    ErrorHandler        ; Reserved
    dc.l    ErrorHandler        ; Reserved
    dc.l    ErrorHandler        ; Reserved
    dc.l    ErrorHandler        ; Reserved
    dc.l    ErrorHandler        ; Reserved
    dc.l    ErrorHandler        ; Reserved
    dc.l    ErrorHandler        ; Reserved
    dc.l    ErrorHandler        ; Spurious interrupt
    dc.l    ErrorHandler        ; Level 1 interrupt (V-blank)
    dc.l    ErrorHandler        ; Level 2 interrupt
    dc.l    ErrorHandler        ; Level 3 interrupt (H-blank)
    dc.l    ErrorHandler        ; Level 4 interrupt
    dc.l    ErrorHandler        ; Level 5 interrupt
    dc.l    ErrorHandler        ; Level 6 interrupt
    dc.l    ErrorHandler        ; Level 7 interrupt
    dc.l    ErrorHandler        ; TRAP #0
    dc.l    ErrorHandler        ; TRAP #1
    dc.l    ErrorHandler        ; TRAP #2
    dc.l    ErrorHandler        ; TRAP #3
    dc.l    ErrorHandler        ; TRAP #4
    dc.l    ErrorHandler        ; TRAP #5
    dc.l    ErrorHandler        ; TRAP #6
    dc.l    ErrorHandler        ; TRAP #7
    dc.l    ErrorHandler        ; TRAP #8
    dc.l    ErrorHandler        ; TRAP #9
    dc.l    ErrorHandler        ; TRAP #10
    dc.l    ErrorHandler        ; TRAP #11
    dc.l    ErrorHandler        ; TRAP #12
    dc.l    ErrorHandler        ; TRAP #13
    dc.l    ErrorHandler        ; TRAP #14
    dc.l    ErrorHandler        ; TRAP #15
    dc.l    ErrorHandler        ; Reserved
    dc.l    ErrorHandler        ; Reserved
    dc.l    ErrorHandler        ; Reserved
    dc.l    ErrorHandler        ; Reserved
    dc.l    ErrorHandler        ; Reserved
    dc.l    ErrorHandler        ; Reserved
    dc.l    ErrorHandler        ; Reserved
    dc.l    ErrorHandler        ; Reserved

    ; -------------------------------------------------------------------------
    ; Megadrive ROM Header ($000100 - $0001FF)
    ; Fixed-length ASCII fields — must be exactly the right number of bytes.
    ; -------------------------------------------------------------------------

    dc.b    "SEGA MEGA DRIVE "  ; Console name (16 bytes, space padded)
    dc.b    "(C)XXXX 2024.JAN" ; Copyright/date (16 bytes)
    dc.b    "HELLO WORLD                                     " ; Domestic name (48 bytes)
    dc.b    "HELLO WORLD                                     " ; Overseas name (48 bytes)
    dc.b    "GM 00000000-00"    ; Serial/revision (14 bytes)
    dc.w    $0000               ; Checksum (0 for now — emulators generally ignore)
    dc.b    "J               "  ; I/O support (16 bytes)
    dc.l    $00000000           ; ROM start address
    dc.l    $000FFFFF           ; ROM end address
    dc.l    $00FF0000           ; RAM start address
    dc.l    $00FFFFFF           ; RAM end address
    dc.b    "            "      ; SRAM info (12 bytes, unused)
    dc.b    "        "          ; Modem info (8 bytes, unused)
    dc.b    "                                        " ; Notes (40 bytes)
    dc.b    "JUE             "  ; Region (16 bytes — J=Japan, U=USA, E=Europe)

    ; -------------------------------------------------------------------------
    ; Exception/error handlers
    ; For now these all just halt. In a real project you might display
    ; a crash screen or log register state.
    ; -------------------------------------------------------------------------

BusError:
AddressError:
IllegalInstr:
DivByZero:
ChkInstr:
TrapV:
PrivViolation:
Trace:
Line1010:
Line1111:
ErrorHandler:
    illegal                     ; Halt the CPU