`timescale 1ns/1ps
`include "altpll_model.v"
module tb_system;
 reg sys_clk=0;always #10 sys_clk=~sys_clk;
 reg rst_n=0;
 wire tx;wire [3:0] led;
 spectrum_streaming_top #(.UART_CLKS_PER_BIT(4)) dut(
  .sys_clk(sys_clk),.sys_rst_n(rst_n),.uart_txd(tx),.led(led));
 integer f,k,j;reg [7:0] byteval;
 initial begin
  f=$fopen("sim/system_packet.hex","w");
  repeat(5)@(negedge sys_clk);rst_n=1;
  for(k=0;k<1330;k=k+1)begin
   @(negedge tx);#30;
   for(j=0;j<8;j=j+1)begin byteval[j]=tx;#20;end
   if(tx!==1)$fatal(1,"System UART stop");
   $fwrite(f,"%02x\n",byteval);
  end
  wait(dut.sent);$fclose(f);
  if(dut.peak_bin!=1024 || dut.bw_bins!=1 || dut.active_count!=8192)$fatal(1,"Top metrics");
  if(dut.in_frame<8)$fatal(1,"Source stopped during UART");
  if(dut.latency_cycles!=57460)$fatal(1,"Analysis latency changed");
  @(negedge dut.clk);
  @(negedge dut.clk);
  if(dut.done || dut.uart_busy)$fatal(1,"UART-only snapshot did not release");
  $display("PASS UART-only system: frame=%0d latency=%0d source_frame=%0d; snapshot released",
   dut.frame_id,dut.latency_cycles,dut.in_frame);
  $finish;
 end
 initial begin #1000000;$fatal(1,"System timeout");end
endmodule
