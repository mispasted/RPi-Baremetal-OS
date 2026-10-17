.section ".text.boot" // Make sure the linker puts this at the start of the kernel image

.global _start // Execution starts here

_start:
    // Check processor ID is zero (executing on main core), else hang
    mrs x1, mpidr_el1
    and x1, x1, #3
    cbz x1, 2f
    // We're not on the main core, so hang in an infinite wait loop
1:
    wfe
    b 1b
2: // We're on the main core!

    // Set stack to start below our code
    ldr x1, =_start
    mov sp, x1

    // Clean the BSS section
    ldr x1, =__bss_start // Start address
    ldr w2, =__bss_size // Size of the section
3:
    cbz w2, 4f // Quit loop if zero
    str xzr, [x1], #8
    sub w2, w2, #1
    cbnz w2, 3b // Loop if non-zero

4:
    bl uart_init // init uart
    bl run // run code

5:  b platform_exit

// AArch64, Pi 4, MMU off / peripheral address mapped at 0xFE100000
// Causes a warm full-system reset; does not cut power.

//    ldr     x0, =0xFE100024          // PM_WDOG
//    mov     w1, #10                  // timeout: a few hundred microseconds
//    movk    w1, #0x5A00, lsl #16     // required PM password
//    str     w1, [x0]
//
//    ldr     x0, =0xFE10001C          // PM_RSTC
//    ldr     w1, [x0]
//    and     w1, w1, #0xFFFFFFCF      // clear reset configuration bits
//    orr     w1, w1, #0x20            // full reset mode
//    movk    w1, #0x5A00, lsl #16     // required PM password
//    str     w1, [x0]
//
//    dsb     sy
// 6:  wfe
//    b       1b
    
    

.section ".rodata" // Read Only Data
.balign 8
exit_args:
    .quad 0x20026 // Normal application exit
    .quad 0 // Exit status
