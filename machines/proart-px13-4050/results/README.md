# results/ — experiment evidence

One folder per test-boot session, named `YYYY-MM-DD-<label>/`, containing
the complete evidence set for that session:

| File | What it proves |
| --- | --- |
| `bench-<label>.json` | `bench_tensor.py` output (stock baseline or unlocked run) |
| `loader.log` | Copied from the stick after the boot — the transaction's own stage record |
| `ssdiag.txt` | Windows-side read-back of the selector state after handoff |
| `notes.md` | Session facts: BIOS changes made, display used, power mode, anything unusual |

Rules (from the profile's test protocol):

- A bench number without its same-session `loader.log` and read-back is a
  claim, not a result — file them together or not at all.
- The stock baseline is run **before** the first unlock attempt, with the
  same instrument, sizes, and power state as the unlocked run it will be
  compared against.
- Failed sessions are filed too, with the failure in `notes.md`. A clean
  negative is a result.
