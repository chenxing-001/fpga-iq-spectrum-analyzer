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
module peak_interleaved_rev19 #(parameter TAG_W=21)(
 input clk,rst_n,clear,valid_in,
 input [24:0] power_in,input [TAG_W-1:0] tag_in,input merge,
 output reg [24:0] peak_power,output reg [TAG_W-1:0] peak_tag);
 reg lane,lane_q,valid_q,merge_q,earlier1,earlier1_q;
 reg valid0_q,valid1_q;
 reg [24:0] power0,power1,candidate;
 reg [TAG_W-1:0] tag0,tag1,candidate_tag;
 // Revision 18: each lane reduces its OWN group results and has its OWN
 // registered acceptance flag. There is no lane mux before the reduction
 // and no shared greater -> lane decode -> register-enable chain.
 // Revision19: four-bit groups plus the top bit, with protected register
 // boundaries. Global physical retiming must not move their reduction
 // back into the lane feedback comparators.
 (* preserve *) reg [6:0] gt0_q,eq0_q,gt1_q,eq1_q,gtm_q,eqm_q;
 function reduce_gt;
  input [6:0] gt,eq;
  begin reduce_gt=gt[6] | (eq[6]&gt[5]) | (&eq[6:5]&gt[4]) |
   (&eq[6:4]&gt[3]) | (&eq[6:3]&gt[2]) | (&eq[6:2]&gt[1]) |
   (&eq[6:1]&gt[0]);end
 endfunction
 (* keep *) wire greater0=reduce_gt(gt0_q,eq0_q);
 (* keep *) wire greater1=reduce_gt(gt1_q,eq1_q);
 (* keep *) wire write0=valid0_q && greater0;
 (* keep *) wire write1=valid1_q && greater1;
 wire merge_greater=reduce_gt(gtm_q,eqm_q);
 wire choose1=merge_greater | ((&eqm_q) && earlier1_q);
 integer g;
 // Unconditionally clock payload and compare bits. valid_q/merge_q guard
 // every consumer, so these bits need no reset or clear mux (area/routing).
 always @(posedge clk)begin
  lane_q<=lane;candidate<=power_in;candidate_tag<=tag_in;earlier1_q<=earlier1;
  // Short independent compares terminate at registers. Reduction and
  // lane write enables are in the NEXT cycle, breaking the feedback path.
  for(g=0;g<6;g=g+1)begin
   gt0_q[g]<=power_in[g*4 +:4]>power0[g*4 +:4];
   eq0_q[g]<=power_in[g*4 +:4]==power0[g*4 +:4];
   gt1_q[g]<=power_in[g*4 +:4]>power1[g*4 +:4];
   eq1_q[g]<=power_in[g*4 +:4]==power1[g*4 +:4];
   gtm_q[g]<=power1[g*4 +:4]>power0[g*4 +:4];
   eqm_q[g]<=power1[g*4 +:4]==power0[g*4 +:4];
  end
  gt0_q[6]<=power_in[24] & !power0[24];eq0_q[6]<=power_in[24]==power0[24];
  gt1_q[6]<=power_in[24] & !power1[24];eq1_q[6]<=power_in[24]==power1[24];
  gtm_q[6]<=power1[24] & !power0[24];eqm_q[6]<=power1[24]==power0[24];
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
