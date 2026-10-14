`timescale 1ns/1ps
// Radix-2^2 branch order 0,2,1,3. Q1.11 coefficients, 3 real multipliers.
// Eight stages (7 edge intervals), one sample/clock including valid bubbles:
// exponent -> ROM address/data -> ROM output -> quadrant -> preadd ->
// multiply -> combine -> truncate/exact-axis selection.
module r22_twiddle_rev13 #(parameter LOGN=13, ROM_FILE="data/sin_tw_8192.hex", RAM_STYLE="M9K", MIF_FILE="data/sin_tw_8192.mif")(
 input clk,rst_n,vin,input signed [11:0] xr,xi,
 output reg vout,output reg signed [11:0] yr,yi);
 reg [LOGN-1:0] count;
 wire [1:0] branch={count[LOGN-2],count[LOGN-1]};
 wire [LOGN-1:0] n={{2{1'b0}},count[LOGN-3:0]};
 wire [LOGN-1:0] expn=branch==0 ? 0:branch==1 ? n:branch==2 ? (n<<1):n+(n<<1);
 reg [LOGN-1:0] exp0;
 reg signed [11:0] a0,b0;
 reg v0;
 wire [LOGN-3:0] cos_addr=-exp0[LOGN-3:0];
 wire [11:0] cos_rom,sin_rom;
 reg [1:0] quad1,quad2;
 reg exact1;
 reg signed [11:0] a1,b1,a2,b2,a3,b3;
 reg signed [11:0] c3,s3;
 reg signed [12:0] ab4,cs4,sc4;
 reg signed [11:0] a4,b4,c4;
 reg signed [25:0] p1,p2,p3;
 reg signed [26:0] real6,imag6;
 reg [5:0] vp;
 reg [4:0] ep;
 reg signed [11:0] er3,ei3,er4,ei4,er5,ei5,er6,ei6;

 // Both ports use CLOCK0, with the internal M9K output registers enabled.
 fft_twiddle_rom #(.AW(LOGN-2),.HEX_FILE(ROM_FILE),.MIF_FILE(MIF_FILE),.RAM_STYLE(RAM_STYLE))
  coefficients(clk,v0,exp0[LOGN-3:0],cos_addr,sin_rom,cos_rom);

 always @(posedge clk or negedge rst_n)
 if(!rst_n)begin count<=0;vp<=0;vout<=0;ep<=0;exact1<=0;yr<=0;yi<=0;v0<=0;exp0<=0;a0<=0;b0<=0;end
 else begin
  v0<=vin;vp<={vp[4:0],v0};vout<=vp[5];
  ep<={ep[3:0],exact1};
  // Register branch/exponent computation before cosine-address negation.
  if(vin)begin
   count<=count+1'b1;exp0<=expn;a0<=xr;b0<=xi;
  end
  // The following original stages keep their local data/tag alignment.
  if(v0)begin
   quad1<=exp0[LOGN-1:LOGN-2];
   exact1<=exp0[LOGN-3:0]==0;a1<=a0;b1<=b0;
  end
  // Stage 2: sample and quadrant align with the new ROM output register.
  a2<=a1;b2<=b1;quad2<=quad1;
  // Stage 3: quadrant/sign reconstruction is isolated from the preadders.
  a3<=a2;b3<=b2;
  case(quad2)
   0:begin c3<=$signed(cos_rom);s3<=-$signed(sin_rom);er3<=a2;ei3<=b2;end
   1:begin c3<=-$signed(sin_rom);s3<=-$signed(cos_rom);er3<=b2;ei3<=-a2;end
   2:begin c3<=-$signed(cos_rom);s3<=$signed(sin_rom);er3<=-a2;ei3<=-b2;end
   3:begin c3<=$signed(sin_rom);s3<=$signed(cos_rom);er3<=-b2;ei3<=a2;end
  endcase
  // Stage 4: one 13-bit add/subtract on each coefficient path.
  ab4<=$signed(a3)+$signed(b3);cs4<=$signed(c3)+$signed(s3);sc4<=$signed(s3)-$signed(c3);
  a4<=a3;b4<=b3;c4<=c3;er4<=er3;ei4<=ei3;
  // Stages 5 and 6 preserve the three-multiply arithmetic and bit widths.
  p1<=ab4*c4;p2<=b4*cs4;p3<=a4*sc4;er5<=er4;ei5<=ei4;
  real6<=$signed(p1)-$signed(p2);imag6<=$signed(p1)+$signed(p3);er6<=er5;ei6<=ei5;
  // Stage 7: exact rotations preserve unity and signed 12-bit wraparound.
  yr<=ep[4] ? er6 : real6>>>11;yi<=ep[4] ? ei6 : imag6>>>11;
 end
endmodule
