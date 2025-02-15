        .export     _sio_read

        .import     _bus
        .import     _fn_bytes_read
        .import     _bus_status
        .import     _copy_network_cmd_data
        .import     _sio_init_interrupts
        .import     _sio_read_complete
        .import     popa
        .import     popax

        .include    "device.inc"
        .include    "zp.inc"
        .include    "macros.inc"

; uint8_t sio_read(uint8_t unit, void * buffer, uint16_t len)

_sio_read:
        axinto  ptr1                    ; length

        axinto  _fn_bytes_read

        ; Initialize interrupt system if not done
        jsr     _sio_init_interrupts

        setax   #t_network_read
        jsr     _copy_network_cmd_data   ; setup DCB

        popax   IO_DCB::dbuflo          ; buffer arg
        popa    IO_DCB::dunit           ; unit arg
        setax   ptr1                    ; length
        sta     IO_DCB::dbytlo
        stx     IO_DCB::dbythi
        sta     IO_DCB::daux1
        stx     IO_DCB::daux2

        ; Clear read complete flag
        lda     #0
        sta     _sio_read_complete

        ; Start the SIO operation
        jsr     _bus

        ; Wait for completion flag
@wait_loop:
        lda     _sio_read_complete
        beq     @wait_loop

        lda     IO_DCB::dunit           ; restore the unit
        jmp     _bus_status

.rodata
t_network_read:
        .byte 'R', $40, $ff, $ff, $ff, $ff
