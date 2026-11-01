#!/usr/bin/env bash
# ============================================================================
# preflight.sh — WSL/Linux companion to preflight.ps1.
#
# Read-only. Run INSIDE WSL on the ProArt (or any Linux boot of it) to check
# the GPU facts that are visible from the Linux side:
#   * GPU identity + VBIOS + power limit via nvidia-smi (WSL path below)
#   * the device ID must be 28A1, matching the profile this build targets
#
# What this script deliberately does NOT claim: Secure Boot state and the
# PCI BDF are Windows/BIOS-side facts — preflight.ps1 owns those. WSL also
# reports "GSP Firmware Version: N/A" on its paravirtual path; that is a
# WSL artefact, not a finding about the card, so it is not checked here.
#
# Exit code: 0 = GPU matches the profile, 1 = mismatch / GPU not visible.
# ============================================================================
set -euo pipefail

# nvidia-smi is not on PATH inside WSL; it ships with the Windows driver.
SMI="/usr/lib/wsl/lib/nvidia-smi"
[ -x "$SMI" ] || SMI="$(command -v nvidia-smi || true)"
[ -n "${SMI:-}" ] && [ -x "$SMI" ] || { echo "[FAIL] nvidia-smi not found"; exit 1; }

EXPECTED_ID="0x28A110DE"   # PCI device:vendor, as nvidia-smi formats it

row="$("$SMI" --query-gpu=name,pci.device_id,vbios_version,driver_version,power.default_limit,memory.total \
        --format=csv,noheader)"
echo "GPU: $row"

id="$(echo "$row" | awk -F', ' '{print $2}')"
if [ "$id" = "$EXPECTED_ID" ]; then
  echo "[PASS] device id — $id"
else
  echo "[FAIL] device id — got $id, expected $EXPECTED_ID"
  exit 1
fi
echo "PREFLIGHT (WSL side) OK — run preflight.ps1 in Windows for BDF + Secure Boot."
