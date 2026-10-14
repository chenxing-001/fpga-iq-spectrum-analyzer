`timescale 1ns/1ps
`include "altpll_model.v"
module tb_system_rearm;
 parameter REFRESH=0,CPB=1,FRAMES=3;
 reg sys_clk=0;always #10 sys_clk=~sys_clk;
 reg rst_n=0;
 wire tx;wire [3:0] led;
 spectrum_streaming_top #(.UART_CLKS_PER_BIT(CPB),.REFRESH_CYCLES(REFRESH)) dut(
  .sys_clk(sys_clk),.sys_rst_n(rst_n),.uart_txd(tx),.led(led));
 integer f,j,k,completed;
 reg [31:0] previous_frame,current_frame;
 reg [264:0] metadata;
 wire [264:0] current_metadata={dut.frame_id,dut.latency_cycles,dut.frames_skipped,
  dut.mode,dut.clipped,dut.peak_bin,dut.bw_bins,dut.active_count,dut.span_count,
  dut.longest_run,dut.peak_power,dut.time_peak_power,dut.energy,dut.peak_code};
 reg [23:0] frozen_time[0:255];reg [7:0] frozen_spec[0:255];
 task receive_packet;
  integer b,n;reg [7:0] value;
  begin
   for(b=0;b<1330;b=b+1)begin
    @(negedge tx);#(7.5*CPB);
    for(n=0;n<8;n=n+1)begin value[n]=tx;#(5.0*CPB);end
    if(tx!==1)$fatal(1,"Integrated packet stop bit %0d",b);
    $fwrite(f,"%02x\n",value);
   end
  end
 endtask
 task check_frozen;
  integer i;
  begin
   while(!dut.release_snapshot)begin
    @(negedge dut.clk);
    if(current_metadata!==metadata)$fatal(1,"UART snapshot metadata changed while sending");
    if(dut.ana.time_we || dut.curve_we)$fatal(1,"Snapshot RAM write while sending");
   end
   if(!dut.sent || dut.uart_busy || !tx)$fatal(1,"Release before final UART stop completed");
   for(i=0;i<256;i=i+1)begin
    if(dut.ana.times[i]!==frozen_time[i] || dut.spec_mem[i]!==frozen_spec[i])
     $fatal(1,"Snapshot memory changed at %0d",i);
   end
  end
 endtask
 initial begin
  completed=0;
  repeat(5)@(negedge sys_clk);rst_n=1;
  // Cancel a partial on-wire packet, then prove complete packet recovery.
  wait(dut.uart.state==dut.uart.SEND && dut.uart.pos==30);
  @(negedge sys_clk);rst_n=0;
  #1;if(tx!==1 || dut.done!==0 || dut.uart_busy!==0)$fatal(1,"Top reset during transmit");
  repeat(5)@(negedge sys_clk);rst_n=1;
  f=$fopen($sformatf("sim/rearm_%0d.hex",REFRESH),"w");
  for(j=0;j<FRAMES;j=j+1)begin
   wait(dut.done);@(negedge dut.clk);
   current_frame=dut.frame_id;metadata=current_metadata;
   if(dut.peak_bin!=1024 || dut.bw_bins!=1 || dut.active_count!=8192 || dut.latency_cycles!=57460)
    $fatal(1,"UART-only rearm metrics");
   if(j==0 && (current_frame!=0 || dut.frames_skipped!=0))$fatal(1,"Reset did not restart frame zero");
   if(j>0 && (current_frame<=previous_frame || dut.frames_skipped!=current_frame-previous_frame-1))
    $fatal(1,"Rearm frame/skip sequence");
   for(k=0;k<256;k=k+1)begin frozen_time[k]=dut.ana.times[k];frozen_spec[k]=dut.spec_mem[k];end
   fork receive_packet;check_frozen;join
   @(negedge dut.clk);
   if(dut.done || dut.uart_busy)$fatal(1,"Snapshot did not release after sent");
   if(dut.in_frame<=current_frame)$fatal(1,"FFT source stalled while sending");
   $display("PASS UART-only rearm refresh=%0d snapshot=%0d frame=%0d skipped=%0d latency=%0d",
    REFRESH,j,current_frame,dut.frames_skipped,dut.latency_cycles);
   previous_frame=current_frame;completed=completed+1;
  end
  $fclose(f);
  if(completed!=FRAMES)$fatal(1,"Missing rearm packet");
  $finish;
 end
 initial begin #4000000;$fatal(1,"UART-only rearm timeout");end
endmodule
