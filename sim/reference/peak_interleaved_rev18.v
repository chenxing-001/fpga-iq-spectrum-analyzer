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
module peak_interleaved_rev18 #(parameter TAG_W=21)(
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
 reg [4:0] gt0_q,eq0_q,gt1_q,eq1_q,gtm_q,eqm_q;
 (* keep *) wire greater0=gt0_q[4] | (eq0_q[4]&gt0_q[3]) |
  (&eq0_q[4:3]&gt0_q[2]) | (&eq0_q[4:2]&gt0_q[1]) |
  (&eq0_q[4:1]&gt0_q[0]);
 (* keep *) wire greater1=gt1_q[4] | (eq1_q[4]&gt1_q[3]) |
  (&eq1_q[4:3]&gt1_q[2]) | (&eq1_q[4:2]&gt1_q[1]) |
  (&eq1_q[4:1]&gt1_q[0]);
 (* keep *) wire write0=valid0_q && greater0;
 (* keep *) wire write1=valid1_q && greater1;
 wire merge_greater=gtm_q[4] | (eqm_q[4]&gtm_q[3]) |
  (&eqm_q[4:3]&gtm_q[2]) | (&eqm_q[4:2]&gtm_q[1]) |
  (&eqm_q[4:1]&gtm_q[0]);
 wire choose1=merge_greater | ((&eqm_q) && earlier1_q);
 integer g;
 // Unconditionally clock payload and compare bits. valid_q/merge_q guard
 // every consumer, so these bits need no reset or clear mux (area/routing).
 always @(posedge clk)begin
  lane_q<=lane;candidate<=power_in;candidate_tag<=tag_in;earlier1_q<=earlier1;
  // Short independent compares terminate at registers. Reduction and
  // lane write enables are in the NEXT cycle, breaking the feedback path.
  for(g=0;g<5;g=g+1)begin
   gt0_q[g]<=power_in[g*5 +:5]>power0[g*5 +:5];
   eq0_q[g]<=power_in[g*5 +:5]==power0[g*5 +:5];
   gt1_q[g]<=power_in[g*5 +:5]>power1[g*5 +:5];
   eq1_q[g]<=power_in[g*5 +:5]==power1[g*5 +:5];
   gtm_q[g]<=power1[g*5 +:5]>power0[g*5 +:5];
   eqm_q[g]<=power1[g*5 +:5]==power0[g*5 +:5];
  end
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
