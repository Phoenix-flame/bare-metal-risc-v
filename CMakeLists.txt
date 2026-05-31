cmake_minimum_required(VERSION 3.20)

# --- Cross toolchain (self-contained, no -DCMAKE_TOOLCHAIN_FILE needed) ------
# Override the prefix if yours differs:
#   cmake -B build -DCROSS_COMPILE=riscv64-linux-gnu-
set(CROSS_COMPILE "riscv64-unknown-elf-" CACHE STRING "Cross toolchain prefix")

set(CMAKE_SYSTEM_NAME Generic)
set(CMAKE_SYSTEM_PROCESSOR riscv)

set(CMAKE_C_COMPILER   ${CROSS_COMPILE}gcc)
set(CMAKE_ASM_COMPILER ${CROSS_COMPILE}gcc)
set(CMAKE_OBJCOPY      ${CROSS_COMPILE}objcopy CACHE FILEPATH "objcopy")
set(CMAKE_OBJDUMP      ${CROSS_COMPILE}objdump CACHE FILEPATH "objdump")
set(CMAKE_SIZE         ${CROSS_COMPILE}size    CACHE FILEPATH "size")

# Building a freestanding firmware: don't link a host test program when CMake
# probes the compiler.
set(CMAKE_TRY_COMPILE_TARGET_TYPE STATIC_LIBRARY)

project(firmware
    LANGUAGES C ASM
    DESCRIPTION "Minimal RV64 bare-metal startup example")

# --- Target architecture (matches the Makefile) ----------------------------
set(ARCH  "rv64imac" CACHE STRING "RISC-V ISA string (-march)")
set(ABI   "lp64"     CACHE STRING "RISC-V ABI (-mabi)")
set(MODEL "medany"   CACHE STRING "Code model (-mcmodel)")

set(COMMON_FLAGS -march=${ARCH} -mabi=${ABI} -mcmodel=${MODEL} -msmall-data-limit=0)

set(LINKER_SCRIPT ${CMAKE_CURRENT_SOURCE_DIR}/linker.ld)

# --- Build the ELF ----------------------------------------------------------
add_executable(firmware.elf
    startup.s
    main.c)

target_include_directories(firmware.elf PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}/include)

target_compile_options(firmware.elf PRIVATE
    ${COMMON_FLAGS}
    $<$<COMPILE_LANGUAGE:C>:-Wall -Wextra -O0 -g -ffreestanding -nostdlib -nostartfiles>
    $<$<COMPILE_LANGUAGE:ASM>:-g>)

target_link_options(firmware.elf PRIVATE
    ${COMMON_FLAGS}
    -nostdlib -nostartfiles
    -T ${LINKER_SCRIPT}
    -Wl,-Map=$<TARGET_FILE_DIR:firmware.elf>/firmware.map)

# Relink when the linker script changes.
set_target_properties(firmware.elf PROPERTIES LINK_DEPENDS ${LINKER_SCRIPT})

# --- Post-build: raw binary, disassembly dump, size report ------------------
add_custom_command(TARGET firmware.elf POST_BUILD
    COMMAND ${CMAKE_OBJCOPY} -O binary $<TARGET_FILE:firmware.elf> firmware.bin
    COMMAND ${CMAKE_OBJDUMP} -D       $<TARGET_FILE:firmware.elf> > firmware.dump
    COMMAND ${CMAKE_SIZE}             $<TARGET_FILE:firmware.elf>
    BYPRODUCTS firmware.bin firmware.dump
    COMMENT "Generating firmware.bin, firmware.dump and size report")

# --- Convenience targets: run / debug in QEMU -------------------------------
set(QEMU_FLAGS -machine virt -nographic -bios none -kernel $<TARGET_FILE:firmware.elf>)

add_custom_target(run
    COMMAND qemu-system-riscv64 ${QEMU_FLAGS}
    DEPENDS firmware.elf
    USES_TERMINAL
    COMMENT "Running firmware in QEMU")

add_custom_target(debug
    COMMAND qemu-system-riscv64 ${QEMU_FLAGS} -S -s
    DEPENDS firmware.elf
    USES_TERMINAL
    COMMENT "Running firmware in QEMU, halted, waiting for GDB on :1234")
