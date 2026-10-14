`timescale 1ns/1ps
module tb_twiddle_rev23;
 parameter LOGN=13;
 localparam N=1<<LOGN;
 parameter ROM_FILE="data/sin_tw_8192.hex",MIF_FILE="data/sin_tw_8192.mif";
 reg clk=0;always #2.5 clk=~clk;
 reg rst_n=0,vin=0;reg signed [11:0] xr=0,xi=0;
 wire vo;wire signed [11:0] yr,yi;
 r22_twiddle #(.LOGN(LOGN),.ROM_FILE(ROM_FILE),.MIF_FILE(MIF_FILE)) dut(clk,rst_n,vin,xr,xi,vo,yr,yi);
 wire ref_vo;wire signed [11:0] ref_yr,ref_yi;
 r22_twiddle_rev22 #(.LOGN(LOGN),.ROM_FILE(ROM_FILE),.MIF_FILE(MIF_FILE)) ref_design(clk,rst_n,vin,xr,xi,ref_vo,ref_yr,ref_yi);
 reg [11:0] operand,neg_expected;
 integer code;
 reg [23:0] inputs[0:3*N-1],expected[0:3*N-1];
 reg [23:0] expect_now=0,history[0:8];reg [8:0] valid_history=0;
 integer k,j,received=0,checked=0;
 always @(posedge clk)begin
  if(!rst_n)begin valid_history=0;received=0;end
  else begin
   for(j=8;j>0;j=j-1)history[j]=history[j-1];
   history[0]=expect_now;valid_history={valid_history[7:0],vin};
   #1;
   if(vo!==ref_vo)$fatal(1,"rev23/rev22 valid changed cycle");
   if(vo && {yr,yi}!=={ref_yr,ref_yi})$fatal(1,"rev23/rev22 value differs");
   if(vo!==valid_history[8])$fatal(1,"N=%0d valid alignment expected=%b got=%b",N,valid_history[8],vo);
   if(vo)begin
    if({yr,yi}!==history[8])$fatal(1,"N=%0d output %0d expected=%h got=%h",N,received,history[8],{yr,yi});
    received=received+1;checked=checked+1;
   end
  end
 end
 task drive;
 input integer idx;
 begin
  @(negedge clk);vin=1;xr=inputs[idx][23:12];xi=inputs[idx][11:0];expect_now=expected[idx];
 end endtask
 task gap;
 input integer length;
 begin
  @(negedge clk);vin=0;xr=2047;xi=-2048;
  repeat(length-1)@(negedge clk);
 end endtask
 initial begin
  for(code=0;code<4096;code=code+1)begin
   operand=code;neg_expected=-operand;
   if(dut.negate12_prefix(operand,{|operand[7:0],|operand[3:0]})!==neg_expected)$fatal(1,"prefix negate failed code=%h",operand);
   if(dut.negate12(operand)!==neg_expected)$fatal(1,"negate12 failed code=%h",operand);
  end
  $display("Rev23 negate12/prefix PASS: all 4096 bit patterns");
  $readmemh($sformatf("sim/twiddle_input_%0d.hex",N),inputs);
  $readmemh($sformatf("sim/twiddle_expected_%0d.hex",N),expected);
  repeat(4)@(negedge clk);rst_n=1;
  // Continuous count wrap, then bubbles including after the very last input.
  for(k=0;k<N;k=k+1)drive(k);
  for(k=N;k<2*N;k=k+1)begin
   if(k%7==0)gap(1);if(k%31==0)gap(9);drive(k);
  end
  gap(10);
  if(received!=2*N)$fatal(1,"N=%0d drain lost samples: %0d",N,received);
  // Reset during in-flight work discards stale tokens and restarts phase count.
  drive(0);drive(1);drive(2);
  @(negedge clk);rst_n=0;vin=0;
  repeat(3)@(negedge clk);rst_n=1;
  gap(10);
  if(received!=0)$fatal(1,"N=%0d stale output after reset",N);
  for(k=2*N;k<3*N;k=k+1)begin if(k%5==0)gap(2);drive(k);end
  gap(10);
  if(received!=N || checked!=3*N)$fatal(1,"N=%0d recovery count",N);
  $display("Rev23/rev22 twiddle N=%0d PASS: %0d exact samples, 9 stages, continuous/bubbles/drain/reset",N,checked);
  $finish;
 end
 initial begin #2000000;$fatal(1,"twiddle timeout");end
endmodule
