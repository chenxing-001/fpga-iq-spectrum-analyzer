"""Wire format v1. All integers little-endian. No GUI / serial dependency."""
from dataclasses import dataclass
import struct
import binascii
import numpy as np
MAGIC=b'IQFT';SIZE=1330
MODE_NAMES=('单音 +25 MHz','双音 +25 / -12.5 MHz','突发单音','扫频')
def crc16(data):return binascii.crc_hqx(data,0xffff)
def decode_power(code):
 c=np.asarray(code,dtype=np.uint16)
 return np.where(c==0,0.,np.exp2(c//8)*(1+(c%8)/8))
def encode_power(p):
 p=np.asarray(p,dtype=np.uint64);e=np.floor(np.log2(np.maximum(p,1))).astype(np.uint64)
 mant=np.where(e>=3,np.right_shift(p,np.maximum(e,3)-3),np.left_shift(p,3-np.minimum(e,3)))&7
 return np.where(p==0,0,np.maximum(1,e*8+mant)).astype(np.uint8)
@dataclass
class Snapshot:
 frame:int;fs:int;n:int;mode:int;clipped:int;peak_bin:int;bw_bins:int
 active:int;span:int;longest:int;time_peak_power:int;energy:int;peak_code:int
 cycles:int;reserved:int;skipped:int;iq:np.ndarray;spectrum:np.ndarray
 @property
 def frequency_mhz(self):return (self.peak_bin if self.peak_bin<self.n//2 else self.peak_bin-self.n)*self.fs/self.n/1e6
 @property
 def bandwidth_mhz(self):return self.bw_bins*self.fs/self.n/1e6
 @property
 def amplitude(self):return np.sqrt(self.time_peak_power)
 @property
 def rms(self):return np.sqrt(self.energy/self.n)
 @property
 def latency_us(self):return self.cycles/self.fs*1e6
 @property
 def spectrum_dbfs(self):return 10*np.log10(np.maximum(decode_power(self.spectrum),1e-12)/2047**2)
def decode(packet):
 if len(packet)!=SIZE or packet[:4]!=MAGIC or packet[4]!=1 or int.from_bytes(packet[6:8],'little')!=SIZE:raise ValueError('Invalid packet header')
 if crc16(packet[:-2])!=int.from_bytes(packet[-2:],'little'):raise ValueError('CRC mismatch')
 u16=lambda o:int.from_bytes(packet[o:o+2],'little')
 u32=lambda o:int.from_bytes(packet[o:o+4],'little')
 return Snapshot(u32(8),u32(12),u16(16),packet[5]&3,(packet[5]>>2)&3,u16(18),u16(20),u16(22),u16(24),u16(26),u32(28),int.from_bytes(packet[32:37],'little'),packet[37],u32(38),u16(42),u32(44),np.frombuffer(packet[48:1072],dtype='<i2').reshape(256,2).copy(),np.frombuffer(packet[1072:1328],dtype=np.uint8).copy())
def encode(s):
 b=bytearray(SIZE);b[:4]=MAGIC;b[4]=1;b[5]=s.mode|(s.clipped<<2)
 for o,v,w in ((6,SIZE,2),(8,s.frame,4),(12,s.fs,4),(16,s.n,2),(18,s.peak_bin,2),(20,s.bw_bins,2),(22,s.active,2),(24,s.span,2),(26,s.longest,2),(28,s.time_peak_power,4),(32,s.energy,5),(37,s.peak_code,1),(38,s.cycles,4),(42,s.reserved,2),(44,s.skipped,4)):
  b[o:o+w]=int(v).to_bytes(w,'little')
 b[48:1072]=np.asarray(s.iq,dtype='<i2').tobytes();b[1072:1328]=np.asarray(s.spectrum,dtype=np.uint8).tobytes();b[-2:]=crc16(b[:-2]).to_bytes(2,'little');return bytes(b)
class Parser:
 def __init__(self):self.buffer=bytearray();self.errors=0
 def feed(self,data):
  self.buffer.extend(data);out=[]
  while True:
   start=self.buffer.find(MAGIC)
   if start<0:
    self.buffer[:]=self.buffer[-3:];break
   if start:del self.buffer[:start]
   if len(self.buffer)<8:break
   if self.buffer[4]!=1 or int.from_bytes(self.buffer[6:8],'little')!=SIZE:
    self.errors+=1;del self.buffer[0];continue
   if len(self.buffer)<SIZE:break
   try:out.append(decode(bytes(self.buffer[:SIZE])));del self.buffer[:SIZE]
   except ValueError:self.errors+=1;del self.buffer[0]
  return out

def demo(frame=0,mode=0):
 n=8192;fs=200_000_000;t=np.arange(n);x=900*np.exp(2j*np.pi*1024*t/n)
 if mode==1:x+=450*np.exp(-2j*np.pi*512*t/n)
 if mode==2:x*=((t>=1024)&(t<5120))
 if mode==3:x=900*np.exp(2j*np.pi*(512*t/n+2048*(t/n)**2))
 x=np.rint(x.real)+1j*np.rint(x.imag);tp=np.rint(abs(x)**2).astype(np.uint64)
 f=np.fft.fft(x)/n;p=np.rint(abs(f)**2).astype(np.uint64);c=encode_power(p);peak=int(np.argmax(p));th=max(1,int(encode_power(p[peak]//np.uint64(2))))
 width=0
 if p[peak]:
  width=1
  for direction in (1,-1):
   j=(peak+direction)%n
   while width<n and c[j]>=th:width+=1;j=(j+direction)%n
 active=tp>65536;idx=np.flatnonzero(active);run=best=0
 for a in active:run=run+1 if a else 0;best=max(best,run)
 # Illustrative nominal FPGA latency; all demo values are PC-generated.
 return Snapshot(frame,fs,n,mode,int(active[0])+2*int(active[-1]),peak,width,int(active.sum()),int(idx[-1]-idx[0]+1) if len(idx) else 0,best,int(tp.max()),int(tp.sum()),int(c[peak]),57460,0,0,np.column_stack((x.real[:256],x.imag[:256])).astype(np.int16),np.fft.fftshift(c).reshape(256,32).max(axis=1))
