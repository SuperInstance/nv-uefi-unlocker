# ProArt PX13 (HN7306WU) — RTX 4050 Laptop profile

A machine profile for [nv-uefi-unlocker](../../README.en.md), tailored to one
specific laptop and one specific GPU, with the process recorded as it was done.
Fork: `SuperInstance/nv-uefi-unlocker`, branch `proart-px13-4050`.
Built 2026-11-01. Upstream base: `physicsdolphin/nv-uefi-unlocker` main
(v2.1.9-dev, after v2.1.8).

## Target hardware — probed live on the machine, 2026-11-01

Measured over SSH on the target itself (WSL `nvidia-smi`, Windows CIM /
PnP via interop, registry). Not copied from a spec sheet.

| Item | Measured value |
| --- | --- |
| Laptop | ASUSTeK ProArt PX13 **HN7306WU** |
| BIOS | HN7306WU.318, 2026-05-03 |
| OS | Windows 11 Home, build 26300 (WSL2: Ubuntu 26.04) |
| CPU / iGPU | AMD Ryzen AI 9 HX 370 / Radeon 890M (drives the internal display in hybrid mode) |
| dGPU | NVIDIA GeForce RTX 4050 Laptop GPU (AD107) |
| PCI ID | `10DE:28A1`, subsystem `1043:1ED3` (ASUSTeK), REV A1 |
| PCI location | **bus 196 (`0xC4`), device 0, function 0 → BDF `c4:00.0`** |
| VBIOS | 95.07.44.00.63 |
| VRAM | 6141 MiB (6 GB) |
| Power | 55 W default limit |
| Windows driver | 616.92 (32.0.16.1692) |
| **Secure Boot** | **ENABLED** (`UEFISecureBootEnabled = 0x1`) — must be disabled, or a self-signed EFI cert enrolled, before the loader will run |
| GSP note | WSL `nvidia-smi` reports GSP Firmware `N/A` (WSL paravirtual path); not the native-Windows reading, and Ada does not need the Turing GSP prerequisite |

## Why this exact card is in scope

Upstream's compatibility matrix marks **AD107 · 4050 Laptop `28a1`** as ✅:
"Full chain, selector read-backs, post-FLR survival and computation integrity
checks pass" ([docs/compatibility.en.md](../../docs/compatibility.en.md),
device 3), with a field record of **1.7–1.9×** on 28a1 silicon
([docs/evidence/m1-ad107-laptop/log.md](../../docs/evidence/m1-ad107-laptop/log.md)).

Differences from that field bench, stated plainly:

- Their 28a1 bench was an ASUS ROG G614JV left in **hybrid output mode**,
  and hybrid is the only mode this machine has: the PX13 HN7306's official
  ASUS specification lists **no MUX switch and no Advanced Optimus** (checked
  2026-11-01 against the ASUS UK tech-spec page for HN7306) — the internal
  OLED is wired to the Radeon 890M. So upstream's "prefer dGPU-only" advice
  is simply unavailable here, and the G614JV hybrid run is the governing
  precedent. Two hybrid risks remain live and are handled by the test
  protocol below, not by assumption: (a) a third-party 28e0 report
  (upstream issue #119) found hybrid entry can leave BAR0/MMIO unreadable
  on some BIOSes (Insyde, Acer) — the PX13's AMI BIOS is untested, and
  `loader.log` is where that would show; (b) some MUX-less laptops lose
  the unlock after OS handoff — the `ssdiag` + benchmark pair is how we
  will know.
- Sustained gains are bounded by this card's **55 W** limit — expect the
  microbenchmark gain, not a promise, and less under sustained load.

## What was built, and how (process record)

1. Forked upstream to `SuperInstance/nv-uefi-unlocker` (2026-11-01).
2. Probed the target hardware as above before touching the build —
   the device ID, BDF and Secure Boot state in this file are measurements,
   not assumptions.
3. Built from source on an x86_64 Linux host (Rust 1.99.1):
   `rustup target add x86_64-unknown-uefi` → `cargo build --release` →
   `cargo efi-tx`.
4. Verified the artifact before packaging:
   `python3 check_efi.py loader.efi` → **TX build**, 335,872 bytes,
   SHA-256 `41a5ca8eee259b0bcead34d70930174e423c4095ab4f42a54b93a46d16a6387f`.
   Test suite: `cargo test --release` → **121 passed, 0 failed**.
5. Generated the family-40 asset set with the pinned inputs
   (NVIDIA 610.43.03; the maker verifies SHA-256 and hard-fails on any
   mismatch — no version substitution):
   `bash release/make-usbroot.sh --family 40 --assets ./target/release/assets --boot-efi ./target/x86_64-unknown-uefi/release/loader.efi`
6. Assembled a stick layout containing **only** the runtime files for the
   Ada family (the maker's intermediate duplicates stay off the stick),
   plus this machine's markers (below). Full per-file hashes in
   [SHA256SUMS.txt](SHA256SUMS.txt); boot instructions in
   [README-PROART.txt](README-PROART.txt).
7. Per upstream's asset discipline, **no NVIDIA-derived `.bin` files are
   committed to git** — they are regenerated locally by step 5, and this
   branch records their hashes instead.

## Machine-specific markers on the stick

| File | Content | Why for this machine |
| --- | --- | --- |
| `tx-select-bdf.txt` | `c4:00.0` | Pin the transaction to the 4050 alone (bus 196). With an AMD iGPU also present, never let the loader pick by order. |
| `tx-quiet.txt` | (empty) | Verdict-lines-only console. The internal display is iGPU-rendered in hybrid mode, and upstream notes slow iGPU consoles turn minutes of echo into seconds with quiet on. |

Deliberately **not** included: `i_know_what_i_am_doing.txt` (auto-run) —
the manual Space/Enter confirm stays, per the project's safety posture.

## Reproduce

```bash
bash machines/proart-px13-4050/build.sh   # builds, verifies, assembles ./out/proart-px13-4050-usb/
```

Then copy the contents of `out/proart-px13-4050-usb/` to a FAT32 stick root
and follow [README-PROART.txt](README-PROART.txt).

## Test protocol (the first real-machine run)

Ordered so each step's evidence survives a failure at the next one.
Read-back is the only success criterion at every stage.

1. **Baseline (before any unlock attempt).** In WSL: `preflight.sh`, then
   `bench_tensor.py --label stock`. Commit the JSON to `results/`.
   Without a same-instrument baseline, an "unlocked" number proves nothing.
2. **Preflight (Windows).** `preflight.ps1` — all hard checks PASS.
3. **BIOS step (Casey, at the desk).** Disable Secure Boot. (There is no
   GPU-mode step: this machine has no MUX — see above.)
4. **Stick boot.** Restart (not Shut down) → one-time boot menu → USB →
   Space/Enter at the version screen. Photograph the verdict lines if
   they scroll; `loader.log` lands on the stick either way.
5. **Windows read-back.** `ssdiag-x86_64-windows.exe` from the upstream
   release: selectors must read back unlocked. Save its output.
6. **Bench pair.** `bench_tensor.py --label unlocked` in the *same*
   environment the baseline used, same sizes, same power state (AC,
   same Windows power mode). Commit JSON + `loader.log` + ssdiag output
   to `results/` as one evidence set.
7. **Failure rule.** STOP/fault/stuck screen at any point: do **not**
   retry in the session. Full power-off, stick out, normal boot, and the
   log is analysed before any second attempt.

## Open questions (this machine, specifically)

| # | Question | Answered by |
| --- | --- | --- |
| Q1 | Does the transaction complete on the PX13's AMI BIOS in hybrid mode (BAR0 readable at entry)? | First stick boot; `loader.log` |
| Q2 | Does the unlock survive Windows driver handoff on a MUX-less AMD-hybrid laptop? | `ssdiag` read-back in step 5 |
| Q3 | Is the unlock visible to compute inside **WSL2** (Windows host driver owns the GPU there)? | Bench pair run in WSL; if WSL shows no gain while native Windows does, that is the answer, and it routes future 4050 AI work to native Windows/Linux boots |
| Q4 | Which external port, if any, is wired to the dGPU (HDMI 2.1 vs USB4 DP)? A dGPU-wired external display would give the loader a direct GOP console. | Test with an external monitor + `loader.log` GOP notes |
| Q5 | How much of the GEMM gain survives sustained load inside the 55 W envelope? | Timed bench at 8192 vs a longer soak variant |

## R&D log

- **2026-11-01** — Profile created. Hardware probed live (SSH/WSL +
  Windows CIM/PnP + registry): device `28A1`, subsystem `1043:1ED3`,
  VBIOS 95.07.44.00.63, bus 196, Secure Boot on. Loader built from source
  (TX-verified, 121 tests green), family-40 assets generated from pinned
  inputs, stick assembled and hash-verified. See "What was built" above.
- **2026-11-01** — BDF pin format verified against loader source:
  `parse_bdf()` in `loader/src/pci.rs` parses every field as **hex**
  (`from_str_radix(_, 16)`), so bus 196 is pinned as `c4:00.0`. A decimal
  pin would have matched nothing — the loader refuses to guess and skips,
  which is safe but would have read as a mysterious no-op.
- **2026-11-01** — MUX question closed by specification, not assumption:
  ASUS's HN7306 spec lists no MUX/Advanced Optimus; hybrid-only. Docs and
  protocol corrected accordingly (earlier text said "dGPU-only if offered"
  — it is not offered).
- **2026-11-01** — Tooling added: hardened `build.sh` (stage gates +
  self-hash-check), `preflight.ps1` / `preflight.sh` (read-only,
  expected-value checks), `bench_tensor.py` (FP16/BF16/TF32 GEMM,
  FP32-accumulate — the exact paths the unlock governs).
- **2026-11-01** — Rebuild determinism verified: a second full
  `build.sh` run produced a stick **byte-identical** to the first
  (all SHA-256 sums match, including BOOTX64.EFI `41a5ca8e…`). The
  build is reproducible from source + pinned inputs, as designed.
- **2026-11-01** — Stock baseline measured on the target in WSL2
  (`results/2026-11-01-stock-baseline/`): FP16 21.4/23.7, BF16 25.1/24.4,
  TF32 12.0/11.3 TFLOPS (4096³/8192³). Consistent with the half-rate cap;
  the unlocked run now has something honest to be compared against.
- **2026-11-01** — `preflight.ps1` caught by its own first run: Windows
  PowerShell 5.1 reads BOM-less files as ANSI, so the UTF-8 em-dashes in
  the first draft corrupted string literals and the script did not parse.
  Fixed by making the script **pure ASCII** (also the right default for
  any PS 5.1 tooling). Lesson recorded because it is exactly the kind of
  bug that only a real run on the real shell finds.

## Casey-only steps (cannot be done remotely)

1. Disable Secure Boot in BIOS setup (currently enabled), or enrol a
   self-signed cert.
2. Boot the stick from the one-time boot menu, press Space/Enter, and after
   Windows loads run `ssdiag-x86_64-windows.exe` from the upstream release
   to read back the unlock state.

## Risks (unchanged from upstream, restated for this machine)

- Experimental, 1-week-old upstream project; nothing is flashed and
  power-off clears the unlock, but the transaction runs before any OS
  protection exists. On STOP/fault/stuck black screen: **do not retry in
  the same session** — full power-off, remove stick, boot normally.
- Secure Boot stays off (or self-signed trust stays enrolled) for as long
  as this is used; anti-cheat titles that require Secure Boot will not run
  in that configuration.
- Extra tensor throughput arrives as extra power/heat inside a 55 W
  thin-and-light chassis; watch thermals on sustained loads.
