"""Revision20: direct frozen19 equivalence and independent control arithmetic."""
from pathlib import Path
import os
import subprocess

P = Path(__file__).resolve().parents[1]
os.chdir(P)
rtl = [str(x) for x in sorted(Path('rtl').glob('*.v'))]
references = [f'sim/reference/{n}_rev19.v' for n in ('snapshot_analyzer', 'peak_interleaved')]
for name, extra in [('tb_peak_rev20', ['sim/reference/peak_interleaved_rev19.v']),
                    ('tb_control_rev20', []), ('tb_revision20', references)]:
    out = f'sim/{name}.vvp'
    subprocess.run(['iverilog', '-g2012', '-Wall', '-I', 'rtl', '-s', name,
                    '-o', out, *rtl, *extra, f'sim/{name}.v'], check=True)
    subprocess.run(['vvp', out], check=True)
print('PASS revision20 frozen19 snapshots/scan/latency and arithmetic regression', flush=True)
