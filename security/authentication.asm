; PassOS Authentication Module
; Handles master token input, Argon2id-based verification, and first-run setup.
; All token data is kept in secure memory and zeroed after use.

BITS 64

global authentication_start
global authentication_verify_token
global authentication_is_first_run
global authentication_first_run_setup

extern display_put_string
extern display_put_char
extern display_clear
extern display_set_color
extern keyboard_read_line_masked
extern keyboard_read_line
extern argon2id_derive
extern secure_zero
extern secure_compare
extern secure_random_bytes
extern storage_read_sector
extern storage_write_sector

TOKEN_MAX_LEN       equ 256
DERIVED_KEY_LEN     equ 64
SALT_LEN            equ 16
HASH_STORAGE_SECTOR equ 1

COLOR_WARN          equ 0x0C
COLOR_NORMAL        equ 0x07
COLOR_BOLD          equ 0x0F
COLOR_INPUT         equ 0x0A

section .bss
    derived_key         resb DERIVED_KEY_LEN
    stored_salt         resb SALT_LEN
    stored_hash         resb DERIVED_KEY_LEN
    token_buffer        resb TOKEN_MAX_LEN
    confirm_buffer      resb TOKEN_MAX_LEN
    auth_sector_buf     resb 512
    first_run_flag      resb 1

section .data
    MAGIC               db 'PASSOS10'
    MAGIC_LEN           equ 8

    str_login_prompt    db 'PassOS Login', 0x0A, 0x0A, 0
    str_user_prompt     db 'Username: root', 0x0A, 0
    str_token_prompt    db 'Master token: ', 0
    str_auth_failed     db 0x0A, 'Authentication failed. Try again.', 0x0A, 0
    str_auth_ok         db 0x0A, 'Authentication successful.', 0x0A, 0

    str_setup_title     db 'PassOS First-Run Security Setup', 0x0A, 0x0A, 0
    str_setup_info      db 'No master token has been configured.', 0x0A
                        db 'You must create a master token now.', 0x0A, 0x0A, 0
    str_new_token       db 'Enter new master token: ', 0
    str_confirm_token   db 'Confirm master token:   ', 0
    str_token_mismatch  db 0x0A, 'Tokens do not match. Try again.', 0x0A, 0
    str_token_short     db 0x0A, 'Token must be at least 8 characters.', 0x0A, 0

    str_warn_title      db 'WARNING: MASTER TOKEN SECURITY', 0x0A, 0x0A, 0
    str_warn_body:
        db 'Your master token is the only way to', 0x0A
        db 'unlock your encrypted password vault.', 0x0A, 0x0A
        db 'If you lose or forget this token,', 0x0A
        db 'your stored passwords cannot be recovered.', 0x0A, 0x0A
        db 'There is:', 0x0A
        db '  - No password reset.', 0x0A
        db '  - No account recovery.', 0x0A
        db '  - No master token recovery.', 0x0A
        db '  - No hidden recovery mechanism.', 0x0A, 0x0A
        db 'Write down your master token and store', 0x0A
        db 'it in a physically secure location.', 0x0A, 0x0A
        db 'Continue? (YES/NO): ', 0
    str_aborted         db 'Setup aborted. System halted.', 0x0A, 0
    str_token_saved     db 0x0A, 'Master token configured. PassOS is ready.', 0x0A, 0

section .text

authentication_start:
    push rbx

    call _load_auth_sector
    call authentication_is_first_run
    test rax, rax
    jnz .first_run

.login_loop:
    call _display_login_screen
    call _prompt_token

    call _verify_stored_token
    test rax, rax
    jnz .auth_failed

    mov dil, COLOR_NORMAL
    call display_set_color
    lea rsi, [str_auth_ok]
    call display_put_string
    jmp .done

.auth_failed:
    mov dil, COLOR_WARN
    call display_set_color
    lea rsi, [str_auth_failed]
    call display_put_string
    mov dil, COLOR_NORMAL
    call display_set_color
    jmp .login_loop

.first_run:
    call authentication_first_run_setup

.done:
    pop rbx
    ret

_display_login_screen:
    call display_clear
    mov dil, COLOR_BOLD
    call display_set_color
    lea rsi, [str_login_prompt]
    call display_put_string
    mov dil, COLOR_NORMAL
    call display_set_color
    lea rsi, [str_user_prompt]
    call display_put_string
    lea rsi, [str_token_prompt]
    call display_put_string
    ret

_prompt_token:
    lea rsi, [token_buffer]
    mov rdx, TOKEN_MAX_LEN - 1
    call keyboard_read_line_masked
    ret

_verify_stored_token:
    push rbx

    lea rdi, [token_buffer]
    call _strlen
    mov rcx, rax

    lea rdi, [derived_key]
    lea rsi, [token_buffer]
    mov rdx, rcx
    lea rcx, [stored_salt]
    mov r8, SALT_LEN
    call argon2id_derive

    lea rdi, [derived_key]
    lea rsi, [stored_hash]
    mov rdx, DERIVED_KEY_LEN
    call secure_compare

    push rax
    lea rdi, [derived_key]
    mov rsi, DERIVED_KEY_LEN
    call secure_zero
    lea rdi, [token_buffer]
    mov rsi, TOKEN_MAX_LEN
    call secure_zero
    pop rax

    xor rax, 1
    pop rbx
    ret

authentication_is_first_run:
    mov al, [first_run_flag]
    movzx rax, al
    ret

authentication_first_run_setup:
    push rbx

    call display_clear
    mov dil, COLOR_BOLD
    call display_set_color
    lea rsi, [str_setup_title]
    call display_put_string
    mov dil, COLOR_NORMAL
    call display_set_color
    lea rsi, [str_setup_info]
    call display_put_string

    mov dil, COLOR_WARN
    call display_set_color
    lea rsi, [str_warn_title]
    call display_put_string
    mov dil, COLOR_NORMAL
    call display_set_color
    lea rsi, [str_warn_body]
    call display_put_string

    lea rsi, [confirm_buffer]
    mov rdx, 4
    call keyboard_read_line

    lea rdi, [confirm_buffer]
    lea rsi, [yes_str]
    mov rdx, 3
    call secure_compare
    test rax, rax
    jz .aborted

.token_entry:
    call display_clear
    lea rsi, [str_new_token]
    call display_put_string
    lea rsi, [token_buffer]
    mov rdx, TOKEN_MAX_LEN - 1
    call keyboard_read_line_masked

    lea rdi, [token_buffer]
    call _strlen
    cmp rax, 8
    jl .too_short

    lea rsi, [str_confirm_token]
    call display_put_string
    lea rsi, [confirm_buffer]
    mov rdx, TOKEN_MAX_LEN - 1
    call keyboard_read_line_masked

    lea rdi, [token_buffer]
    call _strlen
    mov rbx, rax

    lea rdi, [token_buffer]
    lea rsi, [confirm_buffer]
    mov rdx, rbx
    call secure_compare
    test rax, rax
    jz .mismatch

    call _generate_and_store_token
    lea rsi, [str_token_saved]
    call display_put_string
    jmp .done

.too_short:
    lea rsi, [str_token_short]
    call display_put_string
    jmp .token_entry

.mismatch:
    lea rsi, [str_token_mismatch]
    call display_put_string
    jmp .token_entry

.aborted:
    lea rsi, [str_aborted]
    call display_put_string
    cli
.halt:
    hlt
    jmp .halt

.done:
    lea rdi, [token_buffer]
    mov rsi, TOKEN_MAX_LEN
    call secure_zero
    lea rdi, [confirm_buffer]
    mov rsi, TOKEN_MAX_LEN
    call secure_zero

    pop rbx
    ret

_generate_and_store_token:
    push rbx

    lea rdi, [stored_salt]
    mov rsi, SALT_LEN
    call secure_random_bytes

    lea rdi, [token_buffer]
    call _strlen
    mov rcx, rax

    lea rdi, [stored_hash]
    lea rsi, [token_buffer]
    mov rdx, rcx
    lea rcx, [stored_salt]
    mov r8, SALT_LEN
    call argon2id_derive

    call _save_auth_sector

    mov byte [first_run_flag], 0

    pop rbx
    ret

_load_auth_sector:
    push rbx

    lea rdi, [auth_sector_buf]
    mov rsi, HASH_STORAGE_SECTOR
    call storage_read_sector

    lea rdi, [auth_sector_buf]
    lea rsi, [MAGIC]
    mov rdx, MAGIC_LEN
    call secure_compare
    test rax, rax
    jz .first_run_detected

    lea rdi, [stored_salt]
    lea rsi, [auth_sector_buf + MAGIC_LEN]
    mov rdx, SALT_LEN
    call _memcopy

    lea rdi, [stored_hash]
    lea rsi, [auth_sector_buf + MAGIC_LEN + SALT_LEN]
    mov rdx, DERIVED_KEY_LEN
    call _memcopy

    mov byte [first_run_flag], 0
    jmp .done

.first_run_detected:
    mov byte [first_run_flag], 1

.done:
    pop rbx
    ret

_save_auth_sector:
    push rbx

    lea rdi, [auth_sector_buf]
    mov rsi, 512
    xor al, al
    push rdi
    push rsi
    mov rcx, rsi
    rep stosb
    pop rsi
    pop rdi

    lea rdi, [auth_sector_buf]
    lea rsi, [MAGIC]
    mov rdx, MAGIC_LEN
    call _memcopy

    lea rdi, [auth_sector_buf + MAGIC_LEN]
    lea rsi, [stored_salt]
    mov rdx, SALT_LEN
    call _memcopy

    lea rdi, [auth_sector_buf + MAGIC_LEN + SALT_LEN]
    lea rsi, [stored_hash]
    mov rdx, DERIVED_KEY_LEN
    call _memcopy

    lea rsi, [auth_sector_buf]
    mov rdi, HASH_STORAGE_SECTOR
    call storage_write_sector

    pop rbx
    ret

_strlen:
    push rbx
    xor rbx, rbx
.loop:
    cmp byte [rdi + rbx], 0
    je .done
    inc rbx
    jmp .loop
.done:
    mov rax, rbx
    pop rbx
    ret

_memcopy:
    push rcx
    push rsi
    push rdi
    mov rcx, rdx
    rep movsb
    pop rdi
    pop rsi
    pop rcx
    ret

; authentication_verify_token(rdi = null-terminated token string)
; Returns 0 if the token is correct, 1 if it is wrong.
; Used by commands that require re-authentication (delete, export, purge, install, update).
authentication_verify_token:
    push rbx
    push r12

    mov r12, rdi

    ; derive key from supplied token
    call _strlen          ; rax = token length
    mov rcx, rax

    lea rdi, [derived_key]
    mov rsi, r12
    mov rdx, rcx
    lea rcx, [stored_salt]
    mov r8, SALT_LEN
    call argon2id_derive

    ; constant-time compare against stored hash
    lea rdi, [derived_key]
    lea rsi, [stored_hash]
    mov rdx, DERIVED_KEY_LEN
    call secure_compare   ; returns 1 if equal, 0 if different

    ; zero the derived key immediately
    push rax
    lea rdi, [derived_key]
    mov rsi, DERIVED_KEY_LEN
    call secure_zero
    pop rax

    ; invert: secure_compare returns 1=match, callers expect 0=success
    xor rax, 1

    pop r12
    pop rbx
    ret

yes_str db 'YES', 0
