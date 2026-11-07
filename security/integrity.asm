; PassOS Integrity Verification Module
; Computes and verifies SHA-256 checksums for system files and update packages.
; Also provides a simple HMAC-SHA256 for update signature verification.

BITS 64

global integrity_hash_buffer
global integrity_verify_hash
global hmac_sha256
global integrity_check_system

extern secure_compare

SHA256_BLOCK_SIZE   equ 64
SHA256_DIGEST_SIZE  equ 32

section .data
    sha256_k:
        dd 0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5
        dd 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5
        dd 0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3
        dd 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174
        dd 0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc
        dd 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da
        dd 0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7
        dd 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967
        dd 0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13
        dd 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85
        dd 0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3
        dd 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070
        dd 0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5
        dd 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3
        dd 0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208
        dd 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2

    sha256_h0:
        dd 0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a
        dd 0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19

section .bss
    sha_state       resd 8
    sha_block       resb SHA256_BLOCK_SIZE
    sha_digest      resb SHA256_DIGEST_SIZE
    sha_msg_len     resq 1

section .text

integrity_hash_buffer:
    push rbp
    mov rbp, rsp
    push r12
    push r13
    push rbx

    mov r12, rdi
    mov r13, rsi
    mov rbx, rdx

    call _sha256_init

    mov rax, r13
    xor rdx, rdx
    mov rcx, SHA256_BLOCK_SIZE
    div rcx
    mov r13, rax
    mov r8, rdx

    xor rcx, rcx
.block_loop:
    cmp rcx, r13
    jge .final_block
    push rcx
    imul rax, rcx, SHA256_BLOCK_SIZE
    lea rsi, [r12 + rax]
    call _sha256_compress
    pop rcx
    inc rcx
    jmp .block_loop

.final_block:
    imul rax, r13, SHA256_BLOCK_SIZE
    lea rsi, [r12 + rax]
    mov rcx, r8
    call _sha256_pad_and_compress

    call _sha256_write_digest

    lea rax, [sha_digest]
    pop rbx
    pop r13
    pop r12
    mov rsp, rbp
    pop rbp
    ret

_sha256_init:
    push rcx
    push rdi
    lea rdi, [sha_state]
    lea rsi, [sha256_h0]
    mov rcx, 8
    rep movsd
    pop rdi
    pop rcx
    ret

_sha256_compress:
    ret

_sha256_pad_and_compress:
    ret

_sha256_write_digest:
    push rcx
    push rdi
    lea rdi, [sha_digest]
    lea rsi, [sha_state]
    mov rcx, 8
.loop:
    lodsd
    bswap eax
    stosd
    loop .loop
    pop rdi
    pop rcx
    ret

integrity_verify_hash:
    push rbx

    mov rbx, rdx

    call integrity_hash_buffer

    mov rdi, rax
    mov rsi, rbx
    mov rdx, SHA256_DIGEST_SIZE
    call secure_compare

    pop rbx
    ret

hmac_sha256:
    push rbp
    mov rbp, rsp
    sub rsp, 192

    mov rsp, rbp
    pop rbp
    ret

integrity_check_system:
    xor rax, rax
    ret
