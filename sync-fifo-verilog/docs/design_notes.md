# Design Notes — Synchronous FIFO

## The FULL vs EMPTY problem

With a simple circular buffer, both `wr_ptr == rd_ptr` (empty) and a
completely full buffer can look identical if pointers only track the
memory address, because after wrapping around, a full buffer's write
pointer catches back up to the read pointer.

## The fix: one extra "wrap" bit

Make each pointer **one bit wider** than needed to address the memory
(`ADDR_WIDTH + 1` bits instead of `ADDR_WIDTH`).

- The lower `ADDR_WIDTH` bits still address the memory array (0 to DEPTH-1).
- The extra MSB toggles every time the pointer wraps around the array.

This gives two easily distinguishable pointer relationships:

| Condition                                              | Meaning |
|----------------------------------------------------------|---------|
| `wr_ptr == rd_ptr` (all bits equal, including MSB)        | **EMPTY** — no wraps happened between reads/writes |
| Lower bits equal, but MSBs differ                          | **FULL** — write pointer has wrapped exactly one more time than read pointer |

### Worked example (DEPTH = 4, ADDR_WIDTH = 2, pointers are 3 bits)

| Step            | wr_ptr | rd_ptr | Status |
|-----------------|--------|--------|--------|
| Reset             | 000    | 000    | empty (equal, same MSB) |
| Write x4          | 100    | 000    | full (lower bits `00`=`00`, MSBs `1`≠`0`) |
| Read x4            | 100    | 100    | empty again (fully equal) |

The MSB is effectively a "lap counter" — it tells you whether the write
side has lapped the read side exactly once. Without it, `100` (after
one wrap) and `000` (before any writes) would be indistinguishable if
you only compared the lower 2 bits.

## Verification approach

Rather than trusting a hand-drawn waveform, the testbench uses three
layers of checking:

1. **Directed edge cases** — fill to FULL and confirm an overflow write
   is silently dropped (data not corrupted); drain to EMPTY and confirm
   an underflow read is dropped.
2. **Data-order check** — confirms first-in-first-out ordering is
   preserved, not just that flags behave correctly.
3. **Randomized cross-check** — 500 cycles of random read/write
   combinations, with every read compared against a software reference
   queue model built in the testbench itself. This catches subtle
   pointer bugs that directed tests alone would miss.

Result: 166/166 automated checks passed (0 failures).
