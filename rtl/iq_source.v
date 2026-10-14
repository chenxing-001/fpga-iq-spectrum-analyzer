`timescale 1ns/1ps
// Deterministic 12-bit IQ, one complex sample per clock after a 3-stage fill.
// rev18: logic ROM bank reads -> quadrant selection -> sum/gate/output.
// Index/frame/mode/valid follow every data stage; the sample sequence is unchanged.
module iq_source(input clk,rst_n,output reg valid,
 output reg signed [11:0] i,q,output reg [12:0] index,output reg [31:0] frame,output reg [1:0] mode);
 // This is a ROM, not a RAM. Revision 17's ramstyle hint allowed an
 // unregistered M9K read plus quadrant mux in the same timing path.
 (* romstyle="logic" *) reg signed [11:0] sine[0:255];
 initial $readmemh("data/sine.hex",sine);
 reg [12:0] n;reg [31:0] fid;reg [15:0] phase,phase2,sweep_step;
 wire [1:0] m=fid[16:15];
 // sin(a) and cos(a) use the SAME low six address bits and adjacent banks.
 // Register the small bank reads before selecting the quadrant.
 wire [47:0] banks_a,banks_b;
 genvar g;
 generate for(g=0;g<4;g=g+1)begin: sine_banks
  localparam [1:0] BANK=g;
  (* preserve *) reg signed [11:0] ra,rb;
  always @(posedge clk)begin
   ra<=sine[{BANK,phase[13:8]}];rb<=sine[{BANK,phase2[13:8]}];
  end
  assign banks_a[g*12 +: 12]=ra;assign banks_b[g*12 +: 12]=rb;
 end endgenerate
 reg [1:0] qa1,qb1,ca1,cb1,m1,m2;
 reg [12:0] n1,n2;reg [31:0] f1,f2;reg gate1,gate2,v1,v2;
 reg signed [11:0] cos_a2,sin_a2,cos_b2,sin_b2;
 wire signed [12:0] sum_i=$signed(cos_a2)+($signed(cos_b2)>>>1);
 wire signed [12:0] sum_q=$signed(sin_a2)+($signed(sin_b2)>>>1);
 function [11:0] pick;
  input [47:0] banks;input [1:0] quadrant;
  begin case(quadrant)
   0:pick=banks[11:0];1:pick=banks[23:12];2:pick=banks[35:24];3:pick=banks[47:36];
  endcase end
 endfunction
 always @(posedge clk or negedge rst_n)
 if(!rst_n)begin
  n<=0;fid<=0;phase<=0;phase2<=0;sweep_step<=4096;
  v1<=0;v2<=0;valid<=0;i<=0;q<=0;index<=0;frame<=0;mode<=0;
  qa1<=0;qb1<=0;ca1<=0;cb1<=0;m1<=0;m2<=0;n1<=0;n2<=0;f1<=0;f2<=0;gate1<=0;gate2<=0;
  cos_a2<=0;sin_a2<=0;cos_b2<=0;sin_b2<=0;
 end
 else begin
  v1<=1;v2<=v1;valid<=v2;
  qa1<=phase[15:14];ca1<=phase[15:14]+2'd1;
  qb1<=phase2[15:14];cb1<=phase2[15:14]+2'd1;
  n1<=n;f1<=fid;m1<=m;gate1<=(m!=2)||(n>=1024 && n<5120);
  cos_a2<=pick(banks_a,ca1);sin_a2<=pick(banks_a,qa1);
  cos_b2<=pick(banks_b,cb1);sin_b2<=pick(banks_b,qb1);
  n2<=n1;f2<=f1;m2<=m1;gate2<=gate1;
  index<=n2;frame<=f2;mode<=m2;
  i<=!gate2 ? 0:m2==1 ? sum_i[11:0]:cos_a2;
  q<=!gate2 ? 0:m2==1 ? sum_q[11:0]:sin_a2;
  n<=n+1'b1;
  if(n==8191)begin fid<=fid+1'b1;phase<=0;phase2<=0;sweep_step<=4096;end
  else begin
   // sweep_step == (4096 + 4*n) modulo 65536. Register the increment
   // separately so the phase accumulator no longer contains two adders.
   sweep_step<=sweep_step+16'd4;
   phase<=phase+(m==3 ? sweep_step:16'd8192);phase2<=phase2-16'd4096;
  end
 end
endmodule
