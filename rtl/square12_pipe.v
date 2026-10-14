`timescale 1ns/1ps
// Signed 12-bit square, TWO registered stages, one new sample every clock.
// The two private, unreset input registers can pack into the multiplier's
// A/B input registers. Do not merge them into a shared fabric register: the
// revision18 q -> DSP path had no multiplier-local input pipeline stage.
// The caller pipelines valid/tag by two edges; invalid data need no reset.
module square12_pipe(input clk,input signed [11:0] x,output reg [23:0] square);
 (* dont_merge *) reg signed [11:0] a_q,b_q;
 always @(posedge clk)begin
  a_q<=x;b_q<=x;
  square<=a_q*b_q;
 end
endmodule
