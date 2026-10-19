/*  gpio_utils.h

Declares subroutines in gpio_utils.S,
and methods in gpio_utils.c

*/

#ifndef gpio_utils_h
#define gpio_utils_h

#include "types.h"

// defined in gpio_utils.S
void led_init(void);
void led_off(void);
void led_on(void);

void uart_init(void);
void uart_putc(char c);
char uart_getc(void);
void uart_puts(char * c);

uint64_t *uart_debug_write(uintptr_t *address);
void uart_debug_print(uintptr_t *address);

char *reg_to_ascii(uint64_t value, uint64_t byte_count);

// Return values of 
struct cnb_status {
    char c;
    uint32_t read_flag;
};

struct cnb_status uart_getc_nb(void);

// defined in gpio_utils.c
void sleep_ms(uint64_t milliseconds);

// Linker data space
extern uintptr_t __data_bottom[];

#endif