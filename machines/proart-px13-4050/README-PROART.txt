nv-uefi-unlocker — tailored build for ASUS ProArt PX13 HN7306WU
Target GPU: NVIDIA GeForce RTX 4050 Laptop GPU, PCI 10DE:28A1,
subsystem 1043:1ED3, BDF c4:00.0 (bus 196, device 0, function 0), 55 W, 6 GB
Built from SuperInstance/nv-uefi-unlocker branch proart-px13-4050 (upstream main, v2.1.9-dev)

BEFORE BOOTING THIS STICK
1. In Windows, choose Restart (not Shut down) so the GPU starts cold.
2. Secure Boot is currently ENABLED on this machine (measured 2026-11-01).
   Disable Secure Boot in BIOS setup, or enrol/trust a self-signed EFI cert.
   The loader will not run with stock Secure Boot policy.
3. This laptop has NO MUX switch: hybrid output (Radeon iGPU drives the
   panel) is the only display mode, and upstream's verified 28a1 run was
   also done in hybrid mode. Some hybrid laptops lose the unlock after OS
   handoff, so the ssdiag read-back below is mandatory, not optional.

BOOT
1. Copy the CONTENTS of this folder to the root of a FAT32 USB stick
   (keep EFI/BOOT/BOOTX64.EFI in place).
2. One-time boot menu -> select the USB stick.
3. Press Space or Enter at the version screen. Any other key, or 30 s,
   aborts with no changes. Temporary black/frozen screen is expected.
4. The machine chain-loads Windows automatically. Log: loader.log on the stick.

VERIFY (Windows, after boot)
Run ssdiag-x86_64-windows.exe from the upstream release package, then compare
the same FP16/BF16 workload before/after. Read-back is the only proof.

RECOVERY
On STOP, fault or stuck black screen: do NOT retry in the same session.
Fully power off, remove the stick, boot normally. Unlock is volatile:
power-off clears it completely; nothing was flashed.

Markers on this stick:
- tx-select-bdf.txt = c4:00.0  (process ONLY the ProArt's 4050)
- tx-quiet.txt                 (verdict lines only; iGPU console is slow)
