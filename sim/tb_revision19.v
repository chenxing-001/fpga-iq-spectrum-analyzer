`timescale 1ns/1ps
// Compare revision19 to frozen18: unchanged time interface, identical
// scan/curve sequence delayed by two edges, identical final metrics.
module tb_revision19;
 reg clk=0;always #2.5 clk=~clk;
 reg rst_n=0,iv=0,fv=0,release_snapshot=0;
 reg signed [11:0] ir=0,ii=0,fr=0,fi=0;
 reg [12:0] in_index=0,bin=0;
 reg [31:0] in_frame=0,fft_frame=0;
 reg [1:0] in_mode=0;
 reg [7:0] read_addr=0;
 wire tw0,tw1,cw0,cw1,done0,done1;
 wire [7:0] ta0,ta1,ca0,ca1,cd0,cd1;
 wire [23:0] td0,td1,tq0,tq1;
 snapshot_analyzer_rev18 #(.REFRESH_CYCLES(0)) ref_design(
 .clk(clk),.rst_n(rst_n),.iv(iv),.ir(ir),.ii(ii),.in_index(in_index),.in_frame(in_frame),.in_mode(in_mode),
 .fv(fv),.fr(fr),.fi(fi),.bin(bin),.fft_frame(fft_frame),.release_snapshot(release_snapshot),
 .time_we(tw0),.time_waddr(ta0),.time_wdata(td0),.time_addr(read_addr),.time_data(tq0),
 .curve_we(cw0),.curve_addr(ca0),.curve_data(cd0),.done(done0));
 snapshot_analyzer #(.REFRESH_CYCLES(0)) dut(
 .clk(clk),.rst_n(rst_n),.iv(iv),.ir(ir),.ii(ii),.in_index(in_index),.in_frame(in_frame),.in_mode(in_mode),
 .fv(fv),.fr(fr),.fi(fi),.bin(bin),.fft_frame(fft_frame),.release_snapshot(release_snapshot),
 .time_we(tw1),.time_waddr(ta1),.time_wdata(td1),.time_addr(read_addr),.time_data(tq1),
 .curve_we(cw1),.curve_addr(ca1),.curve_data(cd1),.done(done1));
 integer writes=0,merges=0,k,c,j;
 reg [31:0] random_state=32'h312ac457;
 function [31:0] next_random;input [31:0] r;
 begin next_random={r[30:0],r[31]^r[21]^r[1]^r[0]};end endfunction
 wire [255:0] ref_scan={ref_design.state,ref_design.addr,ref_design.scan_index,ref_design.wait_read,ref_design.rd,
       ref_design.bw_count,ref_design.go_left,ref_design.above_threshold,ref_design.threshold,
       ref_design.group_max,ref_design.scan_best};
 wire [255:0] dut_scan={dut.state,dut.addr,dut.scan_index,dut.wait_read,dut.rd,
       dut.bw_count,dut.go_left,dut.above_threshold,dut.threshold,dut.group_max,dut.scan_best};
 reg [255:0] ref_scan_d0=0,ref_scan_d1=0;
 reg [127:0] ref_peak_d0=0,ref_peak_d1=0;
 reg [31:0] ref_curve_d0=0,ref_curve_d1=0;
 reg ref_merge_d0=0,ref_merge_d1=0;
 always @(negedge clk)begin
  ref_scan_d1=ref_scan_d0;ref_scan_d0=ref_scan;
  ref_peak_d1=ref_peak_d0;ref_peak_d0={ref_design.peak_power,ref_design.peak_bin,ref_design.peak_code,ref_design.time_peak_power};
  ref_curve_d1=ref_curve_d0;ref_curve_d0={done0,cw0,ca0,cd0};
  ref_merge_d1=ref_merge_d0;ref_merge_d0=ref_design.merge_peaks;
 end
 always @(posedge clk)begin
  if(rst_n && dut.merge_peaks &&
     (dut.frequency_peak.valid_q || dut.time_peak.valid_q ||
      dut.frequency_peak.valid_in || dut.time_peak.valid_in))
   $fatal(1,"merge started before both pipelines drained");
  #0.1;
  if(rst_n && dut.merge_peaks)begin
   if(!ref_merge_d1)$fatal(1,"merge delay differs");
   merges=merges+1;
  end
  if(rst_n && {tw1,ta1,td1,tq1}!=={tw0,ta0,td0,tq0})$fatal(1,"time interface differs");
  if(tw1)writes=writes+1;
  if(rst_n && dut.state>=2)begin
   if(dut_scan!==ref_scan_d1)
    $fatal(1,"scan trajectory differs frame=%0d state=%0d addr=%0d",c,dut.state,dut.addr);
   if({14'b0,done1,cw1,ca1,cd1}!==ref_curve_d1)$fatal(1,"done/curve delay differs");
   if({57'b0,dut.peak_power,dut.peak_bin,dut.peak_code,dut.time_peak_power}!==ref_peak_d1)
    $fatal(1,"peak differs, including tie order");
   if(done1)begin
    if(dut.latency_cycles!==ref_design.latency_cycles+2)$fatal(1,"latency increment is not two cycles");
    if({dut.frame_id,dut.mode,dut.bw_bins,dut.active_count,dut.span_count,
        dut.longest_run,dut.energy,dut.clipped,dut.frames_skipped,tq1}!==
       {ref_design.frame_id,ref_design.mode,ref_design.bw_bins,ref_design.active_count,ref_design.span_count,
        ref_design.longest_run,ref_design.energy,ref_design.clipped,ref_design.frames_skipped,tq0})
      $fatal(1,"snapshot differs from revision18");
   end
  end
 end
 initial begin
  repeat(5)@(negedge clk);rst_n=1;
  for(c=0;c<22;c=c+1)begin
   in_frame=c==0 ? 32'hffffffff:c-1;in_mode=c;
   for(k=0;k<8192;k=k+1)begin
    if(k>0 && k%127==0)begin
     @(negedge clk);iv=1;in_frame=in_frame+1;ir=-2048;ii=-2048;
     @(negedge clk);iv=0;in_frame=in_frame-1;
    end
    @(negedge clk);iv=1;in_index=k;
    random_state=next_random(random_state);
    case(c)
     0:begin ir=k<2048 ? k:2047;ii=0;end // consecutive rising maxima and ties
     1:begin ir=700;ii=-700;end
     2:begin ir=random_state[11:0];ii=random_state[23:12];end
     3:begin ir=k==8191 ? -2048:0;ii=k==8191 ? -2048:0;end
     14:begin ir=k[0] ? 300:0;ii=0;end // isolated one-sample runs
     15:begin ir=(k%6)<5 ? 300:0;ii=0;end // equal 5-sample runs
     16:begin ir=(k%13)<(1+(k/13)%12) ? 300:0;ii=0;end
     17:begin ir=(k%4)==0 ? 256:(k%4)==1 ? 257:0;ii=0;end
     18:begin ir=k==0 ? 0:300;ii=0;end // 8191, last sample active
     19:begin ir=k==8191 ? 0:300;ii=0;end // 8191, last sample inactive
     20:begin ir=(k<20 || k>=8172) ? 300:0;ii=0;end // distinct head/tail runs
     21:begin ir=random_state[3] ? 300:0;ii=0;end
     default:begin ir=0;ii=0;end
    endcase
   end
   @(negedge clk);iv=0;fft_frame=in_frame;
   for(k=0;k<8192;k=k+1)begin
    if(k%71==0)begin @(negedge clk);fv=0;end
    @(negedge clk);fv=1;bin=k;
    if(c==4)for(j=0;j<13;j=j+1)bin[j]=(k>>(12-j))&1;
    random_state=next_random(random_state);
    case(c)
     0:begin fr=k<2048 ? k:2047;fi=0;end
     1:begin fr=511;fi=-512;end
     2:begin fr=random_state[11:0];fi=random_state[23:12];end
     3:begin fr=k==8191 ? -2048:0;fi=k==8191 ? -2048:0;end
     4:begin fr=(k==1 || k==2) ? 1000:0;fi=0;end // first max bin4096, later max bin2048
     5:begin fr=0;fi=0;end
     6:begin fr=k==0 ? 4:0;fi=0;end // isolated peak at first bin
     7:begin fr=k==8191 ? 4:((k==8190 || k==0) ? 3:0);fi=0;end
     8:begin fr=k==4096 ? 0:4;fi=0;end // width 8191, both scan directions
     9:begin fr=4;fi=0;end // width 8192, terminal count stops scan
     10:begin fr=k==0 ? 4:((k==8191 || k==1) ? 2:0);fi=(k==8191 || k==1) ? 2:0;end
     11:begin fr=k==8191 ? 4:((k==8190 || k==0) ? 2:0);fi=(k==8190 || k==0) ? 2:0;end
     12:begin fr=k==0 ? 1:0;fi=0;end // smallest nonzero power
     13:begin fr=k==8191 ? 2:((k==8190 || k==0) ? 1:0);fi=(k==8190 || k==0) ? 1:0;end // floor(P/2)=2

     default:begin fr=k==17 ? 800:0;fi=0;end
    endcase
   end
   @(negedge clk);fv=0;wait(done1);
   for(k=0;k<256;k=k+1)begin @(negedge clk);read_addr=k;repeat(2)@(negedge clk);end
   if(merges!=c+1)$fatal(1,"merge pulse count %0d expected %0d",merges,c+1);
   if(writes!=(c+1)*256)$fatal(1,"missing/extra time writes %0d",writes);
   $display("Rev19 equivalence PASS frame=%0d peak=%0d time_peak=%0d writes=%0d",c,dut.peak_bin,dut.time_peak_power,writes);
   case(c)
    14,17:if(dut.longest_run!==14'd1)$fatal(1,"isolated run");
    15:if(dut.longest_run!==14'd5)$fatal(1,"equal runs");
    16:if(dut.longest_run!==14'd12)$fatal(1,"increasing run lengths");
    18,19:if(dut.longest_run!==14'd8191)$fatal(1,"long final run");
    20:if(dut.longest_run!==14'd20)$fatal(1,"head/tail runs joined");
    5:if(dut.bw_bins!==14'd0)$fatal(1,"zero bandwidth");
    6,12:if(dut.bw_bins!==14'd1)$fatal(1,"isolated bandwidth");
    7,10,11,13:if(dut.bw_bins!==14'd3)$fatal(1,"wrapped/equal-threshold bandwidth");
    8:if(dut.bw_bins!==14'd8191)$fatal(1,"8191 bandwidth");
    9:if(dut.bw_bins!==14'd8192)$fatal(1,"8192 bandwidth");
   endcase
   $display("Rev19 scan PASS frame=%0d bw=%0d latency=%0d",c,dut.bw_bins,dut.latency_cycles);
   release_snapshot=1;@(negedge clk);release_snapshot=0;repeat(6)@(negedge clk);
  end
  @(negedge clk);iv=1;in_index=0;in_frame=123;ir=300;ii=0;
  @(negedge clk);iv=0;
  wait(dut.run_commit);
  @(negedge clk);rst_n=0;
  repeat(3)@(negedge clk);
  if(dut.run_commit!==0 || dut.longest_run!==0)$fatal(1,"run command survived reset");
  rst_n=1;repeat(6)@(negedge clk);
  $display("Rev19 reset PASS pending longest-run update");
  // Abort an in-flight command in each scan mode, before its STEP edge.
  for(c=0;c<2;c=c+1)begin
   @(negedge clk);iv=1;in_index=0;in_frame=42+c;ir=4;ii=0;
   @(negedge clk);iv=0;fft_frame=in_frame;
   for(k=0;k<8192;k=k+1)begin
    @(negedge clk);fv=1;bin=k;fr=4;fi=0;
   end
   @(negedge clk);fv=0;
   wait(dut.state==(c==0 ? 5:8));
   @(negedge clk);
   if(!dut.addr_commit)$fatal(1,"reset test did not reach a pending command");
   rst_n=0;
   repeat(3)@(negedge clk);
   if(dut.addr!==0 || dut.addr_commit!==0 || dut.done!==0 || dut.state!==0)
    $fatal(1,"pending address command survived reset");
   rst_n=1;repeat(6)@(negedge clk);
   $display("Rev19 reset PASS pending command mode=%0d",c);
  end
  $display("Rev19 analyzer PASS: 22 frames, exact two-edge scan translation and equal snapshots; zero/1/3/8191/8192 bandwidth, wrap and equal threshold");$finish;
 end
 initial begin #20000000;$fatal(1,"rev19 timeout");end
endmodule
