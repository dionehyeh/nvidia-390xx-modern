<div align="center">

# 🚀 NVIDIA 390.157 Legacy Driver for Modern Linux Kernels
### Complete Compatibility Patch & Automation for Linux 6.x & 7.2.xx+

[![Kernel Support](https://img.shields.io/badge/Kernel-Linux%206.x%20%7C%207.0%20%7C%207.2%2B-green?style=for-the-badge&logo=linux)](https://kernel.org)
[![Driver Version](https://img.shields.io/badge/Driver-NVIDIA%20390.157-76B900?style=for-the-badge&logo=nvidia)](https://www.nvidia.com)
[![Target GPU](https://img.shields.io/badge/Target%20GPU-GeForce%20GT%20730-blue?style=for-the-badge)](https://www.nvidia.com)
[![License](https://img.shields.io/badge/License-MIT-orange?style=for-the-badge)](LICENSE)

*A production-ready patch set and automated installer allowing legacy NVIDIA cards (GeForce GT 730, Fermi, and Kepler) to run smoothly on modern Linux distributions (Fedora, Debian, Ubuntu, Arch Linux, CachyOS).*

</div>

---

## 📑 Table of Contents
- [1. Overview & Hardware Support](#1-overview--hardware-support)
- [2. Why This Patch Is Required](#2-why-this-patch-is-required)
- [3. Repository Structure](#3-repository-structure)
- [4. Prerequisites](#4-prerequisites)
- [5. Installation Guide](#5-installation-guide)
  - [Fedora Linux (Automated & Manual)](#fedora-linux)
  - [Debian / Ubuntu / Linux Mint](#debian--ubuntu--linux-mint)
  - [Arch Linux / CachyOS / Manjaro](#arch-linux--cachyos--manjaro)
- [6. Critical Notes: Wayland vs. X11](#6-critical-notes-wayland-vs-x11)
- [7. Automatic Kernel Updates (DKMS)](#7-automatic-kernel-updates-dkms)
- [8. Verifying Your Installation](#8-verifying-your-installation)
- [9. How to Re-pack from Scratch](#9-how-to-re-pack-from-scratch)
- [10. Troubleshooting & FAQ](#10-troubleshooting--faq)
- [11. Pushing to GitHub](#11-pushing-to-github)

---

## 1. Overview & Hardware Support

The **Zebronics GeForce GT 730 4GB (`ZEB-GT730-4GD3`)** and equivalent GT 730 variants (both Fermi `GF108` and Kepler `GK208`) are officially supported up to **Windows driver 391.35**. On Linux, the corresponding official legacy branch is **NVIDIA 390.xx** (specifically `390.157`).

### 🔍 Hardware Compatibility Matrix
| Property | Specification |
| :--- | :--- |
| **GPU Model** | Zebronics GT730 (`ZEB-GT730-4GD3`) / Generic GT 730 |
| **Architecture** | Fermi (GF108/GF119) / Kepler (GK208) |
| **Memory** | 4GB GDDR3 / DDR3, 64-bit bus, 1333 MHz |
| **Interface** | PCI Express 2.0 x8 |
| **Outputs** | HDMI, DVI-D, VGA |
| **Max Resolution** | 4096 x 2160 @ 24Hz / 2560 x 1600 @ 60Hz |
| **DirectX / OpenGL** | DirectX 12 (FL 11_0) / OpenGL 4.4 |
| **Windows Driver** | 391.35 (Final legacy release) |
| **Linux Driver** | **390.157** (Patched with this repository) |

---

## 2. Why This Patch Is Required

NVIDIA ceased mainline maintenance of the 390.xx branch around Linux kernel 5.15. Attempting to install vanilla `NVIDIA-Linux-x86_64-390.157.run` on any recent Linux distribution (such as Fedora 40/41/42, Arch Linux, Ubuntu 24.04+, or Debian 13) causes catastrophic compiler and linker failures due to:

- **Kernel Memory Subsystem Changes:** Removals and renames of `follow_pfn()`, `remap_pfn_range()`, `vm_flags_set()`, and page table mappings.
- **DRM API Overhauls:** Reworked DRM helper structures, `drm_gem_object`, `drm_atomic`, and DMA fence handling.
- **Modern Compiler Restrictions:** GCC 14, 15, and 16 default to strict pointer checking (`-Werror=incompatible-pointer-types`), rejecting legacy conftest checks.
- **Objtool & BTF Generation:** Modern kernels enforce strict object tool validation and Type Information (BTF) generation.

### 🛠️ What This Repository Fixes
This repository incorporates the full community patch stack up through **Linux 7.2.xx**, adapting every affected module:
- `nvidia.ko` (Core proprietary frontend)
- `nvidia-modeset.ko` (Kernel display mode setting)
- `nvidia-uvm.ko` (Unified Virtual Memory)
- `nvidia-drm.ko` (Direct Rendering Manager interface)

> [!NOTE]
> All kernel modules in this project have been **compiled, linked, and BTF-verified against Linux kernel 7.2.9**.

---

## 3. Repository Structure

```
.
├── configs/                                 # System configurations
│   ├── blacklist-nouveau.conf               # Modprobe configuration to disable nouveau
│   ├── nvidia-drm-outputclass.conf          # Xorg OutputClass configuration
│   ├── nvidia-390xx.rules                   # Udev permissions rule for device nodes
│   ├── systemd-homed-override.conf          # Systemd homed compatibility
│   └── systemd-suspend-override.conf        # Systemd sleep/suspend stability
├── dkms-source/                             # Pre-configured DKMS source tree (/usr/src/nvidia-390.157)
│   ├── dkms.conf                            # Configured for modern kernels
│   └── ...                                  # Patched kernel driver source files
├── patches/                                 # Complete kernel compatibility patch suite
│   ├── gcc-14.patch                         # Fixes strict GCC 14 type failures
│   ├── gcc-15.patch                         # Fixes strict GCC 15/16 type failures
│   ├── kernel-4.16+-memory-encryption.patch
│   ├── kernel-6.2.patch ... kernel-6.19.patch
│   ├── kernel-7.0.patch                     # Linux 7.0 DMA fence & interface fixes
│   └── kernel-7.2.patch                     # Linux 7.2 DRM CRTC & modeset fixes
├── scripts/                                 # Automation tools
│   ├── install-fedora.sh                    # Automated installer for Fedora
│   ├── install-debian-ubuntu.sh             # Automated installer for Debian / Ubuntu
│   ├── install-arch.sh                      # Automated installer for Arch / CachyOS
│   ├── setup-dkms.sh                        # Standalone DKMS setup
│   └── repack.sh                            # Rebuilds the self-extracting .run file
├── LICENSE                                  # MIT License
└── README.md                                # This guide
```

---

## 4. Prerequisites

Before installing the driver, ensure the following requirements are met:

1. **Disable Secure Boot (Recommended):**
   - Modern Linux kernels block out-of-tree proprietary drivers under Secure Boot unless signed with a custom Machine Owner Key (MOK).
   - Enter your computer's BIOS/UEFI settings and set **Secure Boot** to **Disabled**.
2. **Internet Connection:**
   - Required to install kernel headers and development tools.
3. **Target Distribution Packages:**
   The included installer scripts install these automatically, but for reference:
   - **Fedora:** `kernel-devel`, `kernel-headers`, `gcc`, `make`, `dkms`, `elfutils-libelf-devel`, `libglvnd-devel`, `xorg-x11-server-Xorg`
   - **Debian / Ubuntu:** `build-essential`, `linux-headers-$(uname -r)`, `dkms`, `libglvnd-dev`, `pkg-config`
   - **Arch / CachyOS:** `base-devel`, `linux-headers`, `dkms`, `libglvnd`, `xorg-server`

---

## 5. Universal Installation Guide (2-Step GUI-to-CLI Process)

The official NVIDIA installer **cannot install while a graphical session (Wayland or X11 / SDDM / GDM) is running** because the display server actively holds open the GPU device nodes.

To make this completely painless, we provide a **Universal 2-Step Process**:

```
[ In Your Graphical Desktop (Konsole/Terminal) ]
                      │
                      ▼
       sudo ./scripts/step1-exit-gui.sh
  (Installs dependencies, blacklists Nouveau,
   prepares installer & drops to text console)
                      │
                      ▼
[ In the Pure Text Console (TTY/CLI) ]
                      │
                      ▼
             sudo install-nvidia
  (Compiles & registers driver with DKMS,
   installs Xorg configs & reboots into GUI)
```

---

### Step 1: Prepare System & Exit to CLI (Run in your desktop terminal)

In your terminal (Konsole, GNOME Terminal, etc.), run:

```bash
cd /path/to/nvidia-390xx-linux7
sudo ./scripts/step1-exit-gui.sh
```
*(Or run `sudo ./scripts/install-fedora.sh`, which automatically calls Step 1 if a desktop session is running).*

**What Step 1 does automatically:**
1. Installs all kernel headers, compilers, DKMS, and build tools.
2. **On Fedora KDE:** Automatically installs `plasma-workspace-x11 kwin-x11` (since Fedora 40+ dropped X11 by default, and legacy NVIDIA 390.xx needs X11).
3. **On Fedora GNOME:** Disables Wayland in `/etc/gdm/custom.conf` (`WaylandEnable=false`).
4. Blacklists the open-source `nouveau` driver and rebuilds your initramfs (`dracut --force`).
5. Creates the global CLI shortcut: `install-nvidia`.
6. Prompts you with instructions, and cleanly stops the display manager (`systemctl isolate multi-user.target`) to bring you to a black text console login prompt.

---

### Step 2: Install Driver in CLI (Run in the text console)

Once the screen transitions to the black text console login prompt:

1. **Log in** with your Linux username and password.
2. Run this single command:
   ```bash
   sudo install-nvidia
   ```
   *(Or: `sudo ./scripts/step2-install-in-cli.sh`)*

**What Step 2 does:**
- Verifies that no display server is holding the GPU.
- **Nouveau Check:** If Nouveau is still active in memory from your previous boot, it will prompt you to press `[ENTER]` to reboot once so the blacklist takes effect. After rebooting, simply log back in and run `sudo install-nvidia`.
- Executes the patched installer and automatically registers the kernel modules with **DKMS**.
- Configures Xorg OutputClass and udev device node rules.
- Asks if you want to **reboot** (recommended) or immediately start the graphical desktop.

---

## 6. Critical Notes: Wayland vs. X11 & Fedora KDE

> [!WARNING]
> **NVIDIA 390.xx DOES NOT SUPPORT MODERN WAYLAND COMPOSITORS!**
> Modern Wayland compositors (GNOME Mutter, KDE KWin) require the generic **GBM** (Generic Buffer Management) API. The legacy 390.xx driver only provides the deprecated proprietary **EGLStreams** API.

### What happens if you try running Wayland on GT 730?
You will experience a black screen, freezing, or fallback to software CPU rendering (`llvmpipe`).

### The Solution: Always use an X11 / Xorg Session
- **Fedora KDE Plasma (Plasma 6):**
  - Starting in Fedora 40/41, KDE is Wayland-only by default.
  - Our `step1-exit-gui.sh` script automatically installs the `plasma-workspace-x11` and `kwin-x11` packages.
  - At the **SDDM login screen**, look at the bottom-left or bottom-right session menu and select **"Plasma (X11)"**!
- **Fedora GNOME:**
  - Select **"GNOME on Xorg"** via the gear icon (⚙) at the login screen. Our script also sets `WaylandEnable=false` in `/etc/gdm/custom.conf` so GDM defaults to X11.
- **XFCE / Cinnamon / MATE / LXQt:**
  - These desktop environments use X11 natively and will work out of the box with zero modifications!

---

## 7. Automatic Kernel Updates (DKMS)

By installing with `--dkms` (or via `sudo ./scripts/setup-dkms.sh`), the driver registers with the Dynamic Kernel Module Support (DKMS) framework.

### How it works:
Whenever your package manager (`dnf`, `apt`, `pacman`) installs a kernel update (e.g., from `7.2.9` to `7.2.10`), DKMS automatically compiles and installs the `nvidia.ko`, `nvidia-modeset.ko`, `nvidia-uvm.ko`, and `nvidia-drm.ko` modules for the new kernel before you reboot!

To verify DKMS status at any time:
```bash
dkms status
```
**Expected Output:**
```
nvidia/390.157, 7.2.9-2-cachyos, x86_64: installed
```

---

## 8. Verifying Your Installation

After rebooting into your desktop session, open a terminal and run:

### 1. Check NVIDIA Driver Status
```bash
nvidia-smi
```
**Expected Output:**
```
+-----------------------------------------------------------------------------+
| NVIDIA-SMI 390.157              Driver Version: 390.157                     |
|-------------------------------+----------------------+----------------------+
| GPU  Name        Persistence-M| Bus-Id        Disp.A | Volatile Uncorr. ECC |
| Fan  Temp  Perf  Pwr:Usage/Cap|         Memory-Usage | GPU-Util  Compute M. |
|===============================+======================+======================|
|   0  GeForce GT 730       Off | 00000000:01:00.0 N/A |                  N/A |
+-----------------------------------------------------------------------------+
```

### 2. Check Loaded Kernel Modules
```bash
lsmod | grep nvidia
```
You should see:
- `nvidia_drm`
- `nvidia_modeset`
- `nvidia_uvm`
- `nvidia`

### 3. Check Hardware Acceleration
```bash
glxinfo | grep "OpenGL renderer"
```
Should display: `OpenGL renderer string: GeForce GT 730/PCIe/SSE2` (and **not** `llvmpipe`).

---

## 9. How to Re-pack from Scratch

If you ever want to re-download the official NVIDIA `.run` installer and rebuild `NVIDIA-Linux-x86_64-390.157-patched.run` from source:

```bash
./scripts/repack.sh
```

**How `repack.sh` works:**
1. Checks for the official NVIDIA installer locally; if absent, downloads it automatically from NVIDIA's official CDN.
2. Extracts the embedded `xz` decompression binary.
3. Unpacks the driver and applies all 19 kernel compatibility patches sequentially.
4. Generates a fresh, self-extracting `.run` file using embedded `makeself`.

---

## 10. Troubleshooting & FAQ

<details>
<summary><b>Q: My screen stays black after rebooting!</b></summary>

1. Switch to a TTY console by pressing `Ctrl + Alt + F3` (or `F4` / `F5`).
2. Log in with your username and password.
3. Check if GDM is attempting to start in Wayland mode:
   ```bash
   sudo sed -i 's/#WaylandEnable=false/WaylandEnable=false/' /etc/gdm/custom.conf
   sudo systemctl restart gdm
   ```
4. Verify that nouveau is not loaded:
   ```bash
   lsmod | grep nouveau
   ```
</details>

<details>
<summary><b>Q: The installer complains that Nouveau is already running.</b></summary>

Ensure you have rebuilt your initramfs so nouveau is removed from the early boot image:
- **Fedora:** `sudo dracut --force && sudo reboot`
- **Debian / Ubuntu:** `sudo update-initramfs -u && sudo reboot`
- **Arch:** `sudo mkinitcpio -P && sudo reboot`
</details>

<details>
<summary><b>Q: How do I completely uninstall the driver?</b></summary>

Run the uninstaller:
```bash
sudo ./NVIDIA-Linux-x86_64-390.157-patched.run --uninstall
```
To restore the open-source Nouveau driver, remove the blacklist file:
```bash
sudo rm -f /etc/modprobe.d/blacklist-nouveau.conf
# On Fedora:
sudo dracut --force
# On Debian/Ubuntu:
sudo update-initramfs -u
```
</details>

---

## 11. Pushing to GitHub

To push this project to your own GitHub account:

1. **Create a new empty repository on GitHub** (e.g. `nvidia-390xx-linux7`).
2. In your terminal, initialize and push:
   ```bash
   cd /home/nabil/Documents/code/projects/nvidia-390xx-linux7

   # Link your remote GitHub repository
   git remote add origin https://github.com/<your-github-username>/nvidia-390xx-linux7.git

   # Push to main branch
   git push -u origin main
   ```
3. **Distributing the 82MB pre-built `.run` file:**
   - By default, `*.run` files are ignored in `.gitignore` to keep the repo clone lightweight (~15MB).
   - Anyone who clones your repo can simply run `./scripts/install-fedora.sh` or `./scripts/repack.sh` and it will automatically download from NVIDIA and patch it in seconds.
   - Alternatively, you can upload `NVIDIA-Linux-x86_64-390.157-patched.run` directly as a binary asset under your **GitHub Releases** tab!

---

<div align="center">

Made with ❤️ for the Linux Community & Legacy GPU Enthusiasts

</div>
