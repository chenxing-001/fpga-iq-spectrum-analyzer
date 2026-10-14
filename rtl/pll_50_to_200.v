`timescale 1ns/1ps
module pll_50_to_200(
    input  wire inclk0,
    input  wire reset_n,
    output wire c0,
    output wire locked
);
    wire [4:0] pll_clk;

    altpll #(
        .bandwidth_type("AUTO"),
        .clk0_divide_by(1),
        .clk0_duty_cycle(50),
        .clk0_multiply_by(4),
        .clk0_phase_shift("0"),
        .compensate_clock("CLK0"),
        .inclk0_input_frequency(20000),
        .intended_device_family("Cyclone IV E"),
        .lpm_type("altpll"),
        .operation_mode("NORMAL"),
        .pll_type("AUTO"),
        .port_areset("PORT_USED"),
        .port_clk0("PORT_USED"),
        .port_inclk0("PORT_USED"),
        .port_locked("PORT_USED"),
        .width_clock(5)
    ) u_altpll (
        .areset(~reset_n),
        .inclk({1'b0, inclk0}),
        .clk(pll_clk),
        .locked(locked)
    );

    assign c0 = pll_clk[0];
endmodule
