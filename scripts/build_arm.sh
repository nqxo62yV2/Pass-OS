#!/usr/bin/env bash
# PassOS ARM64 Build Script
#
# Builds a minimal AArch64 boot stub. The shared kernel/driver/interface
# modules are x86-64 NASM sources and cannot be linked into an AArch64
# image, so this target currently produces the boot entry plus a small
# architecture-specific kernel stub (see kernel/arm/kernel_arm.S).
#
# Requirements: aarch64-linux-gnu-as, aarch64-linux-gnu-ld,
#               aarch64-linux-gnu-objcopy

set -e

OUT="build/arm"
mkdir -p "$OUT/obj"

CROSS="aarch64-linux-gnu-"
AS="${CROSS}as"
LD="${CROSS}ld"
OBJCOPY="${CROSS}objcopy"

echo "=== PassOS ARM64 Build (boot stub) ==="

echo "[1/3] Assembling ARM64 boot entry..."
$AS -o "$OUT/obj/boot_arm.o" boot/arm/boot_arm.asm

echo "[2/3] Assembling ARM64 kernel stub..."
$AS -o "$OUT/obj/kernel_arm.o" kernel/arm/kernel_arm.S

echo "[3/3] Linking ARM64 kernel..."
$LD -T scripts/linker_arm.ld \
    -o "$OUT/kernel_arm.elf" \
    "$OUT/obj/boot_arm.o" \
    "$OUT/obj/kernel_arm.o"

$OBJCOPY -O binary "$OUT/kernel_arm.elf" "$OUT/kernel_arm.bin"

echo ""
echo "=== ARM64 build complete ==="
echo "  ELF:    $OUT/kernel_arm.elf"
echo "  Binary: $OUT/kernel_arm.bin"
