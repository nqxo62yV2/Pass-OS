; PassOS x86-64 Multiboot2 Boot Entry
; GRUB2 loads this ELF, validates the Multiboot2 header, and jumps to
; kernel_entry in 32-bit protected mode. This stub enables PAE + long mode
; and calls kernel_main().
;
; Build: nasm -f elf64 boot/bios/boot.asm -o build/obj/boot.o
; Link:  ld -T scripts/linker.ld -z max-page-size=0x1000 ...

BITS 32

; ── Multiboot2 header ────────────────────────────────────────────────────────
MULTIBOOT2_MAGIC        equ 0xE85250D6
MULTIBOOT2_ARCH_I386    equ 0
MULTIBOOT2_HDR_LEN      equ (mb2_header_end - mb2_header_start)
MULTIBOOT2_CHECKSUM     equ -(MULTIBOOT2_MAGIC + MULTIBOOT2_ARCH_I386 + MULTIBOOT2_HDR_LEN)

section .multiboot progbits alloc noexec nowrite
align 8
mb2_header_start:
    dd MULTIBOOT2_MAGIC
    dd MULTIBOOT2_ARCH_I386
    dd MULTIBOOT2_HDR_LEN
    dd MULTIBOOT2_CHECKSUM

    ; end tag
    dw 0
    dw 0
    dd 8
mb2_header_end:

; ── 32-bit entry point ───────────────────────────────────────────────────────
section .text
global kernel_entry
extern kernel_main

kernel_entry:
    cli                         ; GRUB may leave interrupts enabled
    mov esp, stack_top

%ifdef DEBUG_SERIAL
    call serial_init
    mov esi, msg_boot_entry
    call serial_puts
%endif

    ; GRUB Multiboot2 magic must be in EAX. EBX points at the info struct.
    cmp eax, 0x36D76289
    jne .no_multiboot
    mov edi, ebx                ; MBI pointer (reserved for future use)

    ; Enable PAE (CR4.PAE = bit 5)
    mov eax, cr4
    or  eax, (1 << 5)
    mov cr4, eax

    ; Point CR3 at our PML4 (identity-mapped, physical == virtual)
    mov eax, pml4_table
    mov cr3, eax

    ; Set EFER.LME (long mode enable)
    mov ecx, 0xC0000080
    rdmsr
    or  eax, (1 << 8)
    wrmsr

    ; Load the 64-bit GDT while still in 32-bit protected mode
    lgdt [gdt64_ptr]

    ; Enable paging (CR0.PG). CR0.PE is already set by GRUB.
    mov eax, cr0
    or  eax, (1 << 31)
    mov cr0, eax

    ; Far jump reloads CS with the 64-bit code descriptor
    jmp 0x08:long_mode_entry

.no_multiboot:
    ; Visible error marker: red 'E' in the top-left corner
    mov byte [0xB8000], 'E'
    mov byte [0xB8001], 0x4F
.halt:
    cli
    hlt
    jmp .halt

; ── 64-bit entry ─────────────────────────────────────────────────────────────
BITS 64
long_mode_entry:
%ifdef DEBUG_SERIAL
    mov esi, msg_long_mode
    call serial_puts
%endif

    mov ax, 0x10
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax

    mov rsp, stack_top
    xor rbp, rbp

    call kernel_main

.halt:
    cli
    hlt
    jmp .halt

; ── Page tables: identity-map the first 1 GiB with 2 MiB pages ───────────────
BITS 32
section .data
align 4096
pml4_table:
    dq pdp_table + 0x03         ; present | writable
    times 511 dq 0

align 4096
pdp_table:
    dq pd_table + 0x03          ; present | writable
    times 511 dq 0

align 4096
pd_table:
    %assign i 0
    %rep 512
    dq (i * 0x200000) | 0x83    ; present | writable | 2 MiB page
    %assign i i+1
    %endrep

; ── 64-bit GDT ───────────────────────────────────────────────────────────────
align 8
gdt64_start:
    dq 0x0000000000000000       ; null
    dq 0x00AF9A000000FFFF       ; 64-bit code (L=1)
    dq 0x00CF92000000FFFF       ; data (D/B=1, L=0)

gdt64_end:
gdt64_ptr:
    dw gdt64_end - gdt64_start - 1
    dd gdt64_start

; ── Stack ────────────────────────────────────────────────────────────────────
section .bss
align 16
stack_bottom:
    resb 16384
stack_top:

; ── Optional serial debug output (used by the CI smoke test) ─────────────────
%ifdef DEBUG_SERIAL
BITS 32
section .text

serial_init:
    push eax
    push edx
    mov dx, 0x3F9
    xor al, al
    out dx, al                  ; disable UART interrupts
    mov dx, 0x3FB
    mov al, 0x80
    out dx, al                  ; enable DLAB
    mov dx, 0x3F8
    mov al, 1
    out dx, al                  ; divisor low: 115200 baud
    mov dx, 0x3F9
    xor al, al
    out dx, al                  ; divisor high
    mov dx, 0x3FB
    mov al, 0x03
    out dx, al                  ; 8 data bits, no parity, 1 stop bit
    mov dx, 0x3FA
    mov al, 0xC7
    out dx, al                  ; enable + clear FIFOs
    mov dx, 0x3FC
    mov al, 0x0B
    out dx, al                  ; IRQs off, RTS/DSR asserted
    pop edx
    pop eax
    ret

serial_putc:
    push eax
    push edx
    mov ah, al
    mov dx, 0x3FD
.wait:
    in al, dx
    test al, 0x20               ; THR empty?
    jz .wait
    mov dx, 0x3F8
    mov al, ah
    out dx, al
    pop edx
    pop eax
    ret

serial_puts:
    push eax
    push esi
.loop:
    lodsb
    test al, al
    jz .done
    call serial_putc
    jmp .loop
.done:
    pop esi
    pop eax
    ret

section .rodata
msg_boot_entry  db 'PASSOS:BOOT_ENTRY', 13, 10, 0
msg_long_mode   db 'PASSOS:LONG_MODE', 13, 10, 0
%endif
