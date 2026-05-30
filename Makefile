# Bare-metal RISC-V startup example
# Default toolchain prefix works with riscv64-unknown-elf-gcc.
# Override it like this:
#   make CROSS_COMPILE=riscv64-linux-gnu-

CROSS_COMPILE ?= riscv64-unknown-elf-
CC            := $(CROSS_COMPILE)gcc
OBJCOPY       := $(CROSS_COMPILE)objcopy
OBJDUMP       := $(CROSS_COMPILE)objdump
SIZE          := $(CROSS_COMPILE)size

TARGET        := firmware
LINKER_SCRIPT := linker.ld

SRCS          := startup.s main.c
OBJS          := $(SRCS:.c=.o)
OBJS          := $(OBJS:.s=.o)

ARCH_FLAGS    := -march=rv64imac -mabi=lp64
MODEL_FLAGS   := -mcmodel=medany -msmall-data-limit=0
COMMON_FLAGS  := $(ARCH_FLAGS) $(MODEL_FLAGS)
CFLAGS        := $(COMMON_FLAGS) -Wall -Wextra -O0 -g -ffreestanding -nostdlib -nostartfiles
ASFLAGS       := $(COMMON_FLAGS) -g
LDFLAGS       := $(COMMON_FLAGS) -T $(LINKER_SCRIPT) -nostdlib -nostartfiles -Wl,-Map=$(TARGET).map

.PHONY: all clean dump size

all: $(TARGET).elf $(TARGET).bin $(TARGET).dump size

$(TARGET).elf: $(OBJS) $(LINKER_SCRIPT)
	$(CC) $(OBJS) $(LDFLAGS) -o $@

%.o: %.c
	$(CC) $(CFLAGS) -c $< -o $@

%.o: %.s
	$(CC) $(ASFLAGS) -c $< -o $@

$(TARGET).bin: $(TARGET).elf
	$(OBJCOPY) -O binary $< $@

$(TARGET).dump: $(TARGET).elf
	$(OBJDUMP) -D $< > $@

dump: $(TARGET).dump

size: $(TARGET).elf
	$(SIZE) $<


run: firmware.elf
	qemu-system-riscv64 \
		-machine virt \
		-nographic \
		-bios none \
		-kernel firmware.elf

debug: firmware.elf
	qemu-system-riscv64 \
		-machine virt \
		-nographic \
		-bios none \
		-kernel firmware.elf \
		-S -s

gdb: firmware.elf
	gdb-multiarch firmware.elf \
		-ex "target remote :1234" \
		-ex "break _start" \
		-ex "break main" \
		-ex "continue"

clean:
	rm -f *.o $(TARGET).elf $(TARGET).bin $(TARGET).dump $(TARGET).map
