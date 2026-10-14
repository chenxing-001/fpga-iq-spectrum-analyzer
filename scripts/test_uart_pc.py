"""Revision 17 top-level release/reset and complete serial packet checks."""
from pathlib import Path
import os
import subprocess
import sys
import numpy as np

P = Path(__file__).resolve().parents[1]
os.chdir(P)
sys.path.insert(0, str(P / 'host'))
from protocol import decode, SIZE

rtl = [str(p) for p in sorted(Path('rtl').glob('*.v'))]
for refresh in (0, 1, 2, 7):
    out = f'sim/tb_system_rearm_{refresh}.vvp'
    subprocess.run(['iverilog', '-g2012', '-Wall', '-I', 'rtl', '-I', 'sim',
                    '-s', 'tb_system_rearm', f'-Ptb_system_rearm.REFRESH={refresh}',
                    '-o', out, *rtl, 'sim/tb_system_rearm.v'], check=True)
    subprocess.run(['vvp', out], check=True)
    data = bytes(int(b, 16) for b in Path(f'sim/rearm_{refresh}.hex').read_text().split())
    assert len(data) == 3 * SIZE, ('missing bytes', refresh, len(data))
    snapshots = [decode(data[i:i+SIZE]) for i in range(0, len(data), SIZE)]
    phase = np.arange(256) * np.pi / 4
    expected_iq = np.column_stack((np.rint(900*np.cos(phase)), np.rint(900*np.sin(phase))))
    for i, s in enumerate(snapshots):
        assert s.reserved == 0 and s.cycles == 57460
        assert s.peak_bin == 1024 and s.bw_bins == 1 and s.active == 8192
        assert s.longest == 8192 and s.span == 8192 and s.clipped == 3
        assert np.array_equal(s.iq, expected_iq)
        assert np.array_equal(s.spectrum, snapshots[0].spectrum)
        if i:
            assert s.frame > snapshots[i-1].frame
            assert s.skipped == s.frame - snapshots[i-1].frame - 1
    print(f'PASS UART-only PC decode: refresh={refresh}, 3 complete packets, CRC/IQ/spectrum/metadata', flush=True)
print('PASS revision21 UART/PC integration', flush=True)
