; PassOS Kernel Entry Point
; Architecture: x86-64
; Entry is called from the stage-2 bootloader after long mode is established.

BITS 64

global kernel_main
extern memory_init
extern interrupts_init
extern scheduler_init
extern system_init
extern terminal_init
extern authentication_start
extern boot_screen_display

section .text

kernel_main:
    cld
    mov rbp, rsp

    call memory_init
    call interrupts_init
    call scheduler_init
    call system_init
    call terminal_init
    call boot_screen_display
    call authentication_start

.halt:
    hlt
    jmp .halt

section .data

kernel_version_major    db 1
kernel_version_minor    db 0
kernel_name             db 'PassOS', 0
