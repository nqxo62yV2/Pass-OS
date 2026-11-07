; PassOS Database Search Module
; Handles /search_database("DB=TERM") and /searchall_databases("Name=TERM").
; Searches entry names without decrypting passwords.

BITS 64

global cmd_search_database
global cmd_searchall_databases

extern db_storage_db_count
extern db_storage_find_db
extern db_storage_get_db_info
extern db_storage_read_entry
extern display_put_string
extern display_put_char
extern display_set_color

COLOR_MATCH     equ 0x0B
COLOR_NORMAL    equ 0x07
COLOR_HDR       equ 0x0F
COLOR_ERR       equ 0x0C

ENTRY_FLAG_ACTIVE   equ 0x01
ENTRY_NAME_OFFSET   equ 1
ENTRY_NAME_LEN      equ 64
ENTRY_TOTAL_LEN     equ 256

section .bss
    srch_entry_buf  resb ENTRY_TOTAL_LEN
    srch_result_cnt resq 1

section .data
    str_srch_header     db '--- Search Results ---', 0x0A, 0
    str_srch_none       db 'No matching entries found.', 0x0A, 0
    str_srch_in_db_a    db '  Database: ', 0
    str_srch_entry_a    db '  Entry:    ', 0
    str_srch_sep        db 0x0A, 0
    str_srch_not_found  db 'Error: Database not found.', 0x0A, 0
    str_srch_no_db      db 'Error: No databases exist.', 0x0A, 0

section .text

cmd_search_database:
    push rbx
    push r12
    push r13

    mov r12, rdi
    mov r13, rsi

    mov rdi, r12
    call db_storage_find_db
    cmp rax, -1
    je .not_found

    mov rbx, rax
    mov qword [srch_result_cnt], 0

    mov dil, COLOR_HDR
    call display_set_color
    lea rsi, [str_srch_header]
    call display_put_string
    mov dil, COLOR_NORMAL
    call display_set_color

    call db_storage_get_db_info
    mov r9, qword [rax + 40]

    xor rcx, rcx
.entry_loop:
    cmp rcx, r9
    jge .check_results

    push rcx
    push rbx
    push r9

    mov rdi, rbx
    mov rsi, rcx
    lea rdx, [srch_entry_buf]
    call db_storage_read_entry

    movzx rax, byte [srch_entry_buf]
    test rax, ENTRY_FLAG_ACTIVE
    jz .next_entry

    lea rdi, [srch_entry_buf + ENTRY_NAME_OFFSET]
    mov rsi, r13
    call _substr_match
    test rax, rax
    jz .next_entry

    inc qword [srch_result_cnt]
    mov dil, COLOR_MATCH
    call display_set_color
    lea rsi, [str_srch_entry_a]
    call display_put_string
    lea rsi, [srch_entry_buf + ENTRY_NAME_OFFSET]
    call display_put_string
    mov al, 0x0A
    call display_put_char
    mov dil, COLOR_NORMAL
    call display_set_color

.next_entry:
    pop r9
    pop rbx
    pop rcx
    inc rcx
    jmp .entry_loop

.check_results:
    cmp qword [srch_result_cnt], 0
    jne .done
    lea rsi, [str_srch_none]
    call display_put_string
    jmp .done

.not_found:
    mov dil, COLOR_ERR
    call display_set_color
    lea rsi, [str_srch_not_found]
    call display_put_string
    mov dil, COLOR_NORMAL
    call display_set_color

.done:
    pop r13
    pop r12
    pop rbx
    ret

cmd_searchall_databases:
    push rbx
    push r12
    push r13

    mov r13, rdi

    call db_storage_db_count
    test rax, rax
    jz .no_dbs

    mov r12, rax
    mov qword [srch_result_cnt], 0

    mov dil, COLOR_HDR
    call display_set_color
    lea rsi, [str_srch_header]
    call display_put_string
    mov dil, COLOR_NORMAL
    call display_set_color

    xor rbx, rbx
.db_loop:
    cmp rbx, r12
    jge .check_results

    push rbx
    push r12

    mov rdi, rbx
    call db_storage_get_db_info
    push rax

    mov r9, qword [rax + 40]

    xor rcx, rcx
.entry_loop:
    cmp rcx, r9
    jge .next_db

    push rcx
    push r9

    mov rdi, rbx
    mov rsi, rcx
    lea rdx, [srch_entry_buf]
    call db_storage_read_entry

    movzx rax, byte [srch_entry_buf]
    test rax, ENTRY_FLAG_ACTIVE
    jz .next_entry2

    lea rdi, [srch_entry_buf + ENTRY_NAME_OFFSET]
    mov rsi, r13
    call _substr_match
    test rax, rax
    jz .next_entry2

    inc qword [srch_result_cnt]

    pop r9
    pop rcx
    push rcx
    push r9

    pop r9
    pop rcx
    push rcx
    push r9

    mov rax, [rsp + 24]
    mov dil, COLOR_MATCH
    call display_set_color
    lea rsi, [str_srch_in_db_a]
    call display_put_string
    mov rsi, rax
    call display_put_string
    mov al, 0x0A
    call display_put_char

    lea rsi, [str_srch_entry_a]
    call display_put_string
    lea rsi, [srch_entry_buf + ENTRY_NAME_OFFSET]
    call display_put_string
    mov al, 0x0A
    call display_put_char
    mov dil, COLOR_NORMAL
    call display_set_color

.next_entry2:
    pop r9
    pop rcx
    inc rcx
    jmp .entry_loop

.next_db:
    pop rax
    pop r12
    pop rbx
    inc rbx
    jmp .db_loop

.check_results:
    cmp qword [srch_result_cnt], 0
    jne .done
    lea rsi, [str_srch_none]
    call display_put_string
    jmp .done

.no_dbs:
    mov dil, COLOR_ERR
    call display_set_color
    lea rsi, [str_srch_no_db]
    call display_put_string
    mov dil, COLOR_NORMAL
    call display_set_color

.done:
    pop r13
    pop r12
    pop rbx
    ret

_substr_match:
    push rbx
    push rcx
    push rsi
    push rdi
    push r8
    push r9

    test rsi, rsi
    jz .match_all

    mov r8, rdi
.outer:
    movzx rax, byte [r8]
    test rax, rax
    jz .no_match

    mov r9, r8
    mov rcx, rsi
.inner:
    movzx rax, byte [rcx]
    test rax, rax
    jz .found

    movzx rbx, byte [r9]
    test rbx, rbx
    jz .no_match

    cmp rax, 'A'
    jl .no_lower_a
    cmp rax, 'Z'
    jg .no_lower_a
    add rax, 32
.no_lower_a:
    cmp rbx, 'A'
    jl .no_lower_b
    cmp rbx, 'Z'
    jg .no_lower_b
    add rbx, 32
.no_lower_b:
    cmp rax, rbx
    jne .outer_next

    inc r9
    inc rcx
    jmp .inner

.outer_next:
    inc r8
    jmp .outer

.found:
    mov rax, 1
    jmp .done

.match_all:
    mov rax, 1
    jmp .done

.no_match:
    xor rax, rax

.done:
    pop r9
    pop r8
    pop rdi
    pop rsi
    pop rcx
    pop rbx
    ret
