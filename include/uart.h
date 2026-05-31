#include <stdint.h>

#define UART0_BASE 0x10000000UL
#define UART0_THR  (*(volatile uint8_t *)(UART0_BASE + 0x00))

void uart_putchar(char c)
{
    UART0_THR = (uint8_t)c;
}

void uart_puts(const char *s)
{
    while (*s)
    {
        if (*s == '\n')
            uart_putchar('\r');

        uart_putchar(*s++);
    }
}