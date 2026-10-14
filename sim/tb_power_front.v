`timescale 1ns/1ps
module tb_power_front;
 reg clk=0;always #2.5 clk=~clk;
 reg rst_n=0,valid=0;
 reg signed [11:0] i=0,q=0;
 wire [23:0] isq,qsq;wire [24:0] power;
 square12_pipe si(clk,i,isq),sq(clk,q,qsq);
 power_sum24_pipe add(clk,isq,qsq,power);
 reg [3:0] vp=0;
 reg [24:0] expected[0:3];
 integer j,k,iv,qv,checked=0;
 reg [31:0] rng=32'hcd376149;
 function [31:0] next_random;input [31:0] r;
 begin next_random={r[30:0],r[31]^r[21]^r[1]^r[0]};end endfunction
 always @(posedge clk)begin
  if(!rst_n)vp=0;
  else begin
   for(j=3;j>0;j=j-1)expected[j]=expected[j-1];
   iv=$signed(i);qv=$signed(q);expected[0]=iv*iv+qv*qv;
   vp={vp[2:0],valid};
   #0.1;
   if(vp[3])begin
    if(power!==expected[3])$fatal(1,"power value/latency mismatch got=%h expected=%h",power,expected[3]);
    checked=checked+1;
   end
  end
 end
 initial begin
  repeat(3)@(negedge clk);rst_n=1;
  // All signed-12 codes, including -2048, in both multiplier lanes.
  for(k=0;k<4096;k=k+1)begin @(negedge clk);valid=1;i=k;q=4095-k;end
  // Extreme pairs, valid bubbles, and continuously changing signed operands.
  @(negedge clk);i=-2048;q=-2048;
  @(negedge clk);i=2047;q=2047;
  @(negedge clk);i=0;q=0;
  for(k=0;k<20000;k=k+1)begin
   @(negedge clk);rng=next_random(rng);i=rng[11:0];q=rng[23:12];valid=|rng[2:0];
   if(k==10000)begin
    @(negedge clk);rst_n=0;valid=0;
    repeat(3)@(negedge clk);rst_n=1;
   end
  end
  @(negedge clk);valid=0;repeat(6)@(negedge clk);
  if(checked<21000)$fatal(1,"insufficient valid coverage");
  $display("PASS revision19 power front: %0d exact outputs; all signed12 codes, extrema, bubbles, reset, four-stage alignment",checked);
  $finish;
 end
endmodule
