"""Bit-level protocol, CRC, signed data, baud timing and reset regression."""
from pathlib import Path
import os
import subprocess
import sys

P = Path(__file__).resolve().parents[1]
os.chdir(P)
subprocess.run([sys.executable, 'sim/uart_vectors.py'], check=True)
for divisor, frames, resets in ((1, 20, 1), (2, 20, 0), (4, 20, 0), (17, 20, 0), (1736, 1, 0)):
    output = f'sim/tb_uart_regression_{divisor}.vvp'
    subprocess.run(['iverilog', '-g2012', '-s', 'tb_uart_regression',
                    f'-Ptb_uart_regression.CPB={divisor}',
                    f'-Ptb_uart_regression.FRAMES={frames}',
                    f'-Ptb_uart_regression.RESET_TESTS={resets}',
                    '-o', output, 'rtl/uart_packet.v', 'sim/tb_uart_regression.v'], check=True)
    subprocess.run(['vvp', output], check=True)
