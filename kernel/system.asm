; PassOS System Initialization
; Performs late-stage hardware detection and subsystem startup.

BITS 64

global system_init
global system_halt
global system_reboot
global get_ticks

extern storage_init
extern usb_init
extern display_init
extern keyboard_init

section .data
    system_tick_count   dq 0
    system_initialized  db 0

section .text

system_init:
    push rbx

    call display_init
    call keyboard_init
    call storage_init
    call usb_init

    mov byte [system_initialized], 1

    pop rbx
    ret

system_halt:
    cli
.spin:
    hlt
    jmp .spin

system_reboot:
    mov al, 0xFE
    out 0x64, al
    jmp system_halt

get_ticks:
    mov rax, [system_tick_count]
    ret
