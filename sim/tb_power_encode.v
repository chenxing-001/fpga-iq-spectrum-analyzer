`timescale 1ns/1ps
module tb_power_encode;
 reg clk=0;always #2.5 clk=~clk;
 reg rst_n=0,vin=0;reg [24:0] p=0;reg [37:0] tag=0;
 wire vout;wire [7:0] code;wire [37:0] outtag;
 power_encode_pipe dut(clk,rst_n,vin,p,tag,vout,code,outtag);
 reg [2:0] qv=0;reg [37:0] qt[0:2];
 integer checks=0,seq=0,j,k,e,n,seed=8008;
 reg [7:0] expected,half_code,derived;
 function [7:0] reference_code;
  input [24:0] x;integer bitpos,ex;reg [24:0] t;
  begin
   ex=0;for(bitpos=0;bitpos<25;bitpos=bitpos+1)if(x[bitpos])ex=bitpos;
   t=ex>=3 ? x>>(ex-3):x<<(3-ex);
   reference_code=x==0 ? 0:x==1 ? 1:ex*8+t[2:0];
  end
 endfunction
 always @(posedge clk)begin
  if(!rst_n)qv=0;
  else begin
   qv={qv[1:0],vin};qt[2]=qt[1];qt[1]=qt[0];qt[0]=tag;
  end
  #1;
  if(vout!==qv[2])$fatal(1,"encoder valid latency");
  if(vout)begin
   if(outtag!==qt[2])$fatal(1,"encoder tag order");
   expected=reference_code(outtag[37:13]);
   if(code!==expected)$fatal(1,"power=%0d code=%0d expected=%0d",outtag[37:13],code,expected);
   half_code=reference_code(outtag[37:13]>>1);if(half_code==0)half_code=1;
   derived=code<16 ? 1:code<24 ? ((code-8)&8'hfc):code<32 ? ((code-8)&8'hfe):code-8;
   if(derived!==half_code)$fatal(1,"half-power threshold changed");
   checks=checks+1;
  end
 end
 task send;input [24:0] value;input valid;
  begin @(negedge clk);p=value;vin=valid;tag={value,seq[12:0]};seq=seq+1;end
 endtask
 initial begin
  repeat(3)@(negedge clk);rst_n=1;
  for(j=0;j<65536;j=j+1)send(j,1);
  for(e=0;e<25;e=e+1)for(k=-8;k<=8;k=k+1)begin
   n=(1<<e)+k;if(n>=0 && n<33554432)send(n,1);
  end
  send(25'h1ffffff,1);
  for(j=0;j<100000;j=j+1)begin
   send($random(seed),j%7!=0);
   if(j==30000 || j==70000)begin
    @(negedge clk);rst_n=0;repeat(2)@(negedge clk);rst_n=1;
   end
  end
  send(0,0);repeat(5)@(negedge clk);
  $display("Power encoder PASS: %0d checked words, 3-stage tags/valid, low-16 exhaustive, exponent edges, random, reset, half-power identity",checks);
  $finish;
 end
 initial begin #1200000;$fatal(1,"encoder timeout");end
endmodule
