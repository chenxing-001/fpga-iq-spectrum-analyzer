`timescale 1ns/1ps
// Revision 17: UART/PC only. One 200 MHz processing and UART clock domain.
// The source and FFT run continuously while the selected snapshot is sent.
module spectrum_streaming_top #(
 parameter UART_CLKS_PER_BIT=1736,
 parameter REFRESH_CYCLES=40000000
)(
 input sys_clk,sys_rst_n,
 output uart_txd,output [3:0] led
);
 wire clk,locked;
 pll_50_to_200 u_pll(sys_clk,sys_rst_n,clk,locked);
 wire async_rst_n=sys_rst_n && locked;
 (* altera_attribute="-name SYNCHRONIZER_IDENTIFICATION FORCED_IF_ASYNCHRONOUS" *)
 reg [2:0] r200;
 always @(posedge clk or negedge async_rst_n)
  if(!async_rst_n)r200<=0;else r200<={r200[1:0],1'b1};
 wire rst_n=r200[2];

 wire iv,fv;
 wire signed [11:0] ir,ii,fr,fi;
 wire [12:0] in_index,bin;
 wire [31:0] in_frame,fft_frame;
 wire [1:0] in_mode;
 iq_source src(clk,rst_n,iv,ir,ii,in_index,in_frame,in_mode);
 fft8192_stream fft(clk,rst_n,iv,ir,ii,fv,fr,fi,bin,fft_frame);

 // sent pulses only after the complete final stop bit. Metadata and both
 // snapshot RAMs remain frozen until this acknowledgement is observed.
 wire done,sent,uart_busy;
 wire release_snapshot=done && sent;
 wire [31:0] frame_id,latency_cycles,frames_skipped;
 wire [1:0] mode,clipped;
 wire [12:0] peak_bin;
 wire [13:0] bw_bins,active_count,span_count,longest_run;
 wire [24:0] peak_power,time_peak_power;
 wire [37:0] energy;
 wire [7:0] peak_code,time_addr,spec_addr,curve_addr,curve_data;
 wire [23:0] time_data;
 wire curve_we;
 snapshot_analyzer #(.REFRESH_CYCLES(REFRESH_CYCLES)) ana(
  .clk(clk),.rst_n(rst_n),.iv(iv),.ir(ir),.ii(ii),.in_index(in_index),
  .in_frame(in_frame),.in_mode(in_mode),.fv(fv),.fr(fr),.fi(fi),.bin(bin),
  .fft_frame(fft_frame),.release_snapshot(release_snapshot),
  .time_we(),.time_waddr(),.time_wdata(),.time_addr(time_addr),.time_data(time_data),
  .curve_we(curve_we),.curve_addr(curve_addr),.curve_data(curve_data),
  .done(done),.frame_id(frame_id),.latency_cycles(latency_cycles),.frames_skipped(frames_skipped),
  .mode(mode),.peak_bin(peak_bin),.bw_bins(bw_bins),.active_count(active_count),
  .span_count(span_count),.longest_run(longest_run),.peak_power(peak_power),
  .time_peak_power(time_peak_power),.energy(energy),.peak_code(peak_code),.clipped(clipped)
 );
 (* ramstyle="M9K" *) reg [7:0] spec_mem[0:255];
 reg [7:0] spec_data;
 always @(posedge clk)begin
  if(curve_we)spec_mem[curve_addr]<=curve_data;
  spec_data<=spec_mem[spec_addr];
 end

 // Keep the v1 1330-byte packet layout. The legacy panel_id port supplies
 // reserved bytes 42..43, fixed to zero in this UART-only project.
 uart_packet #(.CLKS_PER_BIT(UART_CLKS_PER_BIT)) uart(
  .clk(clk),.rst_n(rst_n),.done(done),.frame_id(frame_id),.latency_cycles(latency_cycles),
  .frames_skipped(frames_skipped),.mode(mode),.clipped(clipped),.peak_bin(peak_bin),
  .bw_bins(bw_bins),.active_count(active_count),.span_count(span_count),.longest_run(longest_run),
  .peak_power(peak_power),.time_peak_power(time_peak_power),.energy(energy),
  .peak_code(peak_code),.panel_id(16'h0000),.time_addr(time_addr),.time_data(time_data),
  .spec_addr(spec_addr),.spec_data(spec_data),.sent(sent),.tx(uart_txd),.busy(uart_busy)
 );
 reg [26:0] heartbeat;
 always @(posedge clk or negedge rst_n)
  if(!rst_n)heartbeat<=0;else heartbeat<=heartbeat+1'b1;
 assign led=~{heartbeat[26],done,uart_busy,locked};
endmodule
