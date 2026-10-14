// Simulation ONLY: proves integration, never analog PLL lock/timing.
module altpll #(
 parameter bandwidth_type="AUTO",clk0_divide_by=1,clk0_duty_cycle=50,clk0_multiply_by=4,
 clk0_phase_shift="0",compensate_clock="CLK0",inclk0_input_frequency=20000,
 intended_device_family="Cyclone IV E",lpm_type="altpll",operation_mode="NORMAL",pll_type="AUTO",
 port_areset="PORT_USED",port_clk0="PORT_USED",port_inclk0="PORT_USED",port_locked="PORT_USED",width_clock=5
)(input areset,input [1:0] inclk,output [4:0] clk,output reg locked=0);
 reg fast=0;always #2.5 fast=~fast;assign clk={4'b0,fast};integer count=0;
 always @(posedge inclk[0] or posedge areset)
 if(areset)begin count<=0;locked<=0;end else if(count<5)count<=count+1;else locked<=1;
endmodule
