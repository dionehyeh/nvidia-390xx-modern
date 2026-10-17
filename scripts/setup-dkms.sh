#!/usr/bin/env bash
set -euo pipefail

# Standalone DKMS installation script for NVIDIA 390.157
# Installs kernel source directly to /usr/src/nvidia-390.157 and registers with DKMS

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
DKMS_SRC="${PROJECT_DIR}/dkms-source"
DEST_SRC="/usr/src/nvidia-390.157"

echo "=== Standalone DKMS Setup for NVIDIA 390.157 ==="

if [ "$(id -u)" -ne 0 ]; then
    echo "Error: This script must be run as root (use sudo ./setup-dkms.sh)"
    exit 1
fi

if ! command -v dkms &>/dev/null; then
    echo "Error: 'dkms' is not installed. Please install dkms first."
    exit 1
fi

echo "Removing any prior DKMS registration for nvidia/390.157..."
dkms remove -m nvidia -v 390.157 --all 2>/dev/null || true

echo "Copying patched module sources to ${DEST_SRC}..."
rm -rf "${DEST_SRC}"
mkdir -p "${DEST_SRC}"
cp -a "${DKMS_SRC}/"* "${DEST_SRC}/"

echo "Registering module with DKMS..."
dkms add -m nvidia -v 390.157

echo "Building module for running kernel $(uname -r)..."
dkms build -m nvidia -v 390.157

echo "Installing module into kernel tree..."
dkms install -m nvidia -v 390.157

echo "=== DKMS setup completed successfully! ==="
echo "Status:"
dkms status -m nvidia -v 390.157
