"""Rev23 borrow selection: independent arithmetic, frozen22 twiddles and FFT."""
from pathlib import Path
import os
import shutil
import subprocess
import sys

P = Path(__file__).resolve().parents[1]
os.chdir(P)
missing = [tool for tool in ('iverilog', 'vvp') if shutil.which(tool) is None]
if missing:
    raise SystemExit('BLOCKED: missing ' + ', '.join(missing) +
                     '; no revision23 RTL simulation was run.')

def test(tb, sources, params=(), suffix=''):
    out = f'sim/{tb}{suffix}.vvp'
    subprocess.run(['iverilog', '-g2012', '-Wall', '-I', 'rtl', '-s', tb,
                    *params, '-o', out, *sources, f'sim/{tb}.v'], check=True)
    subprocess.run(['vvp', out], check=True)

twiddle = ['rtl/fft_twiddle_rom.v', 'rtl/r22_twiddle.v']
test('tb_combine_rev23', twiddle)
subprocess.run([sys.executable, 'sim/twiddle_vectors.py'], check=True)
for logn in (13, 11, 9, 7, 5, 3):
    tb = 'tb_twiddle_rev23'
    test(tb, twiddle + ['sim/reference/r22_twiddle_rev22.v'],
         [f'-P{tb}.LOGN={logn}', f'-P{tb}.ROM_FILE="data/sin_tw_{1<<logn}.hex"',
          f'-P{tb}.MIF_FILE="data/sin_tw_{1<<logn}.mif"'], f'_{logn}')
test('tb_fft_rev23', [str(p) for p in sorted(Path('rtl').glob('*.v'))] +
     ['sim/reference/r22_twiddle_rev22.v', 'sim/reference/fft8192_stream_rev22.v'])
print('PASS revision23 independent combine / frozen22 twiddles / full FFT regression', flush=True)
