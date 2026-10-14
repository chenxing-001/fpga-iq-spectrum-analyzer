`timescale 1ns/1ps
module tb_uart_rev16;
 parameter CPB=4,FRAMES=1,RESET_TESTS=0,SHORT_TEST=0;
 localparam SIZE=1330,REFERENCE_FRAMES=20,BIT_NS=CPB*10;
 reg clk=0;always #5 clk=~clk;
 reg rst_n=0,done=0;
 reg [31:0] frame_id,latency_cycles,frames_skipped;
 reg [1:0] mode,clipped;
 reg [12:0] peak_bin;
 reg [13:0] bw_bins,active_count,span_count,longest_run;
 reg [24:0] time_peak_power;
 reg [37:0] energy;
 reg [7:0] peak_code;
 reg [15:0] panel_id;
 wire [7:0] ta,sa;
 reg [23:0] td,time_mem[0:255];
 reg [7:0] sd,spec_mem[0:255];
 reg [7:0] reference_bytes[0:REFERENCE_FRAMES*SIZE-1];
 wire tx,sent,busy;
 integer checked_packets=0,reset_count=0,frame,rc;
 reg previous_sent=0;
 uart_packet #(.CLKS_PER_BIT(CPB)) dut(
  .clk(clk),.rst_n(rst_n),.done(done),.frame_id(frame_id),
  .latency_cycles(latency_cycles),.frames_skipped(frames_skipped),
  .mode(mode),.clipped(clipped),.peak_bin(peak_bin),.bw_bins(bw_bins),
  .active_count(active_count),.span_count(span_count),.longest_run(longest_run),
  .peak_power(25'd0),.time_peak_power(time_peak_power),.energy(energy),
  .peak_code(peak_code),.panel_id(panel_id),.time_addr(ta),.time_data(td),
  .spec_addr(sa),.spec_data(sd),.sent(sent),.tx(tx),.busy(busy));
 wire [7:0] ref_ta,ref_sa;wire ref_sent,ref_tx,ref_busy;
 uart_packet_rev15 #(.CLKS_PER_BIT(CPB)) ref_design(
  .clk(clk),.rst_n(rst_n),.done(done),.frame_id(frame_id),
  .latency_cycles(latency_cycles),.frames_skipped(frames_skipped),
  .mode(mode),.clipped(clipped),.peak_bin(peak_bin),.bw_bins(bw_bins),
  .active_count(active_count),.span_count(span_count),.longest_run(longest_run),
  .peak_power(25'd0),.time_peak_power(time_peak_power),.energy(energy),
  .peak_code(peak_code),.panel_id(panel_id),.time_addr(ref_ta),.time_data(td),
  .spec_addr(ref_sa),.spec_data(sd),.sent(ref_sent),.tx(ref_tx),.busy(ref_busy));
 always @(posedge clk)begin
  #0.1;
  if(rst_n && {ta,sa,sent,tx,busy,dut.state,dut.pos,dut.crc,dut.baud_count,dut.bit_count,dut.data_byte} !==
             {ref_ta,ref_sa,ref_sent,ref_tx,ref_busy,ref_design.state,ref_design.pos,ref_design.crc,ref_design.baud_count,ref_design.bit_count,ref_design.data_byte})
   $fatal(1,"Rev16/rev15 UART differs divisor=%0d pos=%0d state=%0d count=%0d",CPB,dut.pos,dut.state,dut.baud_count);
  if(rst_n && dut.state==dut.SEND && dut.baud_last!==(dut.baud_count==CPB-1))
   $fatal(1,"baud terminal lookahead mismatch");
 end
 always @(posedge clk) begin td<=time_mem[ta];sd<=spec_mem[sa];end
 always @(negedge clk) begin
  if(!rst_n) previous_sent=0;
  else begin
   if(sent && previous_sent)$fatal(1,"sent is wider than one cycle");
   if(sent && (busy || !tx))$fatal(1,"sent must follow full stop bit");
   previous_sent=sent;
  end
 end
 function [31:0] u32;
  input integer offset;
  begin u32={reference_bytes[offset+3],reference_bytes[offset+2],reference_bytes[offset+1],reference_bytes[offset]};end
 endfunction
 function [15:0] u16;
  input integer offset;
  begin u16={reference_bytes[offset+1],reference_bytes[offset]};end
 endfunction
 task fixture;
  input integer index;
  integer base,k;
  begin
   base=index*SIZE;
   frame_id=u32(base+8);latency_cycles=u32(base+38);frames_skipped=u32(base+44);
   mode=reference_bytes[base+5][1:0];clipped=reference_bytes[base+5][3:2];
   peak_bin=u16(base+18);bw_bins=u16(base+20);active_count=u16(base+22);
   span_count=u16(base+24);longest_run=u16(base+26);time_peak_power=u32(base+28);
   energy={reference_bytes[base+36][5:0],u32(base+32)};
   peak_code=reference_bytes[base+37];panel_id=u16(base+42);
   for(k=0;k<256;k=k+1) begin
    time_mem[k]={reference_bytes[base+49+4*k][3:0],reference_bytes[base+48+4*k],
                 reference_bytes[base+51+4*k][3:0],reference_bytes[base+50+4*k]};
    spec_mem[k]=reference_bytes[base+1072+k];
   end
  end
 endtask
 task reset_dut;
  begin
   @(negedge clk);rst_n=0;done=0;
   #1;if(tx!==1 || busy!==0 || sent!==0)$fatal(1,"Async reset did not clear outputs");
   repeat(3)@(negedge clk);rst_n=1;
   repeat(3)@(negedge clk);
   if(tx!==1 || busy!==0 || sent!==0)$fatal(1,"Reset did not return to idle");
  end
 endtask
 task packet;
  input integer index;
  integer byte_index,bit_index;
  reg [7:0] received;
  time start_time,previous_start;
  begin
   fixture(index);
   @(negedge clk);done=1;
   for(byte_index=0;byte_index<SIZE;byte_index=byte_index+1) begin
    @(negedge tx);start_time=$time;
    if(byte_index!=0 && start_time-previous_start!=(10*CPB+5)*10)
     $fatal(1,"Unexpected inter-byte timing at byte %0d",byte_index);
    previous_start=start_time;
    #(BIT_NS/2);
    if(tx!==0 || busy!==1 || sent!==0)$fatal(1,"Bad start bit/handshake");
    for(bit_index=0;bit_index<8;bit_index=bit_index+1) begin
     #(BIT_NS);received[bit_index]=tx;
     if(busy!==1 || sent!==0)$fatal(1,"Early packet completion");
    end
    #(BIT_NS);
    if(tx!==1 || busy!==1 || sent!==0)$fatal(1,"Bad stop bit/early sent");
    if(received!==reference_bytes[index*SIZE+byte_index])
     $fatal(1,"CPB=%0d frame=%0d byte=%0d got=%02x expected=%02x",CPB,index,byte_index,received,reference_bytes[index*SIZE+byte_index]);
   end
   wait(sent);#1;
   if($time-start_time!=10*BIT_NS+1)$fatal(1,"Final stop duration");
   if(tx!==1 || busy!==0)$fatal(1,"Packet completion outputs");
   // Keep done asserted after acknowledgement: no duplicate packet allowed.
   repeat(2)@(negedge clk);
   repeat(20) begin
    @(negedge clk);
    if(tx!==1 || busy!==0 || sent!==0)$fatal(1,"Retransmit while done held high");
   end
   done=0;repeat(3)@(negedge clk);
   checked_packets=checked_packets+1;
  end
 endtask
 initial begin
  $readmemh("sim/uart_reference.hex",reference_bytes);
  fixture(0);reset_dut;
  if(SHORT_TEST)begin
   @(negedge clk);done=1;
   wait(dut.state==dut.SEND && dut.baud_count==CPB-2);
   reset_dut; // cancel the pending terminal flag
   @(negedge clk);done=1;
   wait(dut.pos==2 && dut.state==dut.DECODE);
   reset_dut;
   $display("PASS Rev16/rev15 UART boundary CPB=%0d: two bytes cycle-exact, pending terminal reset",CPB);
   $finish;
  end
  if(RESET_TESTS) begin
   for(rc=0;rc<16;rc=rc+1) begin
    fixture(rc);@(negedge clk);done=1;
    case(rc)
     0:wait(dut.state==dut.DECODE);
     1:wait(dut.state==dut.GROUP);
     2:wait(dut.state==dut.HEADER);
     3:wait(dut.state==dut.BYTE);
     4:wait(dut.state==dut.LOAD);
     5:wait(dut.state==dut.SEND && dut.crc_bits==8);
     6:wait(dut.state==dut.SEND && dut.crc_bits==4);
     7:wait(dut.state==dut.SEND && dut.crc_bits==1);
     8:wait(dut.state==dut.SEND && dut.crc_bits==0);
     9:wait(dut.state==dut.SEND && dut.bit_count==9);
     10:wait(dut.pos==47 && dut.state==dut.SEND);
     11:wait(dut.pos==48 && dut.state==dut.SEND);
     12:wait(dut.pos==1072 && dut.state==dut.SEND);
     13:wait(dut.pos==1328 && dut.state==dut.SEND);
     14:wait(dut.pos==1329 && dut.state==dut.SEND);
     15:wait(dut.state==dut.RELEASE);
    endcase
    reset_dut;reset_count=reset_count+1;
    packet(rc); // prove full packet recovery after EVERY interrupted state
   end
  end
  for(frame=0;frame<FRAMES;frame=frame+1)packet(frame);
  $display("PASS Rev16/rev15 UART regression CPB=%0d packets=%0d bytes=%0d reset_recovery=%0d",CPB,checked_packets,checked_packets*SIZE,reset_count);
  $finish;
 end
 initial begin
  // Time literal is real to avoid a 32-bit multiplication overflow at CPB=1736.
  #(10.0*(FRAMES+50)*SIZE*(10*CPB+30));$fatal(1,"UART regression timeout");
 end
endmodule
