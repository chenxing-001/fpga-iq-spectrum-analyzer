`timescale 1ns/1ps
module tb_power_sum24_pipe;
 reg clk=0;always #2.5 clk=~clk;
 reg [23:0] a=0,b=0;wire [24:0] sum;
 reg [24:0] expected0=0,expected1=0;
 integer cycles=0,verified=0;
 always @(posedge clk)begin
  expected1=expected0;expected0={1'b0,a}+{1'b0,b};cycles=cycles+1;
  #0.1;
  if(cycles>=2)begin
   if(sum!==expected1)$fatal(1,"two-stage sum alignment got=%h wanted=%h",sum,expected1);
   verified=verified+1;
  end
 end
 power_sum24_pipe dut(clk,a,b,sum);
 integer i,j,k,checks=0;
 reg [31:0] rng=32'h123467ab;
 function [31:0] next_random;input [31:0] r;
 begin next_random={r[30:0],r[31]^r[21]^r[1]^r[0]};end endfunction
 task check;input [23:0] x,y;
 begin @(negedge clk);a=x;b=y;
  checks=checks+1;
 end endtask
 initial begin
  check(0,0);check(24'hffffff,24'hffffff);
  // Exercise each chunk's complete truth table, both incoming-carry cases,
  // full-width propagate chains, and the largest signed-12-bit squares.
  for(k=0;k<4;k=k+1)for(i=0;i<64;i=i+1)for(j=0;j<64;j=j+1)begin
   check(i<<(6*k),j<<(6*k));
   check((i<<(6*k))|((1<<(6*k))-1),(j<<(6*k))|1);
  end
  for(i=0;i<24;i=i+1)begin
   check((24'h1<<i)-1,1);check(24'hffffff^(24'h1<<i),24'h1<<i);
  end
  check(24'h400000,24'h400000);
  for(i=0;i<100000;i=i+1)begin
   rng=next_random(rng);a=rng[23:0];
   rng=next_random(rng);check(a,rng[23:0]);
  end
  $display("PASS power_sum24: %0d full-width/carry-boundary/random comparisons",checks);
  repeat(3)@(negedge clk);
  if(verified<checks)$fatal(1,"adder did not drain");
  $finish;
 end
endmodule
