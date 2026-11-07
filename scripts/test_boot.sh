#!/usr/bin/env bash
# PassOS boot smoke test.
#
# Boots the ISO in QEMU with no display and captures the COM1 debug output.
# The kernel is expected to be built with NASMFLAGS="-DDEBUG_SERIAL" so the
# boot stub and kernel_main emit PASSOS:* markers.
#
# Usage: bash scripts/test_boot.sh [build/passos.iso]

set -e

ISO="${1:-build/passos.iso}"

if [ ! -f "$ISO" ]; then
    echo "Error: ISO not found: $ISO" >&2
    exit 1
fi

if ! command -v qemu-system-x86_64 >/dev/null 2>&1; then
    echo "qemu-system-x86_64 not found; skipping boot test."
    exit 0
fi

LOG="$(mktemp)"
trap 'rm -f "$LOG"' EXIT

echo "Booting $ISO in QEMU..."
# The kernel waits for keyboard input after the boot screen, so QEMU is
# expected to run until the timeout kills it.
timeout 30 qemu-system-x86_64 \
    -cdrom "$ISO" \
    -m 256M \
    -display none \
    -monitor none \
    -no-reboot \
    -serial stdio > "$LOG" 2>&1 || true

echo "--- guest serial output ---"
cat "$LOG" || true
echo "---------------------------"

for marker in "PASSOS:BOOT_ENTRY" "PASSOS:LONG_MODE" "PASSOS:KERNEL_MAIN" "PASSOS:BOOT_SCREEN_OK"; do
    if ! grep -q "$marker" "$LOG"; then
        echo "Boot test FAILED: missing marker $marker" >&2
        exit 1
    fi
done

echo "Boot test PASSED."
