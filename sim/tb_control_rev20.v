`timescale 1ns/1ps
// Independent 32-bit arithmetic scoreboard. Directed register seeding reaches
// 24/32-bit timer wraps without simulating billions of clocks. Frame-gap
// operands are sampled through the real external frame-acceptance interface.
module tb_control_rev20;
 reg clk=0;always #2.5 clk=~clk;
 reg rst_n=0,iv=0,fv=0,release_snapshot=0;
 reg [12:0] in_index=0;
 reg [31:0] in_frame=0;
 snapshot_analyzer #(.REFRESH_CYCLES(0)) dut(
  .clk(clk),.rst_n(rst_n),.iv(iv),.ir(12'sd0),.ii(12'sd0),
  .in_index(in_index),.in_frame(in_frame),.in_mode(2'd0),
  .fv(fv),.fr(12'sd0),.fi(12'sd0),.bin(13'd0),.fft_frame(32'd0),
  .release_snapshot(release_snapshot),.time_addr(8'd0));
 reg [31:0] expected_timer=0,expected_gap,rng=32'h57361ab9;
 reg checking=0;
 integer checks=0,gaps=0,j,k;
 function [31:0] next_random;input [31:0] x;
  begin next_random={x[30:0],x[31]^x[21]^x[1]^x[0]};end
 endfunction
 always @(posedge clk)begin
  if(checking)begin
   if(!rst_n)expected_timer=0;
   else if(dut.state==0 && dut.cooldown_ready && iv && in_index==0)expected_timer=0;
   else if(dut.state!=0 && dut.state!=10)expected_timer=expected_timer+32'd1;
   #0.1;
   if(dut.timer!==expected_timer)$fatal(1,"timer got %h wanted %h",dut.timer,expected_timer);
   if(dut.timer_carry!=={(&expected_timer[23:0]),(&expected_timer[15:0]),(&expected_timer[7:0])})
    $fatal(1,"timer carry invariant failed at %h",expected_timer);
   if(dut.done && dut.latency_cycles!==expected_timer)$fatal(1,"FINISH latency off by one");
   checks=checks+1;
  end
 end
 task reset_dut;
 begin
  @(negedge clk);rst_n=0;iv=0;fv=0;release_snapshot=0;
  repeat(2)@(negedge clk);rst_n=1;
 end endtask
 task check_gap;input [31:0] a,b;
 begin
  reset_dut;
  @(negedge clk);dut.next_expected_frame=b;iv=1;in_index=0;in_frame=a;
  expected_gap=a==0 ? 32'd0:a-b;
  @(negedge clk);iv=0;in_frame=~a;
  if(dut.frame_id!==a || dut.next_expected_frame!==(a+32'd1))$fatal(1,"frame acceptance changed");
  @(negedge clk);
  if(dut.frames_skipped!==expected_gap)
   $fatal(1,"frame gap a=%h b=%h got=%h expected=%h",a,b,dut.frames_skipped,expected_gap);
  repeat(2)@(negedge clk);
  if(dut.frames_skipped!==expected_gap)$fatal(1,"frame gap changed without acceptance");
  gaps=gaps+1;
 end endtask
 task seed_timer;input [31:0] value;
 begin
  @(negedge clk);
  dut.timer=value;expected_timer=value;
  dut.timer_carry={(&value[23:0]),(&value[15:0]),(&value[7:0])};
  repeat(8)@(negedge clk);
 end endtask
 initial begin
  repeat(3)@(negedge clk);checking=1;rst_n=1;
  check_gap(0,32'hffffffff);check_gap(1,1);check_gap(1,2);
  check_gap(32'hffffffff,0);check_gap(32'h80000000,32'h7fffffff);
  for(j=0;j<32;j=j+1)begin
   check_gap(32'd1<<j,1);
   check_gap((32'd1<<j)-1,32'd1<<j);
   check_gap(32'hfffffffe,32'hfffffffd);
  end
  for(j=0;j<4096;j=j+1)begin
   rng=next_random(rng);expected_gap=rng;
   rng=next_random(rng);check_gap(expected_gap,rng);
  end
  // A reset between acceptance and the pending commit must cancel it.
  reset_dut;
  @(negedge clk);iv=1;in_frame=32'hffffffff;in_index=0;
  @(negedge clk);rst_n=0;iv=0;
  @(negedge clk);rst_n=1;
  repeat(3)@(negedge clk);
  if(dut.frames_skipped!==0 || dut.skip_pending!==0)$fatal(1,"gap survived reset");
  // Natural rollover verifies the prediction from a real zero start.
  @(negedge clk);iv=1;in_frame=1;
  @(negedge clk);iv=0;
  repeat(131080)@(negedge clk);
  seed_timer(32'h000000fc);seed_timer(32'h0000fffc);
  seed_timer(32'h00fffffc);seed_timer(32'hfffffffc);
  // FINISH consumes the same incremented value, including all byte carries.
  for(j=0;j<4;j=j+1)begin
   reset_dut;
   @(negedge clk);
   case(j)
    0:expected_timer=32'h000000ff;
    1:expected_timer=32'h0000ffff;
    2:expected_timer=32'h00ffffff;
    3:expected_timer=32'hffffffff;
   endcase
   dut.timer=expected_timer;
   dut.timer_carry={(&expected_timer[23:0]),(&expected_timer[15:0]),(&expected_timer[7:0])};
   dut.state=9;
   repeat(6)@(negedge clk); // HOLD must freeze timer and carry flags.
   release_snapshot=1;
   @(negedge clk);release_snapshot=0;
   repeat(2)@(negedge clk); // IDLE must freeze until a new accepted frame.
   iv=1;in_frame=7;in_index=0;
   @(negedge clk);iv=0;
   repeat(3)@(negedge clk);
  end
  $display("Rev20 control PASS: %0d gap cases, %0d timer checks, byte/16/24/32-bit wraps, FINISH/HOLD/IDLE, pending reset",gaps,checks);
  $finish;
 end
 initial begin #2000000;$fatal(1,"control timeout");end
endmodule
