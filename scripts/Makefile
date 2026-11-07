# PassOS Master Makefile
# Targets: all, x86_64, arm64, iso, clean

.PHONY: all x86_64 arm64 iso clean

all: x86_64 iso

x86_64:
	@bash scripts/build.sh x86_64

arm64:
	@bash scripts/build_arm.sh

iso: x86_64
	@bash scripts/makeiso.sh

clean:
	rm -rf build/obj build/arm
	rm -f build/kernel.elf build/kernel.bin build/boot.bin build/passos.iso

test:
	@echo "Run: qemu-system-x86_64 -cdrom build/passos.iso -m 256M -serial stdio"
