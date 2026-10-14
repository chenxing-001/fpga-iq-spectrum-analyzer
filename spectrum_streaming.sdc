# Revision 17: 50 MHz board oscillator -> 200 MHz processing/UART PLL.
create_clock -name sys_clk -period 20.000 [get_ports sys_clk]
derive_pll_clocks
derive_clock_uncertainty
# Board reset asserts asynchronously and releases through r200.
set_false_path -from [get_ports sys_rst_n]
# UART and LEDs are asynchronous outputs, not source-synchronous buses.
# All internal FFT/analyzer/UART register paths remain single-cycle timed.
set_false_path -to [get_ports {uart_txd led[*]}]
