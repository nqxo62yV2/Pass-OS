; PassOS Command Parser
; Parses command strings and dispatches to the appropriate handler.
; Supports quoted arguments, special characters, and proper escaping.
;
; Command table:
;   /help
;   /create_database("NAME")
;   /enter_database("NAME")
;   /searchall_databases("Name=TERM")
;   /search_database("DB=TERM")
;   /settings
;   /clear  /cls
;   /changelogs
;   /delete_database("NAME")
;   /export_database("NAME")
;   /export_database=all
;   /purge
;   /update
;   /install
;   /exit

BITS 64

global command_parse_and_execute

extern cmd_help
extern cmd_create_database
extern cmd_enter_database
extern cmd_searchall_databases
extern cmd_search_database
extern cmd_settings
extern cmd_clear
extern cmd_changelogs
extern cmd_delete_database
extern cmd_export_database
extern cmd_export_all_databases
extern cmd_purge
extern cmd_update
extern cmd_install
extern cmd_exit
extern cmd_status
extern display_put_string
extern display_put_char
extern display_set_color

ARG_BUF_LEN     equ 256
ARG2_BUF_LEN    equ 256
COLOR_ERR       equ 0x0C
COLOR_NORMAL    equ 0x07

section .bss
    arg1_buf    resb ARG_BUF_LEN
    arg2_buf    resb ARG2_BUF_LEN

section .data
    str_unknown_cmd     db 'Unknown command. Type /help for a list.', 0x0A, 0
    str_syntax_err      db 'Syntax error. Check /help for correct usage.', 0x0A, 0

    cmd_help_str            db '/help', 0
    cmd_create_db_str       db '/create_database', 0
    cmd_enter_db_str        db '/enter_database', 0
    cmd_searchall_str       db '/searchall_databases', 0
    cmd_search_db_str       db '/search_database', 0
    cmd_settings_str        db '/settings', 0
    cmd_clear_str           db '/clear', 0
    cmd_cls_str             db '/cls', 0
    cmd_changelogs_str      db '/changelogs', 0
    cmd_delete_db_str       db '/delete_database', 0
    cmd_export_db_str       db '/export_database', 0
    cmd_export_all_str      db '/export_database=all', 0
    cmd_purge_str           db '/purge', 0
    cmd_update_str          db '/update', 0
    cmd_status_str          db '/status', 0
    cmd_install_str         db '/install', 0
    cmd_exit_str            db '/exit', 0

section .text

command_parse_and_execute:
    push rbx
    push r12
    push r13

    mov r12, rdi

    lea rsi, [cmd_help_str]
    call _cmd_match
    test rax, rax
    jz .try_create

    call cmd_help
    jmp .done

.try_create:
    lea rsi, [cmd_create_db_str]
    call _cmd_match_with_arg
    test rax, rax
    jz .try_enter

    lea rdi, [arg1_buf]
    call cmd_create_database
    jmp .done

.try_enter:
    lea rsi, [cmd_enter_db_str]
    call _cmd_match_with_arg
    test rax, rax
    jz .try_searchall

    lea rdi, [arg1_buf]
    call cmd_enter_database
    jmp .done

.try_searchall:
    lea rsi, [cmd_searchall_str]
    call _cmd_match_with_arg
    test rax, rax
    jz .try_search

    lea rdi, [arg1_buf]
    call _parse_name_eq_value
    mov rdi, rax
    call cmd_searchall_databases
    jmp .done

.try_search:
    lea rsi, [cmd_search_db_str]
    call _cmd_match_with_arg
    test rax, rax
    jz .try_settings

    lea rdi, [arg1_buf]
    call _parse_db_eq_value
    mov rdi, rax
    mov rsi, rbx
    call cmd_search_database
    jmp .done

.try_settings:
    lea rsi, [cmd_settings_str]
    call _cmd_match
    test rax, rax
    jz .try_clear

    call cmd_settings
    jmp .done

.try_clear:
    lea rsi, [cmd_clear_str]
    call _cmd_match
    test rax, rax
    jz .try_cls

    call cmd_clear
    jmp .done

.try_cls:
    lea rsi, [cmd_cls_str]
    call _cmd_match
    test rax, rax
    jz .try_changelogs

    call cmd_clear
    jmp .done

.try_changelogs:
    lea rsi, [cmd_changelogs_str]
    call _cmd_match
    test rax, rax
    jz .try_delete

    call cmd_changelogs
    jmp .done

.try_delete:
    lea rsi, [cmd_delete_db_str]
    call _cmd_match_with_arg
    test rax, rax
    jz .try_export_all

    lea rdi, [arg1_buf]
    call cmd_delete_database
    jmp .done

.try_export_all:
    lea rsi, [cmd_export_all_str]
    call _cmd_match
    test rax, rax
    jz .try_export

    call cmd_export_all_databases
    jmp .done

.try_export:
    lea rsi, [cmd_export_db_str]
    call _cmd_match_with_arg
    test rax, rax
    jz .try_purge

    lea rdi, [arg1_buf]
    call cmd_export_database
    jmp .done

.try_purge:
    lea rsi, [cmd_purge_str]
    call _cmd_match
    test rax, rax
    jz .try_update

    call cmd_purge
    jmp .done

.try_update:
    lea rsi, [cmd_update_str]
    call _cmd_match
    test rax, rax
    jz .try_status

    call cmd_update
    jmp .done

.try_status:
    lea rsi, [cmd_status_str]
    call _cmd_match
    test rax, rax
    jz .try_install

    call cmd_status
    jmp .done

.try_install:
    lea rsi, [cmd_install_str]
    call _cmd_match
    test rax, rax
    jz .try_exit

    call cmd_install
    jmp .done

.try_exit:
    lea rsi, [cmd_exit_str]
    call _cmd_match
    test rax, rax
    jz .unknown

    call cmd_exit
    jmp .done

.unknown:
    mov dil, COLOR_ERR
    call display_set_color
    lea rsi, [str_unknown_cmd]
    call display_put_string
    mov dil, COLOR_NORMAL
    call display_set_color

.done:
    pop r13
    pop r12
    pop rbx
    ret

_cmd_match:
    push rbx
    push rcx
    push rdi

    mov rdi, r12

.loop:
    movzx rax, byte [rsi]
    movzx rbx, byte [rdi]
    test rax, rax
    jz .check_end
    cmp rax, rbx
    jne .no_match
    inc rsi
    inc rdi
    jmp .loop

.check_end:
    test rbx, rbx
    jnz .no_match
    mov rax, 1
    jmp .done

.no_match:
    xor rax, rax

.done:
    pop rdi
    pop rcx
    pop rbx
    ret

_cmd_match_with_arg:
    push rbx
    push rcx
    push rdi
    push r8

    mov rdi, r12
    mov r8, rsi

.loop:
    movzx rax, byte [r8]
    movzx rbx, byte [rdi]
    test rax, rax
    jz .check_paren
    cmp rax, rbx
    jne .no_match
    inc r8
    inc rdi
    jmp .loop

.check_paren:
    cmp byte [rdi], '('
    jne .no_match
    inc rdi

    cmp byte [rdi], '"'
    jne .no_match
    inc rdi

    lea rsi, [arg1_buf]
    xor rcx, rcx

.arg_loop:
    movzx rax, byte [rdi]
    test rax, rax
    jz .no_match
    cmp rax, '"'
    je .close_quote
    cmp rax, '\\'
    je .escape
    mov byte [rsi + rcx], al
    inc rcx
    inc rdi
    jmp .arg_loop

.escape:
    inc rdi
    movzx rax, byte [rdi]
    test rax, rax
    jz .no_match
    mov byte [rsi + rcx], al
    inc rcx
    inc rdi
    jmp .arg_loop

.close_quote:
    mov byte [rsi + rcx], 0
    inc rdi
    cmp byte [rdi], ')'
    jne .no_match
    mov rax, 1
    jmp .done

.no_match:
    xor rax, rax

.done:
    pop r8
    pop rdi
    pop rcx
    pop rbx
    ret

_parse_name_eq_value:
    push rbx
    push rcx
    push rdi

    xor rcx, rcx

.loop:
    movzx rax, byte [rdi + rcx]
    test rax, rax
    jz .no_eq
    cmp rax, '='
    je .found_eq
    inc rcx
    jmp .loop

.found_eq:
    lea rax, [rdi + rcx + 1]
    jmp .done

.no_eq:
    mov rax, rdi

.done:
    pop rdi
    pop rcx
    pop rbx
    ret

_parse_db_eq_value:
    push rbx
    push rcx
    push rdi

    xor rcx, rcx

.loop:
    movzx rax, byte [rdi + rcx]
    test rax, rax
    jz .no_eq
    cmp rax, '='
    je .found_eq
    inc rcx
    jmp .loop

.found_eq:
    lea rbx, [rdi + rcx + 1]
    mov byte [rdi + rcx], 0
    mov rax, rdi
    jmp .done

.no_eq:
    xor rbx, rbx
    mov rax, rdi

.done:
    pop rdi
    pop rcx
    pop rbx
    ret
