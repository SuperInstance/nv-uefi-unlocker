#!/usr/bin/env bash
# ============================================================================
# build.sh — reproducible, tailored build of nv-uefi-unlocker for ONE machine:
#
#   ASUS ProArt PX13 HN7306WU
#   NVIDIA GeForce RTX 4050 Laptop GPU · PCI 10DE:28A1 · BDF c4:00.0
#
# What it does, in order (each stage hard-fails on error; nothing is
# half-built silently):
#   1. sanity-checks the host toolchain and this machine profile's constants
#   2. builds the host asset tool and the UEFI loader (TX flavour) from source
#   3. verifies the loader is really a TX build (check_efi.py) and runs the
#      full workspace test suite (behaviour simulator included)
#   4. generates the Ada (family 40) firmware set from the maker's PINNED
#      NVIDIA inputs — the maker SHA-256-verifies every download and refuses
#      any substituted version
#   5. assembles a clean USB-stick layout in ./out/proart-px13-4050-usb/:
#      runtime files only (no maker intermediates), plus this machine's
#      marker files, and a SHA256SUMS.txt covering the result
#
# Discipline (inherited from upstream's constitution, kept on purpose):
#   * NVIDIA-derived .bin files are generated locally and NEVER committed.
#   * The loader is pinned to a single card via tx-select-bdf.txt; an
#     unparsable or non-matching pin makes the loader skip, never guess.
#   * No auto-run marker is shipped: the human presses Space/Enter at the
#     version screen, every cold boot.
#
# Usage:  bash machines/proart-px13-4050/build.sh [--skip-tests]
# ============================================================================
set -euo pipefail

# --- Machine constants (measured on the target, 2026-11-01; see PROFILE.md).
# The BDF is written in HEX because that is what the loader's parse_bdf()
# expects (loader/src/pci.rs: usize::from_str_radix(_, 16) on every field).
# Bus 196 decimal == 0xC4. If the GPU is ever re-seated in a different
# machine, re-measure and update these — do not copy them blindly.
EXPECTED_DEV_ID="28a1"
TARGET_BDF_HEX="c4:00.0"
GPU_FAMILY="40"            # Ada; asset set name below is the family bundle id
ASSET_SET="ad102"

# --- Resolve paths relative to the repo root, wherever we were called from.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$REPO_ROOT"

OUT_DIR="$REPO_ROOT/out/proart-px13-4050-usb"
PROFILE_DIR="$REPO_ROOT/machines/proart-px13-4050"
LOADER_EFI="target/x86_64-unknown-uefi/release/loader.efi"

SKIP_TESTS=0
[ "${1:-}" = "--skip-tests" ] && SKIP_TESTS=1

log() { printf '[build] %s\n' "$*"; }
die() { printf '[build] ERROR: %s\n' "$*" >&2; exit 1; }

# --- Stage 1: toolchain + profile sanity -----------------------------------
command -v cargo  >/dev/null || die "cargo not in PATH — install Rust via rustup"
command -v python3 >/dev/null || die "python3 not in PATH — needed for check_efi.py"

# The pin file in this profile must match the constant above; if someone
# edits one and not the other, stop here instead of building a lying stick.
PIN_ON_DISK="$(tr -d '[:space:]' < "$PROFILE_DIR/tx-select-bdf.txt")"
[ "$PIN_ON_DISK" = "$TARGET_BDF_HEX" ] \
  || die "tx-select-bdf.txt says '$PIN_ON_DISK', expected '$TARGET_BDF_HEX'"

log "stage 1/5 ok: toolchain present, profile pin = $TARGET_BDF_HEX (device $EXPECTED_DEV_ID)"

# --- Stage 2: build ---------------------------------------------------------
rustup target add x86_64-unknown-uefi >/dev/null
cargo build --release            # host tools (assets generator, ssdiag)
cargo efi-tx                     # loader, TX flavour, x86_64-unknown-uefi
[ -f "$LOADER_EFI" ] || die "loader.efi missing after cargo efi-tx"
log "stage 2/5 ok: loader + host tools built"

# --- Stage 3: verify the artifact, then the test suite ----------------------
# check_efi.py distinguishes TX (unlock-capable) from read-only builds;
# grep (not the exit code alone) is the evidence, so print the verdict line.
VERDICT="$(python3 check_efi.py "$LOADER_EFI" | tee /dev/stderr | grep 'VERDICT:' || true)"
case "$VERDICT" in
  *"TX build"*) : ;;
  *) die "unexpected check_efi verdict: $VERDICT" ;;
esac
if [ "$SKIP_TESTS" -eq 0 ]; then
  cargo test --release
  log "stage 3/5 ok: TX verdict confirmed, test suite green"
else
  log "stage 3/5 ok: TX verdict confirmed (tests skipped by --skip-tests)"
fi

# --- Stage 4: generate the pinned firmware set ------------------------------
# Downloads are pinned + hash-verified inside the maker; a mismatch aborts
# there. We pass our freshly built loader/assets so the stick matches this
# source tree byte for byte, not a downloaded release.
bash release/make-usbroot.sh --family "$GPU_FAMILY" \
  --assets ./target/release/assets \
  --boot-efi "./$LOADER_EFI"
log "stage 4/5 ok: family-$GPU_FAMILY asset set generated in ./usbroot"

# --- Stage 5: assemble the stick layout -------------------------------------
# Only the files the loader actually reads at runtime go on the stick.
# The maker also drops intermediate duplicates (per-family aliases, raw
# scrubber source, other families' bundles) into usbroot/ — leaving them
# off keeps the stick auditable at a glance.
RUNTIME_FILES=(
  "booter_load_${ASSET_SET}.bin"
  "gsp_boot_${ASSET_SET}.bin"
  "gsp_boot_desc_${ASSET_SET}.bin"
  "fwimage_${ASSET_SET}.bin"
  "fwsignature_${ASSET_SET}.bin"
  "scrubber_ad10x.bin"
  "v67-${ASSET_SET}-four-plm.bin"
)
rm -rf "$OUT_DIR"
mkdir -p "$OUT_DIR/EFI/BOOT"
cp "$LOADER_EFI" "$OUT_DIR/EFI/BOOT/BOOTX64.EFI"
for f in "${RUNTIME_FILES[@]}"; do
  [ -f "usbroot/$f" ] || die "maker did not produce usbroot/$f"
  cp "usbroot/$f" "$OUT_DIR/"
done
# Machine markers + on-stick instructions (sources live in the profile dir,
# so the repo and the stick can never drift apart).
cp "$PROFILE_DIR/tx-select-bdf.txt" "$PROFILE_DIR/tx-quiet.txt" "$OUT_DIR/"
cp "$PROFILE_DIR/README-PROART.txt" "$OUT_DIR/"
# Hash everything except the sums file itself, in stable sorted order, so a
# copied stick can be verified with a single `sha256sum -c SHA256SUMS.txt`.
( cd "$OUT_DIR" && find . -type f ! -name SHA256SUMS.txt | sort | xargs sha256sum ) \
  > "$OUT_DIR/SHA256SUMS.txt"
( cd "$OUT_DIR" && sha256sum -c SHA256SUMS.txt >/dev/null ) \
  || die "assembled stick failed its own hash check"
log "stage 5/5 ok: stick assembled and hash-verified"

echo
log "DONE -> $OUT_DIR"
log "Copy the CONTENTS of that folder to the root of a FAT32 USB stick,"
log "then follow machines/proart-px13-4050/README.md (test protocol)."
