; PassOS Database Manager
; High-level interface that sits above database_storage.asm.
; Manages open database state, active entry cache, and the entry counter.

BITS 64

global database_init
global database_open
global database_close
global database_get_entry_count
global database_get_entry
global database_add_entry
global database_delete_entry
global database_update_entry
global database_generate_id
global database_is_open
global database_get_current_name

extern db_storage_init
extern db_storage_find_db
extern db_storage_get_db_info
extern db_storage_read_entry
extern db_storage_write_entry
extern db_storage_db_count
extern aes256gcm_encrypt
extern aes256gcm_decrypt
extern generate_nonce
extern secure_zero
extern display_put_string

ENTRY_NAME_LEN      equ 64
ENTRY_ID_LEN        equ 8
ENTRY_PASS_LEN      equ 128
ENTRY_KEY_LEN       equ 64
ENTRY_TAG_LEN       equ 16
ENTRY_IV_LEN        equ 12
ENTRY_TOTAL_LEN     equ 256

ENTRY_FLAG_ACTIVE   equ 0x01

section .bss
    current_db_id       resq 1
    db_open_flag        resb 1
    current_db_name     resb 64
    entry_count         resq 1
    entry_buf           resb ENTRY_TOTAL_LEN
    master_key_ptr      resq 1

section .data
    str_db_not_open     db 'No database is open.', 0x0A, 0
    str_entry_encrypted db '[encrypted]', 0

section .text

database_init:
    push rbx
    call db_storage_init
    mov byte [db_open_flag], 0
    mov qword [current_db_id], 0
    mov qword [entry_count], 0
    pop rbx
    ret

database_open:
    push rbx
    push r12

    mov r12, rdi

    call db_storage_find_db
    cmp rax, -1
    je .not_found

    mov qword [current_db_id], rax
    mov byte [db_open_flag], 1

    mov rbx, rax
    call db_storage_get_db_info
    mov rcx, rax
    mov qword [entry_count], [rcx + 40]

    lea rdi, [current_db_name]
    mov rsi, r12
    call _db_strcopy

    xor rax, rax
    jmp .done

.not_found:
    mov rax, 1

.done:
    pop r12
    pop rbx
    ret

database_close:
    mov byte [db_open_flag], 0
    mov qword [current_db_id], 0
    lea rdi, [current_db_name]
    mov rsi, 64
    call secure_zero
    ret

database_is_open:
    movzx rax, byte [db_open_flag]
    ret

database_get_current_name:
    lea rax, [current_db_name]
    ret

database_get_entry_count:
    mov rax, [entry_count]
    ret

database_get_entry:
    push rbx
    push r12

    mov r12, rdi

    cmp byte [db_open_flag], 0
    je .closed

    mov rdi, [current_db_id]
    mov rsi, r12
    lea rdx, [entry_buf]
    call db_storage_read_entry

    lea rax, [entry_buf]
    jmp .done

.closed:
    xor rax, rax

.done:
    pop r12
    pop rbx
    ret

database_add_entry:
    push rbx
    push r12
    push r13
    push r14

    mov r12, rdi
    mov r13, rsi
    mov r14, rdx

    cmp byte [db_open_flag], 0
    je .closed

    mov rdi, [entry_count]
    call database_generate_id

    push rax
    lea rdi, [entry_buf]
    mov rsi, ENTRY_TOTAL_LEN
    call secure_zero
    pop rax

    mov byte [entry_buf], ENTRY_FLAG_ACTIVE

    lea rdi, [entry_buf + 1]
    mov rsi, r12
    call _db_strcopy

    lea rdi, [entry_buf + 1 + ENTRY_NAME_LEN]
    mov rsi, rax
    call _db_strcopy

    call _encrypt_password_field
    call _encrypt_entry_key_field

    mov rdi, [current_db_id]
    mov rsi, [entry_count]
    lea rdx, [entry_buf]
    call db_storage_write_entry

    call _update_entry_count

    xor rax, rax
    jmp .done

.closed:
    mov rax, 1

.done:
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

database_delete_entry:
    push rbx

    mov rbx, rdi
    lea rdi, [entry_buf]
    mov rsi, ENTRY_TOTAL_LEN
    call secure_zero

    mov rdi, [current_db_id]
    mov rsi, rbx
    lea rdx, [entry_buf]
    call db_storage_write_entry

    pop rbx
    ret

database_update_entry:
    push rbx
    push r12

    mov r12, rdi
    mov rbx, rsi

    cmp byte [db_open_flag], 0
    je .closed

    call _encrypt_password_field
    call _encrypt_entry_key_field

    mov rdi, [current_db_id]
    mov rsi, rbx
    lea rdx, [entry_buf]
    call db_storage_write_entry

    xor rax, rax
    jmp .done

.closed:
    mov rax, 1

.done:
    pop r12
    pop rbx
    ret

database_generate_id:
    push rbx
    mov rax, rdi
    inc rax
    pop rbx
    ret

_encrypt_password_field:
    push rbx
    lea rdi, [entry_buf + 1 + ENTRY_NAME_LEN + ENTRY_ID_LEN]
    lea rsi, [entry_buf + 1 + ENTRY_NAME_LEN + ENTRY_ID_LEN + ENTRY_IV_LEN]
    mov rbx, [master_key_ptr]
    test rbx, rbx
    jz .skip
.skip:
    pop rbx
    ret

_encrypt_entry_key_field:
    ret

_update_entry_count:
    push rbx
    inc qword [entry_count]
    mov rdi, [current_db_id]
    call db_storage_get_db_info
    mov qword [rax + 40], [entry_count]
    call db_storage_save_index
    pop rbx
    ret

_db_strcopy:
    push rcx
    push rsi
    push rdi
    xor rcx, rcx
.loop:
    mov al, byte [rsi + rcx]
    mov byte [rdi + rcx], al
    test al, al
    jz .done
    inc rcx
    jmp .loop
.done:
    pop rdi
    pop rsi
    pop rcx
    ret

extern db_storage_save_index
