; PassOS Terminal
; The main interactive loop. Displays a prompt, reads commands,
; dispatches them to the command parser, and prints results.

BITS 64

global terminal_init
global terminal_run
global terminal_print
global terminal_print_ln
global terminal_print_error

extern display_put_string
extern display_put_char
extern display_set_color
extern display_clear
extern keyboard_read_line
extern command_parse_and_execute
extern database_is_open
extern database_get_current_name

PROMPT_COLOR    equ 0x0A
NORMAL_COLOR    equ 0x07
ERROR_COLOR     equ 0x0C
DB_PROMPT_COLOR equ 0x0B

INPUT_BUF_LEN   equ 512

section .bss
    input_buffer    resb INPUT_BUF_LEN

section .data
    str_prompt          db 'PassOS> ', 0
    str_prompt_db_a     db 'PassOS[', 0
    str_prompt_db_b     db ']> ', 0
    str_welcome         db 'PassOS V1.0  |  Type /help for available commands.', 0x0A, 0

section .text

terminal_init:
    call display_clear
    mov dil, NORMAL_COLOR
    call display_set_color
    lea rsi, [str_welcome]
    call display_put_string
    ret

terminal_run:
.loop:
    call _display_prompt
    lea rsi, [input_buffer]
    mov rdx, INPUT_BUF_LEN - 1
    call keyboard_read_line

    lea rdi, [input_buffer]
    call _skip_whitespace

    cmp byte [rax], 0
    je .loop

    mov rdi, rax
    call command_parse_and_execute

    jmp .loop

_display_prompt:
    call database_is_open
    test rax, rax
    jz .simple_prompt

    mov dil, DB_PROMPT_COLOR
    call display_set_color
    lea rsi, [str_prompt_db_a]
    call display_put_string
    call database_get_current_name
    mov rsi, rax
    call display_put_string
    lea rsi, [str_prompt_db_b]
    call display_put_string
    mov dil, NORMAL_COLOR
    call display_set_color
    ret

.simple_prompt:
    mov dil, PROMPT_COLOR
    call display_set_color
    lea rsi, [str_prompt]
    call display_put_string
    mov dil, NORMAL_COLOR
    call display_set_color
    ret

_skip_whitespace:
    push rbx
    mov rbx, rdi
.loop:
    movzx rax, byte [rbx]
    cmp rax, 0x20
    je .skip
    cmp rax, 0x09
    je .skip
    jmp .done
.skip:
    inc rbx
    jmp .loop
.done:
    mov rax, rbx
    pop rbx
    ret

terminal_print:
    push rsi
    mov rsi, rdi
    call display_put_string
    pop rsi
    ret

terminal_print_ln:
    push rax
    push rsi
    mov rsi, rdi
    call display_put_string
    mov al, 0x0A
    call display_put_char
    pop rsi
    pop rax
    ret

terminal_print_error:
    push rax
    push rsi
    mov dil, ERROR_COLOR
    call display_set_color
    mov rsi, rdi
    call display_put_string
    mov al, 0x0A
    call display_put_char
    mov dil, NORMAL_COLOR
    call display_set_color
    pop rsi
    pop rax
    ret
