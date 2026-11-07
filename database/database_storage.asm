; PassOS Database Storage Layer
; Maps logical database blocks to physical disk sectors.
; Each database occupies a contiguous run of sectors defined in the
; database index at sector 2.  Data sectors begin at sector 64.
;
; Database Index Layout (sector 2):
;   Bytes 0-7:   Magic "PWDB0001"
;   Bytes 8-11:  Database count (uint32)
;   Per entry (48 bytes, up to 32 entries):
;     Bytes 0-31:  Database name (UTF-8, null-padded)
;     Bytes 32-35: Start sector (uint32)
;     Bytes 36-39: Sector count (uint32)
;     Bytes 40-47: Entry count  (uint64)

BITS 64

global db_storage_init
global db_storage_load_index
global db_storage_save_index
global db_storage_alloc_db
global db_storage_free_db
global db_storage_read_entry
global db_storage_write_entry
global db_storage_get_db_info
global db_storage_db_count
global db_storage_find_db

extern storage_read_sector
extern storage_write_sector
extern storage_read_sectors
extern storage_write_sectors
extern secure_zero

DB_INDEX_SECTOR      equ 2
DB_DATA_SECTOR_BASE  equ 64
SECTORS_PER_DB       equ 256
DB_MAGIC_LEN         equ 8
MAX_DATABASES        equ 32
DB_NAME_MAX          equ 32
INDEX_ENTRY_SIZE     equ 48
DB_ENTRY_DISK_SIZE   equ 256

section .data
    db_magic    db 'PWDB0001'

section .bss
    index_sector_buf    resb 512
    data_sector_buf     resb 512
    db_count            resd 1

section .text

db_storage_init:
    push rbx
    call db_storage_load_index
    pop rbx
    ret

db_storage_load_index:
    push rbx
    push rdi

    lea rdi, [index_sector_buf]
    mov rsi, DB_INDEX_SECTOR
    call storage_read_sector

    lea rdi, [index_sector_buf]
    lea rsi, [db_magic]
    mov rdx, DB_MAGIC_LEN
    call _db_memcmp
    test rax, rax
    jne .fresh_index

    mov eax, dword [index_sector_buf + DB_MAGIC_LEN]
    mov dword [db_count], eax
    jmp .done

.fresh_index:
    lea rdi, [index_sector_buf]
    mov rsi, 512
    call secure_zero

    lea rdi, [index_sector_buf]
    lea rsi, [db_magic]
    mov rcx, DB_MAGIC_LEN
    rep movsb

    mov dword [index_sector_buf + DB_MAGIC_LEN], 0
    mov dword [db_count], 0
    call db_storage_save_index

.done:
    pop rdi
    pop rbx
    ret

db_storage_save_index:
    push rbx

    mov eax, dword [db_count]
    mov dword [index_sector_buf + DB_MAGIC_LEN], eax

    lea rsi, [index_sector_buf]
    mov rdi, DB_INDEX_SECTOR
    call storage_write_sector

    pop rbx
    ret

db_storage_alloc_db:
    push rbx
    push r12
    push r13

    mov r12, rdi

    mov eax, dword [db_count]
    cmp rax, MAX_DATABASES
    jge .full

    mov r13, rax
    imul rbx, r13, INDEX_ENTRY_SIZE
    add rbx, DB_MAGIC_LEN + 4
    add rbx, index_sector_buf

    lea rdi, [rbx]
    mov rsi, INDEX_ENTRY_SIZE
    call secure_zero

    lea rdi, [rbx]
    mov rsi, r12
    call _db_strcopy

    imul rax, r13, SECTORS_PER_DB
    add rax, DB_DATA_SECTOR_BASE
    mov dword [rbx + DB_NAME_MAX], eax

    mov dword [rbx + DB_NAME_MAX + 4], SECTORS_PER_DB
    mov qword [rbx + DB_NAME_MAX + 8], 0

    inc dword [db_count]
    call db_storage_save_index

    mov rax, r13
    jmp .done

.full:
    mov rax, -1

.done:
    pop r13
    pop r12
    pop rbx
    ret

db_storage_free_db:
    push rbx
    push rcx
    push r12

    mov r12, rdi

    call db_storage_find_db
    cmp rax, -1
    je .not_found

    mov rbx, rax

    ; rcx = pointer to the freed slot in the index buffer
    imul rcx, rbx, INDEX_ENTRY_SIZE
    add rcx, DB_MAGIC_LEN + 4
    add rcx, index_sector_buf

    ; zero the freed slot first
    lea rdi, [rcx]
    mov rsi, INDEX_ENTRY_SIZE
    call secure_zero

    ; check if the freed slot is already the last entry
    mov eax, dword [db_count]
    dec eax
    cmp rbx, rax
    je .just_decrement

    ; copy the last entry into the freed slot
    imul rsi, rax, INDEX_ENTRY_SIZE
    add rsi, DB_MAGIC_LEN + 4
    add rsi, index_sector_buf      ; rsi = last entry
    mov rdi, rcx                   ; rdi = freed slot
    mov rcx, INDEX_ENTRY_SIZE
    rep movsb

    ; zero the now-duplicate last entry
    imul rdi, qword [db_count], INDEX_ENTRY_SIZE
    sub rdi, INDEX_ENTRY_SIZE
    add rdi, DB_MAGIC_LEN + 4
    add rdi, index_sector_buf
    mov rsi, INDEX_ENTRY_SIZE
    call secure_zero

.just_decrement:
    dec dword [db_count]
    call db_storage_save_index
    xor rax, rax
    jmp .done

.not_found:
    mov rax, 1

.done:
    pop r12
    pop rcx
    pop rbx
    ret

db_storage_find_db:
    push rbx
    push rcx

    xor rcx, rcx
    mov eax, dword [db_count]
    mov rbx, rax

.loop:
    cmp rcx, rbx
    jge .not_found

    push rcx
    imul rax, rcx, INDEX_ENTRY_SIZE
    add rax, DB_MAGIC_LEN + 4
    add rax, index_sector_buf

    mov rsi, rax
    call _db_strcmp_ci
    pop rcx

    test rax, rax
    jz .found

    inc rcx
    jmp .loop

.found:
    mov rax, rcx
    jmp .done

.not_found:
    mov rax, -1

.done:
    pop rcx
    pop rbx
    ret

db_storage_get_db_info:
    push rbx

    mov rbx, rdi
    imul rax, rbx, INDEX_ENTRY_SIZE
    add rax, DB_MAGIC_LEN + 4
    add rax, index_sector_buf

    pop rbx
    ret

db_storage_db_count:
    movzx rax, dword [db_count]
    ret

db_storage_read_entry:
    push rbx
    push r12
    push r13

    mov r12, rdi
    mov r13, rsi
    mov rbx, rdx

    imul rax, r12, INDEX_ENTRY_SIZE
    add rax, DB_MAGIC_LEN + 4
    add rax, index_sector_buf
    mov r8d, dword [rax + DB_NAME_MAX]

    imul r9, r13, DB_ENTRY_DISK_SIZE
    mov rax, r9
    xor rdx, rdx
    mov rcx, 512
    div rcx

    add rax, r8

    lea rdi, [data_sector_buf]
    mov rsi, rax
    call storage_read_sector

    lea rsi, [data_sector_buf]
    imul rax, r13, DB_ENTRY_DISK_SIZE
    and rax, 511
    add rsi, rax

    mov rdi, rbx
    mov rcx, DB_ENTRY_DISK_SIZE
    rep movsb

    xor rax, rax
    pop r13
    pop r12
    pop rbx
    ret

db_storage_write_entry:
    push rbx
    push r12
    push r13

    mov r12, rdi
    mov r13, rsi
    mov rbx, rdx

    imul rax, r12, INDEX_ENTRY_SIZE
    add rax, DB_MAGIC_LEN + 4
    add rax, index_sector_buf
    mov r8d, dword [rax + DB_NAME_MAX]

    imul r9, r13, DB_ENTRY_DISK_SIZE
    mov rax, r9
    xor rdx, rdx
    mov rcx, 512
    div rcx

    mov r10, rax
    add r10, r8

    lea rdi, [data_sector_buf]
    mov rsi, r10
    call storage_read_sector

    lea rdi, [data_sector_buf]
    imul rax, r13, DB_ENTRY_DISK_SIZE
    and rax, 511
    add rdi, rax

    mov rsi, rbx
    mov rcx, DB_ENTRY_DISK_SIZE
    rep movsb

    lea rsi, [data_sector_buf]
    mov rdi, r10
    call storage_write_sector

    xor rax, rax
    pop r13
    pop r12
    pop rbx
    ret

_db_memcmp:
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

_db_strcopy:
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
    jmp .loop
.done:
    pop rdi
    pop rsi
    pop rcx
    ret

_db_strcmp_ci:
    push rbx
    push rcx
.loop:
    movzx rax, byte [rdi]
    movzx rbx, byte [rsi]
    test rax, rax
    jz .check_end
    test rbx, rbx
    jz .not_equal
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
    jne .not_equal
    inc rdi
    inc rsi
    jmp .loop
.check_end:
    test rbx, rbx
    jnz .not_equal
    xor rax, rax
    jmp .done
.not_equal:
    mov rax, 1
.done:
    pop rcx
    pop rbx
    ret
