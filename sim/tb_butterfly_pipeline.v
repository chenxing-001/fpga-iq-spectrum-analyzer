`timescale 1ns/1ps
module tb_butterfly_pipeline;
 parameter AW=4,ROTATE=0;
 localparam D=1<<AW;
 reg clk=0,rst_n=0,vin=0;always #2.5 clk=~clk;
 reg signed [11:0] xr=0,xi=0;
 wire vnew,vold;wire signed [11:0] nr,ni,orr,oi;
 sdf_butterfly #(.D(D),.AW(AW),.ROTATE(ROTATE)) dut(clk,rst_n,vin,xr,xi,vnew,nr,ni);
 sdf_butterfly_rev9 #(.D(D),.AW(AW),.ROTATE(ROTATE)) reference(clk,rst_n,vin,xr,xi,vold,orr,oi);
 reg [1:0] delay_v=0;reg [23:0] delay_data1=0,delay_data2=0;integer checked=0,k,epoch,seed=371;
 reg [31:0] rnd;
 always @(posedge clk)begin
  #0.2;
  if(!rst_n)begin delay_v=0;delay_data1=0;delay_data2=0;end
  else begin
   if(vnew!==(D>=8 ? delay_v[1]:vold))$fatal(1,"butterfly valid misalignment D=%0d ROTATE=%0d",D,ROTATE);
   if(vnew)begin
    if(^{nr,ni}===1'bx || {nr,ni}!==(D>=8 ? delay_data2:{orr,oi}))
     $fatal(1,"butterfly data mismatch D=%0d ROTATE=%0d got=%h expected=%h",D,ROTATE,{nr,ni},D>=8 ? delay_data2:{orr,oi});
    checked=checked+1;
   end
   delay_v={delay_v[0],vold};delay_data2=delay_data1;delay_data1={orr,oi};
  end
 end
 generate if(D>=16)begin: check_collision
  always @(posedge clk)if(rst_n && vin && dut.pipelined_ram_delay.v3 &&
     dut.count[AW-1:0]==dut.pipelined_ram_delay.addr3)
    $fatal(1,"valid read collided with feedback write");
 end else if(D==8)begin: check_logic_collision
  always @(posedge clk)if(rst_n && vin && dut.split_logic_delay.v3 &&
     dut.count[2:0]==dut.split_logic_delay.addr3)
    $fatal(1,"selected logic read collided with feedback write");
 end endgenerate
 initial begin
  for(epoch=0;epoch<3;epoch=epoch+1)begin
   @(negedge clk);rst_n=0;vin=0;repeat(3)@(negedge clk);rst_n=1;
   for(k=0;k<16*D+100;k=k+1)begin
    @(negedge clk);rnd=$random(seed);
    vin=epoch==0 ? 1:epoch==1 ? (rnd[3:0]>3):(k%5==0);
    xr=k%19==0 ? -2048:k%19==1 ? 2047:rnd[11:0];
    xi=k%23==0 ? -2048:k%23==1 ? 2047:rnd[23:12];
   end
   // Reset is intentionally asserted with accepted samples still in flight.
  end
  @(negedge clk);vin=0;repeat(5)@(negedge clk);
  if(checked<2*D)$fatal(1,"insufficient butterfly coverage");
  $display("Butterfly pipeline PASS D=%0d ROTATE=%0d checked=%0d: continuous, bubbles, signed extremes, reset, collision-free",D,ROTATE,checked);
  $finish;
 end
endmodule
