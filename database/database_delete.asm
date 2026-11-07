; PassOS Database Delete Module
; Handles /delete_database("NAME") with three-stage confirmation.
; Stage 1: YES/NO warning
; Stage 2: second YES/NO confirmation
; Stage 3: master token re-authentication

BITS 64

global cmd_delete_database

extern db_storage_find_db
extern db_storage_free_db
extern display_put_string
extern display_put_char
extern display_set_color
extern keyboard_read_line
extern keyboard_read_line_masked
extern authentication_verify_token
extern secure_zero

COLOR_WARN      equ 0x0C
COLOR_NORMAL    equ 0x07
COLOR_BOLD      equ 0x0F

INPUT_BUF_LEN   equ 16
TOKEN_BUF_LEN   equ 256

section .bss
    del_input_buf       resb INPUT_BUF_LEN
    del_token_buf       resb TOKEN_BUF_LEN

section .data
    str_del_stage1_a    db 0x0A, 'WARNING:', 0x0A
                        db 'You are about to delete database "', 0
    str_del_stage1_b    db '".', 0x0A, 0x0A
                        db 'Continue? (YES/NO): ', 0
    str_del_stage2      db 0x0A, 'SECOND CONFIRMATION', 0x0A, 0x0A
                        db 'All entries in this database will become', 0x0A
                        db 'permanently inaccessible.', 0x0A, 0x0A
                        db 'Confirm deletion? (YES/NO): ', 0
    str_del_stage3      db 0x0A, 'MASTER TOKEN REQUIRED', 0x0A, 0x0A
                        db 'Enter your master token to authorize deletion: ', 0
    str_del_ok          db 0x0A, 'Database deleted.', 0x0A, 0
    str_del_aborted     db 0x0A, 'Deletion aborted.', 0x0A, 0
    str_del_not_found   db 'Error: Database not found.', 0x0A, 0
    str_del_auth_fail   db 0x0A, 'Authentication failed. Deletion aborted.', 0x0A, 0

    yes_str             db 'YES', 0

section .text

cmd_delete_database:
    push rbx
    push r12

    mov r12, rdi

    mov rdi, r12
    call db_storage_find_db
    cmp rax, -1
    je .not_found

    mov dil, COLOR_WARN
    call display_set_color
    lea rsi, [str_del_stage1_a]
    call display_put_string
    mov dil, COLOR_NORMAL
    call display_set_color
    mov rsi, r12
    call display_put_string
    lea rsi, [str_del_stage1_b]
    call display_put_string

    lea rsi, [del_input_buf]
    mov rdx, INPUT_BUF_LEN - 1
    call keyboard_read_line

    lea rdi, [del_input_buf]
    lea rsi, [yes_str]
    mov rdx, 3
    call _str_eq3
    test rax, rax
    jz .aborted

    mov dil, COLOR_WARN
    call display_set_color
    lea rsi, [str_del_stage2]
    call display_put_string
    mov dil, COLOR_NORMAL
    call display_set_color

    lea rsi, [del_input_buf]
    mov rdx, INPUT_BUF_LEN - 1
    call keyboard_read_line

    lea rdi, [del_input_buf]
    lea rsi, [yes_str]
    mov rdx, 3
    call _str_eq3
    test rax, rax
    jz .aborted

    mov dil, COLOR_BOLD
    call display_set_color
    lea rsi, [str_del_stage3]
    call display_put_string
    mov dil, COLOR_NORMAL
    call display_set_color

    lea rsi, [del_token_buf]
    mov rdx, TOKEN_BUF_LEN - 1
    call keyboard_read_line_masked

    lea rdi, [del_token_buf]
    call authentication_verify_token
    test rax, rax
    jnz .auth_failed

    mov rdi, r12
    call db_storage_free_db

    lea rdi, [del_token_buf]
    mov rsi, TOKEN_BUF_LEN
    call secure_zero

    mov dil, COLOR_NORMAL
    call display_set_color
    lea rsi, [str_del_ok]
    call display_put_string
    xor rax, rax
    jmp .done

.auth_failed:
    lea rdi, [del_token_buf]
    mov rsi, TOKEN_BUF_LEN
    call secure_zero
    mov dil, COLOR_WARN
    call display_set_color
    lea rsi, [str_del_auth_fail]
    call display_put_string
    mov dil, COLOR_NORMAL
    call display_set_color
    mov rax, 1
    jmp .done

.not_found:
    mov dil, COLOR_WARN
    call display_set_color
    lea rsi, [str_del_not_found]
    call display_put_string
    mov dil, COLOR_NORMAL
    call display_set_color
    mov rax, 1
    jmp .done

.aborted:
    lea rdi, [del_token_buf]
    mov rsi, TOKEN_BUF_LEN
    call secure_zero
    lea rsi, [str_del_aborted]
    call display_put_string
    xor rax, rax

.done:
    pop r12
    pop rbx
    ret

_str_eq3:
    push rbx
    movzx rax, byte [rdi]
    movzx rbx, byte [rsi]
    cmp rax, rbx
    jne .no
    movzx rax, byte [rdi + 1]
    movzx rbx, byte [rsi + 1]
    cmp rax, rbx
    jne .no
    movzx rax, byte [rdi + 2]
    movzx rbx, byte [rsi + 2]
    cmp rax, rbx
    jne .no
    movzx rax, byte [rdi + 3]
    test rax, rax
    jnz .no
    mov rax, 1
    jmp .done
.no:
    xor rax, rax
.done:
    pop rbx
    ret
