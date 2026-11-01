#!/usr/bin/env bash
# Reproducible build of nv-uefi-unlocker tailored to the ASUS ProArt PX13
# HN7306WU (RTX 4050 Laptop, 10DE:28A1, BDF c4:00.0). See PROFILE.md.
# Assembles a USB-stick layout under ./out/proart-px13-4050-usb/ .
# NVIDIA-derived .bin files are generated locally by the pinned maker
# script and are never committed to git (upstream asset discipline).
set -euo pipefail
cd "$(dirname "$0")/../.."

command -v cargo >/dev/null || { echo "need Rust (rustup) in PATH"; exit 1; }

rustup target add x86_64-unknown-uefi
cargo build --release
cargo efi-tx

LOADER=target/x86_64-unknown-uefi/release/loader.efi
python3 check_efi.py "$LOADER"
cargo test --release

bash release/make-usbroot.sh --family 40 \
  --assets ./target/release/assets \
  --boot-efi "./$LOADER"

OUT=out/proart-px13-4050-usb
rm -rf "$OUT"
mkdir -p "$OUT/EFI/BOOT"
cp target/x86_64-unknown-uefi/release/loader.efi "$OUT/EFI/BOOT/BOOTX64.EFI"
# Runtime files for the Ada family only (maker intermediates stay off the stick)
cp usbroot/booter_load_ad102.bin usbroot/gsp_boot_ad102.bin \
   usbroot/gsp_boot_desc_ad102.bin usbroot/fwimage_ad102.bin \
   usbroot/fwsignature_ad102.bin usbroot/scrubber_ad10x.bin \
   usbroot/v67-ad102-four-plm.bin "$OUT/"
# Machine markers + docs
cp machines/proart-px13-4050/tx-select-bdf.txt machines/proart-px13-4050/tx-quiet.txt "$OUT/"
cp machines/proart-px13-4050/README-PROART.txt "$OUT/"
# Hashes (excluding the sums file itself)
( cd "$OUT" && find . -type f ! -name SHA256SUMS.txt | sort | xargs sha256sum ) > "$OUT/SHA256SUMS.txt"

echo "DONE -> $OUT (copy its CONTENTS to a FAT32 USB stick root)"
