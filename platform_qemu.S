.global platform_exit
platform_exit:
    mov w0, #0x18 // SYS_EXIT
    adrp x1, exit_args
    add x1, x1, :lo12:exit_args
    hlt #0xf000

.section ".rodata" // Read Only Data
.balign 8
exit_args:
    .quad 0x20026 // Normal application exit
    .quad 0 // Exit status
