; PassOS UEFI Loader
; Entry point for UEFI boot. Called by firmware as a PE64 EFI application.
; Locates the kernel on the EFI System Partition and transfers control.

BITS 64

%define EFI_SUCCESS                 0x0000000000000000
%define EFI_LOAD_ERROR              0x8000000000000001
%define EFI_BUFFER_TOO_SMALL        0x8000000000000005

%define EFI_OPEN_PROTOCOL_BY_HANDLE_PROTOCOL 0x00000001

%define EFI_FILE_MODE_READ          0x0000000000000001
%define EFI_FILE_READ_ONLY          0x0000000000000001

KERNEL_FILENAME equ kernel_filename_utf16

section .text
global efi_main

efi_main:
    push rbx
    push rsi
    push rdi
    push r12
    push r13

    mov [image_handle], rcx
    mov [system_table], rdx

    mov rax, [rdx + 0x60]
    mov [boot_services], rax

    mov rax, [rdx + 0x40]
    mov [con_out], rax

    mov rcx, [con_out]
    lea rdx, [banner_str]
    call [rcx + 0x08]

    xor rax, rax
    pop r13
    pop r12
    pop rdi
    pop rsi
    pop rbx
    ret

section .data

image_handle    dq 0
system_table    dq 0
boot_services   dq 0
con_out         dq 0

banner_str:
    dw 'P','a','s','s','O','S',' ','U','E','F','I',' ','L','o','a','d','e','r',0x000D,0x000A,0

kernel_filename_utf16:
    dw '\','P','a','s','s','O','S','\','k','e','r','n','e','l','.','b','i','n',0
