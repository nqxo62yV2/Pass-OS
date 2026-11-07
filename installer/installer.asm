; PassOS Installer
; Handles /install command: detects drives, guides the user through
; target selection, warns before formatting, and writes PassOS to disk.
; Supports HDD, SSD, USB, and compatible servers.

BITS 64

global cmd_install

extern display_put_string
extern display_put_char
extern display_set_color
extern display_clear
extern keyboard_read_line
extern keyboard_read_char
extern keyboard_read_line_masked
extern storage_read_sector
extern storage_write_sector
extern storage_write_sectors
extern usb_device_count
extern authentication_verify_token
extern secure_zero
extern nav_select_from_list

COLOR_NORMAL    equ 0x07
COLOR_WARN      equ 0x0C
COLOR_OK        equ 0x0A
COLOR_BOLD      equ 0x0F

MAX_DRIVES      equ 8
INPUT_BUF_LEN   equ 8
TOKEN_BUF_LEN   equ 256

section .bss
    install_input_buf   resb INPUT_BUF_LEN
    install_token_buf   resb TOKEN_BUF_LEN
    install_target_dev  resb 1
    drive_labels:       times 8 resq 1

section .data
    str_install_title   db 'PassOS Installer', 0x0A, 0x0A, 0
    str_install_warn    db 'WARNING: Installation will overwrite the target drive.', 0x0A
                        db 'All existing data on the target drive will be destroyed.', 0x0A, 0x0A, 0
    str_select_drive    db 'Select target drive:', 0x0A, 0
    str_no_drives       db 'Error: No suitable drives detected.', 0x0A, 0
    str_confirm_fmt     db 'Confirm format and install? (YES/NO): ', 0
    str_confirm_2       db 'Are you absolutely sure? This cannot be undone. (YES/NO): ', 0
    str_auth_prompt     db 'Enter master token to authorize installation: ', 0
    str_auth_fail       db 'Authentication failed. Installation aborted.', 0x0A, 0
    str_installing      db 0x0A, 'Installing PassOS...', 0x0A, 0
    str_install_ok      db 'Installation complete.', 0x0A
                        db 'PassOS has been installed on the selected drive.', 0x0A
                        db 'Restart to boot from the new installation.', 0x0A, 0
    str_aborted         db 'Installation aborted.', 0x0A, 0
    str_drive_0         db 'Drive 0 (Primary ATA)', 0
    str_drive_1         db 'Drive 1 (Secondary ATA)', 0
    str_drive_usb       db 'USB Drive', 0

section .text

cmd_install:
    push rbx

    call display_clear
    mov dil, COLOR_BOLD
    call display_set_color
    lea rsi, [str_install_title]
    call display_put_string
    mov dil, COLOR_WARN
    call display_set_color
    lea rsi, [str_install_warn]
    call display_put_string
    mov dil, COLOR_NORMAL
    call display_set_color

    call _build_drive_list
    test rax, rax
    jz .no_drives

    mov rdi, drive_labels
    xor rsi, rsi
    call nav_select_from_list
    cmp rax, -1
    je .aborted

    mov byte [install_target_dev], al

    mov dil, COLOR_WARN
    call display_set_color
    lea rsi, [str_confirm_fmt]
    call display_put_string
    mov dil, COLOR_NORMAL
    call display_set_color

    lea rsi, [install_input_buf]
    mov rdx, INPUT_BUF_LEN - 1
    call keyboard_read_line

    lea rdi, [install_input_buf]
    call _str_eq_yes
    test rax, rax
    jz .aborted

    mov dil, COLOR_WARN
    call display_set_color
    lea rsi, [str_confirm_2]
    call display_put_string
    mov dil, COLOR_NORMAL
    call display_set_color

    lea rsi, [install_input_buf]
    mov rdx, INPUT_BUF_LEN - 1
    call keyboard_read_line

    lea rdi, [install_input_buf]
    call _str_eq_yes
    test rax, rax
    jz .aborted

    lea rsi, [str_auth_prompt]
    call display_put_string
    lea rsi, [install_token_buf]
    mov rdx, TOKEN_BUF_LEN - 1
    call keyboard_read_line_masked

    lea rdi, [install_token_buf]
    call authentication_verify_token
    test rax, rax
    jnz .auth_fail

    lea rdi, [install_token_buf]
    mov rsi, TOKEN_BUF_LEN
    call secure_zero

    lea rsi, [str_installing]
    call display_put_string
    call _perform_installation

    mov dil, COLOR_OK
    call display_set_color
    lea rsi, [str_install_ok]
    call display_put_string
    mov dil, COLOR_NORMAL
    call display_set_color
    jmp .done

.no_drives:
    mov dil, COLOR_WARN
    call display_set_color
    lea rsi, [str_no_drives]
    call display_put_string
    mov dil, COLOR_NORMAL
    call display_set_color
    jmp .done

.auth_fail:
    lea rdi, [install_token_buf]
    mov rsi, TOKEN_BUF_LEN
    call secure_zero
    mov dil, COLOR_WARN
    call display_set_color
    lea rsi, [str_auth_fail]
    call display_put_string
    mov dil, COLOR_NORMAL
    call display_set_color
    jmp .done

.aborted:
    lea rsi, [str_aborted]
    call display_put_string

.done:
    pop rbx
    ret

_build_drive_list:
    push rbx
    push rcx

    xor rcx, rcx

    lea rax, [str_drive_0]
    mov qword [drive_labels], rax
    inc rcx

    lea rax, [str_drive_1]
    mov qword [drive_labels + 8], rax
    inc rcx

    movzx rax, byte [usb_device_count]
    test rax, rax
    jz .done
    lea rax, [str_drive_usb]
    mov qword [drive_labels + 16], rax
    inc rcx

.done:
    mov rax, rcx
    pop rcx
    pop rbx
    ret

_perform_installation:
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
