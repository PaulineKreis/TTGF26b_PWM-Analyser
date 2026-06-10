/*
 * Copyright (c) 2024 Your Name
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

module tt_um_PaulineKreis_PWM_Analyser (
    input  wire [7:0] ui_in,    // Dedicated inputs
    output wire [7:0] uo_out,   // Dedicated outputs
    input  wire [7:0] uio_in,   // IOs: Input path
    output wire [7:0] uio_out,  // IOs: Output path
    output wire [7:0] uio_oe,   // IOs: Enable path (active high: 0=input, 1=output)
    input  wire       ena,      // always 1 when the design is powered, so you can ignore it
    input  wire       clk,      // clock
    input  wire       rst_n     // reset_n - low to reset
);

  // All output pins must be assigned. If not used, assign to 0.
  // assign uo_out  = ui_in + uio_in;  // Example: ou_out is the sum of ui_in and uio_in
  assign uio_oe = 8'b00001111;  // only lower 4 as output
  assign uio_out[7:4] = 4'b0000;

  // List all unused inputs to prevent warnings
  wire _unused = &{ena, 1'b0, ui_in[7:2], uio_in[7:0]};

  PWM_Analyser PWM_Analyser_inst (
    .i_clk(clk),
    .i_pwm(ui_in[0]),
    .i_aresetn(rst_n),
    .i_display_sel(ui_in[1]),
    .o_seg(uo_out[6:0]),
    .o_dp(uo_out[7]),
    .o_digit_en(uio_out[3:0])
  );

endmodule
