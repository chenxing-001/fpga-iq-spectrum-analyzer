`timescale 1ns/1ps
// Radix-2^2 branch order 0,2,1,3. Q1.11 coefficients, 3 real multipliers.
// Nine stages (8 edge intervals), one sample/clock including valid bubbles:
// exponent -> ROM address/data -> ROM output -> coefficient/prefix register
// -> quadrant -> preadd -> multiply -> split combine -> carry/exact-axis selection.
// Revision22 uses the existing last two stages; no extra sample latency.
module r22_twiddle_rev22 #(parameter LOGN=13, ROM_FILE="data/sin_tw_8192.hex", RAM_STYLE="M9K", MIF_FILE="data/sin_tw_8192.mif")(
 input clk,rst_n,vin,input signed [11:0] xr,xi,
 output reg vout,output reg signed [11:0] yr,yi);
 // Revision 14: modulo-4096 negation with prefix OR/XOR logic.
 // In -x, bit 0 is unchanged; bit k is x[k] XOR OR(x[k-1:0]).
 // This avoids the ROM -> 12-bit carry chain -> coefficient register path.
 // Includes -2048 wraparound, zero and every other signed 12-bit code.
 function [11:0] negate12;
  input [11:0] x;
  begin
   negate12[0]=x[0];
   negate12[1]=x[1] ^ (|x[0:0]);
   negate12[2]=x[2] ^ (|x[1:0]);
   negate12[3]=x[3] ^ (|x[2:0]);
   negate12[4]=x[4] ^ (|x[3:0]);
   negate12[5]=x[5] ^ (|x[4:0]);
   negate12[6]=x[6] ^ (|x[5:0]);
   negate12[7]=x[7] ^ (|x[6:0]);
   negate12[8]=x[8] ^ (|x[7:0]);
   negate12[9]=x[9] ^ (|x[8:0]);
   negate12[10]=x[10] ^ (|x[9:0]);
   negate12[11]=x[11] ^ (|x[10:0]);
  end
 endfunction
 // Add a registered carry with parallel prefix AND/XOR, not a ripple chain.
 // This is modulo 4096, exactly matching the 12-bit output assignment.
 function [11:0] add_carry12;
  input [11:0] x;
  input carry;
  begin
   add_carry12[0]=x[0]^carry;
   add_carry12[1]=x[1]^(carry & x[0]);
   add_carry12[2]=x[2]^(carry & (&x[1:0]));
   add_carry12[3]=x[3]^(carry & (&x[2:0]));
   add_carry12[4]=x[4]^(carry & (&x[3:0]));
   add_carry12[5]=x[5]^(carry & (&x[4:0]));
   add_carry12[6]=x[6]^(carry & (&x[5:0]));
   add_carry12[7]=x[7]^(carry & (&x[6:0]));
   add_carry12[8]=x[8]^(carry & (&x[7:0]));
   add_carry12[9]=x[9]^(carry & (&x[8:0]));
   add_carry12[10]=x[10]^(carry & (&x[9:0]));
   add_carry12[11]=x[11]^(carry & (&x[10:0]));
  end
 endfunction
 // Revision 16: the exact-axis data already traverses stage 2. Register
 // the two low-bit prefix reductions alongside it; stage 3 only reduces
 // within a four-bit group before XOR and quadrant selection.
 function [11:0] negate12_prefix;
  input [11:0] x;
  input [1:0] prefix;
  begin
   negate12_prefix[0]=x[0];
   negate12_prefix[1]=x[1]^x[0];
   negate12_prefix[2]=x[2]^(|x[1:0]);
   negate12_prefix[3]=x[3]^(|x[2:0]);
   negate12_prefix[4]=x[4]^prefix[0];
   negate12_prefix[5]=x[5]^(prefix[0] | x[4]);
   negate12_prefix[6]=x[6]^(prefix[0] | (|x[5:4]));
   negate12_prefix[7]=x[7]^(prefix[0] | (|x[6:4]));
   negate12_prefix[8]=x[8]^prefix[1];
   negate12_prefix[9]=x[9]^(prefix[1] | x[8]);
   negate12_prefix[10]=x[10]^(prefix[1] | (|x[9:8]));
   negate12_prefix[11]=x[11]^(prefix[1] | (|x[10:8]));
  end
 endfunction
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
 reg [1:0] a_prefix2,b_prefix2;
 // Revision19: register coefficient prefix reductions before sign/mux.
 // The old small-ROM output -> wide prefix OR -> XOR -> quadrant mux
 // path crossed five logic levels in the routed revision18 design.
 (* preserve *) reg [11:0] cos2d,sin2d;
 (* preserve *) reg [1:0] cos_prefix2d,sin_prefix2d;
 reg signed [11:0] a2d,b2d;
 reg [1:0] quad2d,a_prefix2d,b_prefix2d;
 reg signed [11:0] c3,s3;
 reg signed [12:0] ab4,cs4,sc4;
 reg signed [11:0] a4,b4,c4;
 reg signed [25:0] p1,p2,p3;
 // Only result[22:11] survives arithmetic >>>11 and 12-bit assignment.
 // Split at bit 11: compute the discarded low-part carry and upper partial
 // sum independently. Preserve this boundary so the 23-bit carry chain
 // cannot be recombined through the output-stage selection.
 wire [11:0] real_low={1'b0,p1[10:0]}+{1'b0,~p2[10:0]}+12'd1;
 wire [11:0] imag_low={1'b0,p1[10:0]}+{1'b0,p3[10:0]};
 (* preserve *) reg [11:0] real_hi6,imag_hi6;
 (* preserve *) reg real_carry6,imag_carry6;
 reg [6:0] vp;
 reg [5:0] ep;
 reg signed [11:0] er3,ei3,er4,ei4,er5,ei5,er6,ei6;

 // Both ports use CLOCK0, with the internal M9K output registers enabled.
 fft_twiddle_rom #(.AW(LOGN-2),.HEX_FILE(ROM_FILE),.MIF_FILE(MIF_FILE),.RAM_STYLE(RAM_STYLE))
  coefficients(clk,v0,exp0[LOGN-3:0],cos_addr,sin_rom,cos_rom);

 always @(posedge clk or negedge rst_n)
 if(!rst_n)begin count<=0;vp<=0;vout<=0;ep<=0;exact1<=0;yr<=0;yi<=0;v0<=0;exp0<=0;a0<=0;b0<=0;end
 else begin
  v0<=vin;vp<={vp[5:0],v0};vout<=vp[6];
  ep<={ep[4:0],exact1};
  // Register branch/exponent computation before cosine-address negation.
  if(vin)begin
   count<=count+1'b1;exp0<=expn;a0<=xr;b0<=xi;
  end
  // Sample, quadrant and exact flag retain alignment through every stage.
  if(v0)begin
   quad1<=exp0[LOGN-1:LOGN-2];
   exact1<=exp0[LOGN-3:0]==0;a1<=a0;b1<=b0;
  end
  // Stage 2: sample and quadrant align with the new ROM output register.
  a2<=a1;b2<=b1;quad2<=quad1;
  a_prefix2<={|a1[7:0],|a1[3:0]};b_prefix2<={|b1[7:0],|b1[3:0]};
  // New stage: every field advances even during bubbles, like ROM output.
  cos2d<=cos_rom;sin2d<=sin_rom;
  cos_prefix2d<={|cos_rom[7:0],|cos_rom[3:0]};
  sin_prefix2d<={|sin_rom[7:0],|sin_rom[3:0]};
  a2d<=a2;b2d<=b2;quad2d<=quad2;
  a_prefix2d<=a_prefix2;b_prefix2d<=b_prefix2;
  // Stage 4: local sign reconstruction and quadrant mux.
  a3<=a2d;b3<=b2d;
  case(quad2d)
   0:begin c3<=$signed(cos2d);s3<=$signed(negate12_prefix(sin2d,sin_prefix2d));er3<=a2d;ei3<=b2d;end
   1:begin c3<=$signed(negate12_prefix(sin2d,sin_prefix2d));s3<=$signed(negate12_prefix(cos2d,cos_prefix2d));er3<=b2d;ei3<=$signed(negate12_prefix(a2d,a_prefix2d));end
   2:begin c3<=$signed(negate12_prefix(cos2d,cos_prefix2d));s3<=$signed(sin2d);er3<=$signed(negate12_prefix(a2d,a_prefix2d));ei3<=$signed(negate12_prefix(b2d,b_prefix2d));end
   3:begin c3<=$signed(sin2d);s3<=$signed(cos2d);er3<=$signed(negate12_prefix(b2d,b_prefix2d));ei3<=a2d;end
  endcase
  // Stage 5: one 13-bit add/subtract on each coefficient path.
  ab4<=$signed(a3)+$signed(b3);cs4<=$signed(c3)+$signed(s3);sc4<=$signed(s3)-$signed(c3);
  a4<=a3;b4<=b3;c4<=c3;er4<=er3;ei4<=ei3;
  // Stage 6 preserves all three multipliers and their operand widths.
  p1<=ab4*c4;p2<=b4*cs4;p3<=a4*sc4;er5<=er4;ei5<=ei4;
  // Stage 7: parallel 11-bit low / 12-bit high adders. Subtraction uses
  // p1 + ~p2 + 1; the initial +1 belongs ONLY to the low-part addition.
  real_hi6<=p1[22:11]+(~p2[22:11]);real_carry6<=real_low[11];
  imag_hi6<=p1[22:11]+p3[22:11];imag_carry6<=imag_low[11];
  er6<=er5;ei6<=ei5;
  // Stage 8: parallel carry correction followed by the existing exact mux.
  // Signed truncation, modulo wrap, valid, and exact-axis latency are unchanged.
  yr<=ep[5] ? er6 : add_carry12(real_hi6,real_carry6);
  yi<=ep[5] ? ei6 : add_carry12(imag_hi6,imag_carry6);
 end
endmodule
