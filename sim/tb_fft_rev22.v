`timescale 1ns/1ps
// Compare data AND frame/bin metadata to the exact uploaded FFT hierarchy.
module tb_fft_rev22;
 reg clk=0,rst_n=0,vin=0;always #2.5 clk=~clk;
 reg signed [11:0] xr=0,xi=0;
 wire vn,vo;wire signed [11:0] nr,ni,orr,oi;
 wire [12:0] bn,bo;wire [31:0] fn,fo;
 fft8192_stream dut(clk,rst_n,vin,xr,xi,vn,nr,ni,bn,fn);
 fft8192_stream_rev21 ref21(clk,rst_n,vin,xr,xi,vo,orr,oi,bo,fo);
 integer epoch,k,length,checked=0,seed=1281921;
 reg [31:0] rnd;
 always @(posedge clk)begin
  #0.2;
  if(rst_n)begin
   if(vn!==vo)$fatal(1,"whole FFT valid offset changed");
   if(vn)begin
    if(^{fn,bn,nr,ni}===1'bx || {fn,bn,nr,ni}!=={fo,bo,orr,oi})
     $fatal(1,"whole FFT frame/bin/data mismatch epoch=%0d frame=%0d bin=%0d",epoch,fn,bn);
    checked=checked+1;
   end
  end
 end
 initial begin
  for(epoch=0;epoch<4;epoch=epoch+1)begin
   @(negedge clk);rst_n=0;vin=0;repeat(3)@(negedge clk);rst_n=1;
   case(epoch)
    0:length=12000;
    1:length=3003;
    2:length=40960;
    3:length=73857;
   endcase
   for(k=0;k<length;k=k+1)begin
    @(negedge clk);vin=1;rnd=$random(seed);
    xr=k%17==0 ? -2048:k%17==1 ? 2047:rnd[11:0];
    xi=k%19==0 ? -2048:k%19==1 ? 2047:rnd[23:12];
   end
   // First epochs reset active/incomplete frames; final epoch drains bubbles.
  end
  @(negedge clk);vin=0;repeat(150)@(negedge clk);
  if(checked<95000)$fatal(1,"insufficient FFT comparison coverage: %0d",checked);
  $display("Rev22 full FFT PASS checked=%0d: frozen21 complex data/frame/bin, continuous throughput, active/warmup resets, exact same-cycle output",checked);
  $finish;
 end
endmodule
