"""Rev22 split carry: independent arithmetic, frozen21 twiddles and complete FFT."""
from pathlib import Path
import os
import subprocess
import sys

P = Path(__file__).resolve().parents[1]
os.chdir(P)

def test(tb, sources, params=(), suffix=''):
    out = f'sim/{tb}{suffix}.vvp'
    subprocess.run(['iverilog', '-g2012', '-Wall', '-I', 'rtl', '-s', tb,
                    *params, '-o', out, *sources, f'sim/{tb}.v'], check=True)
    subprocess.run(['vvp', out], check=True)

twiddle = ['rtl/fft_twiddle_rom.v', 'rtl/r22_twiddle.v']
test('tb_combine_rev22', twiddle)
subprocess.run([sys.executable, 'sim/twiddle_vectors.py'], check=True)
for logn in (13, 11, 9, 7, 5, 3):
    tb = 'tb_twiddle_rev22'
    test(tb, twiddle + ['sim/reference/r22_twiddle_rev21.v'],
         [f'-P{tb}.LOGN={logn}', f'-P{tb}.ROM_FILE="data/sin_tw_{1<<logn}.hex"',
          f'-P{tb}.MIF_FILE="data/sin_tw_{1<<logn}.mif"'], f'_{logn}')
test('tb_fft_rev22', [str(p) for p in sorted(Path('rtl').glob('*.v'))] +
     ['sim/reference/r22_twiddle_rev21.v', 'sim/reference/fft8192_stream_rev21.v'])
print('PASS revision22 independent combine / frozen21 twiddles / full FFT regression', flush=True)
