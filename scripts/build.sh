#!/usr/bin/env bash
# PassOS Build Script
# Assembles all source files and links the final kernel ELF + flat binary.
# The Multiboot2 header and long-mode entry live in boot/bios/boot.asm and
# are linked into the kernel ELF (GRUB2 loads this ELF directly).
#
# Requirements: nasm, ld (binutils), objcopy
#
# Optional: set NASMFLAGS="-DDEBUG_SERIAL" to emit COM1 boot markers for the
# QEMU smoke test (scripts/test_boot.sh).

set -e

OUT="build"
KERNEL_ELF="$OUT/kernel.elf"
KERNEL_BIN="$OUT/kernel.bin"
NASMFLAGS="${NASMFLAGS:-}"

echo "=== PassOS Build System ==="
echo ""

mkdir -p "$OUT/obj"

echo "[1/7] Assembling boot entry (Multiboot2 + long mode)..."
nasm $NASMFLAGS -f elf64 boot/bios/boot.asm -o "$OUT/obj/boot.o"

echo "[2/7] Assembling kernel..."
nasm $NASMFLAGS -f elf64 kernel/kernel.asm      -o "$OUT/obj/kernel.o"
nasm $NASMFLAGS -f elf64 kernel/memory.asm      -o "$OUT/obj/memory.o"
nasm $NASMFLAGS -f elf64 kernel/interrupts.asm  -o "$OUT/obj/interrupts.o"
nasm $NASMFLAGS -f elf64 kernel/scheduler.asm   -o "$OUT/obj/scheduler.o"
nasm $NASMFLAGS -f elf64 kernel/system.asm      -o "$OUT/obj/system.o"

echo "[3/7] Assembling drivers..."
nasm $NASMFLAGS -f elf64 drivers/display/display.asm   -o "$OUT/obj/display.o"
nasm $NASMFLAGS -f elf64 drivers/keyboard/keyboard.asm -o "$OUT/obj/keyboard.o"
nasm $NASMFLAGS -f elf64 drivers/storage/storage.asm   -o "$OUT/obj/storage.o"
nasm $NASMFLAGS -f elf64 drivers/usb/usb.asm           -o "$OUT/obj/usb.o"
nasm $NASMFLAGS -f elf64 drivers/hardware/hardware.asm -o "$OUT/obj/hardware.o"

echo "[4/7] Assembling security layer..."
nasm $NASMFLAGS -f elf64 security/key_derivation.asm -o "$OUT/obj/key_derivation.o"
nasm $NASMFLAGS -f elf64 security/encryption.asm     -o "$OUT/obj/encryption.o"
nasm $NASMFLAGS -f elf64 security/secure_memory.asm  -o "$OUT/obj/secure_memory.o"
nasm $NASMFLAGS -f elf64 security/authentication.asm -o "$OUT/obj/authentication.o"
nasm $NASMFLAGS -f elf64 security/integrity.asm      -o "$OUT/obj/integrity.o"

echo "[5/7] Assembling database layer..."
nasm $NASMFLAGS -f elf64 database/database_storage.asm -o "$OUT/obj/database_storage.o"
nasm $NASMFLAGS -f elf64 database/database.asm         -o "$OUT/obj/database.o"
nasm $NASMFLAGS -f elf64 database/database_create.asm  -o "$OUT/obj/database_create.o"
nasm $NASMFLAGS -f elf64 database/database_delete.asm  -o "$OUT/obj/database_delete.o"
nasm $NASMFLAGS -f elf64 database/database_search.asm  -o "$OUT/obj/database_search.o"
nasm $NASMFLAGS -f elf64 database/database_export.asm  -o "$OUT/obj/database_export.o"

echo "[6/7] Assembling interface layer..."
nasm $NASMFLAGS -f elf64 interface/terminal.asm       -o "$OUT/obj/terminal.o"
nasm $NASMFLAGS -f elf64 interface/command_parser.asm -o "$OUT/obj/command_parser.o"
nasm $NASMFLAGS -f elf64 interface/table.asm          -o "$OUT/obj/table.o"
nasm $NASMFLAGS -f elf64 interface/navigation.asm     -o "$OUT/obj/navigation.o"
nasm $NASMFLAGS -f elf64 interface/text_editor.asm    -o "$OUT/obj/text_editor.o"
nasm $NASMFLAGS -f elf64 interface/commands.asm       -o "$OUT/obj/commands.o"
nasm $NASMFLAGS -f elf64 settings/settings.asm        -o "$OUT/obj/settings.o"
nasm $NASMFLAGS -f elf64 updates/update.asm           -o "$OUT/obj/update.o"
nasm $NASMFLAGS -f elf64 installer/installer.asm      -o "$OUT/obj/installer.o"

echo "[7/7] Linking kernel ELF..."
# -z max-page-size=0x1000 keeps the ELF file offset of the first section
# small, so the Multiboot2 header stays inside the first 32 KiB of the file.
ld -T scripts/linker.ld -z max-page-size=0x1000 -o "$KERNEL_ELF" \
    "$OUT/obj/boot.o" \
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
echo "  Kernel ELF : $KERNEL_ELF"
echo "  Kernel BIN : $KERNEL_BIN"
echo ""
echo "To create ISO: bash scripts/makeiso.sh"
