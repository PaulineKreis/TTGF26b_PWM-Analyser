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
  reg [0:0] PI_i_clk;
  reg [13:0] PI_i_value;
  reg [0:0] PI_i_aresetn;
  reg [2:0] PI_i_status;
  SevenSegmentDecoder UUT (
    .i_clk(PI_i_clk),
    .i_value(PI_i_value),
    .i_aresetn(PI_i_aresetn),
    .i_status(PI_i_status)
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
    UUT._witness_.anyinit_procdff_169 = 14'b00000000000000;
    UUT._witness_.anyinit_procdff_174 = 2'b01;
    UUT.$auto$proc_rom.\cc:155:do_switch$91 [5'b00000] = 7'b1111110;

    // state 0
    PI_i_clk = 1'b0;
    PI_i_value = 14'b00000000000000;
    PI_i_aresetn = 1'b1;
    PI_i_status = 3'b000;
  end
  always @(posedge clock) begin
    genclock <= cycle < 0;
    cycle <= cycle + 1;
  end
endmodule
