"""Exhaust all six twiddle schedules, then test bubbles and in-flight reset."""
from pathlib import Path
import subprocess
import sys
import os
P = Path(__file__).resolve().parents[1]
os.chdir(P)
subprocess.run([sys.executable, 'sim/twiddle_vectors.py'], check=True)
for logn in (13, 11, 9, 7, 5, 3):
    output = f'sim/tb_twiddle_{logn}.vvp'
    subprocess.run(['iverilog', '-g2012', '-s', 'tb_twiddle',
                    f'-Ptb_twiddle.LOGN={logn}',
                    f'-Ptb_twiddle.ROM_FILE="data/sin_tw_{1 << logn}.hex"',
                    f'-Ptb_twiddle.MIF_FILE="data/sin_tw_{1 << logn}.mif"', '-o', output,
                    'rtl/fft_twiddle_rom.v', 'rtl/r22_twiddle.v', 'sim/tb_twiddle.v'], check=True)
    subprocess.run(['vvp', output], check=True)
