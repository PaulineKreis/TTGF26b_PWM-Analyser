/* Code modified from P. P. Chu, FPGA Prototyping by Verilog Examples: Xilinx Spartan-3 Version, Lisitng 5.5 */

`timescale 1ns / 1ps

module rising_edge_detect
   (
    input wire  clk, resetn,
    input wire  level,
    output wire tick
   );

   // signal declaration
   reg delay_reg;

   // delay register
    always @(posedge clk or negedge resetn)
       if (!resetn)
          delay_reg <= 1'b0;
       else
          delay_reg <= level;

   // decoding logic
   assign tick = ~delay_reg & level;

`ifdef FORMAL
   reg f_past_valid = 0;
   initial assume (resetn == 0);
   always @(posedge clk) begin
      f_past_valid <= 1;
      if (f_past_valid) begin

         // Cover reaching value 1 at the tick
         _c_01_ : cover(tick==1'b1);

      end
   end

   always @(posedge clk) begin
      if (f_past_valid) begin

         // Bounded Checking value 1 at the tick
         if(delay_reg == 1'b1)
            _b_01_: assert(tick==1'b0);

      end
   end

`endif

endmodule

