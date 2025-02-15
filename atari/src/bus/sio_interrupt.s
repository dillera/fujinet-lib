.export     _sio_init_interrupts
.export     _sio_interrupt_handler
.export     _sio_read_complete

.import     _fn_bytes_read
.import     popax

.include    "atari.inc"
.include    "device.inc"
.include    "zp.inc"

; Interrupt vector locations
VSERIR = $0206        ; Serial Input Ready vector
VSEROC = $0208        ; Serial Output Complete vector

.bss
_sio_read_complete:   .res 1  ; Flag to indicate read completion
_sio_buffer_ptr:      .res 2  ; Current buffer position
_sio_bytes_left:      .res 2  ; Remaining bytes to read

.code

; Initialize SIO interrupts
; void sio_init_interrupts()
.proc _sio_init_interrupts
        ; Save old interrupt vectors if needed
        
        ; Set up our interrupt vectors
        lda     #<_sio_interrupt_handler
        sta     VSERIR
        lda     #>_sio_interrupt_handler
        sta     VSERIR+1
        
        ; Enable serial I/O interrupts
        lda     POKMSK
        ora     #%00100000      ; Serial input ready interrupt
        sta     POKMSK
        sta     IRQEN
        
        rts
.endproc

; SIO Interrupt handler
.proc _sio_interrupt_handler
        pha                     ; Save registers
        txa
        pha
        tya
        pha

        ; Check if this is a serial input ready interrupt
        lda     IRQST
        and     #%00100000
        beq     @not_our_irq

        ; Read the byte from SERIN
        lda     SERIN
        ldy     #0
        sta     (_sio_buffer_ptr),y

        ; Increment buffer pointer
        inc     _sio_buffer_ptr
        bne     @no_carry
        inc     _sio_buffer_ptr+1
@no_carry:

        ; Decrement bytes left
        lda     _sio_bytes_left
        bne     @dec_low
        dec     _sio_bytes_left+1
@dec_low:
        dec     _sio_bytes_left
        
        ; Check if we're done
        lda     _sio_bytes_left
        ora     _sio_bytes_left+1
        bne     @not_done
        
        ; Set completion flag
        lda     #1
        sta     _sio_read_complete

@not_done:
@not_our_irq:
        pla                     ; Restore registers
        tay
        pla
        tax
        pla
        rti
.endproc
