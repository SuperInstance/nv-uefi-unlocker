# Session: 2026-11-01 — stock baseline (no unlock attempted)

Purpose: same-instrument baseline for the future unlocked run
(test protocol step 1 in PROFILE.md). Measured on the target machine
itself, in WSL2, over SSH. No stick was booted; the GPU is in its
factory state.

| Fact | Value |
| --- | --- |
| Environment | WSL2 (Ubuntu 26.04) on Windows 11 build 26300 |
| Driver | 616.92 · torch 2.14.1+cu126 (~/ml/.venv) |
| Instrument | `bench_tensor.py` (FP16/BF16/TF32 GEMM, FP32 accumulate, CUDA-event timed, 10 warmup + 30 timed iters) |
| Preflight | `preflight.sh` PASS (device id 0x28A110DE) |

## Numbers (`bench-stock.json`)

| Path | 4096³ | 8192³ |
| --- | --- | --- |
| FP16 | 21.42 TFLOPS | 23.71 TFLOPS |
| BF16 | 25.07 TFLOPS | 24.41 TFLOPS |
| TF32 | 12.02 TFLOPS | 11.33 TFLOPS |

Notes:

- The unlocked comparison run must reuse this exact environment (WSL,
  same venv) — which also makes it the Q3 experiment (is the unlock
  visible inside WSL2 at all?).
- Power state during this run was not instrumented; the card's default
  limit is 55 W. If the unlocked run is taken under different power
  conditions, that difference belongs in its session notes.
- FP16 at ~24 TFLOPS is consistent with the half-rate tensor cap this
  tool exists to remove; the field record for this device ID predicts
  roughly 1.7–1.9× if the unlock holds through handoff.
