`timescale 1ns/1ps
// Wire format v1: 48-byte header + 1024-byte IQ + 256-byte spectrum + CRC16.
// CRC16-CCITT: init FFFF, polynomial 1021, MSB first, no final XOR.
// Revision 16: predecode header lane and register baud terminal look-ahead.
// Same clock as analyzer. Metadata and RAM must stay immutable until sent;
// done is a level handshake. Hold done high until sent, then lower to re-arm.
module uart_packet #(parameter CLKS_PER_BIT=1736)(
 input clk,rst_n,input done,
 input [31:0] frame_id,latency_cycles,frames_skipped,
 input [1:0] mode,clipped,input [12:0] peak_bin,
 input [13:0] bw_bins,active_count,span_count,longest_run,
 input [24:0] peak_power,time_peak_power,input [37:0] energy,input [7:0] peak_code,
 input [15:0] panel_id,
 output [7:0] time_addr,input [23:0] time_data,
 output [7:0] spec_addr,input [7:0] spec_data,
 output reg sent,output reg tx,output reg busy);
 localparam TOTAL=1330;
 localparam [2:0] IDLE=0,DECODE=1,GROUP=2,HEADER=3,BYTE=4,LOAD=5,SEND=6,RELEASE=7;
 localparam [1:0] SEL_HEADER=0,SEL_TIME=1,SEL_SPEC=2,SEL_CRC=3;
 reg [2:0] state;
 reg [10:0] pos;
 reg [15:0] crc;
 reg [3:0] crc_bits;
 reg [9:0] shift;
 reg [15:0] baud_count;
 reg baud_last;
 reg [3:0] bit_count;
 reg [2:0] lane,header_group;
 reg [7:0] lane_select;
 reg [1:0] section;
 reg last_byte,crc_enable;
 reg [7:0] h0,h1,h2,h3,h4,h5;
 reg [7:0] header_byte,time_byte,spec_byte,crc_byte,data_byte;
 reg [23:0] time_word;

 wire [10:0] time_offset=pos-11'd48;
 wire [10:0] spec_offset=pos-11'd1072;
 assign time_addr=time_offset[9:2];
 assign spec_addr=spec_offset[7:0];

 // Each group is little endian: byte 0 is in bits [7:0].
 // Six independent 8:1 muxes -> registers -> one 6:1 mux -> register.
 // The final section mux has another register before the CRC XOR.
 wire [63:0] header0={16'd1330,4'b0,clipped,mode,8'd1,32'h54465149};
 wire [63:0] header1={32'd200000000,frame_id};
 wire [63:0] header2={2'b0,active_count,2'b0,bw_bins,3'b0,peak_bin,16'd8192};
 wire [63:0] header3={7'b0,time_peak_power,2'b0,longest_run,2'b0,span_count};
 wire [63:0] header4={latency_cycles[15:0],peak_code,2'b0,energy};
 wire [63:0] header5={frames_skipped,panel_id,latency_cycles[31:16]};
 function [7:0] byte8;
  input [63:0] word;
  input [7:0] select;
  begin
   byte8=({8{select[0]}} & word[7:0]) | ({8{select[1]}} & word[15:8]) |
         ({8{select[2]}} & word[23:16]) | ({8{select[3]}} & word[31:24]) |
         ({8{select[4]}} & word[39:32]) | ({8{select[5]}} & word[47:40]) |
         ({8{select[6]}} & word[55:48]) | ({8{select[7]}} & word[63:56]);
  end
 endfunction

 // peak_power is retained for port compatibility; v1 sends peak_code only.
 // Even divisor 1 gives ten SEND clocks, sufficient for eight CRC steps.
`ifndef SYNTHESIS
 initial begin
  if(CLKS_PER_BIT<1 || CLKS_PER_BIT>65536)
   $fatal(1,"uart_packet: CLKS_PER_BIT must be in 1..65536");
 end
`endif
 always @(posedge clk or negedge rst_n)
 if(!rst_n) begin
  state<=IDLE;pos<=0;crc<=16'hffff;crc_bits<=0;
  sent<=0;tx<=1;busy<=0;shift<=0;baud_count<=0;bit_count<=0;
  baud_last<=(CLKS_PER_BIT==1);lane_select<=8'b1;
  lane<=0;header_group<=0;section<=SEL_HEADER;last_byte<=0;crc_enable<=0;
  h0<=0;h1<=0;h2<=0;h3<=0;h4<=0;h5<=0;
  header_byte<=0;time_byte<=0;spec_byte<=0;crc_byte<=0;data_byte<=0;time_word<=0;
 end else begin
  sent<=0;
  case(state)
   IDLE:if(done) begin
    busy<=1;pos<=0;crc<=16'hffff;crc_bits<=0;state<=DECODE;
   end
   DECODE:begin
    // RAM addresses settle here. GROUP samples the synchronous RAM outputs
    // on the next edge, after one complete RAM read cycle.
    lane<=pos[2:0];header_group<=pos[5:3];
    lane_select<=8'b1<<pos[2:0];
    last_byte<=(pos==TOTAL-1);crc_enable<=(pos<11'd1328);
    if(pos<11'd48) section<=SEL_HEADER;
    else if(pos<11'd1072) section<=SEL_TIME;
    else if(pos<11'd1328) section<=SEL_SPEC;
    else section<=SEL_CRC;
    state<=GROUP;
   end
   GROUP:begin
    h0<=byte8(header0,lane_select);h1<=byte8(header1,lane_select);
    h2<=byte8(header2,lane_select);h3<=byte8(header3,lane_select);
    h4<=byte8(header4,lane_select);h5<=byte8(header5,lane_select);
    // The long RAM output path ends at this register, before the mux.
    time_word<=time_data;
    spec_byte<=spec_data;crc_byte<=lane[0] ? crc[15:8]:crc[7:0];
    state<=HEADER;
   end
   HEADER:begin
    // Lane remains stable until the next DECODE. Reuse this existing
    // state so packet bytes, baud rate and inter-byte timing are unchanged.
    case(lane[1:0])
     0:time_byte<=time_word[19:12];
     1:time_byte<={{4{time_word[23]}},time_word[23:20]};
     2:time_byte<=time_word[7:0];
     3:time_byte<={{4{time_word[11]}},time_word[11:8]};
    endcase
    case(header_group)
     0:header_byte<=h0;1:header_byte<=h1;2:header_byte<=h2;
     3:header_byte<=h3;4:header_byte<=h4;5:header_byte<=h5;
     default:header_byte<=0;
    endcase
    state<=BYTE;
   end
   BYTE:begin
    case(section)
     SEL_HEADER:data_byte<=header_byte;
     SEL_TIME:data_byte<=time_byte;
     SEL_SPEC:data_byte<=spec_byte;
     SEL_CRC:data_byte<=crc_byte;
    endcase
    state<=LOAD;
   end
   LOAD:begin
    shift<={1'b1,data_byte,1'b0};tx<=0;
    baud_count<=0;bit_count<=0;state<=SEND;
    baud_last<=(CLKS_PER_BIT==1);
    if(crc_enable) begin crc<=crc^{data_byte,8'b0};crc_bits<=8;end
    else crc_bits<=0; // trailer must not feed back into CRC
   end
   SEND:begin
    // No byte mux and no unrolled eight-bit CRC network on this path.
    if(crc_bits!=0) begin
     crc<={crc[14:0],1'b0} ^ (crc[15] ? 16'h1021:16'h0000);
     crc_bits<=crc_bits-1'b1;
    end
    // The look-ahead flag equals the old terminal comparison on each SEND
    // edge, including divisors 1, 2 and 65536. Byte/bit cadence is unchanged.
    if(baud_last) begin
     baud_count<=0;
     baud_last<=(CLKS_PER_BIT==1);
     if(bit_count==9) begin
      tx<=1;
      if(last_byte) begin sent<=1;busy<=0;state<=RELEASE;end
      else begin pos<=pos+1'b1;state<=DECODE;end
     end else begin
      bit_count<=bit_count+1'b1;shift<={1'b1,shift[9:1]};tx<=shift[1];
     end
    end else begin
     baud_count<=baud_count+1'b1;
     baud_last<=(baud_count==CLKS_PER_BIT-2);
    end
   end
   RELEASE:if(!done)state<=IDLE;
   default:begin state<=IDLE;tx<=1;busy<=0;crc_bits<=0;end
  endcase
 end
endmodule
