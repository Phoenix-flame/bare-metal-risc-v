#include <stdint.h>

volatile uint32_t counter = 0;
uint32_t initialized_data = 0x12345678;
uint32_t uninitialized_data;


static void delay(volatile uint64_t count)
{
    while (count--)
    {
        __asm__ volatile ("nop");
    }
}

int main(void)
{
    uninitialized_data = initialized_data;

    while (1)
    {
        counter++;

        delay(1000000);
    }

    return 0;
}
