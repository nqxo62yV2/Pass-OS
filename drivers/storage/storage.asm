; PassOS Storage Driver
; Provides ATA PIO disk I/O for reading and writing 512-byte sectors.
; Also offers a higher-level sector cache and a flat-file layer used by
; the database subsystem.

BITS 64

global storage_init
global storage_read_sector
global storage_write_sector
global storage_read_sectors
global storage_write_sectors
global storage_get_sector_count

ATA_DATA            equ 0x1F0
ATA_ERROR           equ 0x1F1
ATA_SECTOR_COUNT    equ 0x1F2
ATA_LBA_LOW         equ 0x1F3
ATA_LBA_MID         equ 0x1F4
ATA_LBA_HIGH        equ 0x1F5
ATA_DRIVE           equ 0x1F6
ATA_STATUS          equ 0x1F7
ATA_CMD             equ 0x1F7

ATA_CMD_READ_PIO    equ 0x20
ATA_CMD_WRITE_PIO   equ 0x30
ATA_CMD_IDENTIFY    equ 0xEC
ATA_CMD_FLUSH       equ 0xE7

ATA_STATUS_BSY      equ 0x80
ATA_STATUS_DRDY     equ 0x40
ATA_STATUS_DRQ      equ 0x08
ATA_STATUS_ERR      equ 0x01

SECTOR_SIZE         equ 512

section .bss
    sector_count    resq 1
    identify_buf    resb SECTOR_SIZE

section .text

storage_init:
    push rax
    push rbx
    push rcx
    push rdx
    push rdi

    call _ata_wait_ready

    mov dx, ATA_DRIVE
    mov al, 0xE0
    out dx, al

    mov dx, ATA_SECTOR_COUNT
    xor al, al
    out dx, al
    mov dx, ATA_LBA_LOW
    out dx, al
    mov dx, ATA_LBA_MID
    out dx, al
    mov dx, ATA_LBA_HIGH
    out dx, al

    mov dx, ATA_CMD
    mov al, ATA_CMD_IDENTIFY
    out dx, al

    mov dx, ATA_STATUS
    in al, dx
    test al, al
    jz .no_drive

    call _ata_wait_drq
    jc .error

    mov rdi, identify_buf
    mov rcx, 256
    mov dx, ATA_DATA
.read_loop:
    in ax, dx
    mov [rdi], ax
    add rdi, 2
    loop .read_loop

    movzx rax, word [identify_buf + 120]
    movzx rbx, word [identify_buf + 118]
    shl rbx, 16
    or rax, rbx
    mov [sector_count], rax

    pop rdi
    pop rdx
    pop rcx
    pop rbx
    pop rax
    ret

.no_drive:
.error:
    mov qword [sector_count], 0
    pop rdi
    pop rdx
    pop rcx
    pop rbx
    pop rax
    ret

storage_read_sector:
    push rcx
    push rdx
    push rdi

    call _ata_setup_lba28

    mov dx, ATA_CMD
    mov al, ATA_CMD_READ_PIO
    out dx, al

    call _ata_wait_drq
    jc .error

    mov rcx, 256
    mov dx, ATA_DATA
.loop:
    in ax, dx
    mov [rdi], ax
    add rdi, 2
    loop .loop

    xor rax, rax
    pop rdi
    pop rdx
    pop rcx
    ret

.error:
    mov rax, 1
    pop rdi
    pop rdx
    pop rcx
    ret

storage_write_sector:
    push rcx
    push rdx
    push rsi

    call _ata_setup_lba28_write

    mov dx, ATA_CMD
    mov al, ATA_CMD_WRITE_PIO
    out dx, al

    call _ata_wait_drq
    jc .error

    mov rcx, 256
    mov dx, ATA_DATA
.loop:
    mov ax, [rsi]
    out dx, ax
    add rsi, 2
    loop .loop

    mov dx, ATA_CMD
    mov al, ATA_CMD_FLUSH
    out dx, al
    call _ata_wait_ready

    xor rax, rax
    pop rsi
    pop rdx
    pop rcx
    ret

.error:
    mov rax, 1
    pop rsi
    pop rdx
    pop rcx
    ret

storage_read_sectors:
    push r12
    push r13
    push rdi

    mov r12, rdi
    mov r13, rdx

.loop:
    test r13, r13
    jz .done
    push r13
    mov rdi, r12
    call storage_read_sector
    pop r13
    add r12, SECTOR_SIZE
    inc rsi
    dec r13
    jmp .loop

.done:
    xor rax, rax
    pop rdi
    pop r13
    pop r12
    ret

storage_write_sectors:
    push r12
    push r13
    push rsi

    mov r12, rsi
    mov r13, rdx

.loop:
    test r13, r13
    jz .done
    push r13
    mov rsi, r12
    call storage_write_sector
    pop r13
    add r12, SECTOR_SIZE
    inc rdi
    dec r13
    jmp .loop

.done:
    xor rax, rax
    pop rsi
    pop r13
    pop r12
    ret

storage_get_sector_count:
    mov rax, [sector_count]
    ret

_ata_setup_lba28:
    push rax
    push rbx
    push rdx

    mov rax, rsi
    mov rdx, ATA_DRIVE
    mov al, 0xE0
    or al, 0x40
    push rax
    mov rax, rsi
    shr rax, 24
    and al, 0x0F
    pop rbx
    or al, bl
    out dx, al

    mov rax, rsi
    mov dx, ATA_SECTOR_COUNT
    mov al, 1
    out dx, al

    mov dx, ATA_LBA_LOW
    mov rax, rsi
    out dx, al

    mov dx, ATA_LBA_MID
    shr rax, 8
    out dx, al

    mov dx, ATA_LBA_HIGH
    shr rax, 8
    out dx, al

    pop rdx
    pop rbx
    pop rax
    ret

_ata_setup_lba28_write:
    jmp _ata_setup_lba28

_ata_wait_ready:
    push rax
    push rdx
    mov dx, ATA_STATUS
.loop:
    in al, dx
    test al, ATA_STATUS_BSY
    jnz .loop
    pop rdx
    pop rax
    ret

_ata_wait_drq:
    push rax
    push rdx
    push rcx

    mov rcx, 0x10000
    mov dx, ATA_STATUS
.loop:
    in al, dx
    test al, ATA_STATUS_ERR
    jnz .error
    test al, ATA_STATUS_DRQ
    jnz .done
    loop .loop

.error:
    stc
    pop rcx
    pop rdx
    pop rax
    ret

.done:
    clc
    pop rcx
    pop rdx
    pop rax
    ret
