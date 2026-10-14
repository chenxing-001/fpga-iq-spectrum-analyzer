import numpy as np
from pathlib import Path
N=8192

def wrap(x):return ((x+2048)&4095)-2048

def fft_fixed(x):
 r=x.real.astype(np.int64).copy();i=x.imag.astype(np.int64).copy()
 n=N
 while n>2:
  for base in range(0,N,n):
   q=n//4;h=n//2
   # First DIF butterfly, without twiddle.
   a,b=r[base:base+h].copy(),r[base+h:base+n].copy()
   c,d=i[base:base+h].copy(),i[base+h:base+n].copy()
   r[base:base+h]=(a+b)>>1;r[base+h:base+n]=(a-b)>>1
   i[base:base+h]=(c+d)>>1;i[base+h:base+n]=(c-d)>>1
   a=r[base+3*q:base+n].copy()
   r[base+3*q:base+n]=i[base+3*q:base+n];i[base+3*q:base+n]=wrap(-a)
   for half in (base,base+h):
    a,b=r[half:half+q].copy(),r[half+q:half+h].copy()
    c,d=i[half:half+q].copy(),i[half+q:half+h].copy()
    r[half:half+q]=(a+b)>>1;r[half+q:half+h]=(a-b)>>1
    i[half:half+q]=(c+d)>>1;i[half+q:half+h]=(c-d)>>1
   for section,branch in enumerate((0,2,1,3)):
    sl=slice(base+section*q,base+(section+1)*q)
    exp=(branch*np.arange(q))%n;theta=2*np.pi*exp/n
    # Match quadrant reconstruction of quarter wave ROM (including capped +1).
    lut=np.array([int(v,16) for v in (Path(__file__).resolve().parents[1]/f'data/tw_{n}.hex').read_text().split()])
    co=lut[exp%q]>>12;sn=lut[exp%q]&4095
    quad=exp//q
    c=np.select([quad==0,quad==1,quad==2,quad==3],[co,-sn,-co,sn])
    s=np.select([quad==0,quad==1,quad==2,quad==3],[-sn,-co,sn,co])
    a,b=r[sl].copy(),i[sl].copy()
    rr=wrap((a*c-b*s)>>11);ii=wrap((a*s+b*c)>>11)
    exact=exp%q==0
    er=np.select([quad==0,quad==1,quad==2,quad==3],[a,b,-a,-b])
    ei=np.select([quad==0,quad==1,quad==2,quad==3],[b,-a,-b,a])
    r[sl]=np.where(exact,wrap(er),rr);i[sl]=np.where(exact,wrap(ei),ii)
  n//=4
 a,b=r[::2].copy(),r[1::2].copy();c,d=i[::2].copy(),i[1::2].copy()
 r[::2]=(a+b)>>1;r[1::2]=(a-b)>>1;i[::2]=(c+d)>>1;i[1::2]=(c-d)>>1
 rev=np.array([int(f'{j:013b}'[::-1],2) for j in range(N)])
 return (r+1j*i)[rev]

def vectors():
 t=np.arange(N);rng=np.random.default_rng(42)
 tone=lambda b,a: np.rint(a*np.cos(2*np.pi*b*t/N))+1j*np.rint(a*np.sin(2*np.pi*b*t/N))
 return [tone(997,900),tone(-2011,700)+tone(345,300),rng.integers(-700,701,N)+1j*rng.integers(-700,701,N),np.zeros(N,dtype=complex),np.where((t>=1024)&(t<5120),tone(1024,900),0),np.full(N,2047+0j),tone(-4096,1000)]
if __name__=='__main__':
 p=Path(__file__).resolve().parent
 xs=vectors()
 with (p/'input.hex').open('w') as f:
  for x in xs+[np.zeros(N,dtype=complex)]*2:
   for z in x:f.write(f'{int(z.real)&4095:03x}{int(z.imag)&4095:03x}\n')
 np.save(p/'expected.npy',np.array([fft_fixed(x) for x in xs]))

 # Analyzer-only vectors exercise circular edges and all-bins-above-threshold cases.
 ex=np.array([fft_fixed(x) for x in xs]);extra=np.zeros((3,N),dtype=complex)
 extra[0,[8190,8191,0,1,2]]=100;extra[1,:]=100
 extra[2,99:105]=80;extra[2,101]=100
 allx=np.concatenate((ex,extra));np.save(p/'analyzer_expected.npy',allx)
 rev=[int(f'{j:013b}'[::-1],2) for j in range(N)]
 with (p/'fft_input.hex').open('w') as f:
  for row in allx:
   for z in row[rev]:f.write(f'{int(z.real)&4095:03x}{int(z.imag)&4095:03x}\n')
 with (p/'analyzer_input.hex').open('w') as f:
  for x in xs+[np.zeros(N,dtype=complex)]*3:
   for z in x:f.write(f'{int(z.real)&4095:03x}{int(z.imag)&4095:03x}\n')
