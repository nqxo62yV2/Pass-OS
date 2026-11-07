; PassOS Memory Manager
; Implements a physical page allocator and a simple virtual memory map.
; All allocations are tracked in a bitmap stored at BITMAP_BASE.

BITS 64

global memory_init
global alloc_page
global free_page
global alloc_pages
global free_pages
global map_virtual_page
global unmap_virtual_page
global memset64
global memcopy64
global memzero64

BITMAP_BASE         equ 0x400000
PAGE_SIZE           equ 4096
TOTAL_PAGES         equ 0x100000
HEAP_BASE           equ 0x800000
HEAP_LIMIT          equ 0x4000000

section .bss
    align 8
    bitmap:         resb TOTAL_PAGES / 8
    heap_pointer:   resq 1

section .text

memory_init:
    push rbx
    push rcx
    push rdi

    mov rdi, bitmap
    mov rcx, TOTAL_PAGES / 8
    xor al, al
    rep stosb

    call mark_reserved_pages

    mov qword [heap_pointer], HEAP_BASE

    pop rdi
    pop rcx
    pop rbx
    ret

mark_reserved_pages:
    push rax
    push rcx
    xor rcx, rcx
.mark_loop:
    cmp rcx, 256
    jge .done
    call _set_page_used
    inc rcx
    jmp .mark_loop
.done:
    pop rcx
    pop rax
    ret

alloc_page:
    push rbx
    push rcx
    push rdx

    xor rcx, rcx
.search:
    cmp rcx, TOTAL_PAGES
    jge .no_memory

    mov rax, rcx
    shr rax, 3
    movzx rbx, byte [bitmap + rax]
    mov rdx, rcx
    and rdx, 7
    bt rbx, rdx
    jnc .found

    inc rcx
    jmp .search

.found:
    mov rax, rcx
    shr rax, 3
    movzx rbx, byte [bitmap + rax]
    mov rdx, rcx
    and rdx, 7
    bts rbx, rdx
    mov byte [bitmap + rax], bl

    mov rax, rcx
    shl rax, 12

    pop rdx
    pop rcx
    pop rbx
    ret

.no_memory:
    xor rax, rax
    pop rdx
    pop rcx
    pop rbx
    ret

free_page:
    push rbx
    push rcx
    push rdx

    shr rdi, 12
    mov rax, rdi
    shr rax, 3
    mov rdx, rdi
    and rdx, 7
    movzx rbx, byte [bitmap + rax]
    btr rbx, rdx
    mov byte [bitmap + rax], bl

    pop rdx
    pop rcx
    pop rbx
    ret

alloc_pages:
    push r12
    push r13
    push r14

    mov r12, rdi
    xor r13, r13
    xor r14, r14

.outer:
    cmp r13, TOTAL_PAGES
    jge .fail

    mov rax, r13
    shr rax, 3
    movzx rcx, byte [bitmap + rax]
    mov rdx, r13
    and rdx, 7
    bt rcx, rdx
    jc .next_outer

    inc r14
    cmp r14, r12
    je .mark_range

.next_outer:
    test r14, r14
    jnz .reset
    inc r13
    jmp .outer

.reset:
    xor r14, r14
    inc r13
    jmp .outer

.mark_range:
    mov rdi, r13
    sub rdi, r12
    inc rdi
    mov rcx, r12
.mark:
    push rcx
    push rdi
    mov rax, rdi
    shr rax, 3
    movzx rbx, byte [bitmap + rax]
    mov rdx, rdi
    and rdx, 7
    bts rbx, rdx
    mov byte [bitmap + rax], bl
    inc rdi
    pop rdi
    pop rcx
    inc rdi
    loop .mark

    mov rax, r13
    sub rax, r12
    inc rax
    shl rax, 12

    pop r14
    pop r13
    pop r12
    ret

.fail:
    xor rax, rax
    pop r14
    pop r13
    pop r12
    ret

free_pages:
    push rcx
    push rdi
    mov rcx, rsi
.loop:
    push rcx
    call free_page
    add rdi, PAGE_SIZE
    pop rcx
    loop .loop
    pop rdi
    pop rcx
    ret

_set_page_used:
    push rax
    push rbx
    push rdx
    mov rax, rcx
    shr rax, 3
    movzx rbx, byte [bitmap + rax]
    mov rdx, rcx
    and rdx, 7
    bts rbx, rdx
    mov byte [bitmap + rax], bl
    pop rdx
    pop rbx
    pop rax
    ret

map_virtual_page:
    ret

unmap_virtual_page:
    ret

memset64:
    push rcx
    push rdi
    mov rcx, rdx
    mov al, sil
    rep stosb
    pop rdi
    pop rcx
    ret

memcopy64:
    push rcx
    push rsi
    push rdi
    mov rcx, rdx
    rep movsb
    pop rdi
    pop rsi
    pop rcx
    ret

memzero64:
    push rcx
    push rdi
    mov rcx, rsi
    xor al, al
    rep stosb
    pop rdi
    pop rcx
    ret
