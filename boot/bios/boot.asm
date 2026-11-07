; PassOS BIOS Bootloader (Stage 1)
; Target: x86 real mode, loaded at 0x7C00 by BIOS
; Loads Stage 2 from disk and transfers control to it.

BITS 16
ORG 0x7C00

STAGE2_SEGMENT  equ 0x1000
STAGE2_OFFSET   equ 0x0000
STAGE2_SECTORS  equ 32

start:
    cli
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7C00
    sti

    mov [boot_drive], dl

    mov si, msg_loading
    call print_string_rm

    xor ax, ax
    int 0x13
    jc disk_error

    mov ax, STAGE2_SEGMENT
    mov es, ax
    mov bx, STAGE2_OFFSET

    mov ah, 0x02
    mov al, STAGE2_SECTORS
    mov ch, 0x00
    mov cl, 0x02
    mov dh, 0x00
    mov dl, [boot_drive]
    int 0x13
    jc disk_error

    mov si, msg_ok
    call print_string_rm

    jmp STAGE2_SEGMENT:STAGE2_OFFSET

disk_error:
    mov si, msg_disk_error
    call print_string_rm
.halt:
    hlt
    jmp .halt

print_string_rm:
    lodsb
    test al, al
    jz .done
    mov ah, 0x0E
    mov bh, 0x00
    int 0x10
    jmp print_string_rm
.done:
    ret

msg_loading     db 'PassOS: Loading...', 0x0D, 0x0A, 0
msg_ok          db 'Stage 2 loaded.', 0x0D, 0x0A, 0
msg_disk_error  db 'DISK ERROR. Halting.', 0x0D, 0x0A, 0
boot_drive      db 0

TIMES 446 - ($ - $$) db 0
    db 0x80, 0x00, 0x02, 0x00, 0x0B, 0xFE, 0xFF, 0xFF
    dd 0x00000001
    dd 0x0000003F
    times 48 db 0
    dw 0xAA55
