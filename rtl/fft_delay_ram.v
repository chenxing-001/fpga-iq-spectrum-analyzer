`timescale 1ns/1ps
// SDF feedback RAM: address stage, then registered M9K output stage.
// Reads run each clock; valid/phase/address travel in the butterfly pipeline.
// Callers must not read an address until its preceding feedback write commits.
module fft_delay_ram #(parameter D=4096, AW=12)(
 input clk,we,input [AW-1:0] waddr,raddr,input [23:0] wdata,output [23:0] q);
`ifdef USE_ALTERA_FFT_DELAY_RAM
 altsyncram #(
  .operation_mode("DUAL_PORT"),.intended_device_family("Cyclone IV E"),
  .ram_block_type("M9K"),.lpm_type("altsyncram"),
  .width_a(24),.widthad_a(AW),.numwords_a(D),
  .width_b(24),.widthad_b(AW),.numwords_b(D),
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
 (* ramstyle="M9K, no_rw_check" *) reg [23:0] mem[0:D-1];
 reg [23:0] read1,read2;
 always @(posedge clk)begin
  if(we)mem[waddr]<=wdata;
  // A collision is intentionally poisoned in simulation. No valid SDF
  // result may depend on the unspecified mixed-port read/write behavior.
  read1<=(we && waddr==raddr) ? 24'bx:mem[raddr];
  read2<=read1;
 end
 assign q=read2;
`endif
endmodule
