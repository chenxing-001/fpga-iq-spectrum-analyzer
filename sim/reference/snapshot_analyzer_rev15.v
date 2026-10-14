`timescale 1ns/1ps
// Revision 15: prepare scan addresses/decisions during existing RAM waits.
// Metadata and memories remain immutable from done until release.
module snapshot_analyzer_rev15 #(parameter REFRESH_CYCLES=40000000)(
 input clk,rst_n,
 input iv,input signed [11:0] ir,ii,input [12:0] in_index,input [31:0] in_frame,input [1:0] in_mode,
 input fv,input signed [11:0] fr,fi,input [12:0] bin,input [31:0] fft_frame,
 input release_snapshot,
 output reg time_we,output reg [7:0] time_waddr,output reg [23:0] time_wdata,
 input [7:0] time_addr,output reg [23:0] time_data,
 output reg curve_we,output reg [7:0] curve_addr,curve_data,
 output reg done,output reg [31:0] frame_id,latency_cycles,
 output reg [1:0] mode,output wire [12:0] peak_bin,
 output reg [13:0] bw_bins,active_count,span_count,longest_run,
 output wire [24:0] peak_power,time_peak_power,output reg [37:0] energy,
 output wire [7:0] peak_code,output reg [1:0] clipped,
 output reg [31:0] frames_skipped);
 localparam IDLE=0,CAPTURE=1,PREP=2,SCAN_WAIT=3,SCAN_COMPARE=4,
  SCAN_STEP=5,BW_WAIT=6,BW_COMPARE=7,BW_STEP=8,FINISH=9,HOLD=10;
 reg [3:0] state;
 reg [31:0] cooldown,timer,next_expected_frame;
 reg cooldown_ready;
 (* ramstyle="M9K, no_rw_check" *) reg [23:0] times[0:255];
 wire [7:0] rd;
 reg [12:0] addr,scan_index;
 // All look-ahead values settle during WAIT, before COMPARE consumes them.
 // Command registers isolate wide terminal/zero decodes from addr's enable.
 reg [12:0] addr_inc,addr_dec,peak_right,peak_left,addr_command;
 reg scan_last,bw_last,peak_zero,addr_commit;
 reg [1:0] wait_read;
 reg [7:0] group_max,scan_best,threshold;
 reg [13:0] bw_count;
 reg go_left,above_threshold;
 reg [12:0] first_active;
 reg [13:0] last_active_plus1,run;
 reg energy_carry;
 reg time_valid3,time_active3,active_seen;
 reg [24:0] ip3;
 reg [12:0] ix3;
 // Multiply, then add. Index/frame/valid travel with their sample.
 reg [23:0] ir2,ii2,fr2,fi2;
 reg [24:0] ip,fp;
 reg iv1,iv2,fv1,fv2;
 reg [12:0] ix1,ix2,b1,b2;
 reg [31:0] if1,if2,ff1,ff2;
 wire encoded_valid;wire [7:0] encoded_code;wire [37:0] encoded_tag;
 wire [24:0] encoded_power=encoded_tag[37:13];
 wire [12:0] encoded_bin=encoded_tag[12:0];
 power_encode_pipe power_encoder(.clk(clk),.rst_n(rst_n),
  .valid_in(fv2 && state==CAPTURE && ff2==frame_id),.power_in(fp),.tag_in({fp,b2}),
  .valid_out(encoded_valid),.code_out(encoded_code),.tag_out(encoded_tag));
 spectrum_power_ram powers(.clk(clk),.we(encoded_valid),.waddr(encoded_bin),
  .wdata(encoded_code),.raddr(addr),.q(rd));
 wire [25:0] energy_sum={1'b0,energy[24:0]}+{1'b0,ip3};
 wire [7:0] half_code_base=peak_code-8'd8;
 // PREP is entered exactly once per snapshot. Look ahead one edge to
 // emit the same merge pulse as revision 13, without scan_index/wait_read
 // decode in front of the high-fanout comparator operand muxes.
 // PREP also drains the last lane write before the first SCAN_WAIT edge.
 reg merge_peaks;
 always @(posedge clk or negedge rst_n)
 if(!rst_n)merge_peaks<=0;
 else merge_peaks<=(state==PREP);
 always @(posedge clk or negedge rst_n)
 if(!rst_n)begin
  addr<=0;addr_inc<=0;addr_dec<=0;peak_right<=0;peak_left<=0;
  addr_command<=0;scan_last<=0;bw_last<=0;peak_zero<=1;addr_commit<=0;
 end else begin
  // One-cycle arithmetic/decode stages; no extra FSM cycles are introduced.
  addr_inc<=addr+13'd1;addr_dec<=addr-13'd1;
  peak_right<=peak_bin+13'd1;peak_left<=peak_bin-13'd1;
  scan_last<=(scan_index==13'd8191);
  bw_last<=(bw_count==14'd8191);peak_zero<=(peak_power==25'd0);
  addr_commit<=0;
  if(state==SCAN_COMPARE)begin
   addr_command<=scan_last ? peak_right:addr_inc;
   addr_commit<=!scan_last || !peak_zero;
  end else if(state==BW_COMPARE)begin
   addr_command<=rd>=threshold ? (go_left ? addr_dec:addr_inc):peak_left;
   addr_commit<=(rd>=threshold) ? !bw_last:!go_left;
  end
  // A COMPARE command commits on the original STEP edge. PREP is the
  // only fixed-address initialization. No counter/peak decode reaches ena.
  if(state==PREP)addr<=13'd4096;
  else if(addr_commit)addr<=addr_command;
 end
 peak_interleaved_rev15 #(.TAG_W(21)) frequency_peak(
  .clk(clk),.rst_n(rst_n),.clear(state==IDLE),
  .valid_in(encoded_valid && state==CAPTURE),.power_in(encoded_power),
  .tag_in({encoded_bin,encoded_code}),.merge(merge_peaks),
  .peak_power(peak_power),.peak_tag({peak_bin,peak_code}));
 peak_interleaved_rev15 #(.TAG_W(1)) time_peak(
  .clk(clk),.rst_n(rst_n),.clear(state==IDLE),
  .valid_in(time_valid3 && state==CAPTURE),.power_in(ip3),.tag_in(1'b0),
  .merge(merge_peaks),.peak_power(time_peak_power),.peak_tag());
 wire accept_time=iv && ((state==CAPTURE && in_frame==frame_id && in_index<256) ||
  (state==IDLE && cooldown_ready && in_index==0));
 // Capture the decision AND its payload. Both time RAM consumers write
 // one edge after acceptance; sample zero is still selected in IDLE.
 always @(posedge clk or negedge rst_n)
 if(!rst_n)begin time_we<=0;time_waddr<=0;time_wdata<=0;end
 else begin time_we<=accept_time;time_waddr<=in_index[7:0];time_wdata<={ir,ii};end
 always @(posedge clk)begin
  ir2<=ir*ir;ii2<=ii*ii;fr2<=fr*fr;fi2<=fi*fi;
  ip<={1'b0,ir2}+{1'b0,ii2};fp<={1'b0,fr2}+{1'b0,fi2};
  time_data<=times[time_addr];
  if(time_we)times[time_waddr]<=time_wdata;
 end
 always @(posedge clk or negedge rst_n)
 if(!rst_n)begin
  iv1<=0;iv2<=0;fv1<=0;fv2<=0;ix1<=0;ix2<=0;b1<=0;b2<=0;if1<=0;if2<=0;ff1<=0;ff2<=0;
  time_valid3<=0;time_active3<=0;ip3<=0;ix3<=0;
 end else begin
  iv1<=iv;iv2<=iv1;fv1<=fv;fv2<=fv1;ix1<=in_index;ix2<=ix1;b1<=bin;b2<=b1;
  if1<=in_frame;if2<=if1;ff1<=fft_frame;ff2<=ff1;
  // Wide frame equality and threshold detection terminate at registers.
  // The matching power/index travel with these flags, including bubbles.
  time_valid3<=iv2 && state==CAPTURE && if2==frame_id;
  time_active3<=ip>25'd65536;ip3<=ip;ix3<=ix2;
 end
 always @(posedge clk or negedge rst_n)
 if(!rst_n)begin
  state<=IDLE;cooldown<=0;cooldown_ready<=1;timer<=0;done<=0;curve_we<=0;curve_addr<=0;curve_data<=0;
  frame_id<=0;next_expected_frame<=1;frames_skipped<=0;latency_cycles<=0;mode<=0;
  bw_bins<=0;active_count<=0;span_count<=0;longest_run<=0;run<=0;energy<=0;energy_carry<=0;active_seen<=0;
  clipped<=0;first_active<=0;last_active_plus1<=0;
  wait_read<=0;scan_index<=0;group_max<=0;scan_best<=0;threshold<=0;
  bw_count<=0;go_left<=0;above_threshold<=0;
 end else begin
  curve_we<=0;energy_carry<=0;
  // High energy word consumes the preceding sample's carry. It drains
  // before FFT capture completes; no 38-bit accumulator carry path remains.
  if(energy_carry)energy[37:25]<=energy[37:25]+1'b1;
  if(cooldown!=0)cooldown<=cooldown-1'b1;
  // Look ahead one count: ready and cooldown==0 become true on the same
  // edge. The wide counter decode terminates at this register, not at the
  // frame-start muxes and the high-fanout statistics enables.
  if(cooldown==1)cooldown_ready<=1;
  if(state!=IDLE && state!=HOLD)timer<=timer+1'b1;
  case(state)
   IDLE:begin
    // Clear throughout IDLE, including the accepting edge. The input
    // statistics pipeline commits sample zero three edges after acceptance.
    // None of these clears depends on the frame-start condition.
    energy<=0;energy_carry<=0;
    active_count<=0;span_count<=0;longest_run<=0;run<=0;clipped<=0;
    first_active<=0;last_active_plus1<=0;
    active_seen<=0;
    if(cooldown_ready && iv && in_index==0)begin
     state<=CAPTURE;frame_id<=in_frame;mode<=in_mode;timer<=0;done<=0;
     frames_skipped<=in_frame==0 ? 0:in_frame-next_expected_frame;
     next_expected_frame<=in_frame+1'b1;
    end
   end
   CAPTURE:begin
    if(time_valid3)begin
     energy[24:0]<=energy_sum[24:0];energy_carry<=energy_sum[25];
     if(time_active3)begin
      active_count<=active_count+1'b1;run<=run+1'b1;
      if(!active_seen)first_active<=ix3;
      active_seen<=1;
      last_active_plus1<={1'b0,ix3}+1'b1;
      // Compare old count in parallel with increment, preserving tie behavior.
      if(run>=longest_run)longest_run<=run+1'b1;
      if(ix3==0)clipped[0]<=1;
      if(ix3==8191)clipped[1]<=1;
     end else run<=0;
    end
    if(encoded_valid)begin
     // End after the final encoded write, including all three stages.
     if(encoded_bin==8191)state<=PREP;
    end
   end
   PREP:begin
    span_count<=active_count==0 ? 14'd0:last_active_plus1-{1'b0,first_active};
    scan_index<=0;wait_read<=2;group_max<=0;state<=SCAN_WAIT;
   end
   SCAN_WAIT:if(wait_read!=0)wait_read<=wait_read-1'b1;else state<=SCAN_COMPARE;
   SCAN_COMPARE:begin
    // The merged peak is now stable, long before bandwidth scanning.
    if(scan_index==0)begin
    // Preserve floor(P/2), including the lost low bit at P=4..15.
    // At P>=16 the encoder already discards that bit, so subtracting 8 is exact.
    threshold<=peak_code<16 ? 8'd1:peak_code<24 ? (half_code_base & 8'hfc):
               peak_code<32 ? (half_code_base & 8'hfe):half_code_base;
    end
    scan_best<=rd>group_max ? rd:group_max;state<=SCAN_STEP;
   end
   SCAN_STEP:begin
    if(scan_index[4:0]==31)begin
     curve_we<=1;curve_addr<=scan_index[12:5];curve_data<=scan_best;group_max<=0;
    end else group_max<=scan_best;
    if(scan_last)begin
     if(peak_zero)begin bw_bins<=0;state<=FINISH;end
     else begin bw_count<=1;go_left<=0;wait_read<=2;state<=BW_WAIT;end
    end else begin scan_index<=scan_index+1'b1;wait_read<=2;state<=SCAN_WAIT;end
   end
   BW_WAIT:if(wait_read!=0)wait_read<=wait_read-1'b1;else state<=BW_COMPARE;
   BW_COMPARE:begin above_threshold<=rd>=threshold;state<=BW_STEP;end
   BW_STEP:begin
    // One total count replaces right_count + left_count + 1 + comparison.
    if(above_threshold)begin
     if(bw_last)begin bw_bins<=8192;state<=FINISH;end
     else begin
      bw_count<=bw_count+1'b1;
      wait_read<=2;state<=BW_WAIT;
     end
    end else if(!go_left)begin go_left<=1;wait_read<=2;state<=BW_WAIT;end
    else begin bw_bins<=bw_count;state<=FINISH;end
   end
   // Last curve write reaches both consumers before done can be observed.
   FINISH:begin done<=1;latency_cycles<=timer+1'b1;state<=HOLD;end
   HOLD:if(release_snapshot)begin
    done<=0;cooldown<=REFRESH_CYCLES;cooldown_ready<=(REFRESH_CYCLES==0);state<=IDLE;
   end
   default:begin state<=IDLE;done<=0;end
  endcase
 end
endmodule
