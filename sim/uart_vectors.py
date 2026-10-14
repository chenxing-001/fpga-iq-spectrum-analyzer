"""Deterministic UART fixtures, independently encoded by the PC protocol.

The first 16 frames exhaust both signed 12-bit IQ domains and all 16 flag
combinations. Metadata includes zero, maximum-width, checkerboard and random
values. CRC references come from Python's binascii.crc_hqx, not the RTL.
"""
from pathlib import Path
import sys
import numpy as np

P = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(P / 'host'))
from protocol import Snapshot, encode, decode

FRAMES = 20
rng = np.random.default_rng(20261011)
packets = []
for frame in range(FRAMES):
    def value(width):
        if frame == 0:
            return 0
        if frame == 15:
            return (1 << width) - 1
        if frame in (1, 2):
            return (0xAAAAAAAAAA if frame == 1 else 0x5555555555) & ((1 << width) - 1)
        return int(rng.integers(0, 1 << width))

    if frame < 16:
        i = np.arange(256) + frame * 256 - 2048
        iq = np.column_stack((i, -1 - i))
    elif frame == 16:
        iq = np.zeros((256, 2), dtype=np.int16)
    elif frame == 17:
        iq = np.tile([[-2048, 2047], [2047, -2048]], (128, 1))
    else:
        iq = rng.integers(-2048, 2048, (256, 2))
    spectrum = np.arange(256, dtype=np.uint8) if frame == 0 else rng.integers(0, 256, 256, dtype=np.uint8)
    snapshot = Snapshot(
        frame=value(32), fs=200_000_000, n=8192, mode=frame & 3,
        clipped=(frame >> 2) & 3, peak_bin=value(13), bw_bins=value(14),
        active=value(14), span=value(14), longest=value(14),
        time_peak_power=value(25), energy=value(38), peak_code=value(8),
        cycles=value(32), reserved=value(16), skipped=value(32),
        iq=iq.astype(np.int16), spectrum=spectrum)
    packet = encode(snapshot)
    assert encode(decode(packet)) == packet
    packets.append(packet)
(P / 'sim/uart_reference.hex').write_text(
    ''.join(f'{byte:02x}\n' for packet in packets for byte in packet))
print(f'UART reference: {FRAMES} packets; all 4096 I/Q codes and 16 flag combinations')
