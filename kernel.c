#include "gpio_utils.h"

void main()
{

    led_init();
    uart_init();
    uart_puts("[Kernel.c] GPIO17/LED and GPIO14&GPIO15/UART0 Initialized.\r\n");

    uart_puts("[Kernel.c] Completed program. Transmit 'q' to reboot.\r\n");
    led_on();
    for(char c = uart_getc() ;; c = uart_getc())
    {   
        
        if (c == 'q') break;
        uart_putc(c);
    }
}