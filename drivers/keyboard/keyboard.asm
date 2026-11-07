; PassOS Keyboard Driver
; Handles PS/2 and USB HID keyboard input.
; Maintains a 256-byte circular input buffer.
; Translates scancodes to ASCII using configurable layout tables.

BITS 64

global keyboard_init
global keyboard_scancode_handler
global keyboard_read_char
global keyboard_read_line
global keyboard_read_line_masked
global keyboard_peek

KBD_STATUS_PORT     equ 0x64
KBD_DATA_PORT       equ 0x60
BUFFER_SIZE         equ 256

FLAG_SHIFT          equ 0x01
FLAG_CTRL           equ 0x02
FLAG_ALT            equ 0x04
FLAG_CAPS           equ 0x08
FLAG_EXTENDED       equ 0x10

KEY_ARROW_UP        equ 0x48
KEY_ARROW_DOWN      equ 0x50
KEY_ARROW_LEFT      equ 0x4B
KEY_ARROW_RIGHT     equ 0x4D
KEY_ENTER           equ 0x1C
KEY_BACKSPACE       equ 0x0E
KEY_ESCAPE          equ 0x01
KEY_TAB             equ 0x0F
KEY_LSHIFT          equ 0x2A
KEY_RSHIFT          equ 0x36
KEY_LCTRL           equ 0x1D
KEY_LALT            equ 0x38
KEY_CAPSLOCK        equ 0x3A

EXTENDED_PREFIX     equ 0xE0
KEY_RELEASE_FLAG    equ 0x80

section .bss
    kbd_buffer      resb BUFFER_SIZE
    buf_head        resb 1
    buf_tail        resb 1
    modifier_flags  resb 1
    layout_ptr      resq 1

section .data
    us_layout_normal:
        db 0,0x1B,'1','2','3','4','5','6','7','8','9','0','-','=',0x08
        db 0x09,'q','w','e','r','t','y','u','i','o','p','[',']',0x0A
        db 0,'a','s','d','f','g','h','j','k','l',';',"'",0x60,0
        db '\','z','x','c','v','b','n','m',',','.','/',0,'*'
        db 0,' ',0,0,0,0,0,0,0,0,0,0,0,0,0
        db '7','8','9','-','4','5','6','+','1','2','3','0','.'
        times 256-89 db 0

    us_layout_shifted:
        db 0,0x1B,'!','@','#','$','%','^','&','*','(',')','_','+'  ,0x08
        db 0x09,'Q','W','E','R','T','Y','U','I','O','P','{','}',0x0A
        db 0,'A','S','D','F','G','H','J','K','L',':','"','~',0
        db '|','Z','X','C','V','B','N','M','<','>','?',0,'*'
        db 0,' ',0,0,0,0,0,0,0,0,0,0,0,0,0
        db '7','8','9','-','4','5','6','+','1','2','3','0','.'
        times 256-89 db 0

    SPECIAL_KEY_UP      equ 0x80
    SPECIAL_KEY_DOWN    equ 0x81
    SPECIAL_KEY_LEFT    equ 0x82
    SPECIAL_KEY_RIGHT   equ 0x83
    SPECIAL_KEY_ESC     equ 0x84
    SPECIAL_KEY_TAB     equ 0x85

section .text

keyboard_init:
    mov byte [buf_head], 0
    mov byte [buf_tail], 0
    mov byte [modifier_flags], 0
    lea rax, [us_layout_normal]
    mov [layout_ptr], rax
    ret

keyboard_scancode_handler:
    push rax
    push rbx

    movzx rbx, al

    test rbx, KEY_RELEASE_FLAG
    jnz .key_release

    cmp rbx, EXTENDED_PREFIX
    je .extended_skip

    call handle_modifier_press
    call scancode_to_char
    test al, al
    jz .done
    call buffer_push

.done:
    pop rbx
    pop rax
    ret

.key_release:
    and rbx, ~KEY_RELEASE_FLAG
    call handle_modifier_release
    pop rbx
    pop rax
    ret

.extended_skip:
    pop rbx
    pop rax
    ret

handle_modifier_press:
    push rbx
    cmp rbx, KEY_LSHIFT
    je .set_shift
    cmp rbx, KEY_RSHIFT
    je .set_shift
    cmp rbx, KEY_LCTRL
    je .set_ctrl
    cmp rbx, KEY_LALT
    je .set_alt
    cmp rbx, KEY_CAPSLOCK
    je .toggle_caps
    jmp .done

.set_shift:
    or byte [modifier_flags], FLAG_SHIFT
    jmp .done

.set_ctrl:
    or byte [modifier_flags], FLAG_CTRL
    jmp .done

.set_alt:
    or byte [modifier_flags], FLAG_ALT
    jmp .done

.toggle_caps:
    xor byte [modifier_flags], FLAG_CAPS

.done:
    pop rbx
    ret

handle_modifier_release:
    push rbx
    cmp rbx, KEY_LSHIFT
    je .clear_shift
    cmp rbx, KEY_RSHIFT
    je .clear_shift
    cmp rbx, KEY_LCTRL
    je .clear_ctrl
    cmp rbx, KEY_LALT
    je .clear_alt
    jmp .done

.clear_shift:
    and byte [modifier_flags], ~FLAG_SHIFT
    jmp .done

.clear_ctrl:
    and byte [modifier_flags], ~FLAG_CTRL
    jmp .done

.clear_alt:
    and byte [modifier_flags], ~FLAG_ALT

.done:
    pop rbx
    ret

scancode_to_char:
    push rbx
    push rdx

    cmp rbx, KEY_ARROW_UP
    je .arrow_up
    cmp rbx, KEY_ARROW_DOWN
    je .arrow_down
    cmp rbx, KEY_ARROW_LEFT
    je .arrow_left
    cmp rbx, KEY_ARROW_RIGHT
    je .arrow_right
    cmp rbx, KEY_ESCAPE
    je .esc
    cmp rbx, KEY_TAB
    je .tab

    movzx rax, byte [modifier_flags]
    test rax, FLAG_SHIFT
    jnz .shifted

    test rax, FLAG_CAPS
    jz .normal_lookup

.shifted:
    lea rdx, [us_layout_shifted]
    movzx rax, byte [rdx + rbx]
    jmp .done

.normal_lookup:
    mov rdx, [layout_ptr]
    movzx rax, byte [rdx + rbx]
    jmp .done

.arrow_up:
    mov al, SPECIAL_KEY_UP
    jmp .done
.arrow_down:
    mov al, SPECIAL_KEY_DOWN
    jmp .done
.arrow_left:
    mov al, SPECIAL_KEY_LEFT
    jmp .done
.arrow_right:
    mov al, SPECIAL_KEY_RIGHT
    jmp .done
.esc:
    mov al, SPECIAL_KEY_ESC
    jmp .done
.tab:
    mov al, SPECIAL_KEY_TAB

.done:
    pop rdx
    pop rbx
    ret

buffer_push:
    push rbx
    movzx rbx, byte [buf_head]
    mov byte [kbd_buffer + rbx], al
    inc bl
    and bl, BUFFER_SIZE - 1
    mov byte [buf_head], bl
    pop rbx
    ret

buffer_pop:
    push rbx
    movzx rbx, byte [buf_tail]
    cmp bl, byte [buf_head]
    je .empty
    mov al, byte [kbd_buffer + rbx]
    inc bl
    and bl, BUFFER_SIZE - 1
    mov byte [buf_tail], bl
    jmp .done
.empty:
    xor al, al
.done:
    pop rbx
    ret

keyboard_read_char:
    push rbx
.wait:
    movzx rax, byte [buf_tail]
    movzx rbx, byte [buf_head]
    cmp al, bl
    je .wait
    call buffer_pop
    pop rbx
    ret

keyboard_peek:
    push rbx
    movzx rax, byte [buf_tail]
    movzx rbx, byte [buf_head]
    cmp al, bl
    je .empty
    movzx rax, byte [buf_tail]
    movzx rax, byte [kbd_buffer + rax]
    pop rbx
    ret
.empty:
    xor rax, rax
    pop rbx
    ret

keyboard_read_line:
    push rbx
    push rcx
    push rdi

    mov rdi, rsi
    xor rcx, rcx

.loop:
    call keyboard_read_char
    cmp al, 0x0A
    je .done
    cmp al, 0x0D
    je .done
    cmp al, 0x08
    je .backspace

    cmp rcx, rdx
    jge .loop

    mov byte [rdi + rcx], al
    inc rcx

    push rax
    call display_put_char
    pop rax

    jmp .loop

.backspace:
    test rcx, rcx
    jz .loop
    dec rcx
    mov byte [rdi + rcx], 0
    push rax
    mov al, 0x08
    call display_put_char
    mov al, 0x20
    call display_put_char
    mov al, 0x08
    call display_put_char
    pop rax
    jmp .loop

.done:
    mov byte [rdi + rcx], 0
    mov rax, rcx          ; return the line length
    push rax
    mov al, 0x0A
    call display_put_char
    pop rax

    pop rdi
    pop rcx
    pop rbx
    ret

keyboard_read_line_masked:
    push rbx
    push rcx
    push rdi

    mov rdi, rsi
    xor rcx, rcx

.loop:
    call keyboard_read_char
    cmp al, 0x0A
    je .done
    cmp al, 0x0D
    je .done
    cmp al, 0x08
    je .backspace

    cmp rcx, rdx
    jge .loop

    mov byte [rdi + rcx], al
    inc rcx

    push rax
    mov al, '*'
    call display_put_char
    pop rax
    jmp .loop

.backspace:
    test rcx, rcx
    jz .loop
    dec rcx
    mov byte [rdi + rcx], 0
    push rax
    mov al, 0x08
    call display_put_char
    mov al, 0x20
    call display_put_char
    mov al, 0x08
    call display_put_char
    pop rax
    jmp .loop

.done:
    mov byte [rdi + rcx], 0
    mov rax, rcx          ; return the line length
    push rax
    mov al, 0x0A
    call display_put_char
    pop rax

    pop rdi
    pop rcx
    pop rbx
    ret

extern display_put_char
