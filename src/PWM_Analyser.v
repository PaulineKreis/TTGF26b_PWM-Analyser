module PWM_Analyser (
    input wire i_clk,               // system clock
    input wire i_pwm,               // PWM input signal (synchronised internally)
    input wire i_aresetn,           // active-low asynchronous reset
    input wire i_display_sel,       // 0 = frequency, 1 = duty cycle
    output wire [6:0] o_seg,        // active segment pattern for current digit: MSB = a, LSB = g -> {a,b,c,d,e,f,g}
    output wire o_dp,               // decimal point
    output wire [3:0] o_digit_en    // digit enable for multiplexing four display digits
);

    wire [13:0] w_freq_khz;     // max value possible on 4-digit display: 9999 < 2^14
    wire [2:0] w_status_fc;
    wire [6:0] w_duty_cycle;    // max value possible: 100(%) < 2^7

    freq_counter fc(
        .i_pwm(i_pwm),
        .i_clk(i_clk),
        .i_resetn(i_aresetn),
        .o_freq_khz(w_freq_khz),
        .o_status(w_status_fc)
    );

    duty_cycle_counter dc(
        .i_pwm(i_pwm),
        .i_clk(i_clk),
        .i_resetn(i_aresetn),
        .o_duty_cycle(w_duty_cycle)
    );

    // Mux: select between frequency and duty cycle display
    wire [13:0] w_value_muxed  = i_display_sel ? {7'b0, w_duty_cycle} : w_freq_khz;
    wire [2:0] w_status_muxed = i_display_sel ? 3'b010 : w_status_fc;

    SevenSegmentDecoder disp(
        .i_clk(i_clk),
        .i_aresetn(i_aresetn),
        .i_value(w_value_muxed),
        .i_status(w_status_muxed),
        .o_seg(o_seg),
        .o_dp(o_dp),
        .o_digit_en(o_digit_en)
    );

endmodule