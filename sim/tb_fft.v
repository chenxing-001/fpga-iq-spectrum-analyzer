`timescale 1ns/1ps
module tb_fft;
 reg clk=0;always #2.5 clk=~clk;
 reg rst_n=0,vin=0;reg signed [11:0] xr=0,xi=0;
 wire vo;wire signed [11:0] yr,yi;wire [12:0] bin;wire [31:0] frame;
 fft8192_stream dut(clk,rst_n,vin,xr,xi,vo,yr,yi,bin,frame);
 reg [23:0] samples[0:73727];integer k,f,cycles=0,first=-1,first_input=-1,last=-1,num=0;
 initial begin
  $readmemh("sim/input.hex",samples);f=$fopen("sim/rtl_fft.csv","w");
  repeat(5) @(negedge clk);rst_n=1;
  for(k=0;k<73728;k=k+1) begin @(negedge clk);vin=1;xr=samples[k][23:12];xi=samples[k][11:0];end
  @(negedge clk);vin=0;repeat(20) @(negedge clk);$fclose(f);
  // Rev21 adds two clocks in D=8; frozen20 observed latency was 8288 clocks.
  if(num!=57344 || first-first_input!=8290)$fatal(1,"FFT count/latency regression: outputs=%0d latency=%0d",num,first-first_input);
  $display("FFT outputs=%0d first_cycle=%0d input_to_observed_output=%0d cycles",num,first,first-first_input);$finish;
 end
 always @(posedge clk) begin
  cycles=cycles+1;
  if(vin && first_input<0)first_input=cycles;
  if(vo && frame<7) begin
   if(first<0) first=cycles;
   if(last>=0 && cycles!=last+1) $fatal(1,"Output gap");
   last=cycles;num=num+1;$fwrite(f,"%0d,%0d,%0d,%0d\n",frame,bin,yr,yi);
  end
 end
endmodule
