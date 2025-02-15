.export     _sio_init_interrupts
.export     _sio_interrupt_handler
.export     _sio_read_complete
.export     _sio_buffer_ptr
.export     _sio_bytes_left

.import     _fn_bytes_read
.import     popax

.include    "atari.inc"
.include    "device.inc"
.include    "zp.inc"

; Hardware addresses for Atari SIO
VSERIR          = $0206        ; Serial Input Ready vector

.segment "BSS"
_sio_read_complete:   .res 1  ; Flag to indicate read completion
rx_buf:             .res 256 ; Receive buffer
rx_buf_len:         .res 1   ; Number of bytes in receive buffer
rx_buf_idx:         .res 1   ; Current index in receive buffer
dvstat_buf:         .res 4   ; Local copy of DVSTAT
_vserir_save:       .res 2   ; Save location for original VSERIR vector
_pokmsk_save:       .res 1   ; Save location for original POKMSK value

.segment "ZEROPAGE"
_sio_buffer_ptr:      .res 2  ; Current buffer position
_sio_bytes_left:      .res 2  ; Remaining bytes to read

.code

; Initialize SIO interrupts
; void sio_init_interrupts()
.proc _sio_init_interrupts
        sei                     ; Mask interrupts

        ; Save existing VSERIR vector
        lda     VSERIR
        sta     _vserir_save
        lda     VSERIR+1
        sta     _vserir_save+1

        ; Set up our interrupt vector
        lda     #<_sio_interrupt_handler
        sta     VSERIR
        lda     #>_sio_interrupt_handler
        sta     VSERIR+1
        
        ; Save current POKMSK value
        lda     POKMSK
        sta     _pokmsk_save

        ; Enable serial I/O interrupts
        lda     POKMSK
        ora     #%00100000      ; Serial input ready interrupt
        sta     POKMSK
        sta     IRQEN

        ; Initialize our buffers
        lda     #0
        sta     rx_buf_len
        sta     rx_buf_idx
        
        cli                     ; Re-enable interrupts
        rts
.endproc

; Disable SIO interrupts and restore original vectors
.proc _sio_disable_interrupts
        sei                     ; Mask interrupts

        ; Restore original VSERIR vector
        lda     _vserir_save
        sta     VSERIR
        lda     _vserir_save+1
        sta     VSERIR+1

        ; Restore original POKMSK value
        lda     _pokmsk_save
        sta     POKMSK
        sta     IRQEN

        cli                     ; Re-enable interrupts
        rts
.endproc

; Save current DVSTAT values
.proc save_dvstat
        ldx     #3
@loop:  lda     DVSTAT,x
        sta     dvstat_buf,x
        dex
        bpl     @loop
        rts
.endproc

; Restore DVSTAT values
.proc restore_dvstat
        ldx     #3
@loop:  lda     dvstat_buf,x
        sta     DVSTAT,x
        dex
        bpl     @loop
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

        ; Re-enable the interrupt (it gets disabled as acknowledgment)
        lda     POKMSK
        ora     #%00100000      ; Serial input ready interrupt
        sta     POKMSK
        sta     IRQEN

        ; First check if we have space in our receive buffer
        lda     rx_buf_len
        cmp     #255           ; Check against 255 instead of 256
        beq     @buffer_full

        ; Read the byte from SERIN into receive buffer
        ldx     rx_buf_len
        lda     SERIN
        sta     rx_buf,x
        inc     rx_buf_len

        ; If we have pending read request, process it
        lda     _sio_bytes_left
        ora     _sio_bytes_left+1
        beq     @no_pending_read

        ; Copy byte from receive buffer to target buffer
        ldx     rx_buf_idx
        lda     rx_buf,x
        ldy     #0
        sta     (_sio_buffer_ptr),y

        ; Update buffer pointers
        inc     rx_buf_idx
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
        
        ; Check if we're done with current read
        lda     _sio_bytes_left
        ora     _sio_bytes_left+1
        bne     @not_done
        
        ; Set completion flag and save status
        lda     #1
        sta     _sio_read_complete
        jsr     save_dvstat

@not_done:
@no_pending_read:
@buffer_full:
@not_our_irq:
        pla                     ; Restore registers
        tay
        pla
        tax
        pla
        rti
.endproc
