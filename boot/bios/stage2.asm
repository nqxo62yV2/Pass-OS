; PassOS BIOS Stage 2 Bootloader
; Runs in real mode, enables A20, enters protected mode, then long mode,
; loads the kernel, and jumps to it.

BITS 16
ORG 0x0000

    jmp 0x1000:main16

main16:
    mov ax, cs
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax
    mov sp, 0xFFFE

    mov si, msg_stage2
    call print16

    call enable_a20

    lgdt [gdt_descriptor]

    mov eax, cr0
    or eax, 1
    mov cr0, eax
    jmp 0x08:pmode_entry

BITS 32
pmode_entry:
    mov ax, 0x10
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax
    mov esp, 0x90000

    call enable_long_mode
    lgdt [gdt64_descriptor]
    mov eax, cr0
    or eax, 1
    mov cr0, eax
    jmp 0x08:lmode_entry

BITS 64
lmode_entry:
    mov ax, 0x10
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax
    mov rsp, 0x200000

    mov rax, KERNEL_LOAD_ADDRESS
    call rax

.halt:
    hlt
    jmp .halt

BITS 32
enable_long_mode:
    mov eax, cr4
    or eax, (1 << 5)
    mov cr4, eax

    mov eax, pml4_table
    mov cr3, eax

    mov ecx, 0xC0000080
    rdmsr
    or eax, (1 << 8)
    wrmsr

    mov eax, cr0
    or eax, (1 << 31)
    mov cr0, eax
    ret

BITS 16
enable_a20:
    in al, 0x92
    or al, 2
    out 0x92, al
    ret

print16:
    lodsb
    test al, al
    jz .done
    mov ah, 0x0E
    int 0x10
    jmp print16
.done:
    ret

KERNEL_LOAD_ADDRESS equ 0x100000

msg_stage2 db 'PassOS Stage 2 active.', 0x0D, 0x0A, 0

ALIGN 4096
pml4_table:
    dq (pdp_table + 3)
    times 511 dq 0

ALIGN 4096
pdp_table:
    dq (pd_table + 3)
    times 511 dq 0

ALIGN 4096
pd_table:
    %assign i 0
    %rep 512
    dq (i * 0x200000) | 0x83
    %assign i i+1
    %endrep

ALIGN 8
gdt_start:
    dq 0x0000000000000000
    dq 0x00CF9A000000FFFF
    dq 0x00CF92000000FFFF
gdt_end:

gdt_descriptor:
    dw gdt_end - gdt_start - 1
    dd gdt_start

ALIGN 8
gdt64_start:
    dq 0x0000000000000000
    dq 0x00AF9A000000FFFF
    dq 0x00AF92000000FFFF
gdt64_end:

gdt64_descriptor:
    dw gdt64_end - gdt64_start - 1
    dq gdt64_start
