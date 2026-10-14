`timescale 1ns/1ps
module tb_analyzer;
 reg clk=0;always #2.5 clk=~clk;
 reg rst_n=0,iv=0,fv=0,release_snapshot=0;
 reg signed [11:0] ir,ii,fr,fi;reg [12:0] in_index,bin;reg [31:0] in_frame,fft_frame;
 wire done,curve_we,time_we;wire [7:0] curve_addr,curve_data,time_waddr;wire [23:0] time_wdata,time_data;
 reg [7:0] time_addr=0;
 wire [31:0] frame_id,latency_cycles,frames_skipped;wire [1:0] mode,clipped;
 wire [12:0] peak_bin;wire [13:0] bw_bins,active_count,span_count,longest_run;
 wire [24:0] peak_power,time_peak_power;wire [37:0] energy;wire [7:0] peak_code;
 snapshot_analyzer #(.REFRESH_CYCLES(0)) dut(.clk(clk),.rst_n(rst_n),.iv(iv),.ir(ir),.ii(ii),.in_index(in_index),.in_frame(in_frame),.in_mode(2'b0),
 .fv(fv),.fr(fr),.fi(fi),.bin(bin),.fft_frame(fft_frame),.release_snapshot(release_snapshot),.time_we(time_we),.time_waddr(time_waddr),.time_wdata(time_wdata),
 .time_addr(time_addr),.time_data(time_data),.curve_we(curve_we),.curve_addr(curve_addr),.curve_data(curve_data),.done(done),.frame_id(frame_id),.latency_cycles(latency_cycles),
 .mode(mode),.peak_bin(peak_bin),.bw_bins(bw_bins),.active_count(active_count),.span_count(span_count),.longest_run(longest_run),.peak_power(peak_power),.time_peak_power(time_peak_power),.energy(energy),.peak_code(peak_code),.clipped(clipped),.frames_skipped(frames_skipped));
 reg [23:0] samples[0:81919],fft_samples[0:81919];integer j,k,b,c,meta,curves,tf;
 initial begin
  $readmemh("sim/analyzer_input.hex",samples);$readmemh("sim/fft_input.hex",fft_samples);
  meta=$fopen("sim/metrics.csv","w");curves=$fopen("sim/curves.csv","w");tf=$fopen("sim/time.csv","w");
  for(j=0;j<10;j=j+1)begin
   @(negedge clk);rst_n=0;iv=0;fv=0;repeat(4)@(negedge clk);rst_n=1;
   for(k=0;k<16442;k=k+1) begin
    @(negedge clk);iv=k<8192;fv=k>=8250;
    in_frame=j;fft_frame=j;in_index=k;
    if(iv)begin ir=samples[j*8192+k][23:12];ii=samples[j*8192+k][11:0];end
    if(fv)begin b=k-8250;for(c=0;c<13;c=c+1)bin[c]=(b>>(12-c))&1;
     fr=fft_samples[j*8192+b][23:12];fi=fft_samples[j*8192+b][11:0];end
   end
   @(negedge clk);iv=0;fv=0;
   wait(done);@(negedge clk);
   $fwrite(meta,"%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d\n",frame_id,peak_bin,bw_bins,active_count,span_count,longest_run,peak_power,time_peak_power,energy,peak_code,clipped,latency_cycles);
   for(k=0;k<256;k=k+1)begin time_addr=k;repeat(2)@(negedge clk);$fwrite(tf,"%0d,%0d,%0d,%0d\n",j,k,$signed(time_data[23:12]),$signed(time_data[11:0]));$fflush(tf);end
  end
  $fclose(meta);$fclose(curves);$fclose(tf);$display("Analyzer 10 frames completed");$finish;
 end
 always @(posedge clk)if(curve_we)$fwrite(curves,"%0d,%0d,%0d\n",frame_id,curve_addr,curve_data);
 initial begin #6000000;$fatal(1,"Analyzer timeout");end
endmodule
