/* platform_rpi.S */
.global platform_exit
platform_exit:
    msr daifset, #0xf   // mask interrupts
1:
    wfi                 // sleep until an interrupt
    b 1b