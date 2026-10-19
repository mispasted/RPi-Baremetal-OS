/* platform_rpi.S */
.global platform_exit
platform_exit:
    adrp    x0, exit_message // Print exit message
    add     x0, x0, :lo12:exit_message
    bl      uart_puts

platform_restart:
// AArch64, Pi 4, MMU off / peripheral address mapped at 0xFE100000
// Causes a warm full-system reset; does not cut power.
/* Pi 4B, high-peripheral mode */

    adrp    x0, restart_message // Print exit message
    add     x0, x0, :lo12:restart_message
    bl      uart_puts

// Wait for the PL011 to complete sending
    .set UART_BASE_ADDR, 0x47E201000
    .set FR, (UART_BASE_ADDR+0x18)// Flag Register
wait_for_tx_rx_complete:
    ldr     x9, =FR
    ldr     w10, [x9]
    tbnz    w10, #3, wait_for_tx_rx_complete

    ldr     x0, =0x000000047E100024 // PM_WDOG
    mov     w1, #10
    movk    w1, #0x5A00, lsl#16
    str     w1, [x0]

    ldr     x0, =0x000000047E10001C // PM_RSTC
    ldr     w1, [x0]
    bic     w1, w1, #0x30
    orr     w1, w1, #0x20
    movk    w1, #0x5A00, lsl#16
    str     w1, [x0]

    dsb     sy
1:
    wfe
    b       1b

.section ".rodata"

exit_message:
    .asciz "[platform_rpi.S] Entering 'Shutdown' State.\r\n"

restart_message:
    .asciz "[platform_rpi.S] Triggering 'Restart' State.\r\n"
