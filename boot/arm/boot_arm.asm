// PassOS ARM64 (AArch64) Boot Entry
// Loaded by U-Boot or compatible ARM firmware.
// Initializes the execution environment and jumps to the ARM kernel entry.

.section ".text.boot"
.global _start

_start:
    mrs x0, CurrentEL
    lsr x0, x0, #2
    cmp x0, #2
    b.eq el2_init
    cmp x0, #1
    b.eq el1_init
    b hang

el2_init:
    mov x0, #0x5B1
    msr hcr_el2, x0
    mov x0, #0x3C5
    msr spsr_el2, x0
    adr x0, el1_init
    msr elr_el2, x0
    eret

el1_init:
    mov x0, xzr
    msr ttbr0_el1, x0
    msr ttbr1_el1, x0

    ldr x0, =0x00000005
    msr mair_el1, x0

    ldr x0, =0x00000000B5193519
    msr tcr_el1, x0

    isb

    adr x0, vector_table
    msr vbar_el1, x0

    ldr x0, =stack_top
    mov sp, x0

    ldr x0, =bss_start
    ldr x1, =bss_end
    sub x1, x1, x0
    bl memzero

    ldr x0, =kernel_main
    br x0

hang:
    wfe
    b hang

memzero:
    cbz x1, 1f
    str xzr, [x0], #8
    sub x1, x1, #8
    b memzero
1:
    ret

.section ".bss"
.balign 4096
bss_start:
.space 0x10000
bss_end:

.balign 16
.space 0x8000
stack_top:

.section ".text"
.balign 2048
vector_table:
.space 2048
