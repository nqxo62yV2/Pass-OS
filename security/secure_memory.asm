; PassOS Secure Memory Module
; Provides routines for zeroing sensitive data from RAM after use,
; and a secure buffer type that is automatically cleared on free.

BITS 64

global secure_zero
global secure_alloc
global secure_free
global secure_copy
global secure_compare

extern alloc_page
extern free_page

SECURE_CANARY   equ 0xDEADC0DEDEADC0DE

section .bss
    secure_alloc_count  resq 1

section .text

secure_zero:
    push rax
    push rcx
    push rdi

    test rsi, rsi
    jz .done

    mov rdi, rdi
    mov rcx, rsi
    xor eax, eax
    rep stosb

    mfence

.done:
    pop rdi
    pop rcx
    pop rax
    ret

secure_alloc:
    push rbx
    push rcx

    mov rbx, rdi
    call alloc_page
    test rax, rax
    jz .fail

    push rax
    mov rdi, rax
    mov rsi, 4096
    call secure_zero
    pop rax

    inc qword [secure_alloc_count]

    pop rcx
    pop rbx
    ret

.fail:
    xor rax, rax
    pop rcx
    pop rbx
    ret

secure_free:
    push rbx

    test rdi, rdi
    jz .done

    push rdi
    mov rsi, 4096
    call secure_zero
    pop rdi

    call free_page
    dec qword [secure_alloc_count]

.done:
    pop rbx
    ret

secure_copy:
    push rcx
    push rsi
    push rdi

    mov rcx, rdx
    rep movsb

    pop rdi
    pop rsi
    pop rcx
    ret

secure_compare:
    push rbx
    push rcx

    xor rbx, rbx
    mov rcx, rdx

.loop:
    test rcx, rcx
    jz .done
    movzx rax, byte [rdi]
    movzx r8, byte [rsi]
    xor rax, r8
    or rbx, rax
    inc rdi
    inc rsi
    dec rcx
    jmp .loop

.done:
    test rbx, rbx
    setz al
    movzx rax, al

    pop rcx
    pop rbx
    ret
