`timescale 1ns/1ps
module tb_analyzer_edges;
 reg clk=0;always #2.5 clk=~clk;
 reg rst_n=0,iv=0,fv=0,release_snapshot=0;
 reg signed [11:0] ir=0,ii=0,fr=0,fi=0;
 reg [12:0] in_index=0,bin=0;reg [31:0] in_frame=0,fft_frame=0;
 reg [1:0] in_mode=0;reg [7:0] time_addr=0;
 wire done,time_we,curve_we;wire [7:0] curve_addr,curve_data,time_waddr,peak_code;
 wire [23:0] time_wdata,time_data;
 wire [31:0] frame_id,latency_cycles,frames_skipped;wire [1:0] mode,clipped;
 wire [12:0] peak_bin;wire [13:0] bw_bins,active_count,span_count,longest_run;
 wire [24:0] peak_power,time_peak_power;wire [37:0] energy;
 snapshot_analyzer #(.REFRESH_CYCLES(0)) dut(
  .clk(clk),.rst_n(rst_n),.iv(iv),.ir(ir),.ii(ii),.in_index(in_index),.in_frame(in_frame),.in_mode(in_mode),
  .fv(fv),.fr(fr),.fi(fi),.bin(bin),.fft_frame(fft_frame),.release_snapshot(release_snapshot),
  .time_we(time_we),.time_waddr(time_waddr),.time_wdata(time_wdata),.time_addr(time_addr),.time_data(time_data),
  .curve_we(curve_we),.curve_addr(curve_addr),.curve_data(curve_data),.done(done),.frame_id(frame_id),.latency_cycles(latency_cycles),
  .mode(mode),.peak_bin(peak_bin),.bw_bins(bw_bins),.active_count(active_count),.span_count(span_count),.longest_run(longest_run),
  .peak_power(peak_power),.time_peak_power(time_peak_power),.energy(energy),.peak_code(peak_code),.clipped(clipped),.frames_skipped(frames_skipped));
 integer c,k,b,t,ei,eq,ep,ecount,espan,erun,ebest,efirst,elast,emax,ecycle=0,startcycle=0;
 integer expected_peak,expected_bw,expected_fp,columns=0,curve_expect,natural,code;
 reg [37:0] eenergy;reg [1:0] eclip;reg old_done=0;
 reg [31:0] wanted_frame,wanted_skipped;reg [511:0] held_meta;
 function integer time_i;input integer sample;
 begin case(c)
  0:time_i=-2048;
  1:time_i=sample==8191 ? -2048:0;
  2:time_i=(sample<3 || sample>=8190) ? 300:256;
  3:time_i=-2048;
  5:time_i=256;
  6:time_i=sample==8191 ? 257:256;
  7:time_i=0;
  default:time_i=sample%17<8 ? 257:256;
 endcase end endfunction
 function integer time_q;input integer sample;
 begin time_q=c==0 ? -2048:c==3 ? 2047:c==5 ? (sample%2==0 ? 1:0):0;end endfunction
 function integer freq_r;input integer index;
 begin case(c)
  0:freq_r=0;
  1:freq_r=index==8191 ? 1:0;
  2:freq_r=(index==0 || index==1 || index==8191) ? 1:0;
  3:freq_r=index==4096 ? -2048:0;
  default:freq_r=index==17 ? 0:1;
 endcase end endfunction
 function integer freq_i;input integer index;
 begin freq_i=(c==3 && index==4096) ? -2048:0;end endfunction
 always @(posedge clk)begin
  ecycle=ecycle+1;
  if(iv && in_index==0 && dut.state==0)startcycle=ecycle;
  if(curve_we)begin
   curve_expect=0;
   for(t=0;t<32;t=t+1)begin
    natural=(4096+curve_addr*32+t)%8192;
    code=freq_r(natural)*freq_r(natural)+freq_i(natural)*freq_i(natural);
    code=code==0 ? 0:code==1 ? 1:184;
    if(code>curve_expect)curve_expect=code;
   end
   if(curve_data!==curve_expect[7:0] || curve_addr!==columns[7:0])$fatal(1,"edge spectrum curve c=%0d column=%0d",c,columns);
   columns=columns+1;
  end
  #1;
  if(done && !old_done)begin
   if(latency_cycles!=ecycle-startcycle)$fatal(1,"latency does not measure acceptance to done");
   if(latency_cycles>400000)$fatal(1,"analysis exceeds 2 ms at 200 MHz");
  end
  old_done=done;
 end
 initial begin
  repeat(5)@(negedge clk);rst_n=1;
  for(c=0;c<8;c=c+1)begin
   case(c)
    0:begin wanted_frame=32'hfffffffe;wanted_skipped=32'hfffffffd;expected_peak=0;expected_bw=0;expected_fp=0;end
    1:begin wanted_frame=32'hffffffff;wanted_skipped=0;expected_peak=8191;expected_bw=1;expected_fp=1;end
    2:begin wanted_frame=0;wanted_skipped=0;expected_peak=0;expected_bw=3;expected_fp=1;end
    3:begin wanted_frame=3;wanted_skipped=2;expected_peak=4096;expected_bw=1;expected_fp=8388608;end
    4:begin wanted_frame=4;wanted_skipped=0;expected_peak=0;expected_bw=8191;expected_fp=1;end
    default:begin wanted_frame=c;wanted_skipped=0;expected_peak=0;expected_bw=8191;expected_fp=1;end
   endcase
   columns=0;eenergy=0;ecount=0;erun=0;ebest=0;efirst=-1;elast=-1;emax=0;eclip=0;
   for(k=0;k<8192;k=k+1)begin
    // Exercise gaps and wrong-frame samples immediately before valid
    // threshold crossings; they must neither count nor break a valid run.
    if(c>=5 && k>0 && k%19==0)begin
     @(negedge clk);iv=0;
     @(negedge clk);iv=1;in_frame=wanted_frame+1;ir=2047;ii=-2048;in_index=k;
    end
    @(negedge clk);iv=1;in_index=k;in_frame=wanted_frame;in_mode=c;
    ei=time_i(k);eq=time_q(k);ir=ei;ii=eq;ep=ei*ei+eq*eq;
    eenergy=eenergy+ep;if(ep>emax)emax=ep;
    if(ep>65536)begin
     ecount=ecount+1;erun=erun+1;if(erun>ebest)ebest=erun;
     if(efirst<0)efirst=k;elast=k;if(k==0)eclip[0]=1;if(k==8191)eclip[1]=1;
    end else erun=0;
   end
   @(negedge clk);iv=0;
   // Stale FFT frame, including a terminal bin, must not complete capture.
   repeat(10)begin @(negedge clk);fv=1;fft_frame=wanted_frame+1;bin=8191;fr=2047;fi=2047;end
   for(k=0;k<8192;k=k+1)begin
    if(k%257==0)begin @(negedge clk);fv=0;end
    @(negedge clk);fv=1;fft_frame=wanted_frame;
    b=0;for(t=0;t<13;t=t+1)b=b|(((k>>t)&1)<<(12-t));
    bin=b;fr=freq_r(b);fi=freq_i(b);
   end
   @(negedge clk);fv=0;wait(done);@(negedge clk);
   espan=ecount==0 ? 0:elast-efirst+1;
   if(frame_id!==wanted_frame || frames_skipped!==wanted_skipped || mode!==(c&3))$fatal(1,"frame identity/wrap c=%0d",c);
   if(energy!==eenergy || time_peak_power!==emax || active_count!==ecount || span_count!==espan || longest_run!==ebest || clipped!==eclip)
    $fatal(1,"time statistics c=%0d energy=%0d expected=%0d",c,energy,eenergy);
   if(peak_bin!==expected_peak || bw_bins!==expected_bw || peak_power!==expected_fp || columns!=256)
    $fatal(1,"frequency statistics c=%0d peak=%0d width=%0d columns=%0d",c,peak_bin,bw_bins,columns);
   held_meta={frame_id,latency_cycles,mode,peak_bin,bw_bins,active_count,span_count,longest_run,peak_power,time_peak_power,energy,peak_code,clipped,frames_skipped};
   // Hold while unrelated live inputs continue; selected memories must not change.
   for(k=0;k<256;k=k+1)begin
    iv=1;fv=1;in_index=k;in_frame=wanted_frame+1;fft_frame=wanted_frame;bin=k;ir=123;ii=456;fr=777;fi=888;time_addr=k;
    repeat(2)@(negedge clk);
    if($signed(time_data[23:12])!=time_i(k) || $signed(time_data[11:0])!=time_q(k))$fatal(1,"snapshot time RAM changed");
    if(!done || {frame_id,latency_cycles,mode,peak_bin,bw_bins,active_count,span_count,longest_run,peak_power,time_peak_power,energy,peak_code,clipped,frames_skipped}!==held_meta)
     $fatal(1,"snapshot metadata changed during hold");
   end
   $display("Analyzer edge PASS c=%0d frame=%0d width=%0d latency=%0d energy=%0d",c,frame_id,bw_bins,latency_cycles,energy);
   iv=0;fv=0;release_snapshot=1;@(negedge clk);release_snapshot=0;repeat(6)@(negedge clk);
  end
  $display("Analyzer edge PASS: full-scale energy, final bin, low power, circular width, frame wrap, stale frames, bubbles, held snapshot; rev11 65536/65537 threshold, late first active, empty frame");$finish;
 end
 initial begin #10000000;$fatal(1,"analyzer edge timeout");end
endmodule
