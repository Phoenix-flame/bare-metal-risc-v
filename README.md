# RISC-V Bare-Metal Startup Example

This project is a minimal **bare-metal RISC-V** example. It starts from assembly code, initializes memory, then jumps to a C function.

It is useful for learning how embedded RISC-V startup code works before using a full RTOS or vendor SDK.

## What this example does

At reset, execution starts from `_start` in `startup.s`.

The startup code does the following:

1. Sets the stack pointer using `_stack_top` from the linker script.
2. Clears the `.bss` section.
3. Copies initialized `.data` variables from flash/load memory to RAM.
4. Calls the C `main()` function.
5. Enters an infinite loop if `main()` ever returns.

The C example contains a global `counter` variable that increments forever with a delay. You can inspect this variable from GDB.

## Project files

```text
.
├── Makefile
├── README.md
├── linker.ld
├── main.c
└── startup.s
```

| File | Description |
|---|---|
| `startup.s` | RISC-V assembly startup code. Defines `_start`. |
| `main.c` | Simple C application with a delayed `counter++` loop. |
| `linker.ld` | Linker script defining FLASH, RAM, sections, and stack top. |
| `Makefile` | Build, run, debug, dump, and clean commands. |
| `README.md` | This guide. |

## Required packages

On Ubuntu/Debian, install the tools:

```bash
sudo apt update
sudo apt install gcc-riscv64-unknown-elf binutils-riscv64-unknown-elf qemu-system-misc gdb-multiarch make
```

If your distro does not provide `riscv64-unknown-elf-gcc`, you can use another RISC-V bare-metal toolchain and pass the prefix to `make`.

Example:

```bash
make CROSS_COMPILE=riscv64-linux-gnu-
```

For this bare-metal project, `riscv64-unknown-elf-` is preferred.

## Build

```bash
make
```

This generates:

| Output | Description |
|---|---|
| `firmware.elf` | ELF file with symbols, useful for QEMU and GDB. |
| `firmware.bin` | Raw binary image. |
| `firmware.dump` | Disassembly output. |
| `firmware.map` | Linker map file. |

## Clean build files

```bash
make clean
```

## Run in QEMU

This is a bare-metal program, so do **not** run it with `qemu-riscv64`.

Wrong:

```bash
qemu-riscv64 ./firmware.elf
```

Correct:

```bash
make run
```

This runs:

```bash
qemu-system-riscv64 \
    -machine virt \
    -nographic \
    -bios none \
    -kernel firmware.elf
```

You will not see output because this example does not use UART yet. The program is still running and incrementing `counter`.

To exit QEMU:

```text
Ctrl + A, then X
```

## Debug with GDB

Use two terminals.

### Terminal 1

Start QEMU and wait for GDB:

```bash
make debug
```

This starts QEMU with:

```bash
-S -s
```

Meaning:

| Option | Meaning |
|---|---|
| `-S` | Start paused. |
| `-s` | Open GDB server on TCP port `1234`. |

### Terminal 2

Connect GDB:

```bash
make gdb
```

The Makefile runs:

```bash
gdb-multiarch firmware.elf \
    -ex "target remote :1234" \
    -ex "break _start" \
    -ex "break main" \
    -ex "continue"
```

If `gdb-multiarch` is missing, install it:

```bash
sudo apt install gdb-multiarch
```

## Useful GDB commands

### Show source around current location

```gdb
list
```

### Step one source line

```gdb
step
```

or shorter:

```gdb
s
```

### Step one assembly instruction

```gdb
stepi
```

or shorter:

```gdb
si
```

### Continue running

```gdb
continue
```

or:

```gdb
c
```

### Stop running program

Press:

```text
Ctrl + C
```

inside GDB.

### Show registers

```gdb
info registers
```

or:

```gdb
i r
```

### Show program counter

```gdb
p/x $pc
```

### Show stack pointer

```gdb
p/x $sp
```

## Check the `counter` value

The example has this global variable in `main.c`:

```c
volatile uint64_t counter = 0;
```

Because it is `volatile`, the compiler keeps updating it in memory.

In GDB:

```gdb
p counter
```

or:

```gdb
print counter
```

To show it in hexadecimal:

```gdb
p/x counter
```

To show its address:

```gdb
p/x &counter
```

To keep displaying it whenever GDB stops:

```gdb
display counter
```

To stop when `counter` changes:

```gdb
watch counter
continue
```

To stop when it reaches a specific value:

```gdb
break main.c:19 if counter == 10
continue
```

Line numbers may differ if you edit `main.c`.

## Breakpoints

### Add breakpoint

```gdb
break main
```

or:

```gdb
b main
```

### Add breakpoint at a line

```gdb
break main.c:17
```

### Show breakpoints

```gdb
info breakpoints
```

or:

```gdb
i b
```

### Delete one breakpoint

For example, delete breakpoint number `1`:

```gdb
delete 1
```

or:

```gdb
d 1
```

### Delete all breakpoints

```gdb
delete
```

GDB will ask for confirmation.

### Disable breakpoint

```gdb
disable 1
```

### Enable breakpoint again

```gdb
enable 1
```

## Inspect generated assembly

Generate and open the dump:

```bash
make dump
```

Search for startup code:

```text
_start
```

Search for the C entry:

```text
main
```

You should see startup code eventually calling `main`.

## Important build flags

The Makefile uses:

```make
-mcmodel=medany -msmall-data-limit=0
```

### `-mcmodel=medany`

The linker script places code around address `0x80000000`. Without `-mcmodel=medany`, GCC may generate relocations that cannot reach global variables, causing errors such as:

```text
relocation truncated to fit: R_RISCV_HI20
```

### `-msmall-data-limit=0`

This disables automatic use of RISC-V small-data addressing through `gp`.

A more complete startup could initialize the global pointer register `gp`, but this minimal example avoids depending on it.

The linker script still includes `.sdata`, `.sbss`, and `.srodata` sections for safety.

## Memory map

The linker script uses this simple memory layout:

```ld
MEMORY
{
    FLASH (rx)  : ORIGIN = 0x80000000, LENGTH = 512K
    RAM   (rwx) : ORIGIN = 0x80080000, LENGTH = 128K
}
```

| Region | Address | Usage |
|---|---:|---|
| `FLASH` | `0x80000000` | Code and read-only data. |
| `RAM` | `0x80080000` | `.data`, `.bss`, stack. |

The stack top is defined as:

```ld
_stack_top = ORIGIN(RAM) + LENGTH(RAM);
```

## Startup flow

Simplified flow:

```text
_start
  ├── set sp = _stack_top
  ├── clear .bss
  ├── copy .data
  ├── call main
  └── hang forever if main returns
```

## Why there is no terminal output

This example does not configure UART.

So `printf()` will not work unless you add:

1. UART driver code,
2. linker support if needed,
3. syscall stubs if using libc/newlib,
4. or a custom `putchar()` implementation.

For now, use GDB to verify program behavior by checking `counter`.

## Common problems

### `riscv64-unknown-elf-gcc: command not found`

Install the RISC-V bare-metal compiler:

```bash
sudo apt install gcc-riscv64-unknown-elf
```

### `riscv64-unknown-elf-gdb: command not found`

Use `gdb-multiarch` instead:

```bash
sudo apt install gdb-multiarch
```

Then run:

```bash
make gdb
```

### `qemu-system-riscv64: command not found`

Install QEMU system emulators:

```bash
sudo apt install qemu-system-misc
```

### Program runs but nothing is printed

That is expected. There is no UART output in this example.

Use GDB:

```gdb
p counter
```

### QEMU user-mode gives segmentation fault

Do not use this:

```bash
qemu-riscv64 ./firmware.elf
```

That command is for Linux user-mode binaries.

Use:

```bash
make run
```

or:

```bash
make debug
```

## Next steps

Good improvements to add after this example:

1. UART output for `putchar()`.
2. Simple `printf()` support.
3. Trap/interrupt vector setup.
4. Machine timer interrupt.
5. C runtime constructors for C++ support.
6. `gp` initialization if you want to use small-data sections.
