`ifndef VERILATOR
module testbench;
  reg [4095:0] vcdfile;
  reg clock;
`else
module testbench(input clock, output reg genclock);
  initial genclock = 1;
`endif
  reg genclock = 1;
  reg [31:0] cycle = 0;
  reg [0:0] PI_resetn;
  reg [0:0] PI_level;
  wire [0:0] PI_clk = clock;
  rising_edge_detect UUT (
    .resetn(PI_resetn),
    .level(PI_level),
    .clk(PI_clk)
  );
`ifndef VERILATOR
  initial begin
    if ($value$plusargs("vcd=%s", vcdfile)) begin
      $dumpfile(vcdfile);
      $dumpvars(0, testbench);
    end
    #5 clock = 0;
    while (genclock) begin
      #5 clock = 0;
      #5 clock = 1;
    end
  end
`endif
  initial begin
`ifndef VERILATOR
    #1;
`endif
    // UUT.$auto$async2sync.\cc:107:execute$34  = 1'b0;
    // UUT.$auto$async2sync.\cc:116:execute$38  = 1'b1;
    UUT._witness_.anyinit_procdff_25 = 1'b0;
    UUT.f_past_valid = 1'b0;

    // state 0
    PI_resetn = 1'b0;
    PI_level = 1'b0;
  end
  always @(posedge clock) begin
    // state 1
    if (cycle == 0) begin
      PI_resetn <= 1'b0;
      PI_level <= 1'b1;
    end

    // state 2
    if (cycle == 1) begin
      PI_resetn <= 1'b0;
      PI_level <= 1'b0;
    end

    genclock <= cycle < 2;
    cycle <= cycle + 1;
  end
endmodule
