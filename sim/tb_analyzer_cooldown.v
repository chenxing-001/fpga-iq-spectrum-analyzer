`timescale 1ns/1ps
// Exercise the *external* acceptance edge at expiry, including REFRESH=0/1.
module tb_analyzer_cooldown;
 parameter REFRESH=7;
 reg clk=0;always #2.5 clk=~clk;
 reg rst_n=0,iv=0,fv=0,release_snapshot=0;
 reg signed [11:0] ir=0,fr=0;
 reg [12:0] in_index=0,bin=0;
 reg [31:0] in_frame=0,fft_frame=0;
 wire done,time_we;wire [7:0] time_waddr;
 wire [23:0] time_wdata,time_data;
 wire [31:0] frame_id,latency_cycles,frames_skipped;
 wire [12:0] peak_bin;wire [13:0] bw_bins,active_count,span_count,longest_run;
 wire [24:0] time_peak_power;wire [37:0] energy;wire [1:0] clipped;
 snapshot_analyzer #(.REFRESH_CYCLES(REFRESH)) dut(
  .clk(clk),.rst_n(rst_n),.iv(iv),.ir(ir),.ii(12'sd0),.in_index(in_index),.in_frame(in_frame),.in_mode(2'd2),
  .fv(fv),.fr(fr),.fi(12'sd0),.bin(bin),.fft_frame(fft_frame),.release_snapshot(release_snapshot),
  .time_we(time_we),.time_waddr(time_waddr),.time_wdata(time_wdata),.time_addr(8'd0),.time_data(time_data),
  .done(done),.frame_id(frame_id),.latency_cycles(latency_cycles),.frames_skipped(frames_skipped),
  .peak_bin(peak_bin),.bw_bins(bw_bins),.active_count(active_count),.span_count(span_count),
  .longest_run(longest_run),.time_peak_power(time_peak_power),.energy(energy),.clipped(clipped));
 integer c,k,n,cycles=0,accepted_cycle=0;
 reg [31:0] wanted;
 always @(posedge clk)begin
  cycles=cycles+1;
  // Acceptance is unchanged; registered time_we is emitted AFTER this edge.
  if(rst_n && iv && in_index==0 && dut.state==0 && dut.cooldown_ready)accepted_cycle=cycles;
 end
 initial begin
  repeat(4)@(negedge clk);rst_n=1;
  for(c=0;c<4;c=c+1)begin
   wanted=10+c*3;
   // The previous snapshot is released at a rising edge. Try a bogus
   // frame start at EVERY disallowed edge; none may write sample RAM.
   if(c!=0)begin
    @(negedge clk);release_snapshot=1;
    @(posedge clk);#0.1;
    if(done)$fatal(1,"release did not lower done");
    for(n=REFRESH;n>0;n=n-1)begin
     @(negedge clk);release_snapshot=0;iv=1;in_index=0;in_frame=32'hdeadbeef;ir=999;
     #0.1;if(time_we)$fatal(1,"early acceptance with %0d cooldown cycles remaining",n);
     @(posedge clk);#0.1;
     if(dut.cooldown!==n-1 || dut.cooldown_ready!==(n==1))$fatal(1,"expiry off by one");
    end
    if(c==2)begin
     repeat(3)begin
      @(negedge clk);release_snapshot=0;iv=0;in_index=0;
      #0.1;if(time_we)$fatal(1,"accepted invalid sample");
     end
    end
    if(c==3)begin
     repeat(5)begin
      @(negedge clk);release_snapshot=0;iv=1;in_index=1;
      #0.1;if(time_we)$fatal(1,"accepted nonzero first index");
     end
    end
   end
   for(k=0;k<8192;k=k+1)begin
    @(negedge clk);release_snapshot=0;iv=1;in_index=k;in_frame=wanted;
    ir=k==0 ? 500:k==8191 ? 600:(k>=100 && k<=102) ? 300:0;
    @(posedge clk);#0.1;
    if(time_we!==(k<256))$fatal(1,"time write acceptance/address window c=%0d k=%0d",c,k);
    if(k==0 && (time_waddr!==0 || time_wdata!=={12'd500,12'd0}))$fatal(1,"first sample lost");
   end
   @(negedge clk);iv=0;
   for(k=0;k<8192;k=k+1)begin
    @(negedge clk);fv=1;fft_frame=wanted;bin=k;fr=k==17 ? 800:0;
   end
   @(negedge clk);fv=0;wait(done);#0.1;
   if(latency_cycles!==cycles-accepted_cycle)$fatal(1,"latency origin changed");
   if(frame_id!==wanted || frames_skipped!==(c==0 ? 9:2))$fatal(1,"frame selection/skips changed");
   if(peak_bin!==17 || bw_bins!==1 || energy!==38'd880000 || time_peak_power!==360000 ||
      active_count!==5 || span_count!==8192 || longest_run!==3 || clipped!==3)
    $fatal(1,"statistics or sample zero incorrect c=%0d energy=%0d",c,energy);
   if(time_data!=={12'd500,12'd0})$fatal(1,"sample zero missing from snapshot RAM");
   repeat(5)@(negedge clk);
  end
  $display("Cooldown PASS REFRESH=%0d: four snapshots, exact expiry, sample zero, skips, valid/index gating",REFRESH);
  $finish;
 end
 initial begin #10000000;$fatal(1,"cooldown test timeout");end
endmodule
