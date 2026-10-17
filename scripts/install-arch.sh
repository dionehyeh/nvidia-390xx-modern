#!/usr/bin/env bash
set -euo pipefail

# Automated installer script for Arch Linux / CachyOS / Manjaro
# Configures build dependencies, nouveau blacklisting, mkinitcpio, and installs patched NVIDIA 390.157

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
RUN_INSTALLER="${PROJECT_DIR}/NVIDIA-Linux-x86_64-390.157-patched.run"

echo "=========================================================="
echo " NVIDIA 390.157 Installer for Arch Linux / CachyOS / Manjaro"
echo "=========================================================="

if [ "$(id -u)" -ne 0 ]; then
    echo "Error: This script must be run as root (use sudo ./install-arch.sh)"
    exit 1
fi

if [ ! -f "${RUN_INSTALLER}" ]; then
    echo "Patched installer not found at ${RUN_INSTALLER}."
    echo "Running repack script to download, patch, and build it automatically..."
    bash "${PROJECT_DIR}/scripts/repack.sh"
fi

echo "[1/5] Installing build dependencies and kernel headers..."
pacman -S --needed --noconfirm base-devel dkms libglvnd xorg-server

# Check if running a clang-compiled kernel like CachyOS
if grep -qi clang /proc/version; then
    echo "Detected Clang-compiled kernel. Installing clang and lld..."
    pacman -S --needed --noconfirm clang lld
    export CC=clang
    export LLVM=1
    export IGNORE_CC_MISMATCH=1
fi

echo "[2/5] Blacklisting nouveau driver..."
cat << 'EOF' > /etc/modprobe.d/blacklist-nouveau.conf
blacklist nouveau
blacklist lbm-nouveau
options nouveau modeset=0
alias nouveau off
alias lbm-nouveau off
EOF

echo "[3/5] Regenerating initramfs with mkinitcpio..."
if command -v mkinitcpio &>/dev/null; then
    mkinitcpio -P
elif command -v dracut &>/dev/null; then
    dracut --force
fi

echo "[4/5] Installing Xorg and udev helper configurations..."
mkdir -p /etc/X11/xorg.conf.d /etc/udev/rules.d
if [ -f "${PROJECT_DIR}/configs/nvidia-drm-outputclass.conf" ]; then
    cp "${PROJECT_DIR}/configs/nvidia-drm-outputclass.conf" /etc/X11/xorg.conf.d/10-nvidia-drm-outputclass.conf
fi
if [ -f "${PROJECT_DIR}/configs/nvidia-390xx.rules" ]; then
    cp "${PROJECT_DIR}/configs/nvidia-390xx.rules" /etc/udev/rules.d/60-nvidia-390xx.rules
    udevadm control --reload-rules || true
fi

echo "[5/5] Launching patched NVIDIA installer with DKMS enabled..."
if lsmod | grep -q nouveau; then
    echo ""
    echo "=========================================================="
    echo " WARNING: The nouveau driver is currently active in memory!"
    echo " Nouveau has been successfully blacklisted in modprobe and initramfs."
    echo " PLEASE REBOOT YOUR PC NOW."
    echo " After rebooting, run this script again to complete the driver install:"
    echo "   sudo $0"
    echo "=========================================================="
    exit 0
fi

chmod +x "${RUN_INSTALLER}"
"${RUN_INSTALLER}" --dkms "$@"

echo ""
echo "=========================================================="
echo " NVIDIA 390.157 installation completed!"
echo " Reboot your system to start using the proprietary NVIDIA driver."
echo " Select an Xorg / X11 session at the login screen for best stability."
echo "=========================================================="
