`timescale 1ns/1ps
// Isolate the actual DUT post-multiplier registers. Golden arithmetic is the
// original full-width signed add/subtract, not the new segmented equations.
module tb_combine_rev23;
 reg clk=0,rst_n=0;always #2.5 clk=~clk;
 wire vo;wire signed [11:0] yr,yi;
 r22_twiddle dut(clk,rst_n,1'b0,12'sd0,12'sd0,vo,yr,yi);
 reg signed [25:0] x=0,y=0,z=0;
 reg signed [26:0] full_r,full_i;
 reg [23:0] expect0=0,expect1=0;
 reg [11:0] word,incremented;
 integer k,j,cycles=0,checked=0,driven=0,seed=2200123;
 always @(posedge clk)begin
  if(rst_n)begin
   expect1=expect0;
   full_r=$signed(x)-$signed(y);full_i=$signed(x)+$signed(z);
   expect0={full_r[22:11],full_i[22:11]};
   cycles=cycles+1;
   #0.2;
   if(cycles>=2)begin
    if({yr,yi}!==expect1)$fatal(1,"combine mismatch cycle=%0d got=%h expected=%h",cycles,{yr,yi},expect1);
    checked=checked+1;
   end
  end
 end
 task drive;
  input [25:0] a,b,c;
  begin @(negedge clk);x=a;y=b;z=c;driven=driven+1;end
 endtask
 initial begin
  // Exhaust both values of the carry input for every upper-part code.
  for(k=0;k<4096;k=k+1)begin
   word=k;incremented=word+12'd1;
   if(dut.add_carry12(word,1'b0)!==word || dut.add_carry12(word,1'b1)!==incremented)
    $fatal(1,"carry prefix failure code=%h",word);
  end
  force dut.p1=x;force dut.p2=y;force dut.p3=z;force dut.ep=6'd0;
  repeat(3)@(negedge clk);rst_n=1;
  drive(0,0,0);drive(26'h3ffffff,1,1);drive(26'h2000000,26'h1ffffff,26'h2000000);
  // Every lower-part residue at both sides of carry/borrow thresholds.
  // Repeat with upper bits all-zero, all-one, sign transitions, and mixed.
  for(j=0;j<8;j=j+1)for(k=0;k<2048;k=k+1)begin
   drive((j*26'h0492800)|k,(j*26'h06db000)|k,(j*26'h06db000)|(2047-k));
   drive((j*26'h0492800)|k,(j*26'h06db000)|((k+1)&2047),(j*26'h06db000)|((2048-k)&2047));
  end
  for(k=0;k<26;k=k+1)begin
   drive((26'd1<<k)-1,26'd1<<k,1);
   drive(26'd1<<k,(26'd1<<k)-1,26'h3ffffff);
  end
  for(k=0;k<100000;k=k+1)drive($random(seed),$random(seed),$random(seed));
  repeat(3)@(negedge clk);
  if(checked<driven)$fatal(1,"combine did not drain");
  $display("Rev23 combine PASS: 8192 prefix cases, %0d driven full-width signed add/subtract cases, same two stages",driven);
  $finish;
 end
 initial begin #2000000;$fatal(1,"combine timeout");end
endmodule
