"""Rev21 D=8 feedback and full FFT comparisons against uploaded frozen20 RTL."""
from pathlib import Path
import os
import subprocess

P = Path(__file__).resolve().parents[1]
os.chdir(P)
rtl = [str(p) for p in sorted(Path('rtl').glob('*.v'))]
refs = ['sim/reference/sdf_butterfly_rev20.v', 'sim/reference/fft8192_stream_rev20.v']
for tb, parameters, suffix in [
    ('tb_butterfly_rev21', ['-Ptb_butterfly_rev21.ROTATE=0'], '_r0'),
    ('tb_butterfly_rev21', ['-Ptb_butterfly_rev21.ROTATE=1'], '_r1'),
    ('tb_fft_rev21', [], ''),
]:
    out = f'sim/{tb}{suffix}.vvp'
    subprocess.run(['iverilog', '-g2012', '-Wall', '-I', 'rtl', '-s', tb,
                    *parameters, '-o', out, *rtl, *refs, f'sim/{tb}.v'], check=True)
    subprocess.run(['vvp', out], check=True)
print('PASS revision21 frozen20 D8 / full FFT data and metadata regression', flush=True)
