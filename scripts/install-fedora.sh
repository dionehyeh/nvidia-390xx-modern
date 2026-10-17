#!/usr/bin/env bash
set -euo pipefail

# Automated installer script for Fedora Linux
# Configures build dependencies, nouveau blacklisting, dracut, Xorg, and installs patched NVIDIA 390.157

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
RUN_INSTALLER="${PROJECT_DIR}/NVIDIA-Linux-x86_64-390.157-patched.run"

echo "=========================================================="
echo " NVIDIA 390.157 Installer for Fedora Linux (GT 730 / Fermi / Kepler)"
echo "=========================================================="

if [ "$(id -u)" -ne 0 ]; then
    echo "Error: This script must be run as root (use sudo ./install-fedora.sh)"
    exit 1
fi

if [ ! -f "${RUN_INSTALLER}" ]; then
    echo "Patched installer not found at ${RUN_INSTALLER}."
    echo "Running repack script to download, patch, and build it automatically..."
    bash "${PROJECT_DIR}/scripts/repack.sh"
fi

echo "[1/6] Installing build dependencies and kernel headers..."
dnf install -y \
    kernel-devel \
    kernel-headers \
    gcc \
    gcc-c++ \
    make \
    dkms \
    elfutils-libelf-devel \
    libglvnd-devel \
    libglvnd-glx \
    libglvnd-opengl \
    pkgconf \
    xorg-x11-server-Xorg

# Ensure KDE Plasma 6 X11 packages are installed if KDE is present
if command -v kwin_wayland &>/dev/null || command -v plasmashell &>/dev/null || [ -d /usr/share/plasma ]; then
    echo "Detected KDE Plasma on Fedora. Installing plasma-workspace-x11 & kwin-x11..."
    dnf install -y plasma-workspace-x11 kwin-x11 || true
fi

echo "[2/6] Blacklisting nouveau driver..."
cat << 'EOF' > /etc/modprobe.d/blacklist-nouveau.conf
blacklist nouveau
blacklist lbm-nouveau
options nouveau modeset=0
alias nouveau off
alias lbm-nouveau off
EOF

# Update GRUB kernel arguments using grubby if available
if command -v grubby &>/dev/null; then
    echo "Configuring kernel boot arguments via grubby..."
    grubby --update-kernel=ALL --args="rd.driver.blacklist=nouveau modprobe.blacklist=nouveau"
fi

echo "[3/6] Rebuilding dracut initramfs to remove nouveau..."
dracut --force

echo "[4/6] Installing Xorg and udev helper configurations..."
mkdir -p /etc/X11/xorg.conf.d /etc/udev/rules.d
if [ -f "${PROJECT_DIR}/configs/nvidia-drm-outputclass.conf" ]; then
    cp "${PROJECT_DIR}/configs/nvidia-drm-outputclass.conf" /etc/X11/xorg.conf.d/10-nvidia-drm-outputclass.conf
fi
if [ -f "${PROJECT_DIR}/configs/nvidia-390xx.rules" ]; then
    cp "${PROJECT_DIR}/configs/nvidia-390xx.rules" /etc/udev/rules.d/60-nvidia-390xx.rules
    udevadm control --reload-rules || true
fi

echo "[5/6] Checking GDM / Wayland configuration..."
if [ -f /etc/gdm/custom.conf ]; then
    if grep -q "#WaylandEnable=false" /etc/gdm/custom.conf; then
        sed -i 's/#WaylandEnable=false/WaylandEnable=false/' /etc/gdm/custom.conf
        echo "  -> Disabled Wayland in /etc/gdm/custom.conf (X11 mode enabled for NVIDIA 390.xx stability)"
    elif ! grep -q "WaylandEnable=false" /etc/gdm/custom.conf; then
        sed -i '/\[daemon\]/a WaylandEnable=false' /etc/gdm/custom.conf
        echo "  -> Added WaylandEnable=false in /etc/gdm/custom.conf"
    else
        echo "  -> Wayland already disabled in /etc/gdm/custom.conf"
    fi
fi

# Check if a graphical session (Wayland or X11) is currently running
if [ -n "${DISPLAY:-}" ] || [ -n "${WAYLAND_DISPLAY:-}" ] || systemctl is-active --quiet display-manager 2>/dev/null; then
    echo ""
    echo "=========================================================================="
    echo " [!] A graphical desktop session (Wayland or Xorg) is currently active!"
    echo "=========================================================================="
    echo " The NVIDIA installer cannot install while the display server is running."
    echo " Launching Step 1 to transition cleanly into text console (CLI) mode..."
    echo "=========================================================================="
    exec bash "${SCRIPT_DIR}/step1-exit-gui.sh" "$@"
fi

echo "[6/6] Launching patched NVIDIA installer with DKMS enabled..."
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
echo " When logging into GNOME / KDE, select an Xorg / X11 session if prompted."
echo "=========================================================="
