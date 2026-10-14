`timescale 1ns/1ps
// Three registered stages, one value/clock. Exact legacy 8-bit power code.
// Fixed slices replace the 25-deep priority encoder + variable barrel shift.
module power_encode_pipe #(parameter TAG_W=38)(
 input clk,rst_n,valid_in,input [24:0] power_in,input [TAG_W-1:0] tag_in,
 output reg valid_out,output reg [7:0] code_out,output reg [TAG_W-1:0] tag_out);
 reg [10:0] window1;
 reg [6:0] window2;
 reg [1:0] coarse1,coarse2;
 reg upper2,zero2,one1,one2,v1,v2;
 // Revision19: eight-bit local tests, followed by a four-bit reduction.
 // The full 25-bit zero/one equality no longer terminates at stage1.
 (* preserve *) reg [3:0] zero1;
 reg [TAG_W-1:0] tag1,tag2;
 always @(posedge clk or negedge rst_n)
 if(!rst_n)begin
  window1<=0;window2<=0;coarse1<=0;coarse2<=0;upper2<=0;
  zero1<=4'b1111;zero2<=1;one1<=0;one2<=0;v1<=0;v2<=0;valid_out<=0;
  tag1<=0;tag2<=0;tag_out<=0;code_out<=0;
 end else begin
  v1<=valid_in;v2<=v1;valid_out<=v2;
  tag1<=tag_in;tag2<=tag1;tag_out<=tag2;
  zero1<={!power_in[24],power_in[23:16]==0,power_in[15:8]==0,power_in[7:0]==0};
  one1<=(power_in[7:0]==1);zero2<=&zero1;one2<=(&zero1[3:1]) && one1;
  // Stage 1: choose an octet plus the three bits immediately below it.
  if(power_in[24])begin coarse1<=3;window1<={7'b0,power_in[24:21]};end
  else if(|power_in[23:16])begin coarse1<=2;window1<=power_in[23:13];end
  else if(|power_in[15:8])begin coarse1<=1;window1<=power_in[15:5];end
  else begin coarse1<=0;window1<={power_in[7:0],3'b0};end
  // Stage 2: choose a nibble plus its three following bits.
  coarse2<=coarse1;upper2<=|window1[10:7];
  window2<=(|window1[10:7]) ? window1[10:4]:window1[6:0];
  // Stage 3: four-way local priority mux; concatenate the exponent.
  if(zero2)code_out<=0;
  else if(one2)code_out<=1;
  else if(window2[6])code_out<={coarse2,upper2,2'd3,window2[5:3]};
  else if(window2[5])code_out<={coarse2,upper2,2'd2,window2[4:2]};
  else if(window2[4])code_out<={coarse2,upper2,2'd1,window2[3:1]};
  else code_out<={coarse2,upper2,2'd0,window2[2:0]};
 end
endmodule
