#!/usr/bin/env bash
# PassOS ARM64 Build Script
# Assembles the AArch64 boot entry with the GNU cross-assembler,
# then assembles the shared kernel/driver/interface modules with NASM
# (targeting generic ELF64 — the object files are architecture-neutral
# at the assembly level for this build stage).
# Requirements: nasm, aarch64-linux-gnu-as, aarch64-linux-gnu-ld,
#               aarch64-linux-gnu-objcopy

set -e

OUT="build/arm"
mkdir -p "$OUT/obj"

CROSS="aarch64-linux-gnu-"
GAS="${CROSS}as"
LD="${CROSS}ld"
OBJCOPY="${CROSS}objcopy"

echo "=== PassOS ARM64 Build ==="

echo "[1/3] Assembling ARM64 boot entry (GAS)..."
$GAS -o "$OUT/obj/boot_arm.o" boot/arm/boot_arm.asm

echo "[2/3] Assembling shared kernel modules (NASM ELF64)..."
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
    nasm -f elf64 "$src" -o "$OUT/obj/${base}.o"
done

echo "[3/3] Linking ARM64 kernel..."
$LD -T scripts/linker_arm.ld \
    -o "$OUT/kernel_arm.elf" \
    "$OUT/obj/boot_arm.o" \
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

$OBJCOPY -O binary "$OUT/kernel_arm.elf" "$OUT/kernel_arm.bin"

echo ""
echo "=== ARM64 Build complete ==="
echo "  Kernel: $OUT/kernel_arm.bin"
