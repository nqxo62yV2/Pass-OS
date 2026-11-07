# Changelog

All notable changes to PassOS are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project uses [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added

- Boot splash screen with ASCII "PASSOS" logo, version and progress bar.
  It advances with Enter, falls back to a timeout, and is skipped in
  `DEBUG_SERIAL` CI builds so automated boot tests do not block.
- Prebuilt, VirtualBox-verified ISO at `artifacts/passos.iso`.
- `CHANGELOG.md`.

### Fixed

- x86-64 ISO now boots through GRUB2 + Multiboot2. The previous El Torito
  `boot.bin`/`stage2.bin` sector chain never handed control to the kernel and
  left the screen at `S_`.
- Backspace now edits input instead of being written to VGA memory as a
  glyph. The display driver moves the cursor left and the read-line helpers
  erase the character.
- Delete (`E0 53`) is recognised as an extended scancode and deletes the
  previous character. The `0xE0` prefix is no longer mistaken for a key
  release.
- Other special keys (arrows, Esc, Tab) are ignored by line input instead of
  being inserted as characters.
- Keyboard handler preserves callee-saved registers; `keyboard_read_line`
  and `keyboard_read_line_masked` return the actual line length.
- First-run confirmation accepts `yes`, `Yes` and `YES`.
- ARM64 target builds a real AArch64 boot entry + kernel stub instead of
  linking x86-64 NASM objects into an AArch64 image. `continue-on-error` was
  removed from the CI job.
- Linker scripts: `.multiboot` is placed first, `-z max-page-size=0x1000`
  keeps the Multiboot2 header in the first 32 KiB, and the ARM64 script no
  longer references a non-existent object path.

### Changed

- ISO creation uses `grub-mkrescue` defaults; custom `xorriso` flags were
  removed.
- CI boots a debug ISO in QEMU (COM1 markers) before building the clean
  release ISO.

## [1.0.0] - 2026-11-07

Initial release of the x86-64 PassOS password vault:

- Multiboot2 kernel, VGA text console, PS/2 keyboard driver.
- First-run master-token setup and authentication flow.
- `PassOS>` shell with `/help`, database, export, update, install and exit
  commands.

> Note: several security subsystems (notably Argon2id key derivation) are
> still stubs, so the vault is not yet cryptographically functional.
