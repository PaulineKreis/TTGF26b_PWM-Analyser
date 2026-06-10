module PWM_Analyser (
    input wire i_clk,
    input wire i_pwm,
    input wire i_aresetn,
    output wire [6:0] o_seg_dc,         // active segment pattern for current digit: {a,b,c,d,e,f,g}
    output wire o_dp_dc,                // decimal point
    output wire [3:0] o_digit_en_dc,     // digit enable for multiplexing four display digits
    output wire [6:0] o_seg_freq,         // active segment pattern for current digit: {a,b,c,d,e,f,g}
    output wire o_dp_freq,                // decimal point
    output wire [3:0] o_digit_en_freq     // digit enable for multiplexing four display digits
);
    
    wire [13:0] w_freq_khz;
    wire [2:0] w_status_fc;
    wire [6:0] w_duty_cycle;

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

    SevenSegmentDecoder fc_disp(
        .i_clk(i_clk),          
        .i_aresetn(i_aresetn),      
        .i_value(w_freq_khz), 
        .i_status(w_status_fc), 
        .o_seg(o_seg_freq),    
        .o_dp(o_dp_freq),           
        .o_digit_en(o_digit_en_freq)    
    );

    SevenSegmentDecoder dc_disp(
        .i_clk(i_clk),          
        .i_aresetn(i_aresetn),      
        .i_value(w_duty_cycle), 
        .i_status(3'b010), 
        .o_seg(o_seg_dc),    
        .o_dp(o_dp_dc),           
        .o_digit_en(o_digit_en_dc)    
    );

endmodule