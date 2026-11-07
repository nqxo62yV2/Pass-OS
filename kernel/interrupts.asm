; PassOS Interrupt Descriptor Table and Handler Infrastructure
; Sets up IDT, PIC remapping, and common interrupt stubs.

BITS 64

global interrupts_init
global idt_load
global irq_enable
global irq_disable

extern keyboard_scancode_handler

IDT_ENTRIES     equ 256
PIC1_CMD        equ 0x20
PIC1_DATA       equ 0x21
PIC2_CMD        equ 0xA0
PIC2_DATA       equ 0xA1
PIC_EOI         equ 0x20

ICW1_INIT       equ 0x11
ICW4_8086       equ 0x01

section .bss
    align 16
    idt:        resb IDT_ENTRIES * 16
    idtr:       resb 10

section .text

interrupts_init:
    push rbx
    push rcx
    push rdi

    call remap_pic
    call build_idt
    call idt_load
    sti

    pop rdi
    pop rcx
    pop rbx
    ret

remap_pic:
    mov al, ICW1_INIT
    out PIC1_CMD, al
    out PIC2_CMD, al

    mov al, 0x20
    out PIC1_DATA, al
    mov al, 0x28
    out PIC2_DATA, al

    mov al, 0x04
    out PIC1_DATA, al
    mov al, 0x02
    out PIC2_DATA, al

    mov al, ICW4_8086
    out PIC1_DATA, al
    out PIC2_DATA, al

    mov al, 0xFD
    out PIC1_DATA, al
    mov al, 0xFF
    out PIC2_DATA, al
    ret

build_idt:
    push rbx
    push rcx

    lea rbx, [idt]
    mov rcx, 0

.loop:
    cmp rcx, IDT_ENTRIES
    jge .done

    lea rax, [default_handler]
    cmp rcx, 33
    jne .set_default
    lea rax, [keyboard_handler_stub]

.set_default:
    mov word [rbx], ax
    shr rax, 16
    mov word [rbx + 6], ax
    shr rax, 16
    mov dword [rbx + 8], eax

    mov word [rbx + 2], 0x0008
    mov byte [rbx + 4], 0
    mov byte [rbx + 5], 0x8E

    add rbx, 16
    inc rcx
    jmp .loop

.done:
    pop rcx
    pop rbx
    ret

idt_load:
    lea rax, [idt]
    mov word [idtr], IDT_ENTRIES * 16 - 1
    mov qword [idtr + 2], rax
    lidt [idtr]
    ret

default_handler:
    push rax
    mov al, PIC_EOI
    out PIC1_CMD, al
    out PIC2_CMD, al
    pop rax
    iretq

keyboard_handler_stub:
    push rax
    push rbx
    in al, 0x60
    call keyboard_scancode_handler
    mov al, PIC_EOI
    out PIC1_CMD, al
    pop rbx
    pop rax
    iretq

irq_enable:
    sti
    ret

irq_disable:
    cli
    ret
