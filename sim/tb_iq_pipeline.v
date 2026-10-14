`timescale 1ns/1ps
module tb_iq_pipeline;
 reg clk=0,rst_n=0;always #2.5 clk=~clk;
 wire vn,vo;wire signed [11:0] ni,nq,oi,oq;wire [12:0] nn,on;
 wire [31:0] nf,ofr;wire [1:0] nm,om;
 iq_source dut(clk,rst_n,vn,ni,nq,nn,nf,nm);
 iq_source_rev9 reference(clk,rst_n,vo,oi,oq,on,ofr,om);
 reg [1:0] valid_delay=0;reg [70:0] data1=0,data2=0;
 reg [255:0] phases_seen=0;
 integer c,k,checked=0;reg [31:0] seed_frame;
 always @(posedge clk)begin
  if(rst_n)phases_seen[dut.phase[15:8]]=1;
  #0.2;
  if(!rst_n)begin valid_delay=0;data1=0;data2=0;end
  else begin
   if(vn!==valid_delay[1])$fatal(1,"IQ valid must be delayed exactly two cycles");
   if(vn)begin
    if({ni,nq,nn,nf,nm}!==data2)$fatal(1,"IQ pipeline mismatch frame=%0d index=%0d mode=%0d",nf,nn,nm);
    checked=checked+1;
   end
   valid_delay={valid_delay[0],vo};data2=data1;data1={oi,oq,on,ofr,om};
  end
 end
 initial begin
  // Deposit frame IDs only while restarting the test. This accelerates
  // the real 32768-frame mode boundaries without changing production RTL.
  for(c=0;c<6;c=c+1)begin
   @(negedge clk);rst_n=0;repeat(3)@(negedge clk);
   case(c)
    0:seed_frame=0;1:seed_frame=32767;2:seed_frame=65535;
    3:seed_frame=98303;4:seed_frame=131071;5:seed_frame=32'hffffffff;
   endcase
   dut.fid=seed_frame;reference.fid=seed_frame;rst_n=1;
   for(k=0;k<3*8192+11;k=k+1)@(negedge clk);
  end
  if(phases_seen!=={256{1'b1}})$fatal(1,"not all sine addresses exercised");
  $display("IQ pipeline PASS checked=%0d: four modes, all 256 sine addresses, burst edges, mode/frame wrap, two-cycle offset, reset",checked);
  $finish;
 end
endmodule
