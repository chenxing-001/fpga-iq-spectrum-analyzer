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
module peak_interleaved_rev15 #(parameter TAG_W=21)(
 input clk,rst_n,clear,valid_in,
 input [24:0] power_in,input [TAG_W-1:0] tag_in,input merge,
 output reg [24:0] peak_power,output reg [TAG_W-1:0] peak_tag);
 reg lane,lane_q,valid_q,merge_q,earlier1,earlier1_q;
 reg [24:0] power0,power1,candidate;
 reg [TAG_W-1:0] tag0,tag1,candidate_tag;
 reg [4:0] gt_q,eq_q;
 wire [24:0] compare_a=merge ? power1:power_in;
 wire [24:0] compare_b=(merge || !lane) ? power0:power1;
 wire greater=gt_q[4] | (eq_q[4]&gt_q[3]) |
  (&eq_q[4:3]&gt_q[2]) | (&eq_q[4:2]&gt_q[1]) |
  (&eq_q[4:1]&gt_q[0]);
 wire choose1=greater | ((&eq_q) && earlier1_q);
 integer g;
 // Unconditionally clock payload and compare bits. valid_q/merge_q guard
 // every consumer, so these bits need no reset or clear mux (area/routing).
 always @(posedge clk)begin
  lane_q<=lane;candidate<=power_in;candidate_tag<=tag_in;earlier1_q<=earlier1;
  // Short independent compares terminate at registers. Reduction and
  // lane write enables are in the NEXT cycle, breaking the feedback path.
  for(g=0;g<5;g=g+1)begin
   gt_q[g]<=compare_a[g*5 +:5]>compare_b[g*5 +:5];
   eq_q[g]<=compare_a[g*5 +:5]==compare_b[g*5 +:5];
  end
 end
 always @(posedge clk or negedge rst_n)
 if(!rst_n)begin
  lane<=0;valid_q<=0;merge_q<=0;earlier1<=0;
  power0<=0;power1<=0;tag0<=0;tag1<=0;peak_power<=0;peak_tag<=0;
 end else if(clear)begin
  lane<=0;valid_q<=0;merge_q<=0;earlier1<=0;
  power0<=0;power1<=0;tag0<=0;tag1<=0;peak_power<=0;peak_tag<=0;
 end else begin
  valid_q<=valid_in && !merge;merge_q<=merge;
  if(valid_in && !merge)lane<=!lane;
  if(valid_q && greater)begin
   if(lane_q)begin power1<=candidate;tag1<=candidate_tag;end
   else begin power0<=candidate;tag0<=candidate_tag;end
   // This lane's winning sample is now newer than the other lane's.
   // Commits occur in arrival order, so one bit suffices for cross-lane ties.
   earlier1<=!lane_q;
  end
  if(merge_q)begin
   peak_power<=choose1 ? power1:power0;
   peak_tag<=choose1 ? tag1:tag0;
  end
 end
endmodule
