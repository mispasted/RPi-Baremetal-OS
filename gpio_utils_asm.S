
/* Authored by Mispasted 

This is a translation from working C code built by ChatGPT, and
that I suspect was based on the RTEMS UART implementation. I 
added additional comments for readability as well as understanding 
the process for setting up UART.This code was originally written
for the RaspberryPi 4B, with the following firmware 'config.txt' 
parameters:

``` config.txt
dtoverlay=disable-bt
arm_64bit=1
kernel=kernel8.img
enable_uart=1
kernel_address=0x80000
init_uart_clock=48000000
arm_peri_high=1
```

Applicable references: 

- RaspberryPi BCM2711 Peripheral Manual
    https://pip-assets.raspberrypi.com/categories/545-raspberry-pi-4-model-b/documents/RP-008248-DS-1-bcm2711-peripherals.pdf
- RTEMS UART Implementation
    https://docs.rtems.org/doxygen/main/bsps_2aarch64_2raspberrypi_2include_2bsp_2console_8h_source.html
*/


// The Following section defines important Register locations. 
// The base addresses assume "high peripheral mode"
// These addresses were found in the peripheral manual
// When compiling for Physical RPi:
//GPIO_BASE_ADDR = 0x47E200000
//UART_BASE_ADDR = 0x47E201000
#include "gpio_utils.h"

// GPIO Alternate Function Selector
// Will need for setting FSEL for GPIO 14 and 15, which 
// will have Alt0 functionality. (Connect to UART0).
// FSEL15 = 17:15
// FSEL14 = 14:12
.set                 GPFSEL1, (GPIO_BASE_ADDR + 0x04)
.set GPIO_PUP_PDN_CNTRL_REG0, (GPIO_BASE_ADDR + 0xE4)
.set                  GPSET0, (GPIO_BASE_ADDR + 0x1C)
.set                  GPCLR0, (GPIO_BASE_ADDR + 0x28)

// UART Registers - Mapped from table 172 of the Peripheral Manual
.set DR,     (UART_BASE_ADDR + 0x00) // Data Register
.set FR,     (UART_BASE_ADDR + 0x18) // Flag Register
.set IBRD,   (UART_BASE_ADDR + 0x24) // Integer Baud Rate Divisor
.set FBRD,   (UART_BASE_ADDR + 0x28) // Fraction Baud Rate Divisor
.set LCRH,   (UART_BASE_ADDR + 0x2C) // Line Control Register
.set CR,     (UART_BASE_ADDR + 0x30) // Control Register
.set IMSC,   (UART_BASE_ADDR + 0x38) // Interrupt Mask Set Clear Register
.set ICR,    (UART_BASE_ADDR + 0x44) // Interrupt Clear Register

// Initialize uart
/*  As read from the Peripheral Manual:
Program the control registers as follows:
1. Disable the UART.
2. Wait for the end of transmission or reception of the current character.
3. Flush the transmit FIFO by setting the FEN bit to 0 in the Line Control Register, UART_LCRH.
4. Reprogram the Control Register, UART_CR.
5. Enable the UART */ 
.global uart_init
uart_init:
    // Chapter 1 of the Peripheral Manual specifies a Data Memory Barrier 
    // instructions be written before and after accessing any single
    // peripheral:
    dmb st // Memory Write ("Store") Barrier - before first MMIO write

    // Peripheral registers are 32 bits wide; w10 will store the write_datae
    // Addresses are 64 bits wide; x9 will store the reg_address, 

// 1. --- Disable UART: ---
    ldr x9,  =CR            // Setting CR to 0x0 disables the UART 
    str wzr, [x9]

// 2. --- Wait for transmission and reception --
    // FR bit 3 contains BUSY signal - set indicates transmission in progress
    // FR bit 4 contains RXFE signal - unset indicates recieve FIFO contains data
wait_for_tx_rx_complete:
    ldr  x9,  =FR
    ldr  w10, [x9]
    tbnz w10, #3, wait_for_tx_rx_complete
    //tbz  w10, #4, wait_for_tx_rx_complete //comment out while the system is single core and thread 

// 3. --- Flush and disable the FIFO ---
    ldr x9, =LCRH           // Set LCRH to 0x0
    str wzr, [x9]

// --- Edit UART configuration ---
    ldr x9,  =IMSC          // Setting IMSC to 0x0 masks all interrupts
    str wzr, [x9]

    ldr x9,  =ICR           // Clears pending interrupt state (Set all to 1)
    mov w10, #0x7FF
    str w10, [x9]

    
    // Read current FSEL values, then set the functions of GPIO's 14 and 15 to alt0 (FSEL = 100)
    // GPFSEL1 and FSEL values are in table 64 of the Peripheral Manual.
    ldr x9,  =GPFSEL1
    ldr w10, [x9]           // w10 is GPFSEL1; instruction loads the current function select bits
    mov w11, #0b100         // w11 is FSEL
    bfi w10, w11, #12, #3   // Insert FSEL into the proper location of GPFSEL1:
    bfi w10, w11, #15, #3   // Bit position #12 is GPIO 14, #15 is GPIO 15
    str w10, [x9]           // Store the modified function select bits back into GPFSEL1

    // GPIO_PUP_PDN_CNTRL_REG0 determines the "pull up/neutran/down" state when no driving signal 
    // exists from the PL011 UART controller. To not send an erroneous signal, it's best 
    // practice to let them "float" (set to neutral).
    // Bit locations and value options are in table 90 of the Peripheral Manual.
    // We set bits 28-31 to zero. 
    // 29:28 is GPIO14, while 31:31 is GPIO15.
    ldr x9,  =GPIO_PUP_PDN_CNTRL_REG0
    ldr w10, [x9]                       // Now w10 contains the current value in GPIO_PUP-
    bfi w10, wzr, #28, #4               // Bit Field Insert four "0" bits
    str w10, [x9]                       // Store the modified value

    // The IBRD and FBRD set the baudrate based on UARTCLK signal.
    // 48 MHz UART clock, 115200 baud:
    // divisor = 48,000,000 / (16 * 115,200) = 26 + 3/64.
    ldr x9,  =IBRD
    mov w10, #26
    str w10, [x9]

    ldr x9,  =FBRD
    mov w10, #3
    str w10, [x9]

    // LCRH register documentation is Table 179 of the Peripheral Manual.
    // We must:
    // - Enable a word length of 8 bits (a byte): set 6:5 to 0b11
    // - Enable the FIFO's: set 4 to 0b1 (This is the FEN bit)
    // NOTE: I found by trial and error that FIFOs can only be enabled just prior to setting UARTEN
    // else the PL011 simply doesn't transmit.
    ldr x9, =LCRH
    ldr w10, =((0b11 << 5) | 0b1 << 4)     // =0b0111_0000; Enable FIFOS with desired settings
    str w10, [x9]

// --- 4. and 5. Program CR to enable UART ---
    // NOTE: To enable transmission, the TXE bit (bit 8) and UARTEN bit (bit 0) must be set to 1. Similarly,
    // to enable reception, the RXE bit (bit 9) and UARTEN bit, must be set to 1
    ldr x9,  =CR
    ldr w10, =((0b1 << 9 ) | (0b1 << 8) | 0b1 << 0) // 11_0000_0001 
    str w10, [x9]

    // Init is complete, no more reads will occur from the PL011
    dmb ld // Memory Read ("Load") Barrier - after last MMIO read

    ret 

// Adds a single character to the uart transmit FIFO. The PL011 controller
// will take care of the rest. 
// the UART must be initiated first, (call uart_init).
// Arguments:
//  w0 - The character to send
// Returns:
//  None
.global uart_putc
uart_putc:
   dmb st // Prior to store data memory barrier
   // Wait if the transmit FIFO is full 
   // (Indicated by FR bit 5)
   ldr  x9,  =FR
1:
   ldr  w10, [x9]
   tbnz w10, #5, 1b 

   ldr x9,  =DR
   str w0,  [x9]

   ret

// Read a single character to the uart recieve FIFO. The PL011 controller
// will take care of the rest. 
// the UART must be initiated first, (call uart_init).
// Arguments:
//  None
// Returns:
//  w0 - The recieved character 
.global uart_getc
uart_getc:
   // Wait if the recieve FIFO is empty. 
   // (Indicated by FR bit 4)
   ldr  x9,  =FR
1:
   ldr  w10, [x9]
   tbnz w10, #4, 1b 

   ldr x9,  =DR
   ldr w0,  [x9]
   uxtb w0, w0 // Only bit positions 0:7 hold data in the recieve FIFO.   

   dmb  ld // After load, data memory barrier
   ret
// 

// Read a single character (non-blocking) to the uart recieve FIFO. The PL011 controller
// will take care of the rest. This function does not guarentee a character was read, but
// will inform the caller if  
// the UART must be initiated first, (call uart_init).
// Arguments:
//  None
// Returns:
//  w0 - The recieved character (if able) 
//  w1 - Character available flag, set if a char was available to read.
.global uart_getc_nb
uart_getc_nb:
   // Check if the recieve FIFO is empty. 
   // (Indicated by FR bit 4)
   ldr  x9,  =FR
   ldr  w10, [x9]
   tbnz w10, #4, fifo_empty

char_avail:
   ldr x9,  =DR
   ldr w0,  [x9]
   uxtb w0, w0 // Only bit positions 0:7 hold data in the recieve FIFO.   
   mov w1, #1
   b 1b

fifo_empty:
   mov w0, wzr
   mov w1, wzr

1:
   dmb  ld // After load, data memory barrier
   ret

// Write's current UART0 registers to the specified memory location. 
// Not perfect, but does the trick.
// Arguments:
//  - x0 is the location to start writing
// Returns:
//  None
.global uart_debug_write
uart_debug_write:
   mov x17, x0 

   ldr x9, =GPFSEL1
   ldr w10, [x9]
   ldr x9, =GPIO_PUP_PDN_CNTRL_REG0
   ldr w11, [x9]
   stp x10, x11, [x17], #16
   
   ldr x9, =DR
   ldr w10, [x9]
   ldr x9, =FR
   ldr w11, [x9]
   stp x10, x11, [x17], #16

   ldr x9, =IBRD
   ldr w10, [x9]
   ldr x9, =FBRD
   ldr w11, [x9]
   stp x10, x11, [x17], #16
   
   ldr x9, =LCRH
   ldr w10, [x9]
   ldr x9, =CR
   ldr w11, [x9]
   stp x10, x11, [x17], #16

   ldr x9, =IMSC
   ldr w10, [x9]
   ldr x9, =ICR
   ldr w11, [x9]
   stp x10, x11, [x17], #16
   
   mov x0, x17

   ret

// Initiate general I/O for pin 17 - there may be an led there.
// No return or argument registers are used.
.global led_init
led_init:
    dmb st
    // GPIO17 occupies GPFSEL1 bits 23:21.

    ldr x9, =GPFSEL1
    ldr w10, [x9]

    bfi w10, wzr, #21, #3    // clear its function field
    mov w11, #1
    bfi w10, w11, #21, #3    // 001 = output
    str w10, [x9]

    dmb ld

    ret

// Turn pin 17 on.
// Must initiate pin 17 first, (call led_init)
// No return or argument registers are used.
.global led_on
led_on:
    dmb st
    ldr x9, =GPSET0
    mov w10, #(1 << 17)
    str w10, [x9]            // drive GPIO17 high

    ret 

// Turn pin 17 off.
// Must initiate pin 17 first, (call led_init)
// No return or argument registers are used.
.global led_off
led_off:
    dmb st
    ldr x9, =GPCLR0
    mov w10, #(1 << 17)
    str w10, [x9]            // drive GPIO17 low 

    ret 

// Stores the value of a specified register in ascii.
// This procedure takes the register x0, and treats it's
// contents as a x1 * 1-byte value. Meaning, x1 contains the
// number of bytes to be decoded to ascii.
// Each set of 4 bits will be converted to an ascii character 
// and stored in memory as hexidecimal.
// Arguments:
//  x0 - The register to encode in ascii
//  x1 - The number of bytes to encode. (min 1, max 8)
// Returns:
//  x0 - The start address in which the string (null-terminated 
//       char array) is stored.
.global reg_to_ascii
reg_to_ascii:
    // Load the Address
    adrp x17, array
    add x17, x17, :lo12:array
    mov x8, x17

    // store "0x" at the beginning of string
    mov w9, #'0' // store ascii value for '0'
    strb w9, [x8]
    mov w9, #'x' // store ascii value for 'x'
    strb w9, [x8, #1]

    // Compute the final address
    // x8 + 2(bytes) + x1 * 2 - 1 OR x9 = x8 + 1 + (x1 * 2)
    lsl x10, x1, #1 // multipy x1 by two, store in x10
    add x8, x8, #2  // x8 = x8 + 2
    add x9, x8, x10 // x9 = x8 + (x1 * 2) //x9 = first write location

    mov w10, #0 // This will be null
    strb w10, [x9] // Store the null
    sub x9, x9, #1 // x9--; x9 =  second write location

rta_loop:
// Registers:
// x0 - register to encode
// x9 - write-to location
// x8 - last write location
// w11 - 4 bit cleaned value/then ascii
    and x11, x0, #0xf
    subs wzr, w11, #10 // subtraction and set NZCV bit
    b.ge rta_greater_than_equal_10

rta_less_than_10:
    add w11, w11, #'0' // Adding 48/'0' gives the ascii value for this range
    b rta_loop_continue // don't perfrom steps for >= 10

rta_greater_than_equal_10:
    add w11, w11, #55 // Adding 55/('A' - 10)  gives ascii value for this range
    // continue

rta_loop_continue:
    strb w11, [x9] // store the calculated ascii value
    lsr x0, x0, #4 //shift the encode-ee by four bits.
    sub x9, x9, #1 // subtract one from address
    cmp x9, x8 // Compare if the address is one we shouldn't go into.
    b.ge rta_loop
    // Don't loop if x9 < x8

// Finish procedure:
    mov x0, x17 // Return the address of array
    ret

.section ".data" // Data that is initialized
array:
    .fill 65, 1, 0xFF
    // .fill repeat, size, value