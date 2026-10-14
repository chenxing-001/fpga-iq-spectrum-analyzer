`timescale 1ns/1ps
module tb_power_ram;
 reg clk=0;always #2.5 clk=~clk;
 reg we=0;reg [12:0] wa=0,ra=0;reg [7:0] wd=0;wire [7:0] q;
 spectrum_power_ram dut(clk,we,wa,wd,ra,q);
 integer k,previous;
 function [7:0] pattern;input integer a;begin pattern=(a^(a>>5)^8'hc7);end endfunction
 initial begin
  for(k=0;k<8192;k=k+1)begin @(negedge clk);we=1;wa=k;wd=pattern(k);end
  @(negedge clk);we=0;
  for(k=0;k<8193;k=k+1)begin
   ra=(k*3571)%8192;
   @(posedge clk);#1;
   if(k>0 && q!==pattern(previous))$fatal(1,"RAM 2-cycle read at %0d: %h",previous,q);
   previous=ra;@(negedge clk);
  end
  $display("Power RAM PASS: all 8192 addresses, full-rate two-stage reads");$finish;
 end
endmodule
