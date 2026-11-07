; PassOS Hardware Abstraction Layer
; Provides CPUID-based feature detection, hardware capability flags,
; and helpers for architecture-specific setup.

BITS 64

global hardware_detect
global hw_has_aes_ni
global hw_has_rdrand
global hw_get_cpu_vendor
global hw_get_cpu_brand
global hw_get_memory_size

HW_FLAG_AES_NI  equ (1 << 0)
HW_FLAG_RDRAND  equ (1 << 1)
HW_FLAG_SSE4    equ (1 << 2)
HW_FLAG_AVX2    equ (1 << 3)

section .bss
    hw_flags    resq 1
    cpu_vendor  resb 13
    cpu_brand   resb 49

section .text

hardware_detect:
    push rbx
    push rcx
    push rdx

    xor eax, eax
    cpuid
    mov dword [cpu_vendor],     ebx
    mov dword [cpu_vendor + 4], edx
    mov dword [cpu_vendor + 8], ecx
    mov byte  [cpu_vendor + 12], 0

    mov eax, 0x80000002
    cpuid
    mov dword [cpu_brand],      eax
    mov dword [cpu_brand + 4],  ebx
    mov dword [cpu_brand + 8],  ecx
    mov dword [cpu_brand + 12], edx

    mov eax, 0x80000003
    cpuid
    mov dword [cpu_brand + 16], eax
    mov dword [cpu_brand + 20], ebx
    mov dword [cpu_brand + 24], ecx
    mov dword [cpu_brand + 28], edx

    mov eax, 0x80000004
    cpuid
    mov dword [cpu_brand + 32], eax
    mov dword [cpu_brand + 36], ebx
    mov dword [cpu_brand + 40], ecx
    mov dword [cpu_brand + 44], edx
    mov byte  [cpu_brand + 48], 0

    mov eax, 1
    cpuid
    xor rax, rax

    test ecx, (1 << 25)
    jz .no_aes
    or rax, HW_FLAG_AES_NI
.no_aes:
    test ecx, (1 << 30)
    jz .no_rdrand
    or rax, HW_FLAG_RDRAND
.no_rdrand:
    mov [hw_flags], rax

    pop rdx
    pop rcx
    pop rbx
    ret

hw_has_aes_ni:
    mov rax, [hw_flags]
    test rax, HW_FLAG_AES_NI
    setnz al
    movzx rax, al
    ret

hw_has_rdrand:
    mov rax, [hw_flags]
    test rax, HW_FLAG_RDRAND
    setnz al
    movzx rax, al
    ret

hw_get_cpu_vendor:
    lea rax, [cpu_vendor]
    ret

hw_get_cpu_brand:
    lea rax, [cpu_brand]
    ret

; hw_get_memory_size: returns a fixed 64 MB placeholder.
; E820 memory map must be read during real-mode Stage 2 and stored at
; a known physical address before the kernel switches to long mode.
; Reading it via int 0x15 in long mode causes a triple fault.
hw_get_memory_size:
    mov rax, 0x4000000  ; 64 MB safe default
    ret
