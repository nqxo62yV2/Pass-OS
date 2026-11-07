; PassOS Kernel Entry Point
; Architecture: x86-64
; Entered from boot/bios/boot.asm after long mode has been established.

BITS 64

global kernel_main
extern memory_init
extern interrupts_init
extern scheduler_init
extern system_init
extern terminal_init
extern authentication_start
extern splash_screen_display
extern boot_screen_display
extern terminal_run

section .text

kernel_main:
    cld
    mov rbp, rsp

%ifdef DEBUG_SERIAL
    lea rsi, [msg_kernel_main]
    call serial_puts64
%endif

    call memory_init
    call interrupts_init
    call scheduler_init
    call system_init
    call terminal_init
    call splash_screen_display
    call boot_screen_display

%ifdef DEBUG_SERIAL
    lea rsi, [msg_boot_screen]
    call serial_puts64
%endif

    call authentication_start

%ifdef DEBUG_SERIAL
    lea rsi, [msg_auth_done]
    call serial_puts64
%endif

    ; Authentication returns only after a successful login/setup.
    call terminal_run

.halt:
    cli
    hlt
    jmp .halt

%ifdef DEBUG_SERIAL
; ── Minimal COM1 output for the CI boot smoke test ──────────────────────────
; The UART was initialised by boot/bios/boot.asm.
serial_putc64:
    push rax
    push rdx
    mov ah, al
    mov dx, 0x3FD
.wait:
    in al, dx
    test al, 0x20               ; THR empty?
    jz .wait
    mov dx, 0x3F8
    mov al, ah
    out dx, al
    pop rdx
    pop rax
    ret

serial_puts64:
    push rax
    push rsi
.loop:
    lodsb
    test al, al
    jz .done
    call serial_putc64
    jmp .loop
.done:
    pop rsi
    pop rax
    ret
%endif

section .data

kernel_version_major    db 1
kernel_version_minor    db 0
kernel_name             db 'PassOS', 0

%ifdef DEBUG_SERIAL
section .rodata
msg_kernel_main db 'PASSOS:KERNEL_MAIN', 13, 10, 0
msg_boot_screen db 'PASSOS:BOOT_SCREEN_OK', 13, 10, 0
msg_auth_done   db 'PASSOS:AUTH_DONE', 13, 10, 0
%endif
