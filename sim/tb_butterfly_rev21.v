`timescale 1ns/1ps
// Direct uploaded-rev20 comparison, with a precise two-clock output offset.
module tb_butterfly_rev21;
 parameter ROTATE=1;
 reg clk=0,rst_n=0,vin=0;
 always #2.5 clk=~clk;
 reg signed [11:0] xr=0,xi=0;
 wire vn,vo;wire signed [11:0] nr,ni,orr,oi;
 sdf_butterfly #(.D(8),.AW(3),.ROTATE(ROTATE)) dut(clk,rst_n,vin,xr,xi,vn,nr,ni);
 sdf_butterfly_rev20 #(.D(8),.AW(3),.ROTATE(ROTATE)) ref20(clk,rst_n,vin,xr,xi,vo,orr,oi);
 reg [1:0] ev=0;reg [23:0] e0=0,e1=0;
 reg [31:0] rnd,seen=0;
 integer k,epoch,length,checked=0,accepted=0,seed=219021;
 always @(posedge clk)begin
  if(rst_n && vin)begin
   seen[dut.count]=1'b1;accepted=accepted+1;
   if(dut.split_logic_delay.v3 && dut.count[2:0]==dut.split_logic_delay.addr3)
    $fatal(1,"selected read/write collision");
  end
  #0.2;
  if(!rst_n)begin ev=0;e0=0;e1=0;end
  else begin
   if(vn!==ev[1])$fatal(1,"rev21 valid is not rev20 delayed by two clocks");
   if(vn)begin
    if(^{nr,ni}===1'bx || {nr,ni}!==e1)
     $fatal(1,"D8 mismatch ROTATE=%0d epoch=%0d got=%h expected=%h",ROTATE,epoch,{nr,ni},e1);
    checked=checked+1;
   end
   ev={ev[0],vo};e1=e0;e0={orr,oi};
  end
 end
 initial begin
  for(epoch=0;epoch<32;epoch=epoch+1)begin
   @(negedge clk);rst_n=0;vin=0;
   #0.3;if(vn!==0)$fatal(1,"asynchronous reset did not cancel output");
   repeat(2)@(negedge clk);rst_n=1;
   length=epoch<16 ? epoch:2048+37*(epoch-16);
   for(k=0;k<length;k=k+1)begin
    @(negedge clk);rnd=$random(seed);
    case(epoch%4)
     0:vin=1;
     1:vin=rnd[3:0]>3;
     2:vin=k%5==0;
     3:vin=(k%31)<17;
    endcase
    xr=k%11==0 ? -2048:k%11==1 ? 2047:rnd[11:0];
    xi=k%13==0 ? -2048:k%13==1 ? 2047:rnd[23:12];
   end
   // Reset the next epoch while the pipeline may still contain valid tokens.
  end
  @(negedge clk);vin=0;repeat(6)@(negedge clk);
  if(checked<15000 || seen!==32'hffffffff)$fatal(1,"insufficient D8 coverage");
  $display("Rev21 D8 PASS ROTATE=%0d accepted=%0d checked=%0d resets=32 all_addresses/phases, bubbles, extrema, exact +2 clocks",ROTATE,accepted,checked);
  $finish;
 end
endmodule
