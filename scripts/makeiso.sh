#!/usr/bin/env bash
# PassOS ISO Builder
# Creates a bootable ISO image using the assembled kernel and bootloader.
# Requirements: nasm, xorriso, mtools
# Output: build/passos.iso

set -e

OUT="build"
ISO_ROOT="$OUT/isoroot"
ISO="$OUT/passos.iso"

echo "=== PassOS ISO Builder ==="

if [ ! -f "$OUT/kernel.bin" ]; then
    echo "Error: kernel.bin not found. Run scripts/build.sh first."
    exit 1
fi

mkdir -p "$ISO_ROOT/boot/grub"

cat > "$ISO_ROOT/boot/grub/grub.cfg" << 'EOF'
set timeout=3
set default=0

menuentry "PassOS V1.0" {
    multiboot2 /boot/kernel.bin
    boot
}
EOF

cp "$OUT/kernel.bin" "$ISO_ROOT/boot/kernel.bin"
cp "$OUT/boot.bin"   "$ISO_ROOT/boot/boot.bin"

xorriso -as mkisofs \
    -b boot/boot.bin \
    -no-emul-boot \
    -boot-load-size 4 \
    -boot-info-table \
    -iso-level 3 \
    -r -J \
    -o "$ISO" \
    "$ISO_ROOT"

echo ""
echo "ISO created: $ISO"
echo ""
echo "Flash to USB with:"
echo "  Balena Etcher: open $ISO and select your USB drive"
echo "  Rufus:         select $ISO in DD mode"
echo "  dd:            sudo dd if=$ISO of=/dev/sdX bs=4M status=progress && sync"
