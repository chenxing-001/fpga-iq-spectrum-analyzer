`timescale 1ns/1ps
// Two registered read stages in both implementations: address/read, then output.
// ce only stalls the address; the output stage always advances to drain bubbles.
// A primitive is intentional: two inferred read-only ports may be duplicated.
module fft_twiddle_rom #(parameter AW=11,parameter HEX_FILE="data/sin_tw_8192.hex",
 parameter MIF_FILE="data/sin_tw_8192.mif",parameter RAM_STYLE="M9K")(
 input clk,ce,input [AW-1:0] a,b,output [11:0] qa,qb);
 generate if(AW>=7)begin: large_table
`ifdef USE_ALTERA_TDP_ROM
  altsyncram #(
   .operation_mode("BIDIR_DUAL_PORT"),.intended_device_family("Cyclone IV E"),
   .ram_block_type("M9K"),.lpm_type("altsyncram"),
   .width_a(12),.widthad_a(AW),.numwords_a(1<<AW),
   .width_b(12),.widthad_b(AW),.numwords_b(1<<AW),
   .width_byteena_a(1),.width_byteena_b(1),
   .outdata_reg_a("CLOCK0"),.outdata_reg_b("CLOCK0"),
   .address_reg_b("CLOCK0"),.rdcontrol_reg_b("CLOCK0"),.indata_reg_b("CLOCK0"),.wrcontrol_wraddress_reg_b("CLOCK0"),
   .byteena_reg_b("CLOCK0"),
   .clock_enable_input_a("BYPASS"),.clock_enable_input_b("BYPASS"),
   .clock_enable_output_a("BYPASS"),.clock_enable_output_b("BYPASS"),
   .init_file(MIF_FILE),.init_file_layout("PORT_A")
  // All input registers use CLOCK0; Quartus II 13.1 rejects a connected
  // unused CLOCK1. Omit clock1 and its enable, rather than tying them off.
  ) mem(.clock0(clk),.clocken0(1'b1),
   .aclr0(1'b0),.aclr1(1'b0),.address_a(a),.address_b(b),
   .addressstall_a(~ce),.addressstall_b(~ce),
   .data_a(12'b0),.data_b(12'b0),.wren_a(1'b0),.wren_b(1'b0),
   .rden_a(1'b1),.rden_b(1'b1),.byteena_a(1'b1),.byteena_b(1'b1),.q_a(qa),.q_b(qb));
`else
  // Portable RTL simulation; vendor-model test uses the branch above.
  reg [11:0] rom[0:(1<<AW)-1];reg [11:0] ra,rb,ra_out,rb_out;
  initial $readmemh(HEX_FILE,rom);
  always @(posedge clk)begin
   if(ce)begin ra<=rom[a];rb<=rom[b];end
   ra_out<=ra;rb_out<=rb;
  end
  assign qa=ra_out;assign qb=rb_out;
`endif
 end else begin: small_table
  (* romstyle="logic" *) reg [11:0] rom[0:(1<<AW)-1];reg [11:0] ra,rb,ra_out,rb_out;
  initial $readmemh(HEX_FILE,rom);
  always @(posedge clk)begin
   if(ce)begin ra<=rom[a];rb<=rom[b];end
   ra_out<=ra;rb_out<=rb;
  end
  assign qa=ra_out;assign qb=rb_out;
 end endgenerate
endmodule
