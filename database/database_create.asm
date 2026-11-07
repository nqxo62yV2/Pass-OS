; PassOS Database Create Module
; Handles /create_database("NAME") command execution.
; Validates the name, prevents duplicates, initializes encrypted storage.

BITS 64

global cmd_create_database

extern db_storage_find_db
extern db_storage_alloc_db
extern display_put_string
extern display_set_color

MAX_DB_NAME_LEN     equ 31
COLOR_OK            equ 0x0A
COLOR_ERR           equ 0x0C
COLOR_NORMAL        equ 0x07

section .data
    str_create_ok_a     db 'Database "', 0
    str_create_ok_b     db '" created successfully.', 0x0A
                        db 'Encryption initialized.', 0x0A, 0
    str_create_dup      db 'Error: A database with that name already exists.', 0x0A, 0
    str_create_empty    db 'Error: Database name cannot be empty.', 0x0A, 0
    str_create_long     db 'Error: Database name too long (max 31 characters).', 0x0A, 0
    str_create_full     db 'Error: Maximum number of databases reached (32).', 0x0A, 0
    str_create_invalid  db 'Error: Database name contains invalid characters.', 0x0A, 0

section .text

cmd_create_database:
    push rbx
    push r12

    mov r12, rdi

    call _validate_db_name
    test rax, rax
    jnz .done

    mov rdi, r12
    call db_storage_find_db
    cmp rax, -1
    jne .duplicate

    mov rdi, r12
    call db_storage_alloc_db
    cmp rax, -1
    je .full

    mov dil, COLOR_OK
    call display_set_color
    lea rsi, [str_create_ok_a]
    call display_put_string
    mov rsi, r12
    call display_put_string
    lea rsi, [str_create_ok_b]
    call display_put_string
    mov dil, COLOR_NORMAL
    call display_set_color
    xor rax, rax
    jmp .done

.duplicate:
    mov dil, COLOR_ERR
    call display_set_color
    lea rsi, [str_create_dup]
    call display_put_string
    mov dil, COLOR_NORMAL
    call display_set_color
    mov rax, 1
    jmp .done

.full:
    mov dil, COLOR_ERR
    call display_set_color
    lea rsi, [str_create_full]
    call display_put_string
    mov dil, COLOR_NORMAL
    call display_set_color
    mov rax, 1

.done:
    pop r12
    pop rbx
    ret

_validate_db_name:
    push rbx
    push rcx

    test rdi, rdi
    jz .empty

    mov bl, byte [rdi]
    test bl, bl
    jz .empty

    xor rcx, rcx
.len_loop:
    cmp byte [rdi + rcx], 0
    je .check_len
    inc rcx
    jmp .len_loop

.check_len:
    test rcx, rcx
    jz .empty
    cmp rcx, MAX_DB_NAME_LEN
    jg .too_long

    xor rcx, rcx
.char_loop:
    movzx rax, byte [rdi + rcx]
    test rax, rax
    jz .ok
    cmp rax, 0x1F
    jle .invalid
    cmp rax, '/'
    je .invalid
    cmp rax, '\\'
    je .invalid
    cmp rax, ':'
    je .invalid
    cmp rax, '*'
    je .invalid
    cmp rax, '?'
    je .invalid
    cmp rax, '"'
    je .invalid
    cmp rax, '<'
    je .invalid
    cmp rax, '>'
    je .invalid
    cmp rax, '|'
    je .invalid
    inc rcx
    jmp .char_loop

.ok:
    xor rax, rax
    jmp .done

.empty:
    mov dil, COLOR_ERR
    call display_set_color
    lea rsi, [str_create_empty]
    call display_put_string
    mov dil, COLOR_NORMAL
    call display_set_color
    mov rax, 1
    jmp .done

.too_long:
    mov dil, COLOR_ERR
    call display_set_color
    lea rsi, [str_create_long]
    call display_put_string
    mov dil, COLOR_NORMAL
    call display_set_color
    mov rax, 1
    jmp .done

.invalid:
    mov dil, COLOR_ERR
    call display_set_color
    lea rsi, [str_create_invalid]
    call display_put_string
    mov dil, COLOR_NORMAL
    call display_set_color
    mov rax, 1

.done:
    pop rcx
    pop rbx
    ret
