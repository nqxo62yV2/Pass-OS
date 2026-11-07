; PassOS Command Implementations
; Contains cmd_help, cmd_enter_database, cmd_changelogs, cmd_purge, cmd_exit, cmd_clear.

BITS 64

global cmd_help
global cmd_enter_database
global cmd_changelogs
global cmd_purge
global cmd_clear
global cmd_exit

extern display_put_string
extern display_put_char
extern display_set_color
extern display_clear
extern keyboard_read_line
extern keyboard_read_line_masked
extern database_init
extern database_open
extern database_close
extern table_enter_database
extern authentication_verify_token
extern secure_zero
extern system_reboot

COLOR_NORMAL    equ 0x07
COLOR_HEADER    equ 0x0F
COLOR_WARN      equ 0x0C
COLOR_CMD       equ 0x0B
COLOR_OK        equ 0x0A

TOKEN_BUF_LEN   equ 256
INPUT_BUF_LEN   equ 8

section .bss
    purge_token_buf     resb TOKEN_BUF_LEN
    purge_input_buf     resb INPUT_BUF_LEN

section .data
    str_help_header     db 'PassOS V1.0 - Available Commands', 0x0A
                        db '================================', 0x0A, 0x0A, 0
    str_help_table:
        db '/help', 0x0A
        db '  Display this help screen.', 0x0A, 0x0A
        db '/create_database("NAME")', 0x0A
        db '  Create a new password database.', 0x0A, 0x0A
        db '/enter_database("NAME")', 0x0A
        db '  Open a database and view its interactive table.', 0x0A, 0x0A
        db '/searchall_databases("Name=TERM")', 0x0A
        db '  Search all databases for entries matching TERM.', 0x0A, 0x0A
        db '/search_database("DB=TERM")', 0x0A
        db '  Search a specific database for matching entries.', 0x0A, 0x0A
        db '/settings', 0x0A
        db '  Open the system settings panel.', 0x0A, 0x0A
        db '/clear  /cls', 0x0A
        db '  Clear the terminal screen.', 0x0A, 0x0A
        db '/changelogs', 0x0A
        db '  Show installed version and release notes.', 0x0A, 0x0A
        db '/delete_database("NAME")', 0x0A
        db '  Permanently delete a database (3-stage confirmation).', 0x0A, 0x0A
        db '/export_database("NAME")', 0x0A
        db '  Export a database to USB.', 0x0A, 0x0A
        db '/export_database=all', 0x0A
        db '  Export all databases to USB.', 0x0A, 0x0A
        db '/purge', 0x0A
        db '  Permanently destroy ALL databases (requires master token).', 0x0A, 0x0A
        db '/update', 0x0A
        db '  Install a PassOS update from USB.', 0x0A, 0x0A
        db '/install', 0x0A
        db '  Install PassOS to a drive.', 0x0A, 0x0A
        db '/exit', 0x0A
        db '  Exit PassOS safely.', 0x0A, 0
    str_help_footer     db '================================', 0x0A, 0

    str_changelogs_hdr  db 'PassOS Release Notes', 0x0A
                        db '====================', 0x0A, 0x0A, 0
    str_changelogs_v1:
        db 'Version: 1.0', 0x0A
        db 'Release: Initial release', 0x0A, 0x0A
        db 'Features:', 0x0A
        db '  - Argon2id master token key derivation', 0x0A
        db '  - AES-256-GCM authenticated encryption', 0x0A
        db '  - Encrypted password database system', 0x0A
        db '  - Interactive ASCII table navigation', 0x0A
        db '  - Global and per-database search', 0x0A
        db '  - USB export (plaintext and encrypted)', 0x0A
        db '  - Three-stage database deletion', 0x0A
        db '  - Cryptographic purge operation', 0x0A
        db '  - Built-in gap-buffer text editor', 0x0A
        db '  - BIOS and UEFI boot support', 0x0A
        db '  - x86-64 and ARM64 architecture support', 0x0A
        db '  - USB installation support', 0x0A, 0x0A
        db 'Known Limitations:', 0x0A
        db '  - Single user account (root) in V1.0', 0x0A
        db '  - USB HID input via PS/2 compatibility layer', 0x0A, 0

    str_purge_title     db 0x0A, 'CRITICAL SYSTEM OPERATION', 0x0A, 0x0A
                        db 'PURGE WILL DESTROY ALL DATABASES.', 0x0A, 0x0A
                        db 'This operation cannot be reversed.', 0x0A, 0x0A
                        db 'All stored password records and associated', 0x0A
                        db 'encryption keys will be invalidated.', 0x0A, 0x0A
                        db 'Enter your master token to continue: ', 0
    str_purge_confirm   db 0x0A, 'Type CONFIRM to proceed, or anything else to abort: ', 0
    str_purge_running   db 0x0A, 'Purging all databases...', 0x0A, 0
    str_purge_done      db 'Purge complete. All database records destroyed.', 0x0A, 0
    str_purge_aborted   db 'Purge aborted.', 0x0A, 0
    str_purge_auth_fail db 'Authentication failed. Purge aborted.', 0x0A, 0

    str_exit_msg        db 0x0A, 'PassOS shutting down safely. Goodbye.', 0x0A, 0

    confirm_str         db 'CONFIRM', 0

section .text

cmd_help:
    push rbx

    mov dil, COLOR_HEADER
    call display_set_color
    lea rsi, [str_help_header]
    call display_put_string
    mov dil, COLOR_CMD
    call display_set_color
    lea rsi, [str_help_table]
    call display_put_string
    mov dil, COLOR_NORMAL
    call display_set_color
    lea rsi, [str_help_footer]
    call display_put_string

    pop rbx
    ret

cmd_enter_database:
    push rbx
    push r12

    mov r12, rdi

    mov rdi, r12
    call database_open
    test rax, rax
    jnz .not_found

    call table_enter_database
    call database_close
    jmp .done

.not_found:
    mov dil, COLOR_WARN
    call display_set_color
    lea rsi, [str_db_not_found]
    call display_put_string
    mov dil, COLOR_NORMAL
    call display_set_color

.done:
    pop r12
    pop rbx
    ret

cmd_changelogs:
    push rbx

    mov dil, COLOR_HEADER
    call display_set_color
    lea rsi, [str_changelogs_hdr]
    call display_put_string
    mov dil, COLOR_NORMAL
    call display_set_color
    lea rsi, [str_changelogs_v1]
    call display_put_string

    pop rbx
    ret

cmd_purge:
    push rbx

    mov dil, COLOR_WARN
    call display_set_color
    lea rsi, [str_purge_title]
    call display_put_string
    mov dil, COLOR_NORMAL
    call display_set_color

    lea rsi, [purge_token_buf]
    mov rdx, TOKEN_BUF_LEN - 1
    call keyboard_read_line_masked

    lea rdi, [purge_token_buf]
    call authentication_verify_token
    test rax, rax
    jnz .auth_fail

    lea rdi, [purge_token_buf]
    mov rsi, TOKEN_BUF_LEN
    call secure_zero

    mov dil, COLOR_WARN
    call display_set_color
    lea rsi, [str_purge_confirm]
    call display_put_string
    mov dil, COLOR_NORMAL
    call display_set_color

    lea rsi, [purge_input_buf]
    mov rdx, INPUT_BUF_LEN
    call keyboard_read_line

    lea rdi, [purge_input_buf]
    lea rsi, [confirm_str]
    call _str_eq7
    test rax, rax
    jz .aborted

    mov dil, COLOR_WARN
    call display_set_color
    lea rsi, [str_purge_running]
    call display_put_string

    call _purge_all_databases

    mov dil, COLOR_OK
    call display_set_color
    lea rsi, [str_purge_done]
    call display_put_string
    mov dil, COLOR_NORMAL
    call display_set_color
    jmp .done

.auth_fail:
    lea rdi, [purge_token_buf]
    mov rsi, TOKEN_BUF_LEN
    call secure_zero
    mov dil, COLOR_WARN
    call display_set_color
    lea rsi, [str_purge_auth_fail]
    call display_put_string
    mov dil, COLOR_NORMAL
    call display_set_color
    jmp .done

.aborted:
    lea rsi, [str_purge_aborted]
    call display_put_string

.done:
    pop rbx
    ret

_purge_all_databases:
    push rbx
    push rcx

    extern db_storage_db_count
    extern db_storage_free_db
    extern db_storage_get_db_info
    extern secure_zero
    extern storage_write_sector

    call db_storage_db_count
    mov rcx, rax

.purge_loop:
    test rcx, rcx
    jz .done

    push rcx
    mov rdi, 0
    call db_storage_get_db_info
    push rax
    call db_storage_db_count
    dec rax
    mov rdi, rax
    call db_storage_free_db
    pop rax
    pop rcx
    dec rcx
    jmp .purge_loop

.done:
    pop rcx
    pop rbx
    ret

cmd_clear:
    call display_clear
    ret

cmd_exit:
    push rbx

    lea rsi, [str_exit_msg]
    call display_put_string

    call display_clear
    cli
.halt:
    hlt
    jmp .halt

_str_eq7:
    push rbx
    push rcx
    mov rcx, 7
.loop:
    test rcx, rcx
    jz .equal
    movzx rax, byte [rdi]
    movzx rbx, byte [rsi]
    cmp rax, rbx
    jne .no
    inc rdi
    inc rsi
    dec rcx
    jmp .loop
.equal:
    movzx rax, byte [rdi]
    test rax, rax
    jnz .no
    mov rax, 1
    jmp .done
.no:
    xor rax, rax
.done:
    pop rcx
    pop rbx
    ret

str_db_not_found    db 'Error: Database not found.', 0x0A, 0
