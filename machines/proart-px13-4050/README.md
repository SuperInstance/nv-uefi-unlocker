# ProArt PX13 · RTX 4050 Laptop (28a1) — machine profile

Everything in this folder tailors [nv-uefi-unlocker](../../README.en.md) to
one specific laptop: Casey's **ASUS ProArt PX13 HN7306WU** and its
**RTX 4050 Laptop GPU (PCI 10DE:28A1, BDF c4:00.0)**. If your machine is
not that machine, start from the upstream README instead — the constants
here are measured facts about this unit, not general settings.

## Quick start

| Step | Where | What |
| --- | --- | --- |
| 1. Preflight | Windows | `preflight.ps1` — re-checks device ID, BDF pin, Secure Boot |
| 2. Baseline | WSL | `preflight.sh`, then `bench_tensor.py --label stock` |
| 3. Build | any Linux host | `build.sh` — builds, verifies, assembles the stick layout |
| 4. Test boot | at the desk | disable Secure Boot → boot stick → Space/Enter → Windows |
| 5. Verify | Windows + WSL | `ssdiag` read-back, then `bench_tensor.py --label unlocked` |

Full protocol, decision points, and recovery: [PROFILE.md](PROFILE.md).

## Files

| File | Purpose |
| --- | --- |
| `PROFILE.md` | The record: probed hardware, build process, R&D log, open questions, test protocol, risks |
| `build.sh` | Reproducible build: source → verified TX loader → pinned firmware set → hash-checked stick layout |
| `preflight.ps1` | Windows-side read-only check (device ID, subsystem, BDF, Secure Boot, BIOS/driver) |
| `preflight.sh` | WSL-side read-only check (device ID, VBIOS, driver, power via nvidia-smi) |
| `bench_tensor.py` | FP16/BF16/TF32 GEMM benchmark — the before/after evidence instrument |
| `tx-select-bdf.txt` | Stick marker pinning the transaction to `c4:00.0` (hex; the loader parses hex) |
| `tx-quiet.txt` | Stick marker: verdict-lines-only console (the iGPU-rendered console is slow) |
| `README-PROART.txt` | Plain-text instructions that live on the stick itself |
| `SHA256SUMS.txt` | Hashes of the generated stick files from the reference build (firmware is regenerated locally, never committed) |
| `results/` | Bench JSON pairs (stock vs unlocked) as experiments are run |

## The one-paragraph version

Upstream silicon-verified this exact device ID (28a1) at 1.7–1.9× on tensor
GEMMs. This profile pins the loader to the card, documents that the PX13
has **no MUX** (hybrid output is the only mode — the same mode upstream's
28a1 bench ran in), records a stock baseline before any unlock attempt,
and treats read-back — never a status code — as the only proof it worked.
