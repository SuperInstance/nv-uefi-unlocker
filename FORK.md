# About this fork

`SuperInstance/nv-uefi-unlocker` is a fork of
[physicsdolphin/nv-uefi-unlocker](https://github.com/physicsdolphin/nv-uefi-unlocker)
that carries one addition: a **machine profile** for a specific laptop we
own and test on.

| | |
| --- | --- |
| Machine | ASUS ProArt PX13 HN7306WU |
| GPU | GeForce RTX 4050 Laptop, PCI `10DE:28A1`, BDF `c4:00.0` |
| Profile | [`machines/proart-px13-4050/`](machines/proart-px13-4050/README.md) |
| Branch | `proart-px13-4050` |

Everything else is upstream's work, kept as close to upstream `main` as
possible so the fork rebases cleanly: the loader, the asset pipeline, the
simulator, and the docs are theirs (GPL-2.0-only, as is this fork).

What the profile adds:

- probed hardware facts for the target unit (device/subsystem IDs, VBIOS,
  PCI location, BIOS, Secure Boot state — measured, not spec-sheet);
- a reproducible, hash-verifying `build.sh` and read-only preflight
  scripts for both sides of the machine (Windows and WSL);
- a tensor GEMM benchmark so the unlock's effect is measured on the exact
  operation it changes, before and after, on this card;
- an R&D log and test protocol that record what was tried and what the
  read-backs said — including the open questions (this laptop has no MUX;
  whether the unlock survives hybrid handoff, and whether it is visible
  inside WSL2, are answered by experiment, not assumed).

Start at the [profile README](machines/proart-px13-4050/README.md).
