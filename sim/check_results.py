from pathlib import Path
import sys
import numpy as np
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'host'))
from protocol import encode_power,Parser,decode,encode,demo
from model import vectors
p=Path(__file__).resolve().parent
expected=np.load(p/'expected.npy');rows=np.loadtxt(p/'rtl_fft.csv',delimiter=',',dtype=np.int64);actual=np.zeros_like(expected)
assert len(rows)==expected.size
for f,b,r,i in rows:actual[f,b]=r+1j*i
assert np.array_equal(actual,expected),'FFT mismatch'
print(f'PASS FFT {expected.size} exact complex samples, 7 consecutive frames')
metrics=np.loadtxt(p/'metrics.csv',delimiter=',',dtype=np.int64);curves=np.loadtxt(p/'curves.csv',delimiter=',',dtype=np.int64);traces=np.loadtxt(p/'time.csv',delimiter=',',dtype=np.int64)
rev=np.array([int(f'{j:013b}'[::-1],2) for j in range(8192)])
analyzer_expected=np.load(p/'analyzer_expected.npy')
for j,x in enumerate(vectors()+[np.zeros(8192,dtype=complex)]*3):
 power=(analyzer_expected[j].real.astype(np.int64)**2+analyzer_expected[j].imag.astype(np.int64)**2).astype(np.uint64);c=encode_power(power)
 peak=int(rev[np.argmax(power[rev])]);threshold=max(1,int(encode_power(power[peak]//np.uint64(2))))
 width=0
 if power[peak]:
  width=1
  for direction in (1,-1):
   k=(peak+direction)%8192
   while width<8192 and c[k]>=threshold:width+=1;k=(k+direction)%8192
 tp=x.real.astype(np.int64)**2+x.imag.astype(np.int64)**2;active=tp>65536;idx=np.flatnonzero(active);run=best=0
 for a in active:run=run+1 if a else 0;best=max(best,run)
 exp=np.array([j,peak,width,int(active.sum()),int(idx[-1]-idx[0]+1) if len(idx) else 0,best,int(power[peak]),int(tp.max()),int(tp.sum()),int(c[peak]),int(active[0])+2*int(active[-1])])
 assert np.array_equal(exp,metrics[j,:-1]),(j,exp,metrics[j])
 assert 0<metrics[j,-1]<=400000,('2 ms analysis limit at 200 MHz',j,metrics[j,-1])
 assert np.array_equal(curves[curves[:,0]==j,2],np.fft.fftshift(c).reshape(256,32).max(axis=1)),('curves',j)
 assert np.array_equal(traces[traces[:,0]==j,2:],np.column_stack((x.real[:256],x.imag[:256])).astype(int)),('time',j)
 print(f'PASS analyzer frame={j} peak={peak} BW={width} latency={metrics[j,-1]} cycles')
packet=bytes(int(h,16) for h in (p/'uart_bytes.hex').read_text().split());s=decode(packet)
assert s.frame==42 and s.mode==1 and s.clipped==3 and s.skipped==99 and s.fs==200_000_000
assert s.peak_bin==1024 and s.energy==8294400000 and s.reserved==0x4342
assert np.array_equal(s.iq[:,0],np.arange(256)) and np.array_equal(s.iq[:,1],-np.arange(256))
assert np.array_equal(s.spectrum,np.arange(256));assert encode(s)==packet
parser=Parser();bad=bytearray(packet);bad[200]^=1;stream=b'noise'+bad+packet+packet
result=[]
for start in range(0,len(stream),17):result+=parser.feed(stream[start:start+17])
assert len(result)==2 and parser.errors>=1
assert decode(encode(demo(mode=2))).active==4096
print('PASS UART bit-level decode, 1330 bytes, CRC, endianness, signs, fragmented parser and bad-frame recovery')

packet=bytes(int(h,16) for h in (p/'system_packet.hex').read_text().split());s=decode(packet)
assert s.frame==0 and s.peak_bin==1024 and s.bw_bins==1 and s.active==8192
assert s.reserved==0
# Rev21 adds two D=8 butterfly clocks to the frozen20 57458-clock baseline.
# Measured latency remains first accepted IQ sample -> stable done snapshot.
assert s.cycles==57460, s.cycles
phase=np.arange(256)*np.pi/4
assert np.array_equal(s.iq,np.column_stack((np.rint(900*np.cos(phase)),np.rint(900*np.sin(phase)))))
print(f'PASS integrated source -> FFT -> analyzer -> UART, latency={s.cycles} cycles / {s.latency_us:.3f} us')
