    .section .init
    .globl _start
    .type _start, @function

_start:
    /* Set stack pointer. _stack_top is defined in linker.ld */
    la sp, _stack_top

    /* Clear .bss section */
    la t0, __bss_start
    la t1, __bss_end

clear_bss:
    bgeu t0, t1, copy_data
    sw zero, 0(t0)
    addi t0, t0, 4
    j clear_bss

copy_data:
    /* Copy .data from FLASH load address to RAM */
    la t0, __data_load
    la t1, __data_start
    la t2, __data_end

copy_data_loop:
    bgeu t1, t2, call_main
    lw t3, 0(t0)
    sw t3, 0(t1)
    addi t0, t0, 4
    addi t1, t1, 4
    j copy_data_loop

call_main:
    /* Call C application entry */
    call main

hang:
    j hang
