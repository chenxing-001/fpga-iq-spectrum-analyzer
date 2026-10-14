// Frozen rev9 reference for bit-exact sequence regression. Not synthesis input.
`timescale 1ns/1ps
// Deterministic continuous 12-bit IQ at one complex sample per clock.
// Mode changes only at 8192-sample boundaries, every 32768 frames (~1.34s @200M).
module iq_source_rev9(input clk,rst_n,output reg valid,
 output reg signed [11:0] i,q,output reg [12:0] index,output reg [31:0] frame,output reg [1:0] mode);
 (* ramstyle="logic" *) reg signed [11:0] sine[0:255];
 initial $readmemh("data/sine.hex",sine);
 reg [12:0] n;reg [31:0] fid;reg [15:0] phase,phase2;
 wire [1:0] m=fid[16:15];
 wire [7:0] a=phase[15:8],b=phase2[15:8];
 wire [7:0] ac=a+8'd64,bc=b+8'd64;
 wire gate=(m!=2)||(n>=1024 && n<5120);
 wire signed [12:0] sum_i=$signed(sine[ac])+($signed(sine[bc])>>>1);
 wire signed [12:0] sum_q=$signed(sine[a])+($signed(sine[b])>>>1);
 always @(posedge clk or negedge rst_n)
 if(!rst_n) begin n<=0;fid<=0;phase<=0;phase2<=0;valid<=0;i<=0;q<=0;index<=0;frame<=0;mode<=0;end
 else begin
  valid<=1;index<=n;frame<=fid;mode<=m;
  i<=!gate ? 0:m==1 ? sum_i[11:0]:sine[ac];
  q<=!gate ? 0:m==1 ? sum_q[11:0]:sine[a];
  n<=n+1'b1;
  if(n==8191) begin fid<=fid+1'b1;phase<=0;phase2<=0;end
  else begin phase<=phase+(m==3 ? (16'd4096+{n,2'b00}):16'd8192);phase2<=phase2-16'd4096;end
 end
endmodule
