/* PassOS Kernel Linker Script
   Target: x86-64, loaded at physical address 0x100000 (1 MB mark)
   Produces a flat binary-compatible ELF suitable for objcopy -O binary. */

OUTPUT_FORMAT("elf64-x86-64")
OUTPUT_ARCH(i386:x86-64)
ENTRY(kernel_main)

SECTIONS
{
    . = 0x0000000000100000;

    .text : ALIGN(4096)
    {
        *(.text.boot)
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
