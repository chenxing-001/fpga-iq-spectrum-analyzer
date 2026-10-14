"""Verify intentional latency changes against independent math and frozen18 RTL."""
from pathlib import Path
import os
import subprocess
import sys

P = Path(__file__).resolve().parents[1]
os.chdir(P)

def test(name, sources, params=(), suffix=''):
    out = f'sim/{name}{suffix}.vvp'
    subprocess.run(['iverilog', '-g2012', '-Wall', '-I', 'rtl', '-s', name,
                    *params, '-o', out, *sources, f'sim/{name}.v'], check=True)
    subprocess.run(['vvp', out], check=True)

rtl = [str(x) for x in sorted(Path('rtl').glob('*.v'))]
test('tb_power_sum24_pipe', ['rtl/power_sum24_pipe.v'])
test('tb_power_front', ['rtl/square12_pipe.v', 'rtl/power_sum24_pipe.v'])
test('tb_peak_interleaved', ['rtl/peak_interleaved.v'])
test('tb_peak_rev16', ['rtl/peak_interleaved.v', 'sim/reference/peak_interleaved_rev15.v'])
subprocess.run([sys.executable, 'sim/twiddle_vectors.py'], check=True)
for logn in (13, 11, 9, 7, 5, 3):
    tb = 'tb_twiddle_rev19'
    test(tb, ['rtl/fft_twiddle_rom.v', 'rtl/r22_twiddle.v', 'sim/reference/r22_twiddle_rev18.v'],
         [f'-P{tb}.LOGN={logn}', f'-P{tb}.ROM_FILE="data/sin_tw_{1<<logn}.hex"',
          f'-P{tb}.MIF_FILE="data/sin_tw_{1<<logn}.mif"'], f'_{logn}')
test('tb_revision19', rtl + [f'sim/reference/{n}_rev18.v' for n in
     ('snapshot_analyzer', 'peak_interleaved', 'power_encode_pipe')])
# Baud terminal and packet payload remain cycle-exact; preserve all widths.
subprocess.run([sys.executable, 'sim/uart_vectors.py'], check=True)
for cpb in (1, 2, 3, 17, 1736, 65536):
    tb = 'tb_uart_rev16'
    test(tb, ['rtl/uart_packet.v', 'sim/reference/uart_packet_rev15.v'],
         [f'-P{tb}.CPB={cpb}', f'-P{tb}.RESET_TESTS={int(cpb==1)}',
          f'-P{tb}.SHORT_TEST={int(cpb>=1736)}'], f'_{cpb}')
print('PASS revision19 arithmetic/latency/reference regression', flush=True)
