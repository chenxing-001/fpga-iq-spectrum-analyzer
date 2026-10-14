"""Exhaustive integer arithmetic checks for revision23's proposed real combine.

This is an arithmetic model check, NOT Verilog simulation or synthesis. Run
test_revision23.py with Icarus for actual DUT/reference cycle comparisons.
"""
from pathlib import Path
import json
import numpy as np

P = Path(__file__).resolve().parents[1]

# All low operand pairs. Derive the borrow from the actual 12-bit subtraction
# identity, and compare to an independent unsigned ordering relation.
low_pairs = 0
b = np.arange(2048, dtype=np.int64)[None, :]
for start in range(0, 2048, 128):
    a = np.arange(start, start + 128, dtype=np.int64)[:, None]
    low_diff = (a - b) & 0xFFF
    borrow = low_diff >> 11
    assert np.array_equal(borrow, (a < b).astype(np.int64))
    old_carry = (a + (b ^ 0x7FF) + 1) >> 11
    assert np.all(borrow + old_carry == 1)
    low_pairs += a.shape[0] * b.shape[1]
print(f'PASS arithmetic model: all {low_pairs:,} low-11 operand pairs', flush=True)

# All high operand pairs, both borrowed and unborrowed cases. The oracle is a
# full-width subtraction followed by arithmetic shift and 12-bit truncation.
# A low operand pair (0, 1) supplies borrow=1; (0, 0) supplies borrow=0.
high_cases = 0
b = np.arange(4096, dtype=np.int64)[None, :]
for start in range(0, 4096, 128):
    a = np.arange(start, start + 128, dtype=np.int64)[:, None]
    high_without_borrow = (a - b) & 0xFFF
    high_with_borrow = (a + (b ^ 0xFFF)) & 0xFFF
    for borrow, candidate in ((0, high_without_borrow), (1, high_with_borrow)):
        reference = (((a << 11) - ((b << 11) | borrow)) >> 11) & 0xFFF
        assert np.array_equal(candidate, reference)
        high_cases += a.shape[0] * b.shape[1]
print(f'PASS arithmetic model: all {high_cases:,} high-12 / borrow cases', flush=True)

# Full signed 26-bit values include discarded high bits, negative arithmetic
# shifts and modulo wraparound. This does not substitute for a clocked test.
rng = np.random.default_rng(2300123)
random_cases = 0
for _ in range(16):
    x = rng.integers(-(1 << 25), 1 << 25, 65536, dtype=np.int64)
    y = rng.integers(-(1 << 25), 1 << 25, 65536, dtype=np.int64)
    borrow = (((x & 0x7FF) - (y & 0x7FF)) & 0xFFF) >> 11
    xhi = (x >> 11) & 0xFFF
    yhi = (y >> 11) & 0xFFF
    candidate = np.where(borrow, xhi + (yhi ^ 0xFFF), xhi - yhi) & 0xFFF
    reference = ((x - y) >> 11) & 0xFFF
    assert np.array_equal(candidate, reference)
    random_cases += len(x)
print(f'PASS arithmetic model: {random_cases:,} full signed 26-bit pairs', flush=True)

result = dict(
    status='PASS', kind='Python integer arithmetic model, not RTL simulation',
    low_operand_pairs=low_pairs, high_operand_and_borrow_cases=high_cases,
    full_signed_random_pairs=random_cases, seed=2300123,
    rtl_simulation_run=False, quartus_run=False,
)
(P / 'docs/revision23_arithmetic.json').write_text(json.dumps(result, indent=2) + '\n')
print('RTL cycle equivalence and fitted timing remain UNVERIFIED.', flush=True)
