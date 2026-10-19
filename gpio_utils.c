#include "gpio_utils.h"
#include "uart1.h"


void uart_puts(char *char_ptr)
{
    for(; *char_ptr != '\0' ; char_ptr++)
        uart_putc(*char_ptr);
}

// Prints data as it would be written by uart_debug_write.
// Call uart_debug_write first, then print appropriate data
// with this function after the fact.
void uart_debug_print(uint64_t *address)
{
    volatile uint64_t *data = (volatile uint64_t *)address;
    static const char *const names[] = {"GPFSEL1", "GPIO_PUP_PDN_CNTRL_REG0", "DR", "FR", "IBRD", "FBRD", "LCRH", "CR", "IMSC", "ICR"};
    uint64_t len = sizeof(names) / sizeof(names[0]);
    for (int i = 0; i < len; i++)
    {
        uart1_puts(reg_to_ascii(data[i], 4));
        uart1_puts(" in reg: ");
        uart1_puts(names[i]);
        uart1_puts("\n");
    }
}

static uint64_t counter_frequency(void)
{
    uint64_t value;
    __asm__ volatile ("mrs %0, cntfrq_el0" : "=r"(value));
    return value;                 // ticks per second
}

static uint64_t counter_value(void)
{
    uint64_t value;
    __asm__ volatile ("mrs %0, cntpct_el0" : "=r"(value));
    return value;                 // current tick count
}

void sleep_ms(uint64_t milliseconds)
{
    uint64_t ticks = (counter_frequency() * milliseconds) / 1000;
    uint64_t start = counter_value();

    while ((uint64_t)(counter_value() - start) < ticks) {
        __asm__ volatile ("yield");
    }
}