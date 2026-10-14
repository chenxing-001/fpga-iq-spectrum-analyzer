"""UART/PC regression. Requires numpy and Icarus Verilog 11+ on PATH."""
from pathlib import Path
import argparse
import os
import subprocess
import sys

P = Path(__file__).resolve().parents[1]
os.chdir(P)
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--core-only', action='store_true',
                    help='run common system tests; run test_revision19.py through test_revision23.py separately')
args = parser.parse_args()
def run(cmd):
    # One process owns the log stream, including nested test scripts.
    print('RUN', ' '.join(cmd), flush=True)
    result = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
    print(result.stdout, end='', flush=True)
    result.check_returncode()
def test(tb, params=(), suffix=''):
    out = f'sim/{tb}{suffix}.vvp'
    run(['iverilog', '-g2012', '-I', 'rtl', '-I', 'sim', '-s', tb, *params,
         '-o', out, *[str(x) for x in sorted(Path('rtl').glob('*.v'))], f'sim/{tb}.v'])
    run(['vvp', out])

run([sys.executable, 'scripts/generate.py'])
run([sys.executable, 'sim/model.py'])
for tb in ('tb_fft', 'tb_analyzer', 'tb_uart', 'tb_system',
           'tb_power_encode', 'tb_power_ram', 'tb_power_sum24', 'tb_analyzer_edges'):
    test(tb)
run([sys.executable, 'sim/check_results.py'])
for refresh in (0, 1, 2, 7, 31, 255, 256, 257):
    test('tb_analyzer_cooldown', [f'-Ptb_analyzer_cooldown.REFRESH={refresh}'], f'_{refresh}')
scripts = ['test_twiddle.py', 'test_uart.py', 'test_revision10.py']
if not args.core_only:
    scripts += ['test_revision19.py', 'test_revision20.py', 'test_revision21.py', 'test_revision23.py', 'test_revision23.py']
scripts += ['test_uart_pc.py', 'test_host.py']
for script in scripts:
    run([sys.executable, 'scripts/' + script])
print('PASS revision23 common system regression' if args.core_only else
      'PASS complete revision23 UART/PC regression', flush=True)
