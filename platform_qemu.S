/* platform_qemu.S */
.global platform_exit
platform_exit:

    adrp x0, exit_message // Print exit message
    add x0, x0, :lo12:exit_message
    bl uart_puts

    mov w0, #0x18 // SYS_EXIT
    adrp x1, exit_args
    add x1, x1, :lo12:exit_args
    hlt #0xf000

.section ".rodata" // Read Only Data

.balign 8
exit_args:
    .quad 0x20026 // Normal application exit
    .quad 0 // Exit status

exit_message:
    .asciz "[platfrom_qemu.S] Entering 'Shutdown' State (platform is qemu).\n"
