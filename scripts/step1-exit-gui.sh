#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# STEP 1: Prepare System, Install Dependencies, Blacklist Nouveau & Exit to CLI
# Universal script for Fedora (KDE/GNOME), Debian, Ubuntu, Arch, and derivatives
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
RUN_INSTALLER="${PROJECT_DIR}/NVIDIA-Linux-x86_64-390.157-patched.run"

echo "=========================================================================="
echo " [STEP 1/2] NVIDIA 390.157 Pre-Installation & Exit to CLI"
echo "=========================================================================="

if [ "$(id -u)" -ne 0 ]; then
    echo "Error: This script must be run as root. Please run:"
    echo "  sudo $0"
    exit 1
fi

# Detect Linux Distribution
DISTRO="unknown"
if [ -f /etc/os-release ]; then
    . /etc/os-release
    DISTRO="${ID:-unknown}"
fi

echo "[1/5] Detecting distribution: ${DISTRO}..."

# 1. Install Dependencies
echo "[2/5] Installing build tools, kernel headers, and X11 packages..."
case "${DISTRO}" in
    fedora)
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

        # Check for KDE Plasma (Fedora 40/41/42 defaults to Wayland only; install Plasma X11 session)
        if command -v kwin_wayland &>/dev/null || command -v plasmashell &>/dev/null || [ -d /usr/share/plasma ]; then
            echo "  -> Detected KDE Plasma on Fedora! Installing plasma-workspace-x11 & kwin-x11..."
            dnf install -y plasma-workspace-x11 kwin-x11 || true
        fi

        # Check for GDM (GNOME)
        if [ -f /etc/gdm/custom.conf ]; then
            if grep -q "#WaylandEnable=false" /etc/gdm/custom.conf; then
                sed -i 's/#WaylandEnable=false/WaylandEnable=false/' /etc/gdm/custom.conf
            elif ! grep -q "WaylandEnable=false" /etc/gdm/custom.conf; then
                sed -i '/\[daemon\]/a WaylandEnable=false' /etc/gdm/custom.conf
            fi
            echo "  -> Configured GDM to support X11 sessions."
        fi
        ;;
    debian|ubuntu|linuxmint|pop)
        apt update
        apt install -y \
            build-essential \
            linux-headers-$(uname -r) \
            dkms \
            libglvnd-dev \
            pkg-config \
            xserver-xorg-core
        ;;
    arch|cachyos|manjaro|endeavouros)
        pacman -S --needed --noconfirm base-devel dkms libglvnd xorg-server
        if grep -qi clang /proc/version; then
            echo "  -> Detected Clang-compiled kernel (e.g. CachyOS). Installing clang and lld..."
            pacman -S --needed --noconfirm clang lld
        fi
        ;;
    *)
        echo "  -> Note: Unknown distro family '${DISTRO}'. Proceeding assuming packages are installed."
        ;;
esac

# 2. Blacklist Nouveau & update initramfs
echo "[3/5] Blacklisting open-source nouveau driver..."
mkdir -p /etc/modprobe.d
cat << 'EOF' > /etc/modprobe.d/blacklist-nouveau.conf
blacklist nouveau
blacklist lbm-nouveau
options nouveau modeset=0
alias nouveau off
alias lbm-nouveau off
EOF

# Update GRUB command-line if grubby is available (Fedora / RHEL)
if command -v grubby &>/dev/null; then
    grubby --update-kernel=ALL --args="rd.driver.blacklist=nouveau modprobe.blacklist=nouveau" || true
fi

echo "  -> Regenerating initramfs (removing nouveau from boot image)..."
if command -v dracut &>/dev/null; then
    dracut --force
elif command -v update-initramfs &>/dev/null; then
    update-initramfs -u
elif command -v mkinitcpio &>/dev/null; then
    mkinitcpio -P
fi

# 3. Ensure patched installer exists
echo "[4/5] Checking patched installer..."
if [ ! -f "${RUN_INSTALLER}" ]; then
    echo "  -> Patched installer not found. Building it now while internet/GUI is active..."
    bash "${PROJECT_DIR}/scripts/repack.sh"
else
    echo "  -> Found ready installer: ${RUN_INSTALLER}"
fi

# 4. Install convenient shortcut into /usr/local/bin
mkdir -p /usr/local/bin
cat << EOF > /usr/local/bin/install-nvidia
#!/usr/bin/env bash
exec bash "${PROJECT_DIR}/scripts/step2-install-in-cli.sh" "\$@"
EOF
chmod +x /usr/local/bin/install-nvidia
chmod +x "${PROJECT_DIR}/scripts/step2-install-in-cli.sh"

echo "[5/5] Ready to transition to text console mode!"
echo ""
echo "=========================================================================="
echo "                  *** INSTRUCTIONS FOR NEXT STEP ***"
echo "=========================================================================="
echo " When you press [ENTER], your screen will leave the desktop and show"
echo " a black text console login prompt (TTY)."
echo ""
echo " What to do in the text console:"
echo "   1. Type your USERNAME and press Enter."
echo "   2. Type your PASSWORD and press Enter."
echo "   3. Run this single command to install the driver:"
echo ""
echo "         sudo install-nvidia"
echo ""
echo "      (Or: sudo ${PROJECT_DIR}/scripts/step2-install-in-cli.sh)"
echo ""
echo " Once installed, you will be prompted to reboot or restart the desktop!"
echo "=========================================================================="
echo ""
read -r -p "Press [ENTER] to exit graphical mode and open CLI (or Ctrl+C to cancel)..." _dummy

echo "Switching to multi-user target (CLI mode)..."
systemctl isolate multi-user.target
