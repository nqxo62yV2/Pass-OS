; PassOS Navigation Helpers
; Provides common UI navigation primitives used across the interface layer:
; YES/NO prompts, selection menus, and paged list display.

BITS 64

global nav_prompt_yes_no
global nav_select_from_list
global nav_paged_list
global nav_print_banner

extern display_put_string
extern display_put_char
extern display_set_color
extern display_clear
extern keyboard_read_char
extern keyboard_read_line

COLOR_PROMPT    equ 0x0F
COLOR_NORMAL    equ 0x07
COLOR_SELECT    equ 0x70
COLOR_WARN      equ 0x0C

INPUT_BUF_LEN   equ 8

section .bss
    nav_input_buf   resb INPUT_BUF_LEN

section .data
    str_yes_no      db ' (YES/NO): ', 0
    yes_str         db 'YES', 0
    str_nl          db 0x0A, 0

section .text

nav_prompt_yes_no:
    push rbx
    push rsi

    mov rsi, rdi
    call display_put_string

    lea rsi, [str_yes_no]
    call display_put_string

    lea rsi, [nav_input_buf]
    mov rdx, INPUT_BUF_LEN - 1
    call keyboard_read_line

    lea rdi, [nav_input_buf]
    call _str_eq_yes

    pop rsi
    pop rbx
    ret

nav_select_from_list:
    push rbx
    push r12
    push r13
    push r14
    push r15

    mov r12, rdi
    mov r13, rsi
    mov r14, rdx
    mov r15, 0

.render:
    call display_clear
    xor rbx, rbx
.draw_loop:
    cmp rbx, r14
    jge .draw_done
    cmp rbx, r15
    jne .normal_item
    mov dil, COLOR_SELECT
    jmp .set_color
.normal_item:
    mov dil, COLOR_NORMAL
.set_color:
    call display_set_color
    push rbx
    imul rax, rbx, 8
    mov rsi, [r12 + rax]
    call display_put_string
    mov al, 0x0A
    call display_put_char
    pop rbx
    inc rbx
    jmp .draw_loop

.draw_done:
    mov dil, COLOR_NORMAL
    call display_set_color

    call keyboard_read_char
    movzx rbx, al

    cmp rbx, 0x80
    je .up
    cmp rbx, 0x81
    je .down
    cmp rbx, 0x0A
    je .selected
    cmp rbx, 0x0D
    je .selected
    cmp rbx, 0x84
    je .cancel
    jmp .render

.up:
    test r15, r15
    jz .render
    dec r15
    jmp .render

.down:
    mov rax, r14
    dec rax
    cmp r15, rax
    jge .render
    inc r15
    jmp .render

.selected:
    mov rax, r15
    jmp .done

.cancel:
    mov rax, -1

.done:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

nav_paged_list:
    push rbx
    push r12
    push r13
    push r14
    push r15

    mov r12, rdi
    mov r13, rsi
    mov r14, rdx
    mov r15, 0

.render:
    call display_clear
    xor rbx, rbx
.draw:
    cmp rbx, 20
    jge .page_end
    mov rax, r15
    add rax, rbx
    cmp rax, r14
    jge .page_end
    push rbx
    push rax
    imul rax, rax, 8
    mov rsi, [r12 + rax]
    call display_put_string
    mov al, 0x0A
    call display_put_char
    pop rax
    pop rbx
    inc rbx
    jmp .draw

.page_end:
    call keyboard_read_char
    movzx rbx, al

    cmp rbx, 0x84
    je .done
    cmp rbx, 0x0A
    je .next_page
    cmp rbx, 0x0D
    je .next_page
    jmp .render

.next_page:
    add r15, 20
    cmp r15, r14
    jl .render
    mov r15, 0
    jmp .render

.done:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

nav_print_banner:
    push rbx
    push rcx
    mov al, '='
    mov rcx, 32
.loop:
    call display_put_char
    loop .loop
    mov al, 0x0A
    call display_put_char
    pop rcx
    pop rbx
    ret

_str_eq_yes:
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
