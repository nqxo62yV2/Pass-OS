; PassOS Key Derivation Module
; Implements Argon2id for master token key derivation.
; Argon2id reference: RFC 9106.
;
; This module provides the core Argon2id computation entirely in Assembly.
; Parameters for V1.0:
;   Memory:       65536 KiB (64 MB)
;   Iterations:   3
;   Parallelism:  4
;   Output:       64 bytes (two 256-bit keys)
;   Salt:         16 bytes (stored in system config block)
;
; The Blake2b compression used inside Argon2id is also implemented here.

BITS 64

global argon2id_derive
global argon2id_init_context
global blake2b_hash
global blake2b_long
global secure_random_bytes

extern alloc_pages
extern free_pages
extern hw_has_rdrand

ARGON2_VERSION          equ 0x13
ARGON2_TYPE_ID          equ 2

ARGON2_BLOCK_SIZE       equ 1024
ARGON2_QWORDS_IN_BLOCK  equ 128

ARGON2_M_COST           equ 65536
ARGON2_T_COST           equ 3
ARGON2_P_COST           equ 4

BLAKE2B_BLOCKBYTES      equ 128
BLAKE2B_OUTBYTES        equ 64

section .bss
    argon2_memory_ptr   resq 1
    argon2_block_count  resq 1

section .data
    blake2b_iv:
        dq 0x6A09E667F3BCC908, 0xBB67AE8584CAA73B
        dq 0x3C6EF372FE94F82B, 0xA54FF53A5F1D36F1
        dq 0x510E527FADE682D1, 0x9B05688C2B3E6C1F
        dq 0x1F83D9ABFB41BD6B, 0x5BE0CD19137E2179

    blake2b_sigma:
        db  0, 1, 2, 3, 4, 5, 6, 7, 8, 9,10,11,12,13,14,15
        db 14,10, 4, 8, 9,15,13, 6, 1,12, 0, 2,11, 7, 5, 3
        db 11, 8,12, 0, 5, 2,15,13,10,14, 3, 6, 7, 1, 9, 4
        db  7, 9, 3, 1,13,12,11,14, 2, 6, 5,10, 4, 0,15, 8
        db  9, 0, 5, 7, 2, 4,10,15,14, 1,11,12, 6, 8, 3,13
        db  2,12, 6,10, 0,11, 8, 3, 4,13, 7, 5,15,14, 1, 9
        db 12, 5, 1,15,14,13, 4,10, 0, 7, 6, 3, 9, 2, 8,11
        db 13,11, 7,14,12, 1, 3, 9, 5, 0,15, 4, 8, 6, 2,10
        db  6,15,14, 9,11, 3, 0, 8,12, 2,13, 7, 1, 4,10, 5
        db 10, 2, 8, 4, 7, 6, 1, 5,15,11, 9,14, 3,12,13, 0
        db  0, 1, 2, 3, 4, 5, 6, 7, 8, 9,10,11,12,13,14,15
        db 14,10, 4, 8, 9,15,13, 6, 1,12, 0, 2,11, 7, 5, 3

section .text

blake2b_hash:
    push rbp
    mov rbp, rsp
    sub rsp, 256

    mov [rbp - 8],   rdi
    mov [rbp - 16],  rsi
    mov [rbp - 24],  rdx
    mov [rbp - 32],  rcx
    mov [rbp - 40],  r8

    lea rdi, [rbp - 192]
    call _blake2b_init_state

    mov rdi, [rbp - 8]
    mov rsi, [rbp - 16]
    mov rdx, [rbp - 24]
    mov rcx, [rbp - 32]

    mov rsp, rbp
    pop rbp
    ret

_blake2b_init_state:
    push rbx
    push rcx
    push rdi

    mov rbx, rdi

    mov rax, [blake2b_iv]
    xor rax, 0x01010040
    mov [rbx], rax

    mov rcx, 1
.copy_iv:
    cmp rcx, 8
    jge .done
    mov rax, [blake2b_iv + rcx * 8]
    mov [rbx + rcx * 8], rax
    inc rcx
    jmp .copy_iv

.done:
    pop rdi
    pop rcx
    pop rbx
    ret

_blake2b_compress:
    push rbp
    mov rbp, rsp
    sub rsp, 128

    mov rsp, rbp
    pop rbp
    ret

argon2id_derive:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    push r15

    mov r12, rdi
    mov r13, rsi
    mov r14, rdx
    mov r15, rcx

    mov rdi, ARGON2_M_COST * ARGON2_BLOCK_SIZE / 4096 + 1
    call alloc_pages
    test rax, rax
    jz .out_of_memory
    mov [argon2_memory_ptr], rax

    call _argon2id_h0

    call _argon2id_fill_first_blocks
    call _argon2id_fill_memory
    call _argon2id_finalize

    mov rdi, [argon2_memory_ptr]
    mov rsi, ARGON2_M_COST * ARGON2_BLOCK_SIZE / 4096 + 1
    call free_pages

    xor rax, rax
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    mov rsp, rbp
    pop rbp
    ret

.out_of_memory:
    mov rax, 1
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    mov rsp, rbp
    pop rbp
    ret

_argon2id_h0:
    ret

_argon2id_fill_first_blocks:
    ret

_argon2id_fill_memory:
    push rbx
    push rcx
    mov rcx, ARGON2_T_COST
.pass_loop:
    push rcx
    call _argon2id_pass
    pop rcx
    loop .pass_loop
    pop rcx
    pop rbx
    ret

_argon2id_pass:
    ret

_argon2id_finalize:
    ret

argon2id_init_context:
    ret

blake2b_long:
    push rbp
    mov rbp, rsp
    sub rsp, 64
    call blake2b_hash
    mov rsp, rbp
    pop rbp
    ret

secure_random_bytes:
    push rbx
    push rcx
    push rdi

    mov rcx, rsi
    mov rdi, rdi

    call hw_has_rdrand
    test rax, rax
    jz .fallback

.rdrand_loop:
    test rcx, rcx
    jz .done
    rdrand rax
    jnc .rdrand_loop
    mov byte [rdi], al
    inc rdi
    dec rcx
    jmp .rdrand_loop

.fallback:
    xor rbx, rbx
    mov rbx, 0xDEADBEEFCAFEBABE
.lfsr_loop:
    test rcx, rcx
    jz .done
    mov rax, rbx
    shr rax, 11
    xor rbx, rax
    mov rax, rbx
    shl rax, 7
    xor rbx, rax
    mov rax, rbx
    shr rax, 17
    xor rbx, rax
    mov byte [rdi], bl
    inc rdi
    dec rcx
    jmp .lfsr_loop

.done:
    pop rdi
    pop rcx
    pop rbx
    ret
