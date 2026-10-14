`timescale 1ns/1ps
module tb_uart;
 reg clk=0;always #2.5 clk=~clk;
 reg rst_n=0,done=0;wire [7:0] ta,sa;reg [23:0] td;reg [7:0] sd;wire sent,tx,busy;
 uart_packet #(.CLKS_PER_BIT(4)) dut(.clk(clk),.rst_n(rst_n),.done(done),.frame_id(32'd42),.latency_cycles(32'd41038),.frames_skipped(32'd99),
 .mode(2'd1),.clipped(2'd3),.peak_bin(13'd1024),.bw_bins(14'd1),.active_count(14'd8192),.span_count(14'd8192),.longest_run(14'd8192),
 .peak_power(25'd810000),.time_peak_power(25'd1822500),.energy(38'd8294400000),.peak_code(8'd156),.panel_id(16'h4342),
 .time_addr(ta),.time_data(td),.spec_addr(sa),.spec_data(sd),.sent(sent),.tx(tx),.busy(busy));
 wire signed [11:0] val={4'b0,ta};
 always @(posedge clk)begin td<={val,-val};sd<=sa;end
 integer f,k,j;reg [7:0] b;
 initial begin f=$fopen("sim/uart_bytes.hex","w");repeat(5)@(negedge clk);rst_n=1;done=1;
  for(k=0;k<1330;k=k+1)begin
   @(negedge tx);#30;
   for(j=0;j<8;j=j+1)begin b[j]=tx;#20;end
   if(tx!==1)$fatal(1,"Bad UART stop bit");$fwrite(f,"%02x\n",b);
  end
  wait(sent);done=0;$fclose(f);$display("UART decoded 1330 bytes");$finish;
 end
 initial begin #1000000;$fatal(1,"UART timeout");end
endmodule
