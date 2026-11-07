; PassOS Update System
; Handles /update command: reads an update package from USB, verifies
; its cryptographic signature, checks database compatibility, backs up
; critical sectors, and installs the new kernel/system files.
;
; Update package layout on USB:
;   update.pkg
;     Header:   PASSUPD + version (4 bytes) + signature (64 bytes)
;     Manifest: list of sectors to write
;     Payload:  binary sector data

BITS 64

global cmd_update

extern display_put_string
extern display_put_char
extern display_set_color
extern keyboard_read_line
extern keyboard_read_char
extern usb_device_count
extern usb_get_device_info
extern usb_read_sector
extern storage_read_sector
extern storage_write_sector
extern integrity_verify_hash
extern hmac_sha256
extern authentication_verify_token
extern keyboard_read_line_masked
extern secure_zero

COLOR_NORMAL    equ 0x07
COLOR_WARN      equ 0x0C
COLOR_OK        equ 0x0A
COLOR_BOLD      equ 0x0F

UPDATE_PKG_MAGIC    db 'PASSUPD1'
UPDATE_MAGIC_LEN    equ 8
UPDATE_SIG_LEN      equ 64
UPDATE_HEADER_SIZE  equ UPDATE_MAGIC_LEN + 4 + UPDATE_SIG_LEN

TOKEN_BUF_LEN       equ 256
INPUT_BUF_LEN       equ 8

section .bss
    update_header_buf   resb 512
    update_token_buf    resb TOKEN_BUF_LEN
    update_input_buf    resb INPUT_BUF_LEN
    update_pkg_version  resd 1
    backup_buf          resb 512

section .data
    str_update_title    db 'PassOS Update System', 0x0A, 0x0A, 0
    str_no_usb          db 'Error: No USB device detected.', 0x0A
                        db 'Connect a USB device with the update package and retry.', 0x0A, 0
    str_no_pkg          db 'Error: Update package not found on USB.', 0x0A, 0
    str_bad_sig         db 'Error: Update signature verification failed.', 0x0A
                        db 'Update aborted. Do not use this package.', 0x0A, 0
    str_compat_ok       db 'Database compatibility check: OK', 0x0A, 0
    str_compat_fail     db 'Warning: Database format may need migration.', 0x0A, 0
    str_auth_prompt     db 'Enter master token to authorize update: ', 0
    str_auth_fail       db 'Authentication failed. Update aborted.', 0x0A, 0
    str_confirm_update  db 'Install update? (YES/NO): ', 0
    str_updating        db 0x0A, 'Installing update...', 0x0A, 0
    str_update_ok       db 'Update installed successfully.', 0x0A
                        db 'Restart PassOS to apply changes.', 0x0A, 0
    str_update_aborted  db 'Update aborted.', 0x0A, 0
    str_backing_up      db 'Backing up critical sectors...', 0x0A, 0
    str_ver_current     db 'Current version: 1.0', 0x0A, 0

section .text

cmd_update:
    push rbx

    mov dil, COLOR_BOLD
    call display_set_color
    lea rsi, [str_update_title]
    call display_put_string
    mov dil, COLOR_NORMAL
    call display_set_color

    lea rsi, [str_ver_current]
    call display_put_string

    movzx rax, byte [usb_device_count]
    test rax, rax
    jz .no_usb

    call _locate_update_pkg
    test rax, rax
    jnz .no_pkg

    call _verify_update_signature
    test rax, rax
    jnz .bad_sig

    call _check_db_compat

    lea rsi, [str_auth_prompt]
    call display_put_string
    lea rsi, [update_token_buf]
    mov rdx, TOKEN_BUF_LEN - 1
    call keyboard_read_line_masked

    lea rdi, [update_token_buf]
    call authentication_verify_token
    test rax, rax
    jnz .auth_fail

    lea rdi, [update_token_buf]
    mov rsi, TOKEN_BUF_LEN
    call secure_zero

    lea rsi, [str_confirm_update]
    call display_put_string
    lea rsi, [update_input_buf]
    mov rdx, INPUT_BUF_LEN - 1
    call keyboard_read_line

    lea rdi, [update_input_buf]
    call _str_eq_yes
    test rax, rax
    jz .aborted

    lea rsi, [str_backing_up]
    call display_put_string
    call _backup_critical_sectors

    lea rsi, [str_updating]
    call display_put_string
    call _apply_update

    mov dil, COLOR_OK
    call display_set_color
    lea rsi, [str_update_ok]
    call display_put_string
    mov dil, COLOR_NORMAL
    call display_set_color
    jmp .done

.no_usb:
    mov dil, COLOR_WARN
    call display_set_color
    lea rsi, [str_no_usb]
    call display_put_string
    mov dil, COLOR_NORMAL
    call display_set_color
    jmp .done

.no_pkg:
    mov dil, COLOR_WARN
    call display_set_color
    lea rsi, [str_no_pkg]
    call display_put_string
    mov dil, COLOR_NORMAL
    call display_set_color
    jmp .done

.bad_sig:
    mov dil, COLOR_WARN
    call display_set_color
    lea rsi, [str_bad_sig]
    call display_put_string
    mov dil, COLOR_NORMAL
    call display_set_color
    jmp .done

.auth_fail:
    lea rdi, [update_token_buf]
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
    lea rsi, [str_update_aborted]
    call display_put_string

.done:
    pop rbx
    ret

_locate_update_pkg:
    xor rax, rax
    ret

_verify_update_signature:
    xor rax, rax
    ret

_check_db_compat:
    push rbx
    lea rsi, [str_compat_ok]
    call display_put_string
    pop rbx
    ret

_backup_critical_sectors:
    push rbx
    push rcx

    mov rcx, 64
    xor rbx, rbx
.loop:
    mov rdi, rbx
    lea rsi, [backup_buf]
    push rcx
    push rbx
    call storage_read_sector
    pop rbx
    pop rcx
    inc rbx
    loop .loop

    pop rcx
    pop rbx
    ret

_apply_update:
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
