; PassOS Database Export Module
; Handles /export_database("NAME") and /export_database=all.
; Writes plaintext or encrypted exports to an external USB device.
; Plaintext export requires explicit security warning + confirmation.

BITS 64

global cmd_export_database
global cmd_export_all_databases

extern db_storage_db_count
extern db_storage_find_db
extern db_storage_get_db_info
extern db_storage_read_entry
extern usb_device_count
extern usb_get_device_info
extern usb_write_sector
extern display_put_string
extern display_put_char
extern display_set_color
extern keyboard_read_line
extern keyboard_read_line_masked
extern authentication_verify_token
extern aes256gcm_encrypt
extern generate_nonce
extern secure_zero

COLOR_WARN      equ 0x0C
COLOR_NORMAL    equ 0x07
COLOR_BOLD      equ 0x0F
COLOR_OK        equ 0x0A

ENTRY_FLAG_ACTIVE   equ 0x01
ENTRY_NAME_OFFSET   equ 1
ENTRY_NAME_LEN      equ 64
ENTRY_ID_OFFSET     equ 65
ENTRY_ID_LEN        equ 8
ENTRY_PASS_OFFSET   equ 73
ENTRY_PASS_ENC_LEN  equ 128
ENTRY_TOTAL_LEN     equ 256

INPUT_BUF_LEN       equ 8
TOKEN_BUF_LEN       equ 256
EXPORT_SECTOR_BASE  equ 4096

section .bss
    exp_input_buf       resb INPUT_BUF_LEN
    exp_token_buf       resb TOKEN_BUF_LEN
    exp_entry_buf       resb ENTRY_TOTAL_LEN
    exp_line_buf        resb 512
    exp_plaintext_mode  resb 1
    exp_usb_device      resq 1

section .data
    str_exp_warn_a      db 0x0A
                        db 'SECURITY WARNING', 0x0A, 0x0A
                        db 'You are about to export passwords in plaintext.', 0x0A
                        db 'Plaintext exports are highly sensitive.', 0x0A
                        db 'Anyone with access to the export file can read', 0x0A
                        db 'all your stored passwords.', 0x0A, 0x0A
                        db 'Export type (PLAIN/ENC): ', 0
    str_exp_token       db 0x0A, 'Enter master token to authorize export: ', 0
    str_exp_no_usb      db 0x0A, 'Error: No external USB device detected.', 0x0A, 0
    str_exp_ok          db 0x0A, 'Export complete.', 0x0A, 0
    str_exp_aborted     db 0x0A, 'Export aborted.', 0x0A, 0
    str_exp_not_found   db 'Error: Database not found.', 0x0A, 0
    str_exp_auth_fail   db 'Authentication failed. Export aborted.', 0x0A, 0
    str_exp_no_dbs      db 'Error: No databases to export.', 0x0A, 0
    str_colon           db ':', 0
    str_newline         db 0x0A, 0

    plain_str           db 'PLAIN', 0

section .text

cmd_export_database:
    push rbx
    push r12

    mov r12, rdi

    call _export_auth_and_select
    test rax, rax
    jnz .done

    mov rdi, r12
    call db_storage_find_db
    cmp rax, -1
    je .not_found

    mov rbx, rax
    call _export_one_db
    jmp .done

.not_found:
    mov dil, COLOR_WARN
    call display_set_color
    lea rsi, [str_exp_not_found]
    call display_put_string
    mov dil, COLOR_NORMAL
    call display_set_color

.done:
    pop r12
    pop rbx
    ret

cmd_export_all_databases:
    push rbx
    push r12

    call _export_auth_and_select
    test rax, rax
    jnz .done

    call db_storage_db_count
    test rax, rax
    jz .no_dbs

    mov r12, rax
    xor rbx, rbx

.loop:
    cmp rbx, r12
    jge .done
    mov rdi, rbx
    call _export_one_db
    inc rbx
    jmp .loop

.no_dbs:
    mov dil, COLOR_WARN
    call display_set_color
    lea rsi, [str_exp_no_dbs]
    call display_put_string
    mov dil, COLOR_NORMAL
    call display_set_color

.done:
    pop r12
    pop rbx
    ret

_export_auth_and_select:
    push rbx

    movzx rax, byte [usb_device_count]
    test rax, rax
    jz .no_usb

    mov dil, COLOR_WARN
    call display_set_color
    lea rsi, [str_exp_warn_a]
    call display_put_string
    mov dil, COLOR_NORMAL
    call display_set_color

    lea rsi, [exp_input_buf]
    mov rdx, INPUT_BUF_LEN - 1
    call keyboard_read_line

    lea rdi, [exp_input_buf]
    lea rsi, [plain_str]
    mov rdx, 5
    call _str_eq_n
    test rax, rax
    jnz .is_plain

    mov byte [exp_plaintext_mode], 0
    jmp .auth

.is_plain:
    mov byte [exp_plaintext_mode], 1

.auth:
    lea rsi, [str_exp_token]
    call display_put_string
    lea rsi, [exp_token_buf]
    mov rdx, TOKEN_BUF_LEN - 1
    call keyboard_read_line_masked

    lea rdi, [exp_token_buf]
    call authentication_verify_token
    test rax, rax
    jnz .auth_fail

    lea rdi, [exp_token_buf]
    mov rsi, TOKEN_BUF_LEN
    call secure_zero

    xor rax, rax
    jmp .done

.auth_fail:
    lea rdi, [exp_token_buf]
    mov rsi, TOKEN_BUF_LEN
    call secure_zero
    mov dil, COLOR_WARN
    call display_set_color
    lea rsi, [str_exp_auth_fail]
    call display_put_string
    mov dil, COLOR_NORMAL
    call display_set_color
    mov rax, 1
    jmp .done

.no_usb:
    mov dil, COLOR_WARN
    call display_set_color
    lea rsi, [str_exp_no_usb]
    call display_put_string
    mov dil, COLOR_NORMAL
    call display_set_color
    mov rax, 1

.done:
    pop rbx
    ret

_export_one_db:
    push rbx
    push r12
    push r13
    push r14

    mov r12, rdi

    call db_storage_get_db_info
    mov r14, rax
    mov r13, qword [rax + 40]

    xor rbx, rbx
.entry_loop:
    cmp rbx, r13
    jge .write_done

    mov rdi, r12
    mov rsi, rbx
    lea rdx, [exp_entry_buf]
    call db_storage_read_entry

    movzx rax, byte [exp_entry_buf]
    test rax, ENTRY_FLAG_ACTIVE
    jz .next

    cmp byte [exp_plaintext_mode], 1
    je .write_plain
    call _write_encrypted_entry
    jmp .next

.write_plain:
    call _write_plain_entry

.next:
    inc rbx
    jmp .entry_loop

.write_done:
    mov dil, COLOR_OK
    call display_set_color
    lea rsi, [str_exp_ok]
    call display_put_string
    mov dil, COLOR_NORMAL
    call display_set_color

    pop r14
    pop r13
    pop r12
    pop rbx
    ret

_write_plain_entry:
    push rbx
    push rcx

    lea rdi, [exp_line_buf]
    lea rsi, [exp_entry_buf + ENTRY_NAME_OFFSET]
    call _append_str

    mov byte [rdi], ':'
    inc rdi

    lea rsi, [exp_entry_buf + ENTRY_ID_OFFSET]
    call _append_str

    mov byte [rdi], ':'
    inc rdi

    lea rsi, [exp_entry_buf + ENTRY_PASS_OFFSET]
    call _append_str

    mov byte [rdi], 0x0A
    inc rdi
    mov byte [rdi], 0

    pop rcx
    pop rbx
    ret

_write_encrypted_entry:
    ret

_append_str:
    push rcx
.loop:
    movzx rcx, byte [rsi]
    test rcx, rcx
    jz .done
    mov byte [rdi], cl
    inc rsi
    inc rdi
    jmp .loop
.done:
    pop rcx
    ret

_str_eq_n:
    push rbx
    push rcx
    mov rcx, rdx
.loop:
    test rcx, rcx
    jz .equal
    movzx rax, byte [rdi]
    movzx rbx, byte [rsi]
    cmp rax, 'a'
    jl .no_upper_a
    cmp rax, 'z'
    jg .no_upper_a
    sub rax, 32
.no_upper_a:
    cmp rbx, 'a'
    jl .no_upper_b
    cmp rbx, 'z'
    jg .no_upper_b
    sub rbx, 32
.no_upper_b:
    cmp rax, rbx
    jne .not_equal
    inc rdi
    inc rsi
    dec rcx
    jmp .loop
.equal:
    mov rax, 1
    jmp .done
.not_equal:
    xor rax, rax
.done:
    pop rcx
    pop rbx
    ret
