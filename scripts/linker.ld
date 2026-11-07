/* PassOS Kernel Linker Script
   Target: x86-64, loaded by GRUB2 Multiboot2 at 0x100000 (1 MiB mark).

   The .multiboot section MUST be the first allocated section so the
   Multiboot2 header lands in the first 32 KiB of the ELF file.
   Link with -z max-page-size=0x1000 (see scripts/build.sh). */

OUTPUT_FORMAT("elf64-x86-64")
OUTPUT_ARCH(i386:x86-64)
ENTRY(kernel_entry)

SECTIONS
{
    . = 0x0000000000100000;

    /* Multiboot2 header must be in the first 32 KiB and 8-byte aligned */
    .multiboot : ALIGN(8)
    {
        KEEP(*(.multiboot))
    }

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
