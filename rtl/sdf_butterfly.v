`timescale 1ns/1ps
// Natural stream in; DIF sum then difference stream out. One bit scaling per stage.
// D>=16: two-stage M9K read, arithmetic register, then feedback/output mux.
// D==8: banked logic read, bank selection, arithmetic, feedback/output mux.
// D<=4: keep the short feedback latency. One valid sample per clock throughout.
module sdf_butterfly #(parameter D=4096, AW=12, ROTATE=0, RAM_STYLE=(D>=16 ? "M9K, no_rw_check":"logic"))(
 input clk, rst_n, vin, input signed [11:0] xr,xi,
 output reg vout, output reg signed [11:0] yr,yi);
 reg [AW+1:0] count;
 reg filled;
 wire turn = ROTATE && count[AW+1:AW]==2'b11;
 wire signed [11:0] ar=turn ? xi:xr;
 wire signed [11:0] ai=turn ? -xr:xi;
 generate if(D==1) begin: short_delay
   reg signed [11:0] dr,di;
   wire signed [12:0] sr=$signed(dr)+$signed(ar), si=$signed(di)+$signed(ai);
   wire signed [12:0] tr=$signed(dr)-$signed(ar), ti=$signed(di)-$signed(ai);
   always @(posedge clk or negedge rst_n)
    if(!rst_n) begin count<=0;filled<=0;vout<=0;yr<=0;yi<=0;dr<=0;di<=0;end
    else begin
      vout<=0;
      if(vin) begin
        count<=count+1'b1;
        if(count[0]) begin yr<=sr>>>1;yi<=si>>>1;dr<=tr>>>1;di<=ti>>>1;filled<=1;vout<=1;end
        else begin yr<=dr;yi<=di;dr<=ar;di<=ai;vout<=filled;end
      end
    end
 end else if(D>=16) begin: pipelined_ram_delay
   wire [23:0] rd;
   reg signed [11:0] ar1,ai1,ar2,ai2;
   reg [AW-1:0] addr1,addr2,addr3;
   reg phase1,phase2,phase3,v1,v2,v3,good1,good2,good3;
   reg [23:0] sum3,diff3,input3,delayed3;
   wire signed [11:0] dr=rd[23:12],di=rd[11:0];
   wire signed [12:0] sr=$signed(dr)+$signed(ar2),si=$signed(di)+$signed(ai2);
   wire signed [12:0] tr=$signed(dr)-$signed(ar2),ti=$signed(di)-$signed(ai2);
   wire [23:0] wd=phase3 ? diff3:input3;
   // At edge t: request read; t+1: M9K output register;
   // t+2: registered arithmetic; t+3: output and feedback write.
   // Address reuse is >=D edges
   // apart (D>=16), so no valid access depends on a read/write collision.
   fft_delay_ram #(.D(D),.AW(AW)) feedback(
    .clk(clk),.we(v3 && rst_n),.waddr(addr3),.raddr(count[AW-1:0]),.wdata(wd),.q(rd));
   always @(posedge clk or negedge rst_n)
    if(!rst_n)begin
     count<=0;filled<=0;v1<=0;v2<=0;v3<=0;vout<=0;good1<=0;good2<=0;good3<=0;
     phase1<=0;phase2<=0;phase3<=0;addr1<=0;addr2<=0;addr3<=0;
     ar1<=0;ai1<=0;ar2<=0;ai2<=0;yr<=0;yi<=0;
     sum3<=0;diff3<=0;input3<=0;delayed3<=0;
    end else begin
     v1<=vin;v2<=v1;v3<=v2;vout<=v3 && good3;
     if(vin)begin
      count<=count+1'b1;addr1<=count[AW-1:0];phase1<=count[AW];
      ar1<=ar;ai1<=ai;good1<=filled || count[AW];
      if(count[AW])filled<=1;
     end
     if(v1)begin ar2<=ar1;ai2<=ai1;addr2<=addr1;phase2<=phase1;good2<=good1;end
     if(v2)begin
      // Separate the carry chains from the phase mux and RAM write routing.
      sum3<={sr[12:1],si[12:1]};diff3<={tr[12:1],ti[12:1]};
      input3<={ar2,ai2};delayed3<=rd;addr3<=addr2;phase3<=phase2;good3<=good2;
     end
     if(v3)begin {yr,yi}<=phase3 ? sum3:delayed3;end
    end
 end else if(D==8) begin: split_logic_delay
   // Rev21: split the old 8:1 read mux across two register boundaries and
   // register arithmetic before the phase mux / feedback write. This adds
   // two clocks to output latency without changing the accepted sample order.
   // Logic storage is intentional: do not spend another M9K on eight words.
   (* ramstyle = "logic" *) reg [23:0] mem[0:7];
   (* preserve *) reg [23:0] rd_low1,rd_high1;
   reg [23:0] rd2;
   reg signed [11:0] ar1,ai1,ar2,ai2;
   reg [2:0] addr1,addr2,addr3;
   reg bank1,phase1,phase2,phase3,v1,v2,v3,good1,good2,good3;
   reg [23:0] sum3,diff3,input3,delayed3;
   wire signed [11:0] dr=rd2[23:12],di=rd2[11:0];
   wire signed [12:0] sr=$signed(dr)+$signed(ar2),si=$signed(di)+$signed(ai2);
   wire signed [12:0] tr=$signed(dr)-$signed(ar2),ti=$signed(di)-$signed(ai2);
   wire [23:0] wd=phase3 ? diff3:input3;
   always @(posedge clk) begin
     if(vin)begin
       rd_low1<=mem[{1'b0,count[1:0]}];
       rd_high1<=mem[{1'b1,count[1:0]}];
     end
     if(v1)rd2<=bank1 ? rd_high1:rd_low1;
     // Request at t, arithmetic at t+2, write at t+3. The next valid
     // request to the SAME address is at least eight clocks after t.
     // An unselected bank may collide; its data is never consumed.
     if(v3 && rst_n)mem[addr3]<=wd;
   end
   always @(posedge clk or negedge rst_n)
    if(!rst_n)begin
     count<=0;filled<=0;v1<=0;v2<=0;v3<=0;vout<=0;
     good1<=0;good2<=0;good3<=0;bank1<=0;
     phase1<=0;phase2<=0;phase3<=0;addr1<=0;addr2<=0;addr3<=0;
     ar1<=0;ai1<=0;ar2<=0;ai2<=0;yr<=0;yi<=0;
     sum3<=0;diff3<=0;input3<=0;delayed3<=0;
    end else begin
     v1<=vin;v2<=v1;v3<=v2;vout<=v3 && good3;
     if(vin)begin
      count<=count+1'b1;addr1<=count[2:0];bank1<=count[2];phase1<=count[AW];
      ar1<=ar;ai1<=ai;good1<=filled || count[AW];
      if(count[AW])filled<=1;
     end
     if(v1)begin ar2<=ar1;ai2<=ai1;addr2<=addr1;phase2<=phase1;good2<=good1;end
     if(v2)begin
      sum3<={sr[12:1],si[12:1]};diff3<={tr[12:1],ti[12:1]};
      input3<={ar2,ai2};delayed3<=rd2;addr3<=addr2;phase3<=phase2;good3<=good2;
     end
     if(v3)begin {yr,yi}<=phase3 ? sum3:delayed3;end
    end
 end else begin: ram_delay
   (* ramstyle = RAM_STYLE *) reg [23:0] mem[0:D-1];
   reg [23:0] rd;
   reg signed [11:0] ar1,ai1;
   reg [AW-1:0] addr1;
   reg phase1,v1,good1;
   wire signed [11:0] dr=rd[23:12], di=rd[11:0];
   wire signed [12:0] sr=$signed(dr)+$signed(ar1), si=$signed(di)+$signed(ai1);
   wire signed [12:0] tr=$signed(dr)-$signed(ar1), ti=$signed(di)-$signed(ai1);
   wire [23:0] wd=phase1 ? {tr[12:1],ti[12:1]}:{ar1,ai1};
   always @(posedge clk) begin
      if(vin) rd<=mem[count[AW-1:0]];
      if(v1) mem[addr1]<=wd;
   end
   always @(posedge clk or negedge rst_n)
    if(!rst_n) begin count<=0;filled<=0;v1<=0;vout<=0;good1<=0;phase1<=0;addr1<=0;ar1<=0;ai1<=0;yr<=0;yi<=0;end
    else begin
      v1<=vin;vout<=v1 && good1;
      if(vin) begin
        count<=count+1'b1;addr1<=count[AW-1:0];phase1<=count[AW];
        ar1<=ar;ai1<=ai;good1<=filled || count[AW];
        if(count[AW]) filled<=1;
      end
      if(v1) begin yr<=phase1 ? sr[12:1]:dr;yi<=phase1 ? si[12:1]:di;end
    end
 end endgenerate
endmodule
