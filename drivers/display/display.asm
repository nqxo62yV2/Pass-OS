; PassOS Display Driver
; Provides VGA text-mode output (80x25) and a framebuffer abstraction.
; Text mode uses the VGA memory at 0xB8000.

BITS 64

global display_init
global display_clear
global display_put_char
global display_put_string
global display_put_string_at
global display_put_hex
global display_put_dec
global display_set_color
global display_set_cursor
global display_get_cursor_col
global display_get_cursor_row
global display_scroll_up
global display_draw_line
global boot_screen_display
global splash_screen_display

VGA_BASE        equ 0xB8000
VGA_COLS        equ 80
VGA_ROWS        equ 25
DEFAULT_COLOR   equ 0x07

BOOT_COLOR      equ 0x0F
BAR_COLOR       equ 0x07

section .bss
    cursor_row      resb 1
    cursor_col      resb 1
    current_color   resb 1

section .data
    boot_stage_count    db 0

    str_passos          db '             PassOS', 0
    str_separator       db '================================', 0
    str_bootloader      db 'Initializing bootloader ........ OK', 0
    str_kernel          db 'Loading kernel ................. OK', 0
    str_memory          db 'Initializing memory ............ OK', 0
    str_storage         db 'Loading storage drivers ........ OK', 0
    str_encryption      db 'Initializing encryption ........ OK', 0
    str_pwmgr           db 'Loading password manager ....... OK', 0
    str_terminal        db 'Initializing terminal .......... OK', 0
    str_ready1          db 'System initialization complete.', 0
    str_ready2          db 'PassOS is ready.', 0

    str_splash_logo1    db '  ____   _    ____ ____   ___  ____', 0
    str_splash_logo2    db ' |  _ \ / \  / ___/ ___| / _ \/ ___|', 0
    str_splash_logo3    db ' | |_) / _ \ \___ \___ \| | | \___ \', 0
    str_splash_logo4    db ' |  __/ ___ \ ___) |__) | |_| |___) |', 0
    str_splash_logo5    db ' |_| /_/   \_\____/____/ \___/|____|', 0
    str_splash_sub      db 'Password Vault Operating System', 0
    str_splash_ver      db 'Version 1.0', 0
    str_splash_bar      db '[##############################]', 0
    str_splash_start    db 'Starting PassOS...', 0
    str_splash_skip     db 'Press any key to continue', 0

section .text

display_init:
    mov byte [cursor_row], 0
    mov byte [cursor_col], 0
    mov byte [current_color], DEFAULT_COLOR
    call display_clear
    ret

display_clear:
    push rax
    push rcx
    push rdi

    mov rdi, VGA_BASE
    mov ax, (DEFAULT_COLOR << 8) | 0x20
    mov rcx, VGA_COLS * VGA_ROWS
    rep stosw

    mov byte [cursor_row], 0
    mov byte [cursor_col], 0
    call _update_hw_cursor

    pop rdi
    pop rcx
    pop rax
    ret

display_put_char:
    push rax
    push rbx
    push rdx

    cmp al, 0x0A
    je .newline
    cmp al, 0x0D
    je .carriage_return
    cmp al, 0x08
    je .backspace

    movzx rbx, byte [cursor_row]
    imul rbx, VGA_COLS
    movzx rdx, byte [cursor_col]
    add rbx, rdx
    shl rbx, 1
    add rbx, VGA_BASE

    mov byte [rbx], al
    movzx rax, byte [current_color]
    mov byte [rbx + 1], al

    inc byte [cursor_col]
    movzx rax, byte [cursor_col]
    cmp rax, VGA_COLS
    jl .done
    jmp .newline

.newline:
    mov byte [cursor_col], 0
    inc byte [cursor_row]
    movzx rax, byte [cursor_row]
    cmp rax, VGA_ROWS
    jl .done
    call display_scroll_up
    mov byte [cursor_row], VGA_ROWS - 1
    jmp .done

.carriage_return:
    mov byte [cursor_col], 0
    jmp .done

; Backspace: move the cursor left without writing a glyph. The caller is
; responsible for overwriting the character (usually with a space).
.backspace:
    movzx rax, byte [cursor_col]
    test rax, rax
    jz .bs_prev_line
    dec byte [cursor_col]
    jmp .done

.bs_prev_line:
    movzx rax, byte [cursor_row]
    test rax, rax
    jz .done
    dec byte [cursor_row]
    mov byte [cursor_col], VGA_COLS - 1

.done:
    call _update_hw_cursor
    pop rdx
    pop rbx
    pop rax
    ret

display_put_string:
    push rsi
.loop:
    lodsb
    test al, al
    jz .done
    call display_put_char
    jmp .loop
.done:
    pop rsi
    ret

display_put_string_at:
    push rax
    mov byte [cursor_row], dl
    mov byte [cursor_col], cl
    mov rsi, rdi
    call display_put_string
    pop rax
    ret

display_scroll_up:
    push rax
    push rcx
    push rsi
    push rdi

    mov rdi, VGA_BASE
    mov rsi, VGA_BASE + (VGA_COLS * 2)
    mov rcx, VGA_COLS * (VGA_ROWS - 1)
    rep movsw

    mov rdi, VGA_BASE + (VGA_COLS * (VGA_ROWS - 1) * 2)
    mov ax, (DEFAULT_COLOR << 8) | 0x20
    mov rcx, VGA_COLS
    rep stosw

    pop rdi
    pop rsi
    pop rcx
    pop rax
    ret

display_set_color:
    mov byte [current_color], dil
    ret

display_set_cursor:
    mov byte [cursor_row], dil
    mov byte [cursor_col], sil
    call _update_hw_cursor
    ret

display_get_cursor_col:
    movzx rax, byte [cursor_col]
    ret

display_get_cursor_row:
    movzx rax, byte [cursor_row]
    ret

_update_hw_cursor:
    push rax
    push rbx
    push rdx

    movzx rax, byte [cursor_row]
    imul rax, VGA_COLS
    movzx rdx, byte [cursor_col]
    add rax, rdx
    mov rbx, rax           ; save full position

    mov rdx, 0x3D4
    mov al, 0x0F
    out dx, al
    mov rdx, 0x3D5
    mov al, bl             ; low byte of position
    out dx, al

    mov rdx, 0x3D4
    mov al, 0x0E
    out dx, al
    mov rdx, 0x3D5
    mov rax, rbx
    shr rax, 8
    out dx, al

    pop rdx
    pop rbx
    pop rax
    ret

display_put_hex:
    push rbx
    push rcx
    push rdx

    mov rcx, 16
    lea rbx, [hex_buf + 18]
    mov byte [rbx], 0
    dec rbx

.loop:
    mov rdx, rdi
    and rdx, 0xF
    cmp rdx, 9
    jle .digit
    add rdx, 87
    jmp .store
.digit:
    add rdx, 48
.store:
    mov byte [rbx], dl
    dec rbx
    shr rdi, 4
    loop .loop

    mov byte [rbx], 'x'
    dec rbx
    mov byte [rbx], '0'
    mov rsi, rbx
    call display_put_string

    pop rdx
    pop rcx
    pop rbx
    ret

display_put_dec:
    push rbx
    push rcx
    push rdx

    lea rbx, [dec_buf + 20]
    mov byte [rbx], 0
    dec rbx
    mov rax, rdi
    mov rcx, 10

.loop:
    xor rdx, rdx
    div rcx
    add rdx, 48
    mov byte [rbx], dl
    dec rbx
    test rax, rax
    jnz .loop

    inc rbx
    mov rsi, rbx
    call display_put_string

    pop rdx
    pop rcx
    pop rbx
    ret

display_draw_line:
    push rcx
    push rdi
    mov rcx, VGA_COLS
.loop:
    mov al, '-'
    call display_put_char
    loop .loop
    pop rdi
    pop rcx
    ret

boot_screen_display:
    push rbx

    call display_clear

    mov byte [current_color], BOOT_COLOR

    lea rsi, [str_separator]
    call display_put_string
    mov al, 0x0A
    call display_put_char

    lea rsi, [str_passos]
    call display_put_string
    mov al, 0x0A
    call display_put_char

    lea rsi, [str_separator]
    call display_put_string
    mov al, 0x0A
    call display_put_char
    mov al, 0x0A
    call display_put_char

    mov byte [current_color], BAR_COLOR

    lea rsi, [str_bootloader]
    call display_put_string
    mov al, 0x0A
    call display_put_char

    lea rsi, [str_kernel]
    call display_put_string
    mov al, 0x0A
    call display_put_char

    lea rsi, [str_memory]
    call display_put_string
    mov al, 0x0A
    call display_put_char

    lea rsi, [str_storage]
    call display_put_string
    mov al, 0x0A
    call display_put_char

    lea rsi, [str_encryption]
    call display_put_string
    mov al, 0x0A
    call display_put_char

    lea rsi, [str_pwmgr]
    call display_put_string
    mov al, 0x0A
    call display_put_char

    lea rsi, [str_terminal]
    call display_put_string
    mov al, 0x0A
    call display_put_char
    mov al, 0x0A
    call display_put_char

    mov byte [current_color], BOOT_COLOR

    lea rsi, [str_ready1]
    call display_put_string
    mov al, 0x0A
    call display_put_char
    mov al, 0x0A
    call display_put_char

    lea rsi, [str_ready2]
    call display_put_string
    mov al, 0x0A
    call display_put_char
    mov al, 0x0A
    call display_put_char

    mov byte [current_color], DEFAULT_COLOR

    pop rbx
    ret

; ── Boot splash ─────────────────────────────────────────────────────────────
; Shown once before the initialization screen. In debug builds (CI smoke test)
; it does not wait for input; release builds wait for a key or a short timeout.
splash_screen_display:
    push rax
    push rcx
    push rdx
    push rsi

    call display_clear

    mov byte [current_color], 0x0B

    lea rdi, [str_splash_logo1]
    mov dl, 5
    mov cl, 18
    call display_put_string_at

    lea rdi, [str_splash_logo2]
    mov dl, 6
    mov cl, 18
    call display_put_string_at

    lea rdi, [str_splash_logo3]
    mov dl, 7
    mov cl, 18
    call display_put_string_at

    lea rdi, [str_splash_logo4]
    mov dl, 8
    mov cl, 18
    call display_put_string_at

    lea rdi, [str_splash_logo5]
    mov dl, 9
    mov cl, 18
    call display_put_string_at

    mov byte [current_color], 0x0F
    lea rdi, [str_splash_sub]
    mov dl, 11
    mov cl, 22
    call display_put_string_at

    mov byte [current_color], 0x07
    lea rdi, [str_splash_ver]
    mov dl, 12
    mov cl, 34
    call display_put_string_at

    mov byte [current_color], 0x0A
    lea rdi, [str_splash_bar]
    mov dl, 14
    mov cl, 24
    call display_put_string_at

    mov byte [current_color], 0x0E
    lea rdi, [str_splash_start]
    mov dl, 16
    mov cl, 31
    call display_put_string_at

    mov byte [current_color], 0x08
    lea rdi, [str_splash_skip]
    mov dl, 20
    mov cl, 28
    call display_put_string_at

%ifndef DEBUG_SERIAL
    ; Wait for a key press, but continue on a timeout if nobody is there.
    mov ecx, 0x40000000
.wait:
    push rcx
    call keyboard_peek
    pop rcx
    test rax, rax
    jnz .key
    dec ecx
    jnz .wait
    jmp .done
.key:
    call keyboard_read_char
%endif

.done:
    mov byte [current_color], DEFAULT_COLOR

    pop rsi
    pop rdx
    pop rcx
    pop rax
    ret

section .bss
    hex_buf     resb 20
    dec_buf     resb 22

extern display_put_char
extern keyboard_peek
extern keyboard_read_char
