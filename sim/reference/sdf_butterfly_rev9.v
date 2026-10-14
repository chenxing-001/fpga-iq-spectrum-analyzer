// Frozen rev9 reference for bit-exact sequence regression. Not synthesis input.
`timescale 1ns/1ps
// Natural stream in; DIF sum then difference stream out. One bit scaling per stage.
// Long feedback delays use synchronous simple dual-port RAM, no RAM reset.
module sdf_butterfly_rev9 #(parameter D=4096, AW=12, ROTATE=0, RAM_STYLE=(D>=16 ? "M9K, no_rw_check":"logic"))(
 input clk, rst_n, vin, input signed [11:0] xr,xi,
 output reg vout, output reg signed [11:0] yr,yi);
 reg [AW+1:0] count;
 reg filled;
 wire turn = ROTATE && count[AW+1:AW]==2'b11;
 wire signed [11:0] ar=turn ? xi:xr;
 wire signed [11:0] ai=turn ? -xr:xi;
 generate if(D==1) begin: short_delay
   reg signed [11:0] dr,di;
   wire signed [12:0] sr=$signed(dr)+$signed(ar), si=$signed(di)+$signed(ai);
   wire signed [12:0] tr=$signed(dr)-$signed(ar), ti=$signed(di)-$signed(ai);
   always @(posedge clk or negedge rst_n)
    if(!rst_n) begin count<=0;filled<=0;vout<=0;yr<=0;yi<=0;dr<=0;di<=0;end
    else begin
      vout<=0;
      if(vin) begin
        count<=count+1'b1;
        if(count[0]) begin yr<=sr>>>1;yi<=si>>>1;dr<=tr>>>1;di<=ti>>>1;filled<=1;vout<=1;end
        else begin yr<=dr;yi<=di;dr<=ar;di<=ai;vout<=filled;end
      end
    end
 end else begin: ram_delay
   (* ramstyle = RAM_STYLE *) reg [23:0] mem[0:D-1];
   reg [23:0] rd;
   reg signed [11:0] ar1,ai1;
   reg [AW-1:0] addr1;
   reg phase1,v1,good1;
   wire signed [11:0] dr=rd[23:12], di=rd[11:0];
   wire signed [12:0] sr=$signed(dr)+$signed(ar1), si=$signed(di)+$signed(ai1);
   wire signed [12:0] tr=$signed(dr)-$signed(ar1), ti=$signed(di)-$signed(ai1);
   wire [23:0] wd=phase1 ? {tr[12:1],ti[12:1]}:{ar1,ai1};
   always @(posedge clk) begin
      if(vin) rd<=mem[count[AW-1:0]];
      if(v1) mem[addr1]<=wd;
   end
   always @(posedge clk or negedge rst_n)
    if(!rst_n) begin count<=0;filled<=0;v1<=0;vout<=0;good1<=0;phase1<=0;addr1<=0;ar1<=0;ai1<=0;yr<=0;yi<=0;end
    else begin
      v1<=vin;vout<=v1 && good1;
      if(vin) begin
        count<=count+1'b1;addr1<=count[AW-1:0];phase1<=count[AW];
        ar1<=ar;ai1<=ai;good1<=filled || count[AW];
        if(count[AW]) filled<=1;
      end
      if(v1) begin yr<=phase1 ? sr[12:1]:dr;yi<=phase1 ? si[12:1]:di;end
    end
 end endgenerate
endmodule
