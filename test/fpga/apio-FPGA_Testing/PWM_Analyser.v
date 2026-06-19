module PWM_Analyser (
    input i_clk,
    input i_pwm,
    input i_aresetn,
    input i_display_sel,        // 0 = frequency, 1 = duty cycle
    output o_segA,              // active segment pattern for current digit: {a,b,c,d,e,f,g}
    output o_segB,
    output o_segC,
    output o_segD,
    output o_segE,
    output o_segF,
    output o_segG,
    output o_dp,                // decimal point
    output o_digit_en_0,
    output o_digit_en_1,
    output o_digit_en_2,
    output o_digit_en_3,
);

    wire [13:0] w_freq_khz;
    wire [2:0] w_status_fc;
    wire [6:0] w_duty_cycle;
    wire [6:0] o_seg;
    wire [3:0] o_digit_en;

    freq_counter fc(
        .i_pwm(i_pwm),
        .i_clk(i_clk),
        .i_resetn(~i_aresetn),
        .o_freq_khz(w_freq_khz),
        .o_status(w_status_fc)
    );

    duty_cycle_counter dc(
        .i_pwm(i_pwm),
        .i_clk(i_clk),
        .i_resetn(~i_aresetn),
        .o_duty_cycle(w_duty_cycle)
    );

    // Mux: select between frequency and duty cycle display
    wire [13:0] w_value_muxed  = i_display_sel ? {7'b0, w_duty_cycle} : w_freq_khz;
    wire [2:0] w_status_muxed = i_display_sel ? 3'b010 : w_status_fc;

    SevenSegmentDecoder disp(
        .i_clk(i_clk),
        .i_aresetn(~i_aresetn),
        .i_value(w_value_muxed),
        .i_status(w_status_muxed),
        .o_seg(o_seg),
        .o_dp(o_dp),
        .o_digit_en(o_digit_en)
    );

assign o_segA = o_seg[6];
assign o_segB = o_seg[5];
assign o_segC = o_seg[4];
assign o_segD = o_seg[3];
assign o_segE = o_seg[2];
assign o_segF = o_seg[1];
assign o_segG = o_seg[0];

assign o_digit_en_0 = o_digit_en[3];
assign o_digit_en_1 = o_digit_en[2];
assign o_digit_en_2 = o_digit_en[1];
assign o_digit_en_3 = o_digit_en[0];

endmodule