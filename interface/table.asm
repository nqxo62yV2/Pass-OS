; PassOS Interactive ASCII Table
; Renders the 4-column password entry table with keyboard navigation.
; Columns: Name | ID | Password | Encryption Key
; Arrow keys navigate rows/columns, Enter selects, Escape exits.

BITS 64

global table_enter_database
global table_render
global table_handle_input

extern database_get_entry
extern database_get_entry_count
extern database_add_entry
extern database_delete_entry
extern display_put_string
extern display_put_char
extern display_set_color
extern display_clear
extern display_set_cursor
extern display_get_cursor_row
extern display_get_cursor_col
extern keyboard_read_char
extern keyboard_read_line
extern keyboard_read_line_masked
extern aes256gcm_decrypt
extern secure_zero

COLOR_NORMAL        equ 0x07
COLOR_SELECTED      equ 0x70
COLOR_HEADER        equ 0x0F
COLOR_MASKED        equ 0x08
COLOR_REVEALED      equ 0x0A

ENTRY_NAME_OFFSET   equ 1
ENTRY_NAME_LEN      equ 64
ENTRY_ID_OFFSET     equ 65
ENTRY_ID_LEN        equ 8
ENTRY_PASS_OFFSET   equ 73
ENTRY_PASS_ENC_LEN  equ 128
ENTRY_KEY_OFFSET    equ 201
ENTRY_KEY_ENC_LEN   equ 48
ENTRY_TOTAL_LEN     equ 256

COL_NAME    equ 0
COL_ID      equ 1
COL_PASS    equ 2
COL_KEY     equ 3
NUM_COLS    equ 4

TABLE_TOP_ROW   equ 5
TABLE_NAME_COL  equ 1
TABLE_NAME_W    equ 16
TABLE_ID_COL    equ 18
TABLE_ID_W      equ 10
TABLE_PASS_COL  equ 29
TABLE_PASS_W    equ 22
TABLE_KEY_COL   equ 52
TABLE_KEY_W     equ 16

SPECIAL_UP      equ 0x80
SPECIAL_DOWN    equ 0x81
SPECIAL_LEFT    equ 0x82
SPECIAL_RIGHT   equ 0x83
SPECIAL_ESC     equ 0x84
SPECIAL_TAB     equ 0x85

section .bss
    table_row_sel   resq 1
    table_col_sel   resq 1
    table_top_vis   resq 1
    entry_cache     resb ENTRY_TOTAL_LEN
    reveal_row      resq 1
    reveal_col      resq 1
    new_entry_buf   resb 512

section .data
    str_table_hdr_sep   db '+----------------+----------+----------------------+----------------+', 0
    str_table_hdr_row   db '| Name           | ID       | Password             | Encryption Key |', 0
    str_table_title     db 0x0A, 'Database Contents:', 0x0A, 0
    str_table_help      db '[Arrows] Navigate  [Enter] Reveal/Details  [N] New entry  [D] Delete  [Esc] Exit', 0
    str_masked          db '********', 0
    str_empty_db        db '| (no entries in this database)                                              |', 0x0A, 0
    str_newline         db 0x0A, 0
    str_new_name_p      db 'Name: ', 0
    str_new_pass_p      db 'Password: ', 0
    str_new_key_p       db 'Individual key (optional): ', 0
    str_entry_added     db 'Entry added.', 0x0A, 0
    str_del_confirm     db 'Delete this entry? (YES/NO): ', 0
    str_entry_deleted   db 'Entry deleted.', 0x0A, 0
    str_details_hdr     db 0x0A, '--- Entry Details ---', 0x0A, 0
    str_name_shown      db 'Name:     ', 0
    str_password_shown  db 'Password: ', 0
    str_key_shown       db 'Key:      ', 0
    str_press_any_key   db 0x0A, '[Press any key to return to table]', 0

    yes3    db 'YES', 0

section .text

table_enter_database:
    push rbx

    call database_get_entry_count
    mov qword [table_row_sel], 0
    mov qword [table_col_sel], 0
    mov qword [table_top_vis], 0
    mov qword [reveal_row], -1
    mov qword [reveal_col], -1

    call table_render

.event_loop:
    call keyboard_read_char
    movzx rdi, al
    call table_handle_input
    test rax, rax
    jnz .done

    call table_render
    jmp .event_loop

.done:
    pop rbx
    ret

table_render:
    push rbx
    push rcx

    call display_clear

    mov dil, COLOR_HEADER
    call display_set_color
    lea rsi, [str_table_title]
    call display_put_string

    lea rsi, [str_table_hdr_sep]
    call display_put_string
    mov al, 0x0A
    call display_put_char

    lea rsi, [str_table_hdr_row]
    call display_put_string
    mov al, 0x0A
    call display_put_char

    lea rsi, [str_table_hdr_sep]
    call display_put_string
    mov al, 0x0A
    call display_put_char

    mov dil, COLOR_NORMAL
    call display_set_color

    call database_get_entry_count
    mov rcx, rax
    test rcx, rcx
    jnz .has_entries
    lea rsi, [str_empty_db]
    call display_put_string
    jmp .end_rows

.has_entries:
    mov rbx, [table_top_vis]

.row_loop:
    cmp rbx, rcx
    jge .end_rows
    cmp rbx, [table_row_sel]
    jne .normal_row
    mov dil, COLOR_SELECTED
    jmp .pick_color
.normal_row:
    mov dil, COLOR_NORMAL
.pick_color:
    call display_set_color

    push rbx
    push rcx

    mov rdi, rbx
    call database_get_entry
    test rax, rax
    jz .skip_row

    mov rcx, rax

    mov al, '|'
    call display_put_char
    mov al, ' '
    call display_put_char

    lea rsi, [rcx + ENTRY_NAME_OFFSET]
    mov rdx, TABLE_NAME_W - 2
    call _print_padded

    mov al, '|'
    call display_put_char
    mov al, ' '
    call display_put_char

    lea rsi, [rcx + ENTRY_ID_OFFSET]
    mov rdx, TABLE_ID_W - 2
    call _print_padded

    mov al, '|'
    call display_put_char
    mov al, ' '
    call display_put_char

    mov rax, [reveal_row]
    cmp rax, rbx
    jne .mask_pass
    lea rsi, [rcx + ENTRY_PASS_OFFSET]
    mov rdx, TABLE_PASS_W - 2
    call _print_padded
    jmp .after_pass

.mask_pass:
    lea rsi, [str_masked]
    mov rdx, TABLE_PASS_W - 2
    call _print_padded

.after_pass:
    mov al, '|'
    call display_put_char
    mov al, ' '
    call display_put_char

    mov rax, [reveal_row]
    cmp rax, rbx
    jne .mask_key
    lea rsi, [rcx + ENTRY_KEY_OFFSET]
    mov rdx, TABLE_KEY_W - 2
    call _print_padded
    jmp .after_key

.mask_key:
    lea rsi, [str_masked]
    mov rdx, TABLE_KEY_W - 2
    call _print_padded

.after_key:
    mov al, '|'
    call display_put_char
    mov al, 0x0A
    call display_put_char

.skip_row:
    pop rcx
    pop rbx
    inc rbx
    jmp .row_loop

.end_rows:
    mov dil, COLOR_HEADER
    call display_set_color
    lea rsi, [str_table_hdr_sep]
    call display_put_string
    mov al, 0x0A
    call display_put_char

    mov dil, COLOR_NORMAL
    call display_set_color
    lea rsi, [str_table_help]
    call display_put_string
    mov al, 0x0A
    call display_put_char

    pop rcx
    pop rbx
    ret

table_handle_input:
    push rbx

    movzx rbx, dil

    cmp rbx, SPECIAL_ESC
    je .exit_table

    cmp rbx, SPECIAL_UP
    je .move_up

    cmp rbx, SPECIAL_DOWN
    je .move_down

    cmp rbx, SPECIAL_LEFT
    je .move_left

    cmp rbx, SPECIAL_RIGHT
    je .move_right

    cmp rbx, 0x0A
    je .select_enter
    cmp rbx, 0x0D
    je .select_enter

    cmp rbx, 0x09
    je .tab_next

    cmp rbx, 'n'
    je .new_entry
    cmp rbx, 'N'
    je .new_entry

    cmp rbx, 'd'
    je .delete_entry
    cmp rbx, 'D'
    je .delete_entry

    xor rax, rax
    jmp .done

.exit_table:
    mov rax, 1
    jmp .done

.move_up:
    cmp qword [table_row_sel], 0
    je .no_op
    dec qword [table_row_sel]
    xor rax, rax
    jmp .done

.move_down:
    push rcx
    call database_get_entry_count
    dec rax
    cmp [table_row_sel], rax
    jge .no_op_pop
    inc qword [table_row_sel]
    xor rax, rax
    pop rcx
    jmp .done

.no_op_pop:
    xor rax, rax
    pop rcx
    jmp .done

.move_left:
    cmp qword [table_col_sel], 0
    je .no_op
    dec qword [table_col_sel]
    xor rax, rax
    jmp .done

.move_right:
    cmp qword [table_col_sel], NUM_COLS - 1
    jge .no_op
    inc qword [table_col_sel]
    xor rax, rax
    jmp .done

.tab_next:
    inc qword [table_col_sel]
    cmp qword [table_col_sel], NUM_COLS
    jl .no_op
    mov qword [table_col_sel], 0
    jmp .no_op

.select_enter:
    call _handle_select
    xor rax, rax
    jmp .done

.new_entry:
    call _handle_new_entry
    xor rax, rax
    jmp .done

.delete_entry:
    call _handle_delete_entry
    xor rax, rax
    jmp .done

.no_op:
    xor rax, rax

.done:
    pop rbx
    ret

_handle_select:
    push rbx
    push rcx
    push r12

    mov rdi, [table_row_sel]
    call database_get_entry
    test rax, rax
    jz .done

    mov r12, rax

    mov rax, [reveal_row]
    cmp rax, [table_row_sel]
    je .hide_row

    mov rax, [table_row_sel]
    mov [reveal_row], rax

    mov dil, COLOR_HEADER
    call display_set_color
    lea rsi, [str_details_hdr]
    call display_put_string
    mov dil, COLOR_NORMAL
    call display_set_color

    lea rsi, [str_name_shown]
    call display_put_string
    lea rsi, [r12 + ENTRY_NAME_OFFSET]
    call display_put_string
    mov al, 0x0A
    call display_put_char

    lea rsi, [str_password_shown]
    call display_put_string
    mov dil, COLOR_REVEALED
    call display_set_color
    lea rsi, [r12 + ENTRY_PASS_OFFSET]
    call display_put_string
    mov dil, COLOR_NORMAL
    call display_set_color
    mov al, 0x0A
    call display_put_char

    lea rsi, [str_key_shown]
    call display_put_string
    lea rsi, [r12 + ENTRY_KEY_OFFSET]
    call display_put_string
    mov al, 0x0A
    call display_put_char

    lea rsi, [str_press_any_key]
    call display_put_string
    call keyboard_read_char
    jmp .done

.hide_row:
    mov qword [reveal_row], -1

.done:
    pop r12
    pop rcx
    pop rbx
    ret

_handle_new_entry:
    push rbx
    push rcx

    lea rsi, [str_new_name_p]
    call display_put_string
    lea rsi, [new_entry_buf]
    mov rdx, 63
    call keyboard_read_line

    lea rsi, [str_new_pass_p]
    call display_put_string
    lea rsi, [new_entry_buf + 64]
    mov rdx, 127
    call keyboard_read_line_masked

    lea rsi, [str_new_key_p]
    call display_put_string
    lea rsi, [new_entry_buf + 192]
    mov rdx, 63
    call keyboard_read_line_masked

    lea rdi, [new_entry_buf]
    lea rsi, [new_entry_buf + 64]
    lea rdx, [new_entry_buf + 192]
    call database_add_entry

    lea rsi, [str_entry_added]
    call display_put_string

    lea rdi, [new_entry_buf]
    mov rsi, 512
    call secure_zero

    pop rcx
    pop rbx
    ret

_handle_delete_entry:
    push rbx

    lea rsi, [str_del_confirm]
    call display_put_string
    lea rsi, [new_entry_buf]
    mov rdx, 7
    call keyboard_read_line

    lea rdi, [new_entry_buf]
    lea rsi, [yes3]
    mov rdx, 3
    call _str_eq3
    test rax, rax
    jz .aborted

    mov rdi, [table_row_sel]
    call database_delete_entry

    call database_get_entry_count
    cmp [table_row_sel], rax
    jl .ok_row
    test rax, rax
    jz .zero_rows
    dec rax
    mov [table_row_sel], rax
    jmp .ok_row

.zero_rows:
    mov qword [table_row_sel], 0

.ok_row:
    lea rsi, [str_entry_deleted]
    call display_put_string

.aborted:
    pop rbx
    ret

_str_eq3:
    push rbx
    movzx rax, byte [rdi]
    movzx rbx, byte [rsi]
    cmp rax, rbx
    jne .no
    movzx rax, byte [rdi+1]
    movzx rbx, byte [rsi+1]
    cmp rax, rbx
    jne .no
    movzx rax, byte [rdi+2]
    movzx rbx, byte [rsi+2]
    cmp rax, rbx
    jne .no
    movzx rax, byte [rdi+3]
    test rax, rax
    jnz .no
    mov rax, 1
    jmp .done
.no:
    xor rax, rax
.done:
    pop rbx
    ret

_print_padded:
    push rbx
    push rcx
    push rsi

    xor rcx, rcx
.print:
    movzx rax, byte [rsi]
    test rax, rax
    jz .pad
    cmp rcx, rdx
    jge .done_print
    call display_put_char
    inc rsi
    inc rcx
    jmp .print
.pad:
    cmp rcx, rdx
    jge .done_print
    mov al, ' '
    call display_put_char
    inc rcx
    jmp .pad
.done_print:
    mov al, ' '
    call display_put_char
    pop rsi
    pop rcx
    pop rbx
    ret
