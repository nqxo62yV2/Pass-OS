#!/usr/bin/env bash
# PassOS ARM64 Build Script
# Assembles the ARM64 boot entry and kernel.
# Requirements: aarch64-linux-gnu-as, aarch64-linux-gnu-ld, aarch64-linux-gnu-objcopy

set -e

OUT="build/arm"
mkdir -p "$OUT/obj"

CROSS="aarch64-linux-gnu-"
AS="${CROSS}as"
LD="${CROSS}ld"
OBJCOPY="${CROSS}objcopy"

echo "=== PassOS ARM64 Build ==="

echo "[1/3] Assembling ARM64 boot entry..."
$AS -o "$OUT/obj/boot_arm.o" boot/arm/boot_arm.asm

echo "[2/3] Assembling ARM64 kernel modules..."
for src in \
    kernel/kernel.asm \
    kernel/memory.asm \
    kernel/interrupts.asm \
    kernel/scheduler.asm \
    kernel/system.asm \
    drivers/display/display.asm \
    drivers/keyboard/keyboard.asm \
    drivers/storage/storage.asm \
    drivers/usb/usb.asm \
    drivers/hardware/hardware.asm \
    security/key_derivation.asm \
    security/encryption.asm \
    security/secure_memory.asm \
    security/authentication.asm \
    security/integrity.asm \
    database/database_storage.asm \
    database/database.asm \
    database/database_create.asm \
    database/database_delete.asm \
    database/database_search.asm \
    database/database_export.asm \
    interface/terminal.asm \
    interface/command_parser.asm \
    interface/table.asm \
    interface/navigation.asm \
    interface/text_editor.asm \
    interface/commands.asm \
    settings/settings.asm \
    updates/update.asm \
    installer/installer.asm
do
    base=$(basename "$src" .asm)
    $AS -o "$OUT/obj/${base}.o" "$src"
done

echo "[3/3] Linking ARM64 kernel..."
$LD -T scripts/linker_arm.ld -o "$OUT/kernel_arm.elf" "$OUT/obj/"*.o
$OBJCOPY -O binary "$OUT/kernel_arm.elf" "$OUT/kernel_arm.bin"

echo ""
echo "=== ARM64 Build complete ==="
echo "  Kernel: $OUT/kernel_arm.bin"
