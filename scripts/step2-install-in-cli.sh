#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# STEP 2: Execute Patched NVIDIA Installer in Pure Text Console (CLI)
# Run directly in the text console (TTY): sudo install-nvidia
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
RUN_INSTALLER="${PROJECT_DIR}/NVIDIA-Linux-x86_64-390.157-patched.run"

echo "=========================================================================="
echo " [STEP 2/2] NVIDIA 390.157 Driver Installation (CLI Mode)"
echo "=========================================================================="

if [ "$(id -u)" -ne 0 ]; then
    echo "Error: This script must be run as root. Please run:"
    echo "  sudo $0"
    exit 1
fi

# Ensure display manager / X server is stopped
if systemctl is-active --quiet display-manager 2>/dev/null; then
    echo "Stopping active display manager to free GPU device nodes..."
    systemctl stop display-manager || true
    sleep 2
fi

# Check if Nouveau is still active in kernel memory
if lsmod | grep -q nouveau; then
    echo ""
    echo "=========================================================================="
    echo " [!] ATTENTION: The open-source Nouveau driver is still active in memory."
    echo "=========================================================================="
    echo " The nouveau blacklist is already configured in modprobe and your initramfs,"
    echo " but the kernel will not release the GPU hardware until a fresh reboot."
    echo ""
    echo " What to do next:"
    echo "   1. Press [ENTER] below to REBOOT your computer now."
    echo "   2. After rebooting, log in to the text console."
    echo "   3. Run this command again:"
    echo ""
    echo "         sudo install-nvidia"
    echo ""
    echo "=========================================================================="
    read -r -p "Press [ENTER] to reboot now (or Ctrl+C to abort)..." _dummy
    reboot
    exit 0
fi

if [ ! -f "${RUN_INSTALLER}" ]; then
    echo "Patched installer not found at ${RUN_INSTALLER}."
    echo "Building it now..."
    bash "${PROJECT_DIR}/scripts/repack.sh"
fi

# Clang kernel compatibility (e.g. CachyOS)
if grep -qi clang /proc/version; then
    echo "Configuring Clang environment for kernel build..."
    export CC=clang
    export LLVM=1
    export IGNORE_CC_MISMATCH=1
fi

echo "Launching NVIDIA installer with DKMS module registration..."
chmod +x "${RUN_INSTALLER}"
"${RUN_INSTALLER}" --dkms "$@"

echo "Installing Xorg OutputClass and udev helper rules..."
mkdir -p /etc/X11/xorg.conf.d /etc/udev/rules.d
if [ -f "${PROJECT_DIR}/configs/nvidia-drm-outputclass.conf" ]; then
    cp "${PROJECT_DIR}/configs/nvidia-drm-outputclass.conf" /etc/X11/xorg.conf.d/10-nvidia-drm-outputclass.conf
fi
if [ -f "${PROJECT_DIR}/configs/nvidia-390xx.rules" ]; then
    cp "${PROJECT_DIR}/configs/nvidia-390xx.rules" /etc/udev/rules.d/60-nvidia-390xx.rules
    udevadm control --reload-rules || true
fi

echo ""
echo "=========================================================================="
echo " [SUCCESS] NVIDIA 390.157 INSTALLED & REGISTERED WITH DKMS!"
echo "=========================================================================="
echo ""
echo " CRITICAL NOTE FOR FEDORA KDE / GNOME USERS:"
echo " ----------------------------------------------------------------------"
echo " The NVIDIA 390.xx legacy driver requires an X11 (Xorg) desktop session."
echo " At the login screen (SDDM or GDM):"
echo "   - On KDE Plasma: Select 'Plasma (X11)' in the bottom session menu."
echo "   - On GNOME: Click your name, click the gear icon (⚙), and select"
echo "     'GNOME on Xorg'."
echo " ----------------------------------------------------------------------"
echo ""
echo "What would you like to do now?"
echo "  [1] Reboot system (Recommended)"
echo "  [2] Start graphical desktop session immediately"
echo "  [3] Stay in text console"
echo ""
read -r -p "Enter choice [1-3, default: 1]: " CHOICE
CHOICE="${CHOICE:-1}"

case "${CHOICE}" in
    1)
        echo "Rebooting system..."
        reboot
        ;;
    2)
        echo "Starting graphical target..."
        systemctl isolate graphical.target
        ;;
    *)
        echo "Done. You can start the graphical interface later with:"
        echo "  sudo systemctl isolate graphical.target"
        ;;
esac
