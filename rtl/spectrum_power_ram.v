`timescale 1ns/1ps
// 8192 x 8, one write port, one read port, TWO rising-edge read stages.
// Explicit M9K output register: no raw RAM tCO + comparison in one cycle.
// No read data is consumed during capture; collisions are unspecified.
module spectrum_power_ram(input clk,input we,input [12:0] waddr,
 input [7:0] wdata,input [12:0] raddr,output [7:0] q);
`ifdef USE_ALTERA_POWER_RAM
 altsyncram #(
  .operation_mode("DUAL_PORT"),.intended_device_family("Cyclone IV E"),
  .ram_block_type("M9K"),.lpm_type("altsyncram"),
  .width_a(8),.widthad_a(13),.numwords_a(8192),
  .width_b(8),.widthad_b(13),.numwords_b(8192),
  .width_byteena_a(1),.width_byteena_b(1),
  .address_reg_b("CLOCK0"),.rdcontrol_reg_b("CLOCK0"),
  .outdata_reg_b("CLOCK0"),.outdata_aclr_b("NONE"),
  .clock_enable_input_a("BYPASS"),.clock_enable_input_b("BYPASS"),
  .clock_enable_output_b("BYPASS"),
  .read_during_write_mode_mixed_ports("DONT_CARE")
 ) mem(.clock0(clk),.clocken0(1'b1),.aclr0(1'b0),.aclr1(1'b0),
  .address_a(waddr),.data_a(wdata),.wren_a(we),.byteena_a(1'b1),
  .address_b(raddr),.rden_b(1'b1),.addressstall_a(1'b0),.addressstall_b(1'b0),.q_b(q));
`else
 (* ramstyle="M9K, no_rw_check" *) reg [7:0] mem[0:8191];
 reg [7:0] read1,read2;
 always @(posedge clk)begin
  if(we)mem[waddr]<=wdata;
  read1<=mem[raddr];read2<=read1;
 end
 assign q=read2;
`endif
endmodule
