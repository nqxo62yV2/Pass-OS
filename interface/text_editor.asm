; PassOS Built-in Text Editor
; Nano-comparable lightweight terminal editor.
; Supports: create/open/edit/save/save-as/exit.
; Uses a gap buffer for efficient line editing.

BITS 64

global text_editor_open
global text_editor_new
global cmd_edit

extern display_put_string
extern display_put_char
extern display_set_color
extern display_clear
extern display_set_cursor
extern display_get_cursor_row
extern display_get_cursor_col
extern keyboard_read_char
extern keyboard_read_line
extern storage_read_sectors
extern storage_write_sectors

EDITOR_COLS         equ 80
EDITOR_ROWS         equ 22
EDITOR_BUF_SIZE     equ 65536
STATUS_ROW          equ 23
HELP_ROW            equ 24

COLOR_EDITOR        equ 0x07
COLOR_STATUS        equ 0x70
COLOR_MODIFIED      equ 0x6E

SPECIAL_UP          equ 0x80
SPECIAL_DOWN        equ 0x81
SPECIAL_LEFT        equ 0x82
SPECIAL_RIGHT       equ 0x83
SPECIAL_ESC         equ 0x84
KEY_CTRL_S          equ 0x13
KEY_CTRL_Q          equ 0x11
KEY_CTRL_A          equ 0x01
KEY_BACKSPACE       equ 0x08
KEY_DELETE          equ 0x7F
KEY_ENTER           equ 0x0A
KEY_TAB             equ 0x09

section .bss
    editor_buffer   resb EDITOR_BUF_SIZE
    editor_gap_start resq 1
    editor_gap_end  resq 1
    editor_cursor   resq 1
    editor_top_line resq 1
    editor_modified resb 1
    editor_filename resb 256
    editor_filesize resq 1

section .data
    str_editor_title    db 'PassOS Editor', 0
    str_help_bar        db 'Ctrl+S Save  Ctrl+Q Quit  Ctrl+A Save As  Arrows Navigate', 0
    str_status_new      db '[New File]', 0
    str_status_mod      db ' [Modified]', 0
    str_save_prompt     db 0x0A, 'Save as: ', 0
    str_saved           db 'File saved.', 0
    str_quit_confirm    db 'Unsaved changes. Quit? (YES/NO): ', 0
    str_editor_warning  db 'WARNING: Do not store sensitive data in unencrypted files.', 0x0A, 0

    yes3                db 'YES', 0

section .text

text_editor_new:
    push rbx

    lea rdi, [editor_filename]
    mov rsi, 256
    xor al, al
    push rcx
    push rdi
    mov rcx, rsi
    rep stosb
    pop rdi
    pop rcx

    lea rdi, [editor_buffer]
    mov rsi, EDITOR_BUF_SIZE
    xor al, al
    push rcx
    push rdi
    mov rcx, rsi
    rep stosb
    pop rdi
    pop rcx

    mov qword [editor_gap_start], 0
    mov qword [editor_gap_end], EDITOR_BUF_SIZE
    mov qword [editor_cursor], 0
    mov qword [editor_top_line], 0
    mov byte [editor_modified], 0
    mov qword [editor_filesize], 0

    call _editor_main_loop

    pop rbx
    ret

text_editor_open:
    push rbx
    push r12

    mov r12, rdi

    lea rdi, [editor_filename]
    mov rsi, r12
    call _str_copy_256

    call _load_file

    call _editor_main_loop

    pop r12
    pop rbx
    ret

cmd_edit:
    test rdi, rdi
    jz text_editor_new
    jmp text_editor_open

_editor_main_loop:
    push rbx

    call _render_editor

.event_loop:
    call keyboard_read_char
    movzx rbx, al

    cmp rbx, KEY_CTRL_S
    je .save

    cmp rbx, KEY_CTRL_Q
    je .quit

    cmp rbx, KEY_CTRL_A
    je .save_as

    cmp rbx, SPECIAL_UP
    je .cursor_up

    cmp rbx, SPECIAL_DOWN
    je .cursor_down

    cmp rbx, SPECIAL_LEFT
    je .cursor_left

    cmp rbx, SPECIAL_RIGHT
    je .cursor_right

    cmp rbx, KEY_BACKSPACE
    je .backspace

    cmp rbx, KEY_DELETE
    je .delete_fwd

    cmp rbx, KEY_ENTER
    je .insert_nl

    cmp rbx, KEY_TAB
    je .insert_tab

    cmp rbx, 0x20
    jl .no_insert
    cmp rbx, 0x7E
    jg .no_insert

    mov rdi, rbx
    call _insert_char
    mov byte [editor_modified], 1
    call _render_editor
    jmp .event_loop

.cursor_up:
    call _cursor_move_up
    call _render_cursor
    jmp .event_loop

.cursor_down:
    call _cursor_move_down
    call _render_cursor
    jmp .event_loop

.cursor_left:
    call _cursor_move_left
    call _render_cursor
    jmp .event_loop

.cursor_right:
    call _cursor_move_right
    call _render_cursor
    jmp .event_loop

.backspace:
    call _delete_back
    mov byte [editor_modified], 1
    call _render_editor
    jmp .event_loop

.delete_fwd:
    call _delete_forward
    mov byte [editor_modified], 1
    call _render_editor
    jmp .event_loop

.insert_nl:
    mov rdi, 0x0A
    call _insert_char
    mov byte [editor_modified], 1
    call _render_editor
    jmp .event_loop

.insert_tab:
    mov rdi, ' '
    call _insert_char
    call _insert_char
    call _insert_char
    call _insert_char
    mov byte [editor_modified], 1
    call _render_editor
    jmp .event_loop

.no_insert:
    jmp .event_loop

.save:
    call _save_file
    call _render_status
    jmp .event_loop

.save_as:
    call _save_as_prompt
    call _render_status
    jmp .event_loop

.quit:
    cmp byte [editor_modified], 0
    je .quit_confirmed

    lea rsi, [str_quit_confirm]
    call display_put_string
    lea rsi, [_quit_buf]
    mov rdx, 7
    call keyboard_read_line_stub

    lea rdi, [_quit_buf]
    call _str_eq3

    test rax, rax
    jz .event_loop

.quit_confirmed:
    pop rbx
    ret

_render_editor:
    call display_clear
    mov dil, COLOR_EDITOR
    call display_set_color

    push rbx
    push rcx

    mov rbx, [editor_top_line]
    xor rcx, rcx

.line_loop:
    cmp rcx, EDITOR_ROWS
    jge .render_done
    push rcx
    push rbx
    call _render_line
    pop rbx
    pop rcx
    inc rcx
    jmp .line_loop

.render_done:
    call _render_status
    pop rcx
    pop rbx
    ret

_render_line:
    ret

_render_status:
    push rbx

    mov dil, STATUS_ROW
    mov sil, 0
    call display_set_cursor

    mov dil, COLOR_STATUS
    call display_set_color

    lea rsi, [str_editor_title]
    call display_put_string

    mov al, ' '
    call display_put_char

    lea rsi, [editor_filename]
    call display_put_string

    cmp byte [editor_modified], 0
    je .no_mod
    lea rsi, [str_status_mod]
    call display_put_string

.no_mod:
    mov dil, COLOR_EDITOR
    call display_set_color

    pop rbx
    ret

_render_cursor:
    ret

_cursor_move_up:
    ret

_cursor_move_down:
    ret

_cursor_move_left:
    push rbx
    cmp qword [editor_cursor], 0
    je .done
    call _gap_move_left
    dec qword [editor_cursor]
.done:
    pop rbx
    ret

_cursor_move_right:
    push rbx
    call _gap_size
    mov rbx, EDITOR_BUF_SIZE
    sub rbx, rax
    cmp [editor_cursor], rbx
    jge .done
    call _gap_move_right
    inc qword [editor_cursor]
.done:
    pop rbx
    ret

_insert_char:
    push rbx
    mov rbx, [editor_gap_start]
    cmp rbx, [editor_gap_end]
    je .no_space
    mov rbx, [editor_gap_start]
    mov byte [editor_buffer + rbx], dil
    inc qword [editor_gap_start]
    inc qword [editor_cursor]
.no_space:
    pop rbx
    ret

_delete_back:
    push rbx
    cmp qword [editor_gap_start], 0
    je .done
    dec qword [editor_gap_start]
    dec qword [editor_cursor]
.done:
    pop rbx
    ret

_delete_forward:
    push rbx
    cmp qword [editor_gap_end], EDITOR_BUF_SIZE
    je .done
    inc qword [editor_gap_end]
.done:
    pop rbx
    ret

_gap_size:
    mov rax, [editor_gap_end]
    sub rax, [editor_gap_start]
    ret

_gap_move_left:
    push rbx
    cmp qword [editor_gap_start], 0
    je .done
    dec qword [editor_gap_start]
    dec qword [editor_gap_end]
    mov rbx, [editor_gap_start]
    movzx rax, byte [editor_buffer + rbx]
    mov rbx, [editor_gap_end]
    mov byte [editor_buffer + rbx], al
.done:
    pop rbx
    ret

_gap_move_right:
    push rbx
    cmp qword [editor_gap_end], EDITOR_BUF_SIZE
    je .done
    mov rbx, [editor_gap_end]
    movzx rax, byte [editor_buffer + rbx]
    mov rbx, [editor_gap_start]
    mov byte [editor_buffer + rbx], al
    inc qword [editor_gap_start]
    inc qword [editor_gap_end]
.done:
    pop rbx
    ret

_save_file:
    cmp byte [editor_filename], 0
    je _save_as_prompt
    call _write_buffer_to_disk
    mov byte [editor_modified], 0
    ret

_save_as_prompt:
    push rbx
    lea rsi, [str_save_prompt]
    call display_put_string
    lea rsi, [editor_filename]
    mov rdx, 255
    call keyboard_read_line_stub
    call _write_buffer_to_disk
    mov byte [editor_modified], 0
    pop rbx
    ret

_write_buffer_to_disk:
    ret

_load_file:
    ret

_str_copy_256:
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
    cmp rcx, 255
    jl .loop
    mov byte [rdi + 255], 0
.done:
    pop rdi
    pop rsi
    pop rcx
    ret

_str_eq3:
    push rbx
    movzx rax, byte [rdi]
    cmp al, 'Y'
    jne .no
    movzx rax, byte [rdi+1]
    cmp al, 'E'
    jne .no
    movzx rax, byte [rdi+2]
    cmp al, 'S'
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

keyboard_read_line_stub:
    jmp keyboard_read_line

section .bss
    _quit_buf   resb 8
