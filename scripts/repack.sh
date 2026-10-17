#!/usr/bin/env bash
set -euo pipefail

# Script to extract, patch, and repack NVIDIA 390.157 for modern Linux kernels (up to 7.2+)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
DOWNLOADS_DIR="${HOME}/Downloads"
SRC_RUN="${1:-${DOWNLOADS_DIR}/NVIDIA-Linux-x86_64-390.157.run}"
OUTPUT_RUN="${PROJECT_DIR}/NVIDIA-Linux-x86_64-390.157-patched.run"
WORK_DIR="${PROJECT_DIR}/build_tmp"
EXTRACT_DIR="${WORK_DIR}/NVIDIA-Linux-x86_64-390.157"
PATCHES_DIR="${PROJECT_DIR}/patches"

NVIDIA_URL="https://us.download.nvidia.com/XFree86/Linux-x86_64/390.157/NVIDIA-Linux-x86_64-390.157.run"

echo "=== NVIDIA 390.157 Modern Kernel Repacker ==="
if [ ! -f "${SRC_RUN}" ]; then
    if [ -f "${PROJECT_DIR}/NVIDIA-Linux-x86_64-390.157.run" ]; then
        SRC_RUN="${PROJECT_DIR}/NVIDIA-Linux-x86_64-390.157.run"
    else
        echo "Source file not found locally. Downloading official NVIDIA 390.157 driver from NVIDIA CDN..."
        mkdir -p "${DOWNLOADS_DIR}"
        SRC_RUN="${DOWNLOADS_DIR}/NVIDIA-Linux-x86_64-390.157.run"
        if command -v curl &>/dev/null; then
            curl -fLo "${SRC_RUN}" "${NVIDIA_URL}"
        elif command -v wget &>/dev/null; then
            wget -O "${SRC_RUN}" "${NVIDIA_URL}"
        else
            echo "Error: Neither curl nor wget found. Please download NVIDIA-Linux-x86_64-390.157.run manually."
            exit 1
        fi
    fi
fi

echo "Source archive: ${SRC_RUN}"
echo "Patches folder: ${PATCHES_DIR}"

rm -rf "${WORK_DIR}"
mkdir -p "${WORK_DIR}"

echo "Extracting embedded decompression binary..."
sh "${SRC_RUN}" --extract-decompress > "${WORK_DIR}/embedded_xz"
chmod +x "${WORK_DIR}/embedded_xz"

echo "Extracting driver contents..."
sh "${SRC_RUN}" --extract-only --target "${EXTRACT_DIR}"

echo "Applying kernel compatibility patches..."
cd "${EXTRACT_DIR}"

PATCH_LIST=(
    "kernel-4.16+-memory-encryption.patch"
    "kernel-6.2.patch"
    "kernel-6.3.patch"
    "kernel-6.4.patch"
    "kernel-6.5.patch"
    "kernel-6.6.patch"
    "kernel-6.8.patch"
    "gcc-14.patch"
    "kernel-6.10.patch"
    "kernel-6.12.patch"
    "kernel-6.13.patch"
    "kernel-6.14.patch"
    "gcc-15.patch"
    "kernel-6.15.patch"
    "kernel-6.17.patch"
    "kernel-6.19.patch"
    "kernel-6.18-nv_workqueue_flush.patch"
    "kernel-7.0.patch"
    "kernel-7.2.patch"
)

for patch_file in "${PATCH_LIST[@]}"; do
    patch_path="${PATCHES_DIR}/${patch_file}"
    if [ -f "${patch_path}" ]; then
        echo "  -> Applying ${patch_file}..."
        patch -Np1 -i "${patch_path}"
    else
        echo "  -> Warning: Patch ${patch_file} not found in ${PATCHES_DIR}, skipping!"
    fi
done

# Clean any backup files
find kernel/ -name "*.orig" -delete || true

echo "Repacking into self-extracting archive: ${OUTPUT_RUN}..."
cd "${WORK_DIR}"
"${EXTRACT_DIR}/makeself.sh" --xz \
    --target-os Linux \
    --target-arch x86_64 \
    --version-string 390.157 \
    --pkg-version 0 \
    --help-script ./makeself-help-script.sh \
    --embed-decompress "${WORK_DIR}/embedded_xz" \
    "${EXTRACT_DIR}" \
    "${OUTPUT_RUN}" \
    "NVIDIA Accelerated Graphics Driver for Linux-x86_64 390.157" \
    ./nvidia-installer

chmod +x "${OUTPUT_RUN}"
echo "Verifying archive integrity..."
sh "${OUTPUT_RUN}" --check

echo "Cleaning up temporary files..."
rm -rf "${WORK_DIR}"

echo "=== SUCCESS! Patched installer ready at: ${OUTPUT_RUN} ==="
