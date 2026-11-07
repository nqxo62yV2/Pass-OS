#!/usr/bin/env bash
# PassOS Build Script
# Assembles all source files and links the final kernel binary and ISO image.
# Requirements: nasm, ld (binutils), xorriso, mtools

set -e

ARCH="${1:-x86_64}"
OUT="build"
KERNEL_ELF="$OUT/kernel.elf"
KERNEL_BIN="$OUT/kernel.bin"
ISO="$OUT/passos.iso"

echo "=== PassOS Build System ==="
echo "Architecture: $ARCH"
echo ""

mkdir -p "$OUT/obj"

echo "[1/8] Assembling bootloader (BIOS stage 1)..."
nasm -f bin boot/bios/boot.asm -o "$OUT/boot.bin"

echo "[2/8] Assembling bootloader (BIOS stage 2)..."
nasm -f bin boot/bios/stage2.asm -o build/stage2.bin

echo "[3/8] Assembling kernel..."
nasm -f elf64 kernel/kernel.asm      -o "$OUT/obj/kernel.o"
nasm -f elf64 kernel/memory.asm      -o "$OUT/obj/memory.o"
nasm -f elf64 kernel/interrupts.asm  -o "$OUT/obj/interrupts.o"
nasm -f elf64 kernel/scheduler.asm   -o "$OUT/obj/scheduler.o"
nasm -f elf64 kernel/system.asm      -o "$OUT/obj/system.o"

echo "[4/8] Assembling drivers..."
nasm -f elf64 drivers/display/display.asm     -o "$OUT/obj/display.o"
nasm -f elf64 drivers/keyboard/keyboard.asm   -o "$OUT/obj/keyboard.o"
nasm -f elf64 drivers/storage/storage.asm     -o "$OUT/obj/storage.o"
nasm -f elf64 drivers/usb/usb.asm             -o "$OUT/obj/usb.o"
nasm -f elf64 drivers/hardware/hardware.asm   -o "$OUT/obj/hardware.o"

echo "[5/8] Assembling security layer..."
nasm -f elf64 security/key_derivation.asm  -o "$OUT/obj/key_derivation.o"
nasm -f elf64 security/encryption.asm      -o "$OUT/obj/encryption.o"
nasm -f elf64 security/secure_memory.asm   -o "$OUT/obj/secure_memory.o"
nasm -f elf64 security/authentication.asm  -o "$OUT/obj/authentication.o"
nasm -f elf64 security/integrity.asm       -o "$OUT/obj/integrity.o"

echo "[6/8] Assembling database layer..."
nasm -f elf64 database/database_storage.asm -o "$OUT/obj/database_storage.o"
nasm -f elf64 database/database.asm         -o "$OUT/obj/database.o"
nasm -f elf64 database/database_create.asm  -o "$OUT/obj/database_create.o"
nasm -f elf64 database/database_delete.asm  -o "$OUT/obj/database_delete.o"
nasm -f elf64 database/database_search.asm  -o "$OUT/obj/database_search.o"
nasm -f elf64 database/database_export.asm  -o "$OUT/obj/database_export.o"

echo "[7/8] Assembling interface layer..."
nasm -f elf64 interface/terminal.asm        -o "$OUT/obj/terminal.o"
nasm -f elf64 interface/command_parser.asm  -o "$OUT/obj/command_parser.o"
nasm -f elf64 interface/table.asm           -o "$OUT/obj/table.o"
nasm -f elf64 interface/navigation.asm      -o "$OUT/obj/navigation.o"
nasm -f elf64 interface/text_editor.asm     -o "$OUT/obj/text_editor.o"
nasm -f elf64 interface/commands.asm        -o "$OUT/obj/commands.o"

nasm -f elf64 settings/settings.asm         -o "$OUT/obj/settings.o"
nasm -f elf64 updates/update.asm            -o "$OUT/obj/update.o"
nasm -f elf64 installer/installer.asm       -o "$OUT/obj/installer.o"

echo "[8/8] Linking kernel ELF..."
ld -T scripts/linker.ld -o "$KERNEL_ELF" \
    "$OUT/obj/kernel.o" \
    "$OUT/obj/memory.o" \
    "$OUT/obj/interrupts.o" \
    "$OUT/obj/scheduler.o" \
    "$OUT/obj/system.o" \
    "$OUT/obj/display.o" \
    "$OUT/obj/keyboard.o" \
    "$OUT/obj/storage.o" \
    "$OUT/obj/usb.o" \
    "$OUT/obj/hardware.o" \
    "$OUT/obj/key_derivation.o" \
    "$OUT/obj/encryption.o" \
    "$OUT/obj/secure_memory.o" \
    "$OUT/obj/authentication.o" \
    "$OUT/obj/integrity.o" \
    "$OUT/obj/database_storage.o" \
    "$OUT/obj/database.o" \
    "$OUT/obj/database_create.o" \
    "$OUT/obj/database_delete.o" \
    "$OUT/obj/database_search.o" \
    "$OUT/obj/database_export.o" \
    "$OUT/obj/terminal.o" \
    "$OUT/obj/command_parser.o" \
    "$OUT/obj/table.o" \
    "$OUT/obj/navigation.o" \
    "$OUT/obj/text_editor.o" \
    "$OUT/obj/commands.o" \
    "$OUT/obj/settings.o" \
    "$OUT/obj/update.o" \
    "$OUT/obj/installer.o"

objcopy -O binary "$KERNEL_ELF" "$KERNEL_BIN"

echo ""
echo "=== Build complete ==="
echo "  Kernel ELF:  $KERNEL_ELF"
echo "  Kernel BIN:  $KERNEL_BIN"
echo ""
echo "To create ISO: run scripts/makeiso.sh"
