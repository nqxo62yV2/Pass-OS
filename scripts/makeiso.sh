#!/usr/bin/env bash
# PassOS ISO Builder
# Creates a bootable ISO using GRUB2 as the bootloader. GRUB2 loads
# build/kernel.elf through the Multiboot2 protocol.
#
# Requirements: grub-mkrescue (grub-common + grub-pc-bin), xorriso, mtools

set -e

OUT="build"
ISO_ROOT="$OUT/isoroot"
ISO="$OUT/passos.iso"

echo "=== PassOS ISO Builder ==="

if [ ! -f "$OUT/kernel.elf" ]; then
    echo "Error: $OUT/kernel.elf not found. Run scripts/build.sh first."
    exit 1
fi

if ! command -v grub-mkrescue >/dev/null 2>&1; then
    echo "Error: grub-mkrescue not found."
    echo "  Debian/Ubuntu: sudo apt install grub-common grub-pc-bin xorriso mtools"
    exit 1
fi

# Reject a kernel that GRUB would not recognise before building the ISO.
if command -v grub-file >/dev/null 2>&1; then
    if ! grub-file --is-x86-multiboot2 "$OUT/kernel.elf"; then
        echo "Error: $OUT/kernel.elf has no valid Multiboot2 header."
        exit 1
    fi
    echo "Multiboot2 header: OK"
fi

rm -rf "$ISO_ROOT"
mkdir -p "$ISO_ROOT/boot/grub"

# Force the VGA text console so the kernel's 0xB8000 text output is visible.
cat > "$ISO_ROOT/boot/grub/grub.cfg" << 'EOF'
terminal_output console
set timeout=3
set default=0

menuentry "PassOS V1.0" {
    multiboot2 /boot/kernel.elf
    boot
}
EOF

# GRUB reads the ELF program headers and loads the image at its link address.
cp "$OUT/kernel.elf" "$ISO_ROOT/boot/kernel.elf"

# Build a hybrid BIOS/UEFI ISO. Extra arguments after -- go to xorriso.
grub-mkrescue -o "$ISO" "$ISO_ROOT" -- -iso-level 3 -r -J

echo ""
echo "ISO created: $ISO"
echo ""
echo "Test in VirtualBox / QEMU:"
echo "  qemu-system-x86_64 -cdrom $ISO -m 256M"
echo ""
echo "Flash to USB:"
echo "  Linux: sudo dd if=$ISO of=/dev/sdX bs=4M status=progress && sync"
echo "  Windows: Rufus (DD mode) or Balena Etcher"
