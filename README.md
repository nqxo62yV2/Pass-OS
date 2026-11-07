# PassOS V1.0

PassOS is a standalone, security-focused operating system for password management. It is written entirely in Assembly and currently runs on x86-64 hardware, with an ARM64 port in progress. There is no network connectivity, no background services, and no unnecessary software. Everything is oriented toward protecting stored credentials.

---

## Quick Start

> **Prebuilt ISO:** [`artifacts/passos.iso`](artifacts/passos.iso) — verified
> booting in VirtualBox 7.2.20 (BIOS, GRUB2/Multiboot2).

### Build Requirements

| Tool | Purpose |
|---|---|
| `nasm` | x86-64 assembler |
| `ld` (binutils) | Linker |
| `objcopy` (binutils) | Binary extraction |
| `grub-mkrescue` + `grub-pc-bin` | Bootable ISO creation (GRUB2/Multiboot2) |
| `xorriso`, `mtools` | ISO filesystem tools used by `grub-mkrescue` |
| `aarch64-linux-gnu-*` | ARM64 cross toolchain |
| `qemu-system-x86_64` | Testing (optional) |

> The ISO boots via GRUB2 + Multiboot2. `build/kernel.elf` is loaded directly
> by GRUB; there is no El Torito stage-1/stage-2 disk chain any more.

> **ARM64 status:** the shared kernel modules are x86-64 NASM sources, so the
> ARM64 target currently builds the AArch64 boot entry plus a minimal kernel
> stub (`kernel/arm/kernel_arm.S`). It is a working cross-build, not a
> functional PassOS port yet.

### Build and Create ISO

```bash
bash scripts/build.sh
bash scripts/makeiso.sh
```

Or use Make:

```bash
make           # builds x86_64 + ISO
make arm64     # builds ARM64 boot stub (full port still in progress)
make clean     # removes build artifacts
```

### Flash to USB

```bash
# Linux
sudo dd if=build/passos.iso of=/dev/sdX bs=4M status=progress && sync

# Windows: use Rufus or Balena Etcher
```

### Test in QEMU

```bash
qemu-system-x86_64 -cdrom build/passos.iso -m 256M
```

---

## First Boot

On first boot PassOS detects no master token and walks you through setup:

1. Read and acknowledge the security warning.
2. Enter a master token (minimum 8 characters).
3. Confirm the token.
4. PassOS derives a cryptographic key using Argon2id and stores a salted hash. The token itself is never written to disk.

After setup, every subsequent boot requires the master token at the login screen.

---

## Commands

| Command | Description |
|---|---|
| `/help` | List all commands |
| `/create_database("NAME")` | Create a new database |
| `/enter_database("NAME")` | Open and navigate a database |
| `/searchall_databases("Name=TERM")` | Search all databases |
| `/search_database("DB=TERM")` | Search one database |
| `/settings` | System settings |
| `/clear` or `/cls` | Clear the terminal |
| `/changelogs` | Version and release notes |
| `/delete_database("NAME")` | Delete a database (3-stage) |
| `/export_database("NAME")` | Export one database to USB |
| `/export_database=all` | Export all databases to USB |
| `/purge` | Destroy all databases |
| `/update` | Install an update from USB |
| `/install` | Install PassOS to a drive |
| `/exit` | Shut down safely |

See `docs/Document.md` for full documentation.

---

## Security Model

- **Master token** is never stored in plaintext. Argon2id (64 MB, 3 passes, parallelism 4) derives a 64-byte key bundle from which all database keys are derived.
- **Database encryption** uses AES-256-GCM with hardware AES-NI when available, falling back to a software implementation. Each operation uses a fresh random nonce.
- **Individual entry keys** add a second encryption layer on each password field.
- **Secure memory** routines zero all sensitive buffers immediately after use with `mfence` barriers.
- **No recovery mechanism** exists. A lost master token means permanent loss of all stored passwords.

---

## Project Layout

```
PassOS/
├── boot/          BIOS (Multiboot2) and ARM64 boot entry
├── kernel/        Core kernel: memory, interrupts, scheduler, system init
├── drivers/       Display, keyboard, storage, USB, hardware detection
├── security/      Key derivation, encryption, secure memory, authentication, integrity
├── database/      Database storage, CRUD, search, export, deletion
├── interface/     Terminal, command parser, table UI, navigation, text editor, commands
├── settings/      Persistent settings
├── updates/       Update installation
├── installer/     Drive installer
├── docs/          Document.md — full documentation
├── scripts/       Build scripts, linker scripts, Makefile
├── artifacts/     Prebuilt, verified ISO images
├── CHANGELOG.md   Release history
└── build/         Build output (generated)
```

---

## License

PassOS is proprietary software. All rights reserved.
