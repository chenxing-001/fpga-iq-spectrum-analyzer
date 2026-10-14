"""PC protocol, damaged stream recovery, plots, and CSV/JSON export."""
from pathlib import Path
from types import SimpleNamespace
import json
import sys
import tempfile
import numpy as np

P = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(P / 'host'))
from protocol import Parser, crc16, decode, encode, demo, SIZE, MAGIC
from app import Application, draw_figure
from matplotlib.figure import Figure
from matplotlib.backends.backend_agg import FigureCanvasAgg

assert crc16(b'123456789') == 0x29B1
packets = [encode(demo(100 + mode, mode)) for mode in range(4)]
for mode, packet in enumerate(packets):
    s = decode(packet)
    assert len(packet) == SIZE and s.reserved == 0 and s.mode == mode
    assert encode(s) == packet
    assert s.fs == 200_000_000 and s.n == 8192 and s.cycles == 57460
    if mode == 2:
        assert s.active == 4096 and s.longest == 4096 and s.span == 4096
        assert np.count_nonzero(s.iq) == 0

bad = bytearray(packets[0]);bad[200] ^= 1
bad_version = bytearray(packets[0]);bad_version[4] = 99
bad_length = bytearray(packets[0]);bad_length[6:8] = b'\x00\x00'
stream = b'garbage' + bad + bad_version + bad_length + b''.join(packets)
for chunk in (1, 3, 17, 1329, 4096):
    parser = Parser();frames = []
    for offset in range(0, len(stream), chunk):
        frames.extend(parser.feed(stream[offset:offset+chunk]))
    assert [s.frame for s in frames] == [100, 101, 102, 103]
    assert parser.errors >= 3
    assert len(parser.buffer) < SIZE
legacy = bytearray(packets[0]);legacy[42:44] = b'\x42\x43'
legacy[-2:] = crc16(legacy[:-2]).to_bytes(2, 'little')
assert decode(legacy).reserved == 0x4342
print('PASS PC parser: 4 modes, CRC, fragmented/noisy/bad-version/bad-length recovery, legacy reserved bytes', flush=True)

with tempfile.TemporaryDirectory(dir=P / 'sim') as folder:
    folder = Path(folder)
    for mode, packet in enumerate(packets):
        s = decode(packet)
        fig = Figure(figsize=(12, 7), dpi=100);FigureCanvasAgg(fig)
        axes = draw_figure(fig, s);fig.savefig(folder / f'mode_{mode}.png')
        assert len(axes[0].lines[0].get_xdata()) == 256
        assert len(axes[1].lines[0].get_xdata()) == 256
    target = folder / 'test_frame.json'
    statuses = []
    errors = []
    context = SimpleNamespace(snapshot=decode(packets[1]), snapshot_source='hardware',
        filedialog=SimpleNamespace(asksaveasfilename=lambda **kw: str(target)),
        status=SimpleNamespace(set=statuses.append),
        messagebox=SimpleNamespace(showerror=lambda *args: errors.append(args)))
    Application.export(context)
    assert not errors and statuses
    meta = json.loads(target.read_text(encoding='utf-8'))
    assert meta['source'] == 'hardware' and meta['reserved'] == 0 and meta['frame'] == 101
    time_data = np.loadtxt(folder / 'test_frame_time.csv', delimiter=',', skiprows=1)
    freq_data = np.loadtxt(folder / 'test_frame_spectrum.csv', delimiter=',', skiprows=1)
    assert time_data.shape == (256, 3) and freq_data.shape == (256, 3)
    assert np.array_equal(time_data[:, 1:], context.snapshot.iq)
    assert np.isclose(time_data[1, 0] - time_data[0, 0], 5e-9, rtol=1e-12, atol=0)
    assert np.array_equal(freq_data[:, 1], context.snapshot.spectrum)
print('PASS PC plots (4 modes) and hardware-tagged CSV/JSON export', flush=True)

try:
    import serial
except ImportError:
    print('SKIP optional serial loopback: install host/requirements.txt', flush=True)
else:
    with serial.serial_for_url('loop://', baudrate=115200, timeout=1) as port:
        assert port.write(packets[0]) == SIZE
        raw = port.read(SIZE)
        assert raw == packets[0] and decode(raw).frame == 100
    print('PASS pyserial loopback (software transport; not a board test)', flush=True)
