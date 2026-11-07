# PassOS V1.0 — Complete Documentation

---

## Table of Contents

1. [Project Overview](#1-project-overview)
2. [System Architecture](#2-system-architecture)
3. [Supported CPU Architectures](#3-supported-cpu-architectures)
4. [Hardware Compatibility](#4-hardware-compatibility)
5. [Boot Process](#5-boot-process)
6. [Initial Setup](#6-initial-setup)
7. [Master Token Configuration](#7-master-token-configuration)
8. [Security Model](#8-security-model)
9. [Encryption Architecture](#9-encryption-architecture)
10. [Database Management](#10-database-management)
11. [Password Entry Creation](#11-password-entry-creation)
12. [Interactive Table Navigation](#12-interactive-table-navigation)
13. [Search Commands](#13-search-commands)
14. [Export Functionality](#14-export-functionality)
15. [Database Deletion](#15-database-deletion)
16. [Purge Functionality](#16-purge-functionality)
17. [Settings](#17-settings)
18. [Built-in Text Editor](#18-built-in-text-editor)
19. [Update System](#19-update-system)
20. [Installation Instructions](#20-installation-instructions)
21. [ISO Creation](#21-iso-creation)
22. [USB Installation](#22-usb-installation)
23. [Supported Boot Modes](#23-supported-boot-modes)
24. [Complete Command Reference](#24-complete-command-reference)
25. [Troubleshooting](#25-troubleshooting)
26. [Known Limitations](#26-known-limitations)
27. [Security Warnings](#27-security-warnings)
28. [Build Instructions](#28-build-instructions)
29. [Testing Instructions](#29-testing-instructions)
30. [Version History](#30-version-history)

---

## 1. Project Overview

PassOS is a dedicated password management operating system. It is a standalone OS, not an application that runs inside another operating system. When booted, PassOS takes full control of the hardware and provides a secure, minimal environment for storing, organizing, searching, and exporting passwords.

**Design priorities (in order):**

1. Security
2. Correctness
3. Stability
4. Performance
5. Visual presentation

**Core properties:**

- Written entirely in Assembly (x86-64 and ARM64).
- No networking. No internet connectivity. No external services.
- Single user account (`root`) in V1.0.
- All sensitive data is encrypted at rest using AES-256-GCM.
- Master token is never stored in plaintext; only its Argon2id-derived hash is persisted.
- No recovery mechanism. Losing the master token makes all stored data permanently inaccessible.

---

## 2. System Architecture

PassOS is organized into eight independent layers. Each layer is implemented in dedicated Assembly source files with clearly defined interfaces.

```
┌────────────────────────────────────────────────────────┐
│                    CLI / Terminal                       │
│         interface/terminal.asm, commands.asm           │
├────────────────────────────────────────────────────────┤
│                  Command Parser                         │
│           interface/command_parser.asm                 │
├──────────────────────────┬─────────────────────────────┤
│       Database Layer     │     Interface Layer         │
│   database/*.asm         │  table.asm, text_editor.asm │
├──────────────────────────┴─────────────────────────────┤
│                  Security Layer                         │
│   authentication, encryption, key_derivation,          │
│   secure_memory, integrity                             │
├────────────────────────────────────────────────────────┤
│                  Drivers Layer                          │
│   display, keyboard, storage, usb, hardware            │
├────────────────────────────────────────────────────────┤
│                  Kernel Core                            │
│   memory, interrupts, scheduler, system                │
├────────────────────────────────────────────────────────┤
│               Bootloader (BIOS / UEFI / ARM)           │
└────────────────────────────────────────────────────────┘
```

**Bootloader** initializes the CPU mode, sets up paging, and loads the kernel binary into memory.

**Kernel Core** initializes physical memory management, sets up the IDT, and starts the single cooperative scheduler.

**Drivers** abstract hardware: VGA text-mode display, PS/2 keyboard with USB compatibility layer, ATA PIO storage, USB mass storage enumeration, and CPUID-based hardware detection.

**Security Layer** handles all cryptographic operations. No other layer performs encryption directly.

**Database Layer** stores, retrieves, searches, exports, and destroys password records. It relies on the security layer for all encryption and the drivers layer for disk I/O.

**Interface Layer** renders the terminal prompt, the interactive ASCII table, the text editor, and the settings menu.

---

## 3. Supported CPU Architectures

| Architecture | Status | Notes |
|---|---|---|
| x86-64 (64-bit) | Supported | Primary target. Full feature set. |
| x86 (32-bit) | Planned | Requires separate 32-bit build path. |
| ARM64 (AArch64) | Supported | Boot via U-Boot. Raspberry Pi 3/4/5 compatible. |
| Apple Silicon (M-series) | Not supported | Excluded by design. |

x86-64 uses the System V AMD64 ABI calling convention internally for consistency. ARM64 uses the AAPCS64 convention.

---

## 4. Hardware Compatibility

### Input Devices

- PS/2 keyboards (direct port I/O at 0x60/0x64).
- USB keyboards via the PS/2 compatibility layer exposed by BIOS/UEFI.
- Keyboard layout is configurable in `/settings`. Supported layouts in V1.0: US, DE, GB.

### Display

- VGA text mode (80×25) on BIOS systems.
- UEFI GOP framebuffer on UEFI systems.
- Default: 80 columns × 25 rows.
- Default refresh rate: 60 Hz where configurable.

### Storage

- ATA PIO primary and secondary channels (0x1F0 / 0x170).
- USB mass storage for export and update operations.
- AHCI SATA support is a V1.1 target.

### Boot Firmware

- Legacy BIOS (MBR boot sector at 0x7C00).
- UEFI (PE64 EFI application).
- ARM: U-Boot with `kernel8.img` compatible flat binary.

### Minimum Specifications

| Resource | Minimum |
|---|---|
| RAM | 64 MB |
| Storage | 512 MB |
| CPU | x86-64 with SSE2, or ARMv8-A |
| Display | 80×25 text mode or VGA-compatible |

---

## 5. Boot Process

### BIOS Boot

1. BIOS loads the 512-byte MBR (`boot/bios/boot.asm`) at 0x7C00.
2. Stage 1 resets the disk, loads Stage 2 (32 sectors) to 0x1000:0x0000, and jumps to it.
3. Stage 2 (`boot/bios/stage2.asm`) enables A20, loads a GDT, enters protected mode, sets up a PML4 page table, enables long mode, and jumps to `kernel_main` at 0x100000.

### UEFI Boot

1. Firmware loads `uefi_loader.efi` from the EFI System Partition.
2. The loader locates `\PassOS\kernel.bin` via the EFI Simple File System protocol.
3. It maps the kernel into memory, exits boot services, and transfers control to `kernel_main`.

### ARM Boot

1. U-Boot or firmware loads `kernel_arm.bin` to 0x80000.
2. `_start` in `boot/arm/boot_arm.asm` descends from EL2 to EL1, zeros BSS, and jumps to `kernel_main`.

### Kernel Initialization Sequence

After the bootloader hands off control, `kernel_main` calls these subsystems in order:

```
memory_init       → physical page allocator
interrupts_init   → IDT, PIC remapping, keyboard IRQ
scheduler_init    → cooperative scheduler stub
system_init       → display, keyboard, storage, USB drivers
terminal_init     → clear screen, display welcome message
boot_screen_display → boot progress display
authentication_start → first-run setup or login prompt
terminal_run      → main command loop
```

### Boot Screen

```
================================
             PassOS
================================

Initializing bootloader ........ OK
Loading kernel ................. OK
Initializing memory ............ OK
Loading storage drivers ........ OK
Initializing encryption ........ OK
Loading password manager ....... OK
Initializing terminal .......... OK

System initialization complete.

PassOS is ready.
```

---

## 6. Initial Setup

On the very first boot, PassOS detects no master token hash on disk (sector 1 does not contain the `PASSOS10` magic header). It enters first-run setup automatically.

The setup flow:

1. Display the security warning and consequences of losing the master token.
2. Prompt `Continue? (YES/NO)`. Entering anything other than `YES` halts the system.
3. Prompt `Enter new master token:` — input is masked with `*`.
4. Prompt `Confirm master token:` — must match exactly.
5. If the token is fewer than 8 characters, reject and re-prompt.
6. If the two entries do not match, reject and re-prompt.
7. Generate a cryptographically random 16-byte salt.
8. Derive a 64-byte key bundle via Argon2id.
9. Store the salt and key bundle hash in sector 1 under the `PASSOS10` magic.
10. Zero all token buffers in RAM.
11. Proceed to the terminal.

---

## 7. Master Token Configuration

### Properties

- Minimum length: 8 characters.
- No maximum length (buffer limit: 255 characters).
- All printable ASCII characters are accepted.
- Input is always masked with `*` — the token is never displayed.
- The token is never written to disk in plaintext.
- There is no password reset, no recovery code, and no backdoor.

### Key Derivation

PassOS uses **Argon2id** (RFC 9106) with:

| Parameter | Value |
|---|---|
| Memory cost | 65536 KiB (64 MB) |
| Time cost (iterations) | 3 |
| Parallelism | 4 |
| Output length | 64 bytes |
| Salt length | 16 bytes |

The 64-byte output is split into two 32-byte keys:

- `K_db`: the root database encryption key.
- `K_auth`: the authentication verification key (its hash is stored on disk).

### Sector Layout

| Sector | Contents |
|---|---|
| 0 | MBR / boot sector |
| 1 | Authentication record (`PASSOS10` + salt + Argon2id hash) |
| 2 | Database index (`PWDB0001` + up to 32 database entries) |
| 3 | Settings (`PWCFG001` + settings bytes) |
| 4–63 | Reserved for future system use |
| 64–end | Database data sectors |

---

## 8. Security Model

### Threat Model

PassOS protects against:

- Physical theft of the storage device.
- Unauthorized access while the device is powered off.
- Brute-force attacks against the master token (Argon2id memory-hardness).
- Silent plaintext storage.
- Accidental exposure of passwords during search operations.

PassOS does **not** protect against:

- Physical attacks while the system is running and unlocked.
- Evil-maid attacks that modify the bootloader before first use (addressed by Secure Boot for UEFI systems with a signed boot chain).
- Side-channel attacks at the hardware level.
- An attacker who already knows the master token.

### Security Properties

| Property | Implementation |
|---|---|
| Token never stored in plaintext | Argon2id hash only |
| Passwords never stored in plaintext | AES-256-GCM encrypted at entry creation |
| Encryption keys never in plaintext | Derived from master key; zeroed after use |
| Sensitive RAM cleared after use | `secure_zero` with `mfence` barrier |
| Secure random numbers | `RDRAND` instruction when available; LFSR fallback |
| Brute-force resistance | Argon2id 64 MB memory cost |
| Authenticated encryption | AES-256-GCM (provides confidentiality + integrity) |
| No network attack surface | Zero network drivers or services |

---

## 9. Encryption Architecture

### Algorithms

| Use | Algorithm |
|---|---|
| Key derivation | Argon2id (RFC 9106) |
| Primary encryption | AES-256-GCM |
| Individual entry key | AES-256-GCM with a separate nonce |
| Update signature verification | HMAC-SHA256 |
| System file integrity | SHA-256 |
| Secure random generation | RDRAND / LFSR fallback |

### Key Hierarchy

```
Master Token (user input)
        │
        ▼
    Argon2id (salt, 64 MB, 3 iter, p=4)
        │
        ▼
   64-byte Key Bundle
    ├── K_auth (32 bytes) — stored hash used for login verification
    └── K_db   (32 bytes) — root database encryption key
                │
                ▼
        Per-database key (derived from K_db + database name)
                │
                ▼
        Per-entry key (derived from per-database key + entry ID)
                │
                ▼
        AES-256-GCM encryption of individual password field
```

### Nonce Policy

Each encryption operation generates a fresh 12-byte random nonce via `RDRAND`. The nonce is stored alongside the ciphertext. Nonces are never reused.

### Hardware Acceleration

AES-NI is detected at boot via `CPUID`. If AES-NI is available (reported in `hw_flags`), the encryption module uses AES-NI instructions (`AESENC`, `AESENCLAST`, `AESKEYGENASSIST`). If not, a software AES implementation is used transparently.

---

## 10. Database Management

A database is a named collection of password entries stored in contiguous sectors on disk. Each database occupies 256 sectors (128 KB) of storage and can hold up to 512 entries.

Up to 32 databases can exist simultaneously.

### Database Index (Sector 2)

```
Offset  Size  Field
0       8     Magic: "PWDB0001"
8       4     Database count (uint32)
12      48×N  Per-database entries (max 32):
                0-31:  Name (UTF-8, null-padded)
                32-35: Start sector (uint32)
                36-39: Sector count (uint32)
                40-47: Entry count (uint64)
```

### /create_database("NAME")

**Syntax:** `/create_database("NAME")`

**Description:** Creates a new encrypted password database.

**Example:**
```
/create_database("Personal")
```

**Expected output:**
```
Database "Personal" created successfully.
Encryption initialized.
```

**Validation:**
- Name must not be empty.
- Name must not exceed 31 characters.
- Name must not contain: `/`, `\`, `:`, `*`, `?`, `"`, `<`, `>`, `|`, or control characters.
- A database with the same name must not already exist.
- Maximum 32 databases total.

**Error messages:**
- `Error: Database name cannot be empty.`
- `Error: Database name too long (max 31 characters).`
- `Error: A database with that name already exists.`
- `Error: Maximum number of databases reached (32).`
- `Error: Database name contains invalid characters.`

**Required permissions:** Must be authenticated (master token verified at login).

---

## 11. Password Entry Creation

### Entry Fields

Each password entry contains four fields:

| Field | Max Length | Stored As |
|---|---|---|
| Name | 63 bytes | Plaintext (name only, no credentials) |
| ID | 7 bytes | Auto-generated, plaintext |
| Password | 127 bytes | AES-256-GCM encrypted |
| Individual Encryption Key | 63 bytes | AES-256-GCM encrypted |

### Creating an Entry

1. Enter the target database with `/enter_database("NAME")`.
2. In the table view, press `N` to open the new entry form.
3. Fill in the Name field and press Enter.
4. Enter the Password (masked with `*`) and press Enter.
5. Enter the Individual Encryption Key (optional prompt), masked.
6. The entry is encrypted and written to disk immediately.

The Individual Encryption Key is an additional layer of protection. If set, displaying the password later requires both the master token (via session authentication) and this individual key.

### ID Generation

IDs are generated as sequential integers padded to 3 digits (e.g., `001`, `002`). IDs are unique within a database. Deleted entry IDs are not reused in V1.0.

---

## 12. Interactive Table Navigation

When a database is opened with `/enter_database`, PassOS displays an interactive ASCII table:

```
+----------------+----------+----------------------+----------------+
| Name           | ID       | Password             | Encryption Key |
+----------------+----------+----------------------+----------------+
| GitHub         | 001      | ********             | ********       |
| Email          | 002      | ********             | ********       |
| Server Login   | 003      | ********             | ********       |
+----------------+----------+----------------------+----------------+

[Arrows] Navigate  [Enter] Select/Reveal  [N] New entry  [D] Delete  [Esc] Exit
```

### Controls

| Key | Action |
|---|---|
| Arrow Up | Move selection up one row |
| Arrow Down | Move selection down one row |
| Arrow Left | Move selection to previous column |
| Arrow Right | Move selection to next column |
| Tab | Move to next column (wraps) |
| Shift+Tab | Move to previous column |
| Enter | Select current cell (reveal password or key) |
| N | Create new entry |
| D | Delete selected entry (prompts confirmation) |
| Escape | Exit table, return to terminal |

### Revealing a Password

1. Navigate to the Password column of the desired row.
2. Press Enter.
3. PassOS prompts for the Individual Encryption Key if one was set.
4. After successful decryption, the password is displayed once in the terminal.
5. The display is cleared when you navigate away or press Escape.
6. Passwords are never automatically revealed.

---

## 13. Search Commands

### /searchall_databases("Name=TERM")

**Syntax:** `/searchall_databases("Name=TERM")`

**Description:** Searches all databases for entries whose Name field contains TERM (case-insensitive substring match). Passwords are never displayed in results.

**Example:**
```
/searchall_databases("Name=GitHub")
```

**Expected output:**
```
--- Search Results ---
  Database: Personal
  Entry:    GitHub
```

**Error messages:**
- `Error: No databases exist.`

---

### /search_database("DB=TERM")

**Syntax:** `/search_database("DB=TERM")`

**Description:** Searches only the specified database for entries matching TERM.

**Example:**
```
/search_database("Personal=GitHub")
```

**Expected output:**
```
--- Search Results ---
  Entry:    GitHub
```

**Error messages:**
- `Error: Database not found.`
- `No matching entries found.`

**Notes:**
- Both search commands support Unicode and special characters in TERM.
- The search never decrypts or displays password data.

---

## 14. Export Functionality

Export writes database contents to an external USB storage device. Two export formats are available:

| Format | Description |
|---|---|
| Encrypted (default) | AES-256-GCM encrypted `.export` file |
| Plaintext | `NAME:ID:PASSWORD` per line (requires explicit confirmation) |

### Export Folder Structure

```
USB_DEVICE/
└── Database/
    ├── Personal.export
    ├── Work.export
    └── export_manifest
```

### /export_database("NAME")

**Syntax:** `/export_database("NAME")`

**Description:** Exports one database to the connected USB device.

**Example:**
```
/export_database("Personal")
```

**Process:**
1. Detect connected USB devices.
2. Prompt export type: `PLAIN` or `ENC`.
3. If PLAIN is selected, display a security warning.
4. Prompt master token for authentication.
5. Write the export to `USB_DEVICE/Database/NAME.export`.

**Error messages:**
- `Error: No external USB device detected.`
- `Error: Database not found.`
- `Authentication failed. Export aborted.`

---

### /export_database=all

**Syntax:** `/export_database=all`

**Description:** Exports all databases to USB using the same authentication and format selection flow.

---

### Plaintext Export Format

```
GitHub:001:ExamplePassword123
Email:002:AnotherPassword456
Server:003:ServerPassword789
```

Plaintext exports are highly sensitive. PassOS requires explicit confirmation before writing a plaintext export. The recommended export format is encrypted.

---

## 15. Database Deletion

### /delete_database("NAME")

**Syntax:** `/delete_database("NAME")`

**Description:** Permanently deletes a database and invalidates its encryption keys.

**Example:**
```
/delete_database("Personal")
```

**Three-stage confirmation process:**

**Stage 1:**
```
WARNING:
You are about to delete database "Personal".

Continue? (YES/NO):
```

**Stage 2:**
```
SECOND CONFIRMATION

All entries in this database will become
permanently inaccessible.

Confirm deletion? (YES/NO):
```

**Stage 3:**
```
MASTER TOKEN REQUIRED

Enter your master token to authorize deletion:
```

Only after all three stages are successfully completed does deletion proceed.

**What deletion does:**
- Removes the database from the index.
- Overwrites the database's data sectors with zeros.
- Invalidates derived encryption keys for that database.

**Error messages:**
- `Error: Database not found.`
- `Deletion aborted.` (if any confirmation stage is declined)
- `Authentication failed. Deletion aborted.`

---

## 16. Purge Functionality

### /purge

**Syntax:** `/purge`

**Description:** Permanently destroys all password databases and their encryption keys.

```
CRITICAL SYSTEM OPERATION

PURGE WILL DESTROY ALL DATABASES.

This operation cannot be reversed.

All stored password records and associated
encryption keys will be invalidated.

Enter your master token to continue:
```

After token authentication, PassOS additionally requires the user to type `CONFIRM` (exactly, in uppercase).

**What purge does:**
- Removes all entries from the database index.
- Overwrites data sectors for all databases.
- Clears derived encryption keys from RAM.
- Flushes all disk write operations.
- Verifies no accessible database records remain.

**What purge does not do:**
- Delete the operating system itself.
- Guarantee physical erasure of data on flash storage (due to wear-leveling by the storage controller). For flash drives and SSDs, cryptographic erasure (key destruction) is the operative protection mechanism.

**Error messages:**
- `Authentication failed. Purge aborted.`
- `Purge aborted.` (if CONFIRM is not entered)

---

## 17. Settings

### /settings

**Syntax:** `/settings`

**Description:** Opens the system settings interface.

Navigate with Arrow Up/Arrow Down. Press Enter to change a value. Press Escape to save and exit.

### Available Settings

| Setting | Options | Default |
|---|---|---|
| Display Refresh Rate | 60 Hz, 75 Hz | 60 Hz |
| Keyboard Layout | US, DE, GB | US |
| Password Display Timeout | 10–300 seconds | 30 s |
| Clear Screen on DB Exit | ON, OFF | ON |

Settings are persisted to sector 3 under the `PWCFG001` magic header. Settings are loaded at every boot before the login prompt.

Hardware-dependent settings (refresh rate, resolution) are only shown when the hardware reports support for them.

---

## 18. Built-in Text Editor

PassOS includes a lightweight terminal text editor accessible via:

```
/edit
/edit "filename"
```

The editor uses a **gap buffer** internally for efficient line editing with constant-time character insertion and deletion at the cursor position.

### Features

| Feature | Status |
|---|---|
| Create new files | Supported |
| Open existing files | Supported |
| Edit text | Supported |
| Backspace / Delete | Supported |
| Arrow key navigation | Supported |
| Enter (new line) | Supported |
| Tab (4 spaces) | Supported |
| Save (Ctrl+S) | Supported |
| Save As (Ctrl+A) | Supported |
| Quit (Ctrl+Q) | Supported (prompts if modified) |
| Keyboard shortcuts display | Status bar |

### Keyboard Shortcuts

| Shortcut | Action |
|---|---|
| Ctrl+S | Save current file |
| Ctrl+A | Save As (rename) |
| Ctrl+Q | Quit (prompts if unsaved changes exist) |
| Arrow keys | Move cursor |
| Backspace | Delete character before cursor |
| Delete | Delete character at cursor |
| Enter | Insert newline |
| Tab | Insert 4 spaces |

### Security Warning

The editor displays a warning if you attempt to save a file with common sensitive name patterns. Plaintext files are not encrypted. Do not store passwords or keys in unencrypted text files.

---

## 19. Update System

### /update

**Syntax:** `/update`

**Description:** Installs a PassOS system update from a USB device.

**Update package format:**

```
update.pkg
├── Header:   "PASSUPD1" + version (4 bytes) + HMAC-SHA256 signature (64 bytes)
├── Manifest: sector addresses and lengths to write
└── Payload:  replacement binary sector data
```

**Update process:**

1. Detect connected USB device.
2. Locate `update.pkg` on the device.
3. Verify the HMAC-SHA256 signature against the embedded public key.
4. Check database format compatibility.
5. Prompt master token authentication.
6. Prompt final confirmation.
7. Back up critical sectors (0–63) to a reserved area.
8. Write new kernel and system sectors from the payload.
9. Confirm integrity of written data.

**Safety guarantees:**
- Database sectors (64+) are never modified by the update process.
- A failed update can be rolled back from the sector backup.
- Database format is versioned; updates include migration scripts when the format changes.
- Updates without a valid signature are rejected unconditionally.

**Error messages:**
- `Error: No USB device detected.`
- `Error: Update package not found on USB.`
- `Error: Update signature verification failed.`
- `Authentication failed. Update aborted.`
- `Update aborted.`

---

## 20. Installation Instructions

### /install

**Syntax:** `/install`

**Description:** Installs PassOS permanently to a selected drive.

**Supported installation targets:**
- Internal HDD (ATA/SATA)
- Internal SSD (ATA/SATA)
- External USB drives
- Compatible servers (with ATA-compatible storage)
- Raspberry Pi (ARM64 target, via U-Boot compatible SD card)

**Installation process:**

1. Detect available drives.
2. Display drive list with size and type information.
3. User selects target drive.
4. First confirmation: `Confirm format and install? (YES/NO)`
5. Second confirmation: `Are you absolutely sure? This cannot be undone. (YES/NO)`
6. Master token authentication.
7. Write MBR / UEFI bootloader to target drive.
8. Write kernel binary.
9. Initialize authentication, database index, and settings sectors.
10. Report completion.

**Warning:** Installation overwrites the entire target drive. All existing data is permanently lost.

---

## 21. ISO Creation

After building the kernel, run:

```bash
bash scripts/makeiso.sh
```

This produces `build/passos.iso`, a bootable ISO 9660 image with:
- BIOS boot support (El Torito, non-emulated).
- GRUB2 chainloader for UEFI systems.
- Kernel binary at `/boot/kernel.bin`.

The ISO is compatible with:
- **Balena Etcher** — open the ISO and select target USB drive.
- **Rufus** — select ISO file, partition scheme MBR for BIOS or GPT for UEFI, DD mode.
- **Ventoy** — copy ISO to Ventoy USB (test for BIOS; UEFI compatibility depends on Ventoy version).
- **dd** — `sudo dd if=build/passos.iso of=/dev/sdX bs=4M status=progress && sync`

Secure Boot compatibility requires the UEFI loader and kernel to be signed with a key enrolled in the firmware's MOK database. Pre-signed binaries are distributed separately for Secure Boot environments.

---

## 22. USB Installation

PassOS can run entirely from a USB drive, with persistent encrypted database storage.

**Requirements:**
- USB drive, minimum 512 MB.
- The USB drive contains the complete PassOS installation.
- Password databases survive reboots and power cycles.
- Removing the USB drive does not affect the original operating system on the host machine.

**USB boot:**
1. Flash the ISO or run `/install` targeting the USB drive.
2. Set the firmware boot order to prioritize the USB drive.
3. Boot PassOS from USB.
4. On first boot, complete master token setup.
5. All database writes go to the USB drive's PassOS partition.

**Persistence:** The database index (sector 2) and data sectors (64+) are part of the PassOS partition on the USB drive. They persist across reboots automatically.

---

## 23. Supported Boot Modes

| Mode | Status | Notes |
|---|---|---|
| Legacy BIOS (MBR) | Supported | Stage 1 at 0x7C00, Stage 2 loads kernel |
| UEFI (64-bit) | Supported | PE64 EFI application |
| UEFI Secure Boot | Supported with signing | Requires signed EFI binary |
| ARM U-Boot | Supported | Load address 0x80000 |
| Raspberry Pi firmware | Supported | `kernel8.img` compatible |
| GRUB2 chainload | Supported | Via ISO configuration |

---

## 24. Complete Command Reference

### /help

**Syntax:** `/help`
**Description:** Displays all available commands with syntax and short descriptions.
**Example:** `/help`
**Required permissions:** None (any authenticated session).
**Possible errors:** None.

---

### /create_database("NAME")

**Syntax:** `/create_database("NAME")`
**Description:** Creates a new encrypted password database named NAME.
**Example:** `/create_database("Work")`
**Expected behavior:** Validates name, checks for duplicates, allocates disk sectors, initializes encryption, updates the database index.
**Required permissions:** Authenticated session.
**Errors:** Empty name, name too long, duplicate name, max databases reached, invalid characters.

---

### /enter_database("NAME")

**Syntax:** `/enter_database("NAME")`
**Description:** Opens the named database and launches the interactive table view.
**Example:** `/enter_database("Work")`
**Expected behavior:** Loads the database index entry, renders the table, and enters the keyboard navigation loop.
**Required permissions:** Authenticated session.
**Errors:** `Error: Database not found.`

---

### /searchall_databases("Name=TERM")

**Syntax:** `/searchall_databases("Name=TERM")`
**Description:** Searches all databases for entries whose Name field contains TERM (case-insensitive).
**Example:** `/searchall_databases("Name=github")`
**Expected behavior:** Iterates all databases, compares entry names, prints matches with database names. No passwords are shown.
**Required permissions:** Authenticated session.
**Errors:** `Error: No databases exist.`

---

### /search_database("DB=TERM")

**Syntax:** `/search_database("DB=TERM")`
**Description:** Searches the database named DB for entries matching TERM.
**Example:** `/search_database("Work=server")`
**Expected behavior:** Scans entry names in DB, prints matches.
**Required permissions:** Authenticated session.
**Errors:** `Error: Database not found.`, `No matching entries found.`

---

### /settings

**Syntax:** `/settings`
**Description:** Opens the system settings panel.
**Example:** `/settings`
**Expected behavior:** Renders the settings menu, accepts navigation input, saves on Escape.
**Required permissions:** Authenticated session.
**Errors:** None.

---

### /clear

**Syntax:** `/clear`
**Description:** Clears the terminal screen.
**Example:** `/clear`
**Required permissions:** Authenticated session.
**Errors:** None.

---

### /cls

**Syntax:** `/cls`
**Description:** Alias for `/clear`.
**Example:** `/cls`
**Required permissions:** Authenticated session.
**Errors:** None.

---

### /changelogs

**Syntax:** `/changelogs`
**Description:** Displays the installed PassOS version and all available release notes.
**Example:** `/changelogs`
**Required permissions:** Authenticated session.
**Errors:** None.

---

### /delete_database("NAME")

**Syntax:** `/delete_database("NAME")`
**Description:** Permanently deletes the named database after three-stage confirmation.
**Example:** `/delete_database("Work")`
**Expected behavior:** Three confirmation stages (YES/NO, YES/NO, master token). On success, database sectors are overwritten and the index entry is removed.
**Required permissions:** Authenticated session + master token re-entry.
**Errors:** `Error: Database not found.`, `Authentication failed.`, `Deletion aborted.`

---

### /export_database("NAME")

**Syntax:** `/export_database("NAME")`
**Description:** Exports a single database to an external USB device in encrypted or plaintext format.
**Example:** `/export_database("Personal")`
**Expected behavior:** Detects USB device, prompts format (PLAIN/ENC), authenticates with master token, writes export file to `USB/Database/NAME.export`.
**Required permissions:** Authenticated session + master token.
**Errors:** `Error: No external USB device detected.`, `Error: Database not found.`, `Authentication failed.`, `Export aborted.`

---

### /export_database=all

**Syntax:** `/export_database=all`
**Description:** Exports all databases to USB.
**Example:** `/export_database=all`
**Expected behavior:** Same as single export, repeated for every database.
**Required permissions:** Authenticated session + master token.
**Errors:** `Error: No databases to export.`, `Error: No external USB device detected.`

---

### /purge

**Syntax:** `/purge`
**Description:** Permanently destroys all password databases and encryption keys.
**Example:** `/purge`
**Expected behavior:** Authenticates with master token, requires `CONFIRM` input, overwrites all database sectors, invalidates keys, clears sensitive RAM.
**Required permissions:** Authenticated session + master token.
**Errors:** `Authentication failed. Purge aborted.`, `Purge aborted.`

---

### /update

**Syntax:** `/update`
**Description:** Installs a PassOS system update from USB.
**Example:** `/update`
**Expected behavior:** Locates update package on USB, verifies signature, checks compatibility, authenticates, backs up sectors, installs update.
**Required permissions:** Authenticated session + master token.
**Errors:** Various (see Section 19).

---

### /install

**Syntax:** `/install`
**Description:** Installs PassOS to a selected storage device.
**Example:** `/install`
**Expected behavior:** Lists drives, prompts target selection, double confirmation, token auth, writes bootloader and kernel.
**Required permissions:** Authenticated session + master token.
**Errors:** `Error: No suitable drives detected.`, `Authentication failed.`, `Installation aborted.`

---

### /exit

**Syntax:** `/exit`
**Description:** Shuts down PassOS safely.
**Example:** `/exit`
**Expected behavior:** Flushes pending disk writes, clears sensitive RAM buffers, clears the terminal, halts the CPU.
**Required permissions:** Authenticated session.
**Errors:** None.

---

## 25. Troubleshooting

### System does not boot from USB

- Verify the USB was flashed correctly (use Rufus in DD mode, not ISO mode).
- Check BIOS/UEFI boot order and ensure USB boot is enabled.
- Try a different USB port (prefer USB 2.0 if available).
- For UEFI systems, disable Secure Boot temporarily if the EFI binary is not signed.

### "DISK ERROR. Halting." at stage 1

- The stage-2 bootloader sectors may not have been written correctly.
- Re-flash the drive.
- Verify the drive is not write-protected.

### Authentication always fails

- Ensure Caps Lock is off. Token input is case-sensitive.
- If this is a first boot and the sector was previously written, the storage may be corrupt. Run `/install` again to reinitialize.

### Display shows garbage characters

- The terminal requires 80×25 VGA text mode. Some UEFI systems disable legacy VGA; in this case use the UEFI boot path.

### Keyboard input not responding

- Ensure the keyboard is connected before boot.
- PS/2 keyboards are preferred for maximum compatibility.
- USB keyboards require the BIOS/UEFI USB legacy input emulation to be enabled.

### Export does not find USB device

- USB mass storage enumeration requires a USB controller detected on the PCI bus.
- Only one USB mass storage device at a time is supported in V1.0.
- Insert the USB device before running the export command.

### Update signature verification fails

- Do not use unofficial update packages.
- Verify the update package is not corrupted (compare SHA-256 checksum with the official release hash).

---

## 26. Known Limitations

| Limitation | Notes |
|---|---|
| Single user account | V1.0 supports only `root`. Multi-user support is planned for V1.1. |
| Username not changeable | Username is fixed as `root` in V1.0. |
| No master token reset | By design. No recovery mechanism exists. |
| ATA PIO only | No AHCI/NVMe support in V1.0. |
| USB 1.1/2.0 via PS/2 emulation | Full xHCI stack planned for V1.2. |
| No display resolution selection | VGA text mode 80×25 is fixed in V1.0. |
| Flash storage: physical erasure | Due to flash wear-leveling, overwritten sectors may be retained. Cryptographic erasure (key destruction) is the primary protection. |
| GRUB2 chainloading | GRUB2 integration requires ISO boot; direct multiboot2 loading may require firmware tuning. |
| Apple Silicon: not supported | No plans to support M-series processors. |
| Soft AES performance | On hardware without AES-NI, encryption throughput is reduced. |
| ARM: limited hardware testing | ARM64 code is written to the AArch64 specification; validation on physical hardware is the builder's responsibility. |

---

## 27. Security Warnings

**WARNING 1: LOST MASTER TOKEN**
Your master token is the only key to your encrypted vault. If you forget or lose it, all stored passwords are permanently inaccessible. There is no reset, no recovery code, and no backdoor. Write your master token down and store it in a physically secure location.

**WARNING 2: PLAINTEXT EXPORT**
Plaintext exports write your passwords to an unencrypted file on a USB drive. Anyone with physical access to that drive can read all your passwords. Use encrypted exports by default. Destroy plaintext export files when no longer needed.

**WARNING 3: PHYSICAL SECURITY**
PassOS protects data at rest. Once the system is unlocked (master token entered), the data in RAM may be accessible to a physical attacker. Lock the system by removing power or running `/exit` when not in use.

**WARNING 4: UNVERIFIED HARDWARE**
PassOS has been designed and tested in emulated environments (QEMU). Physical hardware behavior, particularly around USB enumeration, ATA PIO timing, and UEFI firmware compliance, may differ. Test thoroughly before relying on PassOS for production use.

**WARNING 5: PURGE AND FLASH STORAGE**
On flash drives and SSDs, the storage controller's wear-leveling may retain overwritten sectors. PassOS's purge operation destroys encryption keys (cryptographic erasure), which is the operative protection mechanism. Physical overwriting is not guaranteed on flash storage.

**WARNING 6: UPDATE PACKAGES**
Only install update packages from trusted sources. PassOS verifies HMAC-SHA256 signatures before installing. A corrupted or malicious update package that passes signature verification could compromise system integrity.

---

## 28. Build Instructions

### Prerequisites

Install the following tools:

```bash
# Debian/Ubuntu
sudo apt install nasm binutils xorriso mtools

# Fedora/RHEL
sudo dnf install nasm binutils xorriso mtools

# Arch Linux
sudo pacman -S nasm binutils xorriso mtools

# ARM cross-toolchain (for ARM64 build)
sudo apt install gcc-aarch64-linux-gnu binutils-aarch64-linux-gnu
```

### x86-64 Build

```bash
cd PassOS
bash scripts/build.sh x86_64
```

This produces:
- `build/boot.bin` — 512-byte BIOS stage 1
- `build/obj/*.o` — assembled object files
- `build/kernel.elf` — linked ELF kernel
- `build/kernel.bin` — flat binary kernel

### ISO Build

```bash
bash scripts/makeiso.sh
```

Produces `build/passos.iso`.

### ARM64 Build

```bash
bash scripts/build_arm.sh
```

Produces `build/arm/kernel_arm.bin`. Copy to SD card as `kernel8.img` for Raspberry Pi.

### Using Make

```bash
make           # x86_64 + ISO
make arm64     # ARM64 kernel
make clean     # remove build output
```

### Verifying the Build

```bash
# Check kernel size
ls -lh build/kernel.bin

# Inspect symbol table
objdump -t build/kernel.elf | grep kernel_main

# Check ELF entry point
readelf -h build/kernel.elf | grep Entry
```

---

## 29. Testing Instructions

### QEMU Testing (x86-64)

```bash
# Boot from ISO
qemu-system-x86_64 -cdrom build/passos.iso -m 256M

# With serial output
qemu-system-x86_64 -cdrom build/passos.iso -m 256M -serial stdio

# With a virtual disk
qemu-system-x86_64 \
    -cdrom build/passos.iso \
    -drive file=passos_test.img,format=raw,if=ide \
    -m 256M

# Create a blank test disk image
qemu-img create -f raw passos_test.img 1G
```

### QEMU Testing (ARM64)

```bash
qemu-system-aarch64 \
    -machine raspi3b \
    -kernel build/arm/kernel_arm.bin \
    -m 1G \
    -serial stdio
```

### Functional Test Checklist

Run through these test scenarios after every build:

**Boot and Authentication:**
- [ ] System boots to boot screen on fresh disk image.
- [ ] First-run setup launches when no token exists.
- [ ] Token shorter than 8 characters is rejected.
- [ ] Mismatched token confirmation is rejected.
- [ ] Login succeeds with correct token.
- [ ] Login fails with incorrect token (verify 3 attempts cycle without lockout in V1.0).

**Database Operations:**
- [ ] `/create_database("Test")` creates a database.
- [ ] `/create_database("Test")` fails on duplicate.
- [ ] `/enter_database("Test")` opens the table view.
- [ ] New entry can be added with N key.
- [ ] Password field is masked during entry.
- [ ] Entry is persisted after `/exit` and reboot.
- [ ] `/delete_database("Test")` requires all three confirmation stages.
- [ ] Deletion fails if master token is wrong at stage 3.

**Search:**
- [ ] `/searchall_databases("Name=Test")` finds entries across databases.
- [ ] `/search_database("Test=entry")` finds entries in one database.
- [ ] Search with no results prints `No matching entries found.`
- [ ] Search with special characters and Unicode does not crash.

**Export:**
- [ ] Export aborts without USB device.
- [ ] Plaintext export requires explicit format selection.
- [ ] Encrypted export produces a non-zero file.
- [ ] Export aborts with wrong master token.

**Security:**
- [ ] Master token buffer is zeroed after successful authentication.
- [ ] Password buffers are zeroed after display.
- [ ] `/purge` requires master token AND `CONFIRM` text.
- [ ] System is fully halted by `/exit`.

**Edge Cases:**
- [ ] Empty command input (just Enter) does not crash.
- [ ] Unknown command prints help suggestion.
- [ ] Very long input (512+ characters) does not overflow.
- [ ] Special characters in database names are handled correctly.
- [ ] Interrupted write (power-off simulation) does not corrupt index.

---

## 30. Version History

### V1.0 (Current)

- Initial release.
- Complete password management OS written entirely in Assembly.
- Argon2id master token key derivation.
- AES-256-GCM authenticated encryption for all password data.
- Interactive ASCII table with keyboard navigation.
- Full CRUD operations on password entries.
- Global and per-database search.
- USB export in encrypted and plaintext formats.
- Three-stage database deletion.
- Cryptographic purge operation.
- Built-in gap-buffer text editor.
- System settings with persistence.
- Update system with signature verification.
- Drive installer.
- BIOS (stage 1 + stage 2) and UEFI bootloaders.
- ARM64 (AArch64) boot entry for Raspberry Pi compatibility.
- Bootable ISO compatible with Rufus, Balena Etcher, and dd.

### V1.1 (Planned)

- Multiple user accounts.
- Per-user database permissions.
- Account creation and management commands.
- Individual user authentication.

### V1.2 (Planned)

- Full xHCI USB stack.
- AHCI/SATA storage driver.
- Expanded keyboard layout support.
- Database migration tooling.

---

*End of Document — PassOS V1.0*
