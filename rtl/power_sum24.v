`timescale 1ns/1ps
// Unsigned 24+24 -> 25, combinational. Four independent six-bit adders
// plus parallel group carry lookahead replace a 24-bit ripple chain.
// Carry-in 0 and 1 are computed in parallel; no extra pipeline cycle.
module power_sum24(input [23:0] a,b,output [24:0] sum);
 wire [3:0] gen_c,prop_c;
 (* keep *) wire [4:0] carry;
 assign carry[0]=1'b0;
 assign carry[1]=gen_c[0];
 assign carry[2]=gen_c[1] | (prop_c[1]&gen_c[0]);
 assign carry[3]=gen_c[2] | (prop_c[2]&gen_c[1]) |
                  (prop_c[2]&prop_c[1]&gen_c[0]);
 assign carry[4]=gen_c[3] | (prop_c[3]&gen_c[2]) |
                  (prop_c[3]&prop_c[2]&gen_c[1]) |
                  (prop_c[3]&prop_c[2]&prop_c[1]&gen_c[0]);
 genvar g;
 generate for(g=0;g<4;g=g+1)begin: chunk
  (* keep *) wire [6:0] add0={1'b0,a[g*6 +:6]}+{1'b0,b[g*6 +:6]};
  (* keep *) wire [6:0] add1={1'b0,a[g*6 +:6]}+{1'b0,b[g*6 +:6]}+7'd1;
  assign gen_c[g]=add0[6];
  assign prop_c[g]=&(a[g*6 +:6]^b[g*6 +:6]);
  assign sum[g*6 +:6]=carry[g] ? add1[5:0]:add0[5:0];
 end endgenerate
 assign sum[24]=carry[4];
endmodule
