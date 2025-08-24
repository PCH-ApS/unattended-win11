#!/bin/bash

# 12. Cross-platform compatibility
if [[ "$(uname -s)" != "Linux" ]]; then
  echo "❌ This script is intended for Linux systems only."
  exit 1
fi

# 9. Check for root privileges
if [ "$EUID" -ne 0 ]; then
  echo "❌ Please run as root or with sudo."
  exit 1
fi

# 6. Logging to file and console
LOGFILE="customimze_win11_iso_$(date +%Y%m%d_%H%M%S).log"
exec > >(tee -a "$LOGFILE") 2>&1

# 1. Robust error handling
fail_if_error() {
  if [ $? -ne 0 ]; then
    echo "❌ Error: $1"
    exit 1
  fi
}

# 7. Flexible argument parsing with getopts
usage() {
  echo
  echo "Usage: $0 -i <source.iso> -a <autounattend.xml|-> -d <USB device> [-f <FAT32 label>] [-n <NTFS label>]"
  echo
  echo "Example (with answer file):"
  echo "  sudo $0 -i windows11.iso -a autounattend.xml -d /dev/sdX"
  echo "Example (without answer file):"
  echo "  sudo $0 -i windows11.iso -a - -d /dev/sdX"
  echo
  echo "⚠ WARNING: The specified USB device (e.g. /dev/sdX) will be ERASED!"
  echo
  lsblk -dno NAME,SIZE,MODEL
  echo
  exit 1
}

# 8. Unmount on error/exit
cleanup() {
  [[ -d "$ISO_MNT" ]] && sudo umount "$ISO_MNT" 2>/dev/null || true && rmdir "$ISO_MNT" 2>/dev/null || true
  [[ -d "$FAT32_MNT" ]] && sudo umount "$FAT32_MNT" 2>/dev/null || true && rmdir "$FAT32_MNT" 2>/dev/null || true
  [[ -d "$NTFS_MNT" ]] && sudo umount "$NTFS_MNT" 2>/dev/null || true && rmdir "$NTFS_MNT" 2>/dev/null || true
}
trap cleanup EXIT

# 10. Optional custom labels (defaults)
FAT32_LABEL="BOOT"
NTFS_LABEL="WINDOWS"

# Parse options
SRC_ISO=""
UNATTEND_XML=""
USB_DEV=""
while getopts ":i:a:d:f:n:" opt; do
  case $opt in
    i) SRC_ISO="$OPTARG" ;;
    a) UNATTEND_XML="$OPTARG" ;;
    d) USB_DEV="$OPTARG" ;;
    f) FAT32_LABEL="$OPTARG" ;;
    n) NTFS_LABEL="$OPTARG" ;;
    *) usage ;;
  esac
done

# Validate arguments
if [ -z "$SRC_ISO" ] || [ -z "$UNATTEND_XML" ] || [ -z "$USB_DEV" ]; then
  usage
fi

# 3. Always quote variables to support paths with spaces
# 11. Documentation and comments throughout

# 1. Check dependencies
for cmd in parted mkfs.vfat mkfs.ntfs wipefs 7z mount rsync; do
  command -v $cmd >/dev/null 2>&1 || { echo "❌ Required tool missing: $cmd"; exit 1; }
done

# Validate input
[ -f "$SRC_ISO" ] || { echo "❌ Source ISO not found: $SRC_ISO"; exit 1; }
if [ "$UNATTEND_XML" != "-" ]; then
  [ -f "$UNATTEND_XML" ] || { echo "❌ autounattend.xml not found: $UNATTEND_XML"; exit 1; }
  USE_UNATTEND=1
else
  USE_UNATTEND=0
fi
[ -b "$USB_DEV" ] || { echo "❌ Invalid USB device: $USB_DEV"; usage; }

# Confirm erase
read -p "⚠ Are you sure you want to ERASE ALL DATA on $USB_DEV? (yes/NO): " confirm
if [[ "$confirm" != "yes" ]]; then
  echo "[!] Operation cancelled."
  exit 1
fi

echo "[+] Unmounting and wiping $USB_DEV..."
for part in $(lsblk -ln -o NAME "$USB_DEV" | tail -n +2); do
  sudo fuser -km "/dev/$part" 2>/dev/null || true
  sudo umount "/dev/$part" 2>/dev/null || true
done
sudo wipefs -a "$USB_DEV"
fail_if_error "Failed to wipe USB device"

echo "[+] Creating GPT with FAT32 (boot) and NTFS (data) partitions..."
sudo parted "$USB_DEV" --script mklabel gpt
fail_if_error "Failed to create GPT label"
sudo parted "$USB_DEV" --script mkpart primary fat32 1MiB 1025MiB
fail_if_error "Failed to create FAT32 partition"
sudo parted "$USB_DEV" --script set 1 esp on
fail_if_error "Failed to set ESP flag"
sudo parted "$USB_DEV" --script mkpart primary ntfs 1025MiB 100%
fail_if_error "Failed to create NTFS partition"
sleep 2

# Resolve partition names
if [[ "$USB_DEV" =~ nvme ]]; then
  BOOT_PART="${USB_DEV}p1"
  DATA_PART="${USB_DEV}p2"
else
  BOOT_PART="${USB_DEV}1"
  DATA_PART="${USB_DEV}2"
fi

echo "[+] Formatting partitions..."
sudo mkfs.vfat -F32 -n "$FAT32_LABEL" "$BOOT_PART"
fail_if_error "Failed to format FAT32 partition"
sudo mkfs.ntfs -f -L "$NTFS_LABEL" "$DATA_PART"
fail_if_error "Failed to format NTFS partition"

# Mount everything
ISO_MNT=$(mktemp -d)
FAT32_MNT=$(mktemp -d)
NTFS_MNT=$(mktemp -d)

echo "[+] Mounting ISO and USB partitions..."
sudo mount -o loop "$SRC_ISO" "$ISO_MNT"
fail_if_error "Failed to mount ISO"
sudo mount "$BOOT_PART" "$FAT32_MNT"
fail_if_error "Failed to mount FAT32 partition"
sudo mount "$DATA_PART" "$NTFS_MNT"
fail_if_error "Failed to mount NTFS partition"

# 2. Check for sufficient disk space on USB device before copying
ISO_SIZE_KB=$(du -k "$SRC_ISO" | awk '{print $1}')
FREE_SPACE_KB=$(df --output=avail "$NTFS_MNT" | tail -n 1)
if [ "$FREE_SPACE_KB" -lt "$ISO_SIZE_KB" ]; then
  echo "❌ Not enough free space on USB NTFS partition. Required: $((ISO_SIZE_KB/1024)) MB, Available: $((FREE_SPACE_KB/1024)) MB"
  exit 1
fi

echo "[+] Copying UEFI boot files to FAT32..."
sudo mkdir -p "$FAT32_MNT/sources"
fail_if_error "Failed to create sources directory on FAT32"
if [ "$USE_UNATTEND" -eq 1 ]; then
  sudo cp "$UNATTEND_XML" "$FAT32_MNT/autounattend.xml"
  fail_if_error "Failed to copy autounattend.xml to FAT32"
  sudo cp "$UNATTEND_XML" "$NTFS_MNT/autounattend.xml"
  fail_if_error "Failed to copy autounattend.xml to NTFS"
fi
sudo cp -r "$ISO_MNT/boot" "$FAT32_MNT/"
fail_if_error "Failed to copy boot folder to FAT32"
sudo cp -r "$ISO_MNT/efi" "$FAT32_MNT/"
fail_if_error "Failed to copy efi folder to FAT32"
sudo cp "$ISO_MNT/bootmgr"* "$FAT32_MNT/" 2>/dev/null || true
sudo cp "$ISO_MNT/setup.exe" "$FAT32_MNT/"
fail_if_error "Failed to copy setup.exe to FAT32"
sudo cp "$ISO_MNT/sources/boot.wim" "$FAT32_MNT/sources/"
fail_if_error "Failed to copy boot.wim to FAT32"

echo "[+] Copying all ISO files (including install.wim) to NTFS..."
# 4. Use rsync with progress for better feedback on large copies
sudo rsync -a --info=progress2 "$ISO_MNT"/ "$NTFS_MNT"/
fail_if_error "Failed to copy ISO contents to NTFS"

# 5. Optional verification step
echo "[+] Verifying critical files on USB..."

if [ "$USE_UNATTEND" -eq 1 ]; then
  if [ ! -f "$FAT32_MNT/autounattend.xml" ]; then
    echo "❌ autounattend.xml not found on FAT32 partition!"
    exit 1
  fi
  if [ ! -f "$NTFS_MNT/autounattend.xml" ]; then
    echo "❌ autounattend.xml not found on NTFS partition!"
    exit 1
  fi
fi

if [ ! -f "$FAT32_MNT/sources/boot.wim" ]; then
  echo "❌ boot.wim not found on FAT32 partition!"
  exit 1
fi

if [ ! -f "$NTFS_MNT/sources/install.wim" ] && [ ! -f "$NTFS_MNT/sources/install.esd" ]; then
  echo "❌ install.wim or install.esd not found on NTFS partition!"
  exit 1
fi

echo "[✓] Critical files verified."

echo "[+] Syncing and cleaning up..."
sync
sudo umount "$ISO_MNT" "$FAT32_MNT" "$NTFS_MNT"
rmdir "$ISO_MNT" "$FAT32_MNT" "$NTFS_MNT"

echo "[✓] Hybrid USB created successfully. Boot using UEFI mode and install Windows 11."