"""Run: python app.py [--demo] ; optional headless plot: --render-demo FILE.png"""
import argparse,json,queue,threading,time
from pathlib import Path
import numpy as np
from protocol import Parser,demo,MODE_NAMES

def draw_figure(fig,s):
 fig.clear();axes=fig.subplots(2,1);fig.subplots_adjust(hspace=.55,left=.075,right=.98,top=.94,bottom=.09)
 a,b=axes
 t=np.arange(256)/s.fs*1e6
 a.plot(t,s.iq[:,0],color='#009eb5',lw=1.4,label='I');a.plot(t,s.iq[:,1],color='#f19524',lw=1.2,label='Q')
 a.set(title='Time domain · first 256 consecutive samples',xlabel='Time (us)',ylabel='ADC code',ylim=(-2048,2048));a.legend(loc='upper right',ncol=2);a.grid(alpha=.2)
 centers=(np.arange(256)+.5)*s.fs/256/1e6-s.fs/2e6
 b.plot(centers,s.spectrum_dbfs,color='#159875',lw=1.4);b.fill_between(centers,s.spectrum_dbfs,-90,alpha=.12,color='#159875')
 b.axvline(s.frequency_mhz,color='#ab506f',ls='--',lw=1,label=f'Peak {s.frequency_mhz:.6f} MHz')
 b.set(title='FPGA spectrum · maximum of 32 bins per column · log power approximation',xlabel='Baseband frequency (MHz)',ylabel='dBFS (approx.)',xlim=(-s.fs/2e6,s.fs/2e6),ylim=(-90,5));b.legend(loc='upper right');b.grid(alpha=.2)
 return axes

class Application:
 def __init__(self,root,start_demo=False):
  import tkinter as tk
  from tkinter import ttk,messagebox,filedialog
  from matplotlib.figure import Figure
  from matplotlib.backends.backend_tkagg import FigureCanvasTkAgg
  self.tk=tk;self.ttk=ttk;self.messagebox=messagebox;self.filedialog=filedialog;self.root=root
  self.events=queue.Queue();self.stop=threading.Event();self.worker=None;self.serial=None;self.generation=0;self.snapshot=None;self.demo_mode=False;self.frame=0
  root.title('200 MSPS IQ · UART / PC · Revision 23');root.geometry('1200x880');root.minsize(950,740)
  style=ttk.Style();style.theme_use('clam');style.configure('TLabel',font=('Arial',11));style.configure('Value.TLabel',font=('Arial',16,'bold'))
  top=ttk.Frame(root,padding=12);top.pack(fill='x')
  ttk.Label(top,text='STREAMING IQ  /  8192 FFT',font=('Arial',19,'bold')).pack(side='left')
  self.port=tk.StringVar();self.ports=ttk.Combobox(top,textvariable=self.port,width=18);self.ports.pack(side='left',padx=12)
  ttk.Button(top,text='刷新串口',command=self.refresh_ports).pack(side='left')
  self.connect_btn=ttk.Button(top,text='连接 · 115200',command=self.connect);self.connect_btn.pack(side='left',padx=6)
  ttk.Button(top,text='断开',command=self.disconnect).pack(side='left')
  ttk.Button(top,text='演示模式',command=self.start_demo).pack(side='right')
  self.status=tk.StringVar(value='未连接。请先烧录 FPGA，再选择串口。');ttk.Label(root,textvariable=self.status,padding=(14,4)).pack(fill='x')
  cards=ttk.Frame(root,padding=(14,10));cards.pack(fill='x');self.stats={}
  for col,name in enumerate(('频率 MHz','带宽 MHz ≈','峰值幅度','RMS 幅度','分析耗时 µs')):
   box=ttk.Frame(cards,padding=10,relief='groove');box.grid(row=0,column=col,sticky='ew',padx=3);cards.columnconfigure(col,weight=1)
   ttk.Label(box,text=name).pack(anchor='w');value=tk.StringVar(value='—');self.stats[name]=value;ttk.Label(box,textvariable=value,style='Value.TLabel').pack(anchor='w')
  self.detail=tk.StringVar(value='幅度单位为数字码值；信号帧长度按门限检测，在当前 8192 点窗口内统计。');ttk.Label(root,textvariable=self.detail,padding=(14,8)).pack(fill='x')
  self.fig=Figure(figsize=(11,5.8),dpi=100,facecolor='#fafcfd');self.canvas=FigureCanvasTkAgg(self.fig,master=root);self.canvas.get_tk_widget().pack(fill='both',expand=True,padx=12)
  bottom=ttk.Frame(root,padding=12);bottom.pack(fill='x')
  ttk.Label(bottom,text='频谱：FPGA 结果，256 列最大值压缩；时域：连续 256 点快照。').pack(side='left')
  ttk.Button(bottom,text='导出当前帧 CSV + JSON',command=self.export).pack(side='right')
  self.refresh_ports();root.protocol('WM_DELETE_WINDOW',self.close);root.after(100,self.poll)
  if start_demo:self.start_demo()
 def refresh_ports(self):
  try:
   from serial.tools import list_ports
   values=[p.device for p in list_ports.comports()];self.ports['values']=values
   if values and not self.port.get():self.port.set(values[0])
  except ImportError:self.status.set('未安装 pyserial；仍可使用演示模式。运行 pip install -r requirements.txt')
 def disconnect(self):
  self.generation+=1;self.demo_mode=False;self.stop.set()
  if self.serial:
   try:self.serial.close()
   except Exception:pass
   self.serial=None
  self.status.set('已断开')
 def connect(self):
  self.disconnect()
  try:
   import serial
   ser=serial.Serial(self.port.get(),115200,timeout=.15)
  except Exception as e:self.messagebox.showerror('串口连接失败',str(e));return
  self.serial=ser;self.stop=threading.Event();stop=self.stop;generation=self.generation
  self.status.set(f'接收中：{self.port.get()}，115200 8-N-1；等待有效 CRC 数据帧')
  def receive():
   parser=Parser()
   try:
    while not stop.is_set():
     data=ser.read(4096)
     for s in parser.feed(data):self.events.put((generation,'frame',(s,parser.errors)))
   except Exception as e:
    if not stop.is_set():self.events.put((generation,'error',str(e)))
   finally:
    try:ser.close()
    except Exception:pass
  self.worker=threading.Thread(target=receive,daemon=True);self.worker.start()
 def start_demo(self):
  self.disconnect();self.demo_mode=True;self.frame=0;self.next_demo=0
  self.status.set('演示模式：电脑合成数据，未连接硬件；数值不代表板测结果')
 def poll(self):
  try:
   while True:
    gen,kind,payload=self.events.get_nowait()
    if gen!=self.generation:continue
    if kind=='frame':
     s,errors=payload;self.show(s,"hardware");self.status.set(f'硬件帧 {s.frame} · {MODE_NAMES[s.mode]} · UART 115200 · CRC/同步错误 {errors} · 间隔跳过 {s.skipped} 帧')
    else:self.disconnect();self.status.set('串口异常：'+payload)
  except queue.Empty:pass
  if self.demo_mode and time.monotonic()>=self.next_demo:
   self.show(demo(self.frame,(self.frame//8)%4),"demo");self.frame+=1;self.next_demo=time.monotonic()+.5
  self.root.after(50,self.poll)
 def show(self,s,source):
  self.snapshot=s;self.snapshot_source=source
  for name,value in zip(self.stats,(f'{s.frequency_mhz:.6f}',f'{s.bandwidth_mhz:.6f}',f'{s.amplitude:.1f}',f'{s.rms:.1f}',f'{s.latency_us:.3f}')):self.stats[name].set(value)
  clipped='窗口边缘截断，不能推断完整协议帧长' if s.clipped else '门限区间位于窗口内'
  self.detail.set(f'活动点 {s.active}  |  首尾跨度 {s.span} 点 / {s.span/s.fs*1e6:.3f} µs  |  最长连续段 {s.longest} 点  |  {clipped}')
  draw_figure(self.fig,s);self.canvas.draw_idle()
 def export(self):
  s=self.snapshot
  if s is None:return
  target=self.filedialog.asksaveasfilename(defaultextension='.json',initialfile=f'frame_{s.frame}.json',filetypes=[('Metadata','*.json')])
  if not target:return
  p=Path(target);base=p.with_suffix('')
  meta={k:v for k,v in vars(s).items() if k not in ('iq','spectrum')};meta.update(source=self.snapshot_source,spectrum_note='256 peak-held groups of 32 bins; not full FFT',time_note='first 256 consecutive samples',bandwidth_note='quantized contiguous half-power component, circular frequency axis')
  try:
   p.write_text(json.dumps(meta,indent=2,ensure_ascii=False),encoding='utf-8')
   np.savetxt(str(base)+'_time.csv',np.column_stack((np.arange(256)/s.fs,s.iq)),delimiter=',',header='time_s,I,Q',comments='')
   np.savetxt(str(base)+'_spectrum.csv',np.column_stack(((np.arange(256)+.5)*s.fs/256-s.fs/2,s.spectrum,s.spectrum_dbfs)),delimiter=',',header='group_center_Hz,power_code,approx_dBFS',comments='')
   self.status.set('已导出 '+str(p))
  except OSError as e:self.messagebox.showerror('导出失败',str(e))
 def close(self):self.disconnect();self.root.destroy()

if __name__=='__main__':
 parser=argparse.ArgumentParser();parser.add_argument('--demo',action='store_true');parser.add_argument('--render-demo');args=parser.parse_args()
 if args.render_demo:
  import matplotlib;matplotlib.use('Agg')
  from matplotlib.figure import Figure
  fig=Figure(figsize=(12,7),dpi=130);draw_figure(fig,demo(mode=1));fig.savefig(args.render_demo)
 else:
  import tkinter as tk
  root=tk.Tk();Application(root,args.demo);root.mainloop()
