#!/usr/bin/env python3
"""
bench_tensor.py — before/after evidence for the tensor-rate unlock.

The unlock changes exactly one thing: the issue rate of Tensor Core
operations that accumulate into FP32 (FP16/BF16/TF32 on GeForce silicon).
A benchmark that hopes to see it must therefore measure large GEMMs in
those precisions — not LLM tokens/s, not image-gen wall time, which are
diluted by memory bandwidth, power limits, and a dozen other things.

Method (kept boring on purpose, so two runs are comparable):
  * square GEMMs at 4096 and 8192 (big enough to saturate tensor cores,
    small enough to fit a 6 GB card alongside nothing else);
  * CUDA-event timing around a fixed iteration count, after warmup;
  * FP16 and BF16 inputs go through torch.matmul (FP32 accumulation is
    PyTorch's default for half-precision GEMM); TF32 uses FP32 inputs
    with torch's TF32 matmul mode enabled explicitly;
  * results are printed as TFLOPS and written to JSON with the GPU name,
    a caller-supplied label (e.g. "stock" / "unlocked"), and a UTC
    timestamp, so the pair of files IS the experiment record.

Usage:
    python3 bench_tensor.py --label stock    --out results/stock.json
    python3 bench_tensor.py --label unlocked --out results/unlocked.json

Requires PyTorch with CUDA. On the ProArt, run it with the ml venv:
    ~/ml/.venv/bin/python bench_tensor.py --label stock
"""

import argparse
import json
import platform
import sys
import time
from datetime import datetime, timezone

import torch

# GEMM sizes and iteration counts. 8192^3 fp16 inputs+outputs peak at
# ~0.5 GB, comfortable in 6 GB with the OS/driver's share already resident.
SIZES = (4096, 8192)
WARMUP_ITERS = 10
TIMED_ITERS = 30


def bench_gemm(size: int, dtype: torch.dtype, use_tf32: bool) -> float:
    """Return sustained TFLOPS for size x size x size GEMM in `dtype`.

    TF32 is not a storage type: it is FP32 storage with 10-bit mantissa
    math inside the tensor core, enabled via the matmul backend flag.
    """
    torch.backends.cuda.matmul.allow_tf32 = use_tf32
    a = torch.randn(size, size, device="cuda", dtype=dtype)
    b = torch.randn(size, size, device="cuda", dtype=dtype)

    for _ in range(WARMUP_ITERS):  # reach steady clocks before timing
        _ = a @ b
    torch.cuda.synchronize()

    start = torch.cuda.Event(enable_timing=True)
    stop = torch.cuda.Event(enable_timing=True)
    start.record()
    for _ in range(TIMED_ITERS):
        _ = a @ b
    stop.record()
    torch.cuda.synchronize()

    seconds = start.elapsed_time(stop) / 1000.0 / TIMED_ITERS
    flops = 2.0 * size**3  # multiply-accumulate = 2 FLOPs per output element pair
    del a, b
    torch.cuda.empty_cache()
    return flops / seconds / 1e12


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[1])
    parser.add_argument("--label", required=True,
                        help="run label recorded in the JSON, e.g. 'stock' or 'unlocked'")
    parser.add_argument("--out", default=None,
                        help="JSON output path (default: bench-<label>.json)")
    args = parser.parse_args()

    if not torch.cuda.is_available():
        print("CUDA is not available to this Python — wrong venv or driver down.",
              file=sys.stderr)
        return 1

    results = {
        "label": args.label,
        "timestamp_utc": datetime.now(timezone.utc).isoformat(),
        "host": platform.node(),
        "gpu": torch.cuda.get_device_name(0),
        "torch": torch.__version__,
        "tflops": {},
    }
    print(f"{results['gpu']} · torch {results['torch']} · label={args.label}")

    # (name, dtype, tf32?) — the three paths the unlock's selectors govern.
    for name, dtype, tf32 in (("fp16", torch.float16, False),
                              ("bf16", torch.bfloat16, False),
                              ("tf32", torch.float32, True)):
        per_size = {}
        for size in SIZES:
            per_size[str(size)] = round(bench_gemm(size, dtype, tf32), 2)
        results["tflops"][name] = per_size
        print(f"  {name:5s} " + "  ".join(f"{s}: {v:.2f} TFLOPS"
                                          for s, v in per_size.items()))

    out_path = args.out or f"bench-{args.label}.json"
    with open(out_path, "w", encoding="utf-8") as fh:
        json.dump(results, fh, indent=2)
    print(f"wrote {out_path} in {time.process_time():.1f}s process time")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
