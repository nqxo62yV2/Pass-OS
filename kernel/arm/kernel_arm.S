// PassOS ARM64 (AArch64) kernel entry stub.
//
// The full PassOS kernel is currently x86-64 only. This stub gives the ARM
// boot path a real, linkable target so the cross-toolchain build stays green:
// it prints a banner on the QEMU "virt" PL011 UART and halts.

.section ".text"
.global kernel_main

kernel_main:
    // PL011 UART data register for QEMU virt.
    ldr x0, =0x09000000
    adr x1, arm_banner

1:
    ldrb w2, [x1], #1
    cbz w2, 3f
2:
    // Wait until the UART TX FIFO has room (FR bit 5 clear).
    ldr w3, [x0, #0x18]
    tbnz w3, #5, 2b
    strb w2, [x0]
    b 1b

3:
    wfe
    b 3b

.section ".rodata"
.balign 8
arm_banner:
    .asciz "\r\nPassOS ARM64: boot stub OK\r\n"
