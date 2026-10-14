`timescale 1ns/1ps
module tb_peak_interleaved;
 reg clk=0;always #2.5 clk=~clk;
 reg rst_n=0,clear=0,valid_in=0,merge=0;
 reg [24:0] power_in=0;
 reg [20:0] tag_in=0;
 wire [24:0] peak_power;
 wire [20:0] peak_tag;
 peak_interleaved dut(.*);
 reg [24:0] expected=0;
 reg [20:0] expected_tag=0;
 reg [31:0] rng=32'h50197cab;
 integer windows=0,samples=0,k,c;
 function [31:0] random_next;input [31:0] r;
 begin random_next={r[30:0],r[31]^r[21]^r[1]^r[0]};end endfunction
 task start_window;
 begin
  @(negedge clk);clear=1;valid_in=0;merge=0;
  expected=0;expected_tag=0;
  @(negedge clk);clear=0;
  if(peak_power!==0 || peak_tag!==0)$fatal(1,"clear failed");
 end endtask
 task sample;input [24:0] p;input [20:0] t;
 begin
  @(negedge clk);valid_in=1;power_in=p;tag_in=t;samples=samples+1;
  if(p>expected)begin expected=p;expected_tag=t;end
 end endtask
 task bubble;
 begin @(negedge clk);valid_in=0;power_in=25'h1ffffff;tag_in=21'h1fffff;end endtask
 task finish_window;
 begin
  // Last sample is accepted on the edge before this falling edge.
  @(negedge clk);valid_in=0;
  @(negedge clk);merge=1; // preceding rising edge drained the pending sample
  @(negedge clk);merge=0;
  @(negedge clk);
  if({peak_power,peak_tag}!=={expected,expected_tag})
   $fatal(1,"window %0d got %h/%h wanted %h/%h",windows,peak_power,peak_tag,expected,expected_tag);
  repeat(3)begin
   @(negedge clk);
   if({peak_power,peak_tag}!=={expected,expected_tag})$fatal(1,"snapshot not stable");
  end
  windows=windows+1;
 end endtask
 initial begin
  repeat(3)@(negedge clk);rst_n=1;
  start_window;finish_window; // empty
  start_window;sample(0,99);finish_window; // original all-zero metadata is zero
  start_window;sample(25'h1ffffff,123);finish_window; // odd count / full 25-bit
  start_window;sample(10,4096);sample(10,2048);finish_window;
  start_window;sample(1,0);sample(10,700);sample(10,1);finish_window; // lane1 wins tie
  start_window;sample(10,90);sample(1,91);sample(2,92);sample(10,93);finish_window;
  start_window;
  for(k=0;k<1000;k=k+1)sample(k+1,1000-k);
  finish_window;
  start_window;
  for(k=0;k<1000;k=k+1)begin sample(1000-k,k);if(k%3==0)bubble;end
  finish_window;
  start_window;
  for(k=0;k<63;k=k+1)sample(50,k);
  sample(25'h1ffffff,654);finish_window;
  for(c=0;c<200;c=c+1)begin
   start_window;
   for(k=0;k<c+1;k=k+1)begin
    rng=random_next(rng);
    if(rng[2:0]==0)bubble;
    if(rng[3:0]==1)begin bubble;bubble;end
    // Low-resolution windows force frequent ties across both lanes.
    sample(c%2 ? {21'b0,rng[3:0]}:rng[24:0],rng[20:0]);
   end
   finish_window;
  end
  // Clear/reset must cancel a pending winning sample, not leak it next window.
  start_window;sample(25'h1ffffff,55);start_window;sample(3,7);finish_window;
  start_window;sample(25'h1ffffff,66);
  @(negedge clk);rst_n=0;valid_in=0;
  @(negedge clk);rst_n=1;
  start_window;sample(4,8);finish_window;
  $display("Rev13 peak PASS: %0d windows, %0d samples; continuous/bubbles, full25, ties, arrival order, odd/empty/zero, final maximum, clear/reset",windows,samples);
  $finish;
 end
 initial begin #1000000;$fatal(1,"peak unit timeout");end
endmodule
