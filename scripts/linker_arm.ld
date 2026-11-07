/* PassOS ARM64 Kernel Linker Script
   Target: AArch64, loaded at 0x80000 (standard U-Boot load address for RPi). */

OUTPUT_FORMAT("elf64-littleaarch64")
OUTPUT_ARCH(aarch64)
ENTRY(_start)

SECTIONS
{
    . = 0x0000000000080000;

    .text : ALIGN(4096)
    {
        boot/arm/boot_arm.o(.text.boot)
        *(.text*)
    }

    .rodata : ALIGN(4096)
    {
        *(.rodata*)
    }

    .data : ALIGN(4096)
    {
        *(.data*)
    }

    .bss : ALIGN(4096)
    {
        bss_start = .;
        *(.bss*)
        *(COMMON)
        bss_end = .;
    }

    /DISCARD/ :
    {
        *(.eh_frame)
        *(.comment)
        *(.note*)
    }
}
