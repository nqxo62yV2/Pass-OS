; PassOS USB Mass Storage Driver (Stub + EHCI/xHCI detection)
; Detects USB controllers via PCI bus scan, enumerates mass storage devices,
; and exposes a sector-read/write interface compatible with the storage layer.

BITS 64

global usb_init
global usb_scan_devices
global usb_read_sector
global usb_write_sector
global usb_device_count
global usb_get_device_info

PCI_CONFIG_ADDRESS      equ 0xCF8
PCI_CONFIG_DATA         equ 0xCFC

USB_CLASS_SERIAL_BUS    equ 0x0C
USB_SUBCLASS_USB        equ 0x03
USB_PROG_EHCI           equ 0x20
USB_PROG_XHCI           equ 0x30
USB_PROG_OHCI           equ 0x10
USB_PROG_UHCI           equ 0x00

MAX_USB_DEVICES         equ 8

section .bss
    usb_device_count    resb 1
    usb_devices:
        .bus            resb MAX_USB_DEVICES
        .dev            resb MAX_USB_DEVICES
        .func           resb MAX_USB_DEVICES
        .type           resb MAX_USB_DEVICES
        .base_addr      resq MAX_USB_DEVICES

section .text

usb_init:
    push rbx
    push rcx
    push rdx

    mov byte [usb_device_count], 0
    call usb_scan_devices

    pop rdx
    pop rcx
    pop rbx
    ret

usb_scan_devices:
    push rax
    push rbx
    push rcx
    push rdx

    xor rbx, rbx

.bus_loop:
    cmp rbx, 256
    jge .done

    xor rcx, rcx
.dev_loop:
    cmp rcx, 32
    jge .next_bus

    xor rdx, rdx
.func_loop:
    cmp rdx, 8
    jge .next_dev

    push rbx
    push rcx
    push rdx

    mov rdi, rbx
    mov rsi, rcx
    mov rdx, rdx
    call pci_read_class

    cmp al, USB_CLASS_SERIAL_BUS
    jne .skip_dev
    cmp ah, USB_SUBCLASS_USB
    jne .skip_dev

    call register_usb_controller

.skip_dev:
    pop rdx
    pop rcx
    pop rbx
    inc rdx
    jmp .func_loop

.next_dev:
    inc rcx
    jmp .dev_loop

.next_bus:
    inc rbx
    jmp .bus_loop

.done:
    pop rdx
    pop rcx
    pop rbx
    pop rax
    ret

pci_read_class:
    push rdx
    push rcx

    mov eax, 0x80000000
    mov cl, 5
    shl edi, cl
    or eax, edi
    shl esi, 3
    or eax, esi
    and edx, 7
    or eax, edx
    or eax, 8

    mov dx, PCI_CONFIG_ADDRESS
    out dx, eax

    mov dx, PCI_CONFIG_DATA
    in eax, dx

    shr eax, 24
    mov ah, al
    shr eax, 8
    and al, 0xFF
    and ah, 0xFF

    pop rcx
    pop rdx
    ret

register_usb_controller:
    push rax
    push rbx

    movzx rax, byte [usb_device_count]
    cmp rax, MAX_USB_DEVICES
    jge .full

    mov byte [usb_devices.bus + rax], bl
    mov byte [usb_devices.dev + rax], cl
    mov byte [usb_devices.func + rax], dl

    inc byte [usb_device_count]

.full:
    pop rbx
    pop rax
    ret

usb_read_sector:
    xor rax, rax
    ret

usb_write_sector:
    xor rax, rax
    ret

usb_get_device_info:
    xor rax, rax
    ret
