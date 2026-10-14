`timescale 1ns/1ps
// Unsigned 25-bit maximum, one accepted sample per clock.
// Alternate ACCEPTED samples between two lanes. Each lane is revisited at
// least two edges later, after its preceding compare has committed, even
// with valid bubbles. A plain delayed single-lane maximum is NOT equivalent.
//
// clear starts a new window and cancels pending work. After the last accepted
// sample allow one drain edge, then assert merge for one edge with valid_in=0.
// Keep inputs idle until the following edge publishes peak_power/peak_tag.
// Outputs are snapshots (not a running maximum); they hold until clear/merge.
// Strict > preserves first arrival on ties, independent of tag/bin ordering.
module peak_interleaved #(parameter TAG_W=21)(
 input clk,rst_n,clear,valid_in,
 input [24:0] power_in,input [TAG_W-1:0] tag_in,input merge,
 output reg [24:0] peak_power,output reg [TAG_W-1:0] peak_tag);
 reg lane,lane_q,valid_q,merge_q,earlier1,earlier1_q;
 reg valid0_q,valid1_q;
 reg [24:0] power0,power1,candidate;
 reg [TAG_W-1:0] tag0,tag1,candidate_tag;
 // Revision20: rebalance the two-edge feedback path to 8/8/9-bit groups.
 // Rev19's seven-group reduction and kept greater/write nets mapped to
 // six logic levels followed by a 46-load enable. Three groups need only
 // a short priority reduction. Acceptance is folded into the registered
 // greater flags, so it is not another gate after that reduction.
 // Preserve registers, but let synthesis absorb the combinational terms.
 (* preserve *) reg [2:0] gt0_q,eq0_q,gt1_q,eq1_q,gtm_q,eqm_q;
 function reduce_gt;
  input [2:0] gt,eq;
  begin reduce_gt=gt[2] | (eq[2] & (gt[1] | (eq[1]&gt[0])));end
 endfunction
 wire write0=reduce_gt(gt0_q,eq0_q);
 wire write1=reduce_gt(gt1_q,eq1_q);
 wire merge_greater=reduce_gt(gtm_q,eqm_q);
 wire choose1=merge_greater | ((&eqm_q) && earlier1_q);
 wire accept0=valid_in && !merge && !lane;
 wire accept1=valid_in && !merge && lane;
 integer g;
 // These greater flags now include validity; reset/clear must cancel them
 // even if a pending winner, clear and merge coincide. Equality/payload
 // registers can still clock freely because a zero greater vector cannot
 // request a write. Alternating ACCEPTED samples is unchanged.
 always @(posedge clk or negedge rst_n)
 if(!rst_n)begin gt0_q<=0;gt1_q<=0;end
 else if(clear)begin gt0_q<=0;gt1_q<=0;end
 else begin
  gt0_q[0]<=accept0 && power_in[7:0]>power0[7:0];
  gt0_q[1]<=accept0 && power_in[15:8]>power0[15:8];
  gt0_q[2]<=accept0 && power_in[24:16]>power0[24:16];
  gt1_q[0]<=accept1 && power_in[7:0]>power1[7:0];
  gt1_q[1]<=accept1 && power_in[15:8]>power1[15:8];
  gt1_q[2]<=accept1 && power_in[24:16]>power1[24:16];
 end
 always @(posedge clk)begin
  lane_q<=lane;candidate<=power_in;candidate_tag<=tag_in;earlier1_q<=earlier1;
  for(g=0;g<2;g=g+1)begin
   eq0_q[g]<=power_in[g*8 +:8]==power0[g*8 +:8];
   eq1_q[g]<=power_in[g*8 +:8]==power1[g*8 +:8];
   gtm_q[g]<=power1[g*8 +:8]>power0[g*8 +:8];
   eqm_q[g]<=power1[g*8 +:8]==power0[g*8 +:8];
  end
  eq0_q[2]<=power_in[24:16]==power0[24:16];
  eq1_q[2]<=power_in[24:16]==power1[24:16];
  gtm_q[2]<=power1[24:16]>power0[24:16];
  eqm_q[2]<=power1[24:16]==power0[24:16];
 end
 always @(posedge clk or negedge rst_n)
 if(!rst_n)begin
  lane<=0;valid_q<=0;valid0_q<=0;valid1_q<=0;merge_q<=0;earlier1<=0;
  power0<=0;power1<=0;tag0<=0;tag1<=0;peak_power<=0;peak_tag<=0;
 end else if(clear)begin
  lane<=0;valid_q<=0;valid0_q<=0;valid1_q<=0;merge_q<=0;earlier1<=0;
  power0<=0;power1<=0;tag0<=0;tag1<=0;peak_power<=0;peak_tag<=0;
 end else begin
  valid_q<=valid_in && !merge;merge_q<=merge;
  valid0_q<=valid_in && !merge && !lane;
  valid1_q<=valid_in && !merge && lane;
  if(valid_in && !merge)lane<=!lane;
  if(write0)begin power0<=candidate;tag0<=candidate_tag;end
  if(write1)begin power1<=candidate;tag1<=candidate_tag;end
  // The flags are mutually exclusive and commits remain in arrival order.
  // A winning sample makes the other lane earlier for a future equal tie.
  if(write0)earlier1<=1;
  else if(write1)earlier1<=0;
  if(merge_q)begin
   peak_power<=choose1 ? power1:power0;
   peak_tag<=choose1 ? tag1:tag0;
  end
 end
endmodule
