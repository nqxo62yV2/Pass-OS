; PassOS Settings Module
; Provides /settings command and persistent settings storage.
; Settings are serialized to sector 3 on disk.

BITS 64

global cmd_settings
global settings_load
global settings_save
global settings_get_refresh_rate
global settings_get_keyboard_layout
global settings_get_display_timeout

extern display_put_string
extern display_put_char
extern display_set_color
extern display_clear
extern display_put_dec
extern keyboard_read_char
extern keyboard_read_line
extern storage_read_sector
extern storage_write_sector
extern secure_zero

SETTINGS_SECTOR      equ 3
SETTINGS_MAGIC_LEN   equ 8

COLOR_NORMAL         equ 0x07
COLOR_SELECTED       equ 0x70
COLOR_HEADER         equ 0x0F
COLOR_WARN           equ 0x0C

SPECIAL_UP           equ 0x80
SPECIAL_DOWN         equ 0x81
SPECIAL_ESC          equ 0x84
KEY_ENTER            equ 0x0A

section .bss
    settings_sector_buf  resb 512
    setting_refresh_hz   resb 1
    setting_kbd_layout   resb 1
    setting_disp_timeout resb 1
    setting_clear_on_exit resb 1
    settings_dirty       resb 1

section .data
    settings_magic       db 'PWCFG001'

    str_settings_title   db 'PassOS Settings', 0x0A, 0x0A, 0
    str_settings_help    db '[Up/Down] Navigate  [Enter] Change  [Esc] Save & Exit', 0x0A, 0

    str_refresh_label    db 'Display Refresh Rate: ', 0
    str_kbd_label        db 'Keyboard Layout:      ', 0
    str_timeout_label    db 'Password Timeout (s): ', 0
    str_clear_label      db 'Clear on DB Exit:     ', 0

    str_60hz             db '60 Hz', 0
    str_75hz             db '75 Hz', 0
    str_kbd_us           db 'US', 0
    str_kbd_de           db 'DE', 0
    str_kbd_gb           db 'GB', 0
    str_on               db 'ON', 0
    str_off              db 'OFF', 0

    str_saved            db 0x0A, 'Settings saved.', 0x0A, 0

section .text

settings_load:
    push rbx

    lea rdi, [settings_sector_buf]
    mov rsi, SETTINGS_SECTOR
    call storage_read_sector

    lea rdi, [settings_sector_buf]
    lea rsi, [settings_magic]
    mov rdx, SETTINGS_MAGIC_LEN
    call _mem_cmp
    test rax, rax
    jnz .defaults

    mov al, byte [settings_sector_buf + SETTINGS_MAGIC_LEN]
    mov byte [setting_refresh_hz], al
    mov al, byte [settings_sector_buf + SETTINGS_MAGIC_LEN + 1]
    mov byte [setting_kbd_layout], al
    mov al, byte [settings_sector_buf + SETTINGS_MAGIC_LEN + 2]
    mov byte [setting_disp_timeout], al
    mov al, byte [settings_sector_buf + SETTINGS_MAGIC_LEN + 3]
    mov byte [setting_clear_on_exit], al
    jmp .done

.defaults:
    mov byte [setting_refresh_hz], 60
    mov byte [setting_kbd_layout], 0
    mov byte [setting_disp_timeout], 30
    mov byte [setting_clear_on_exit], 1
    call settings_save

.done:
    mov byte [settings_dirty], 0
    pop rbx
    ret

settings_save:
    push rbx
    push rcx
    push rsi
    push rdi

    lea rdi, [settings_sector_buf]
    mov rsi, 512
    call secure_zero

    lea rdi, [settings_sector_buf]
    lea rsi, [settings_magic]
    mov rcx, SETTINGS_MAGIC_LEN
    rep movsb

    mov al, byte [setting_refresh_hz]
    mov byte [settings_sector_buf + SETTINGS_MAGIC_LEN], al
    mov al, byte [setting_kbd_layout]
    mov byte [settings_sector_buf + SETTINGS_MAGIC_LEN + 1], al
    mov al, byte [setting_disp_timeout]
    mov byte [settings_sector_buf + SETTINGS_MAGIC_LEN + 2], al
    mov al, byte [setting_clear_on_exit]
    mov byte [settings_sector_buf + SETTINGS_MAGIC_LEN + 3], al

    lea rsi, [settings_sector_buf]
    mov rdi, SETTINGS_SECTOR
    call storage_write_sector

    mov byte [settings_dirty], 0

    pop rdi
    pop rsi
    pop rcx
    pop rbx
    ret

cmd_settings:
    push rbx

    call settings_load
    call _render_settings_menu

.event_loop:
    call keyboard_read_char
    movzx rbx, al

    cmp rbx, SPECIAL_ESC
    je .save_and_exit

    cmp rbx, SPECIAL_UP
    je .move_up

    cmp rbx, SPECIAL_DOWN
    je .move_down

    cmp rbx, KEY_ENTER
    je .change_value
    cmp rbx, 0x0D
    je .change_value

    jmp .event_loop

.save_and_exit:
    cmp byte [settings_dirty], 0
    je .done
    call settings_save
    lea rsi, [str_saved]
    call display_put_string

.done:
    pop rbx
    ret

.move_up:
    jmp .event_loop

.move_down:
    jmp .event_loop

.change_value:
    jmp .event_loop

_render_settings_menu:
    push rbx

    call display_clear

    mov dil, COLOR_HEADER
    call display_set_color
    lea rsi, [str_settings_title]
    call display_put_string

    mov dil, COLOR_NORMAL
    call display_set_color

    lea rsi, [str_refresh_label]
    call display_put_string

    movzx rax, byte [setting_refresh_hz]
    cmp rax, 60
    je .print_60
    lea rsi, [str_75hz]
    jmp .print_hz
.print_60:
    lea rsi, [str_60hz]
.print_hz:
    call display_put_string
    mov al, 0x0A
    call display_put_char

    lea rsi, [str_kbd_label]
    call display_put_string
    movzx rax, byte [setting_kbd_layout]
    test rax, rax
    jz .print_us
    cmp rax, 1
    je .print_de
    lea rsi, [str_kbd_gb]
    jmp .print_kbd
.print_us:
    lea rsi, [str_kbd_us]
    jmp .print_kbd
.print_de:
    lea rsi, [str_kbd_de]
.print_kbd:
    call display_put_string
    mov al, 0x0A
    call display_put_char

    lea rsi, [str_timeout_label]
    call display_put_string
    movzx rdi, byte [setting_disp_timeout]
    call display_put_dec
    mov al, 0x0A
    call display_put_char

    lea rsi, [str_clear_label]
    call display_put_string
    movzx rax, byte [setting_clear_on_exit]
    test rax, rax
    jnz .print_on
    lea rsi, [str_off]
    jmp .print_onoff
.print_on:
    lea rsi, [str_on]
.print_onoff:
    call display_put_string
    mov al, 0x0A
    call display_put_char
    mov al, 0x0A
    call display_put_char

    lea rsi, [str_settings_help]
    call display_put_string

    pop rbx
    ret

settings_get_refresh_rate:
    movzx rax, byte [setting_refresh_hz]
    ret

settings_get_keyboard_layout:
    movzx rax, byte [setting_kbd_layout]
    ret

settings_get_display_timeout:
    movzx rax, byte [setting_disp_timeout]
    ret

_mem_cmp:
    push rcx
    push rsi
    push rdi
    mov rcx, rdx
    repe cmpsb
    setz al
    movzx rax, al
    pop rdi
    pop rsi
    pop rcx
    ret
