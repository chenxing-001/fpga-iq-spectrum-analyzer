`timescale 1ns/1ps
// Unsigned 24+24 -> 25, TWO registered stages, one addition per clock.
// Stage 1 computes four independent six-bit sums for carry-in 0 and 1.
// Stage 2 selects the results using registered generate/propagate flags.
// No path crosses a six-bit adder AND the inter-group carry selector.
// Valid and metadata are pipelined in the caller. No reset on payload.
module power_sum24_pipe(input clk,input [23:0] a,b,output reg [24:0] sum);
 (* preserve *) reg [5:0] add0[0:3],add1[0:3];
 (* preserve *) reg [3:0] gen_q,prop_q;
 wire [4:0] carry;
 assign carry[0]=1'b0;
 assign carry[1]=gen_q[0];
 assign carry[2]=gen_q[1] | (prop_q[1]&gen_q[0]);
 assign carry[3]=gen_q[2] | (prop_q[2]&gen_q[1]) |
                 (prop_q[2]&prop_q[1]&gen_q[0]);
 assign carry[4]=gen_q[3] | (prop_q[3]&gen_q[2]) |
                 (prop_q[3]&prop_q[2]&gen_q[1]) |
                 (prop_q[3]&prop_q[2]&prop_q[1]&gen_q[0]);
 genvar g;
 generate for(g=0;g<4;g=g+1)begin: chunk
  wire [6:0] s0={1'b0,a[g*6 +:6]}+{1'b0,b[g*6 +:6]};
  wire [6:0] s1={1'b0,a[g*6 +:6]}+{1'b0,b[g*6 +:6]}+7'd1;
  always @(posedge clk)begin
   add0[g]<=s0[5:0];add1[g]<=s1[5:0];
   gen_q[g]<=s0[6];prop_q[g]<=&(a[g*6 +:6]^b[g*6 +:6]);
   sum[g*6 +:6]<=carry[g] ? add1[g]:add0[g];
  end
 end endgenerate
 always @(posedge clk)sum[24]<=carry[4];
endmodule
