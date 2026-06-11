module duty_cycle_counter # (
    parameter CLK_FREQ = 100_000
) (
    input wire i_pwm,
    input wire i_clk,
    input wire i_resetn,

    output reg [6:0] o_duty_cycle
);

reg [31:0] counter_live_re, counter_live_fe, counter_calc_re_re, counter_calc_re_fe;
reg cntr_latch, cntr_latch_fe;
wire w_pwm_re, w_pwm_fe;

always @(posedge i_clk or negedge i_resetn) begin
    if (!i_resetn) begin
        counter_live_re <= 0;
        counter_live_fe <= 0;
        counter_calc_re_re <= 0;
        counter_calc_re_fe <= 0;
        cntr_latch <= 0;
        cntr_latch_fe <= 0;
    end else begin
        if (w_pwm_re) begin
            counter_live_re <= 0;
            counter_live_fe <= 0;
            counter_calc_re_re <= counter_live_re + 1;
            cntr_latch <= 1;
        end else if (w_pwm_fe) begin
            counter_calc_re_fe <= counter_live_fe + 1;
            cntr_latch_fe <= 1;
        end else begin
            if (cntr_latch) begin
                counter_live_re <= counter_live_re + 1;
                counter_live_fe <= counter_live_fe + 1;
            end
        end
    end
end

// REGISTERED OUTPUT CALCULATION

always @(posedge i_clk or negedge i_resetn) begin
    if (!i_resetn) begin
        o_duty_cycle <= 0;
    end else begin
        if (cntr_latch_fe)
            o_duty_cycle <= (counter_calc_re_fe * 100) / counter_calc_re_re;
    end
end

falling_edge_detect pwm_fe
(
    .clk(i_clk),
    .resetn(i_resetn),
    .level(i_pwm),
    .tick(w_pwm_fe)
);

rising_edge_detect pwm_re
(
    .clk(i_clk),
    .resetn(i_resetn),
    .level(i_pwm),
    .tick(w_pwm_re)
);

// formal verification tests
`ifdef FORMAL
    `include "falling_edge_detect.v"
    `include "rising_edge_detect.v"

    // R6: o_duty_cycle must always be in range 0 to 100
    always @(*) begin
        assert(o_duty_cycle <= 100);
    end

    // R6: all duty cycle values 0 to 100 must be reachable
    integer i;
    always @(*) begin
        for (i = 0; i <= 100; i = i + 1) begin
            cover(o_duty_cycle == i);
        end
    end

    // alternative: only cover representative values (uncomment if loop is too slow)
    // cover(o_duty_cycle == 0);
    // cover(o_duty_cycle == 50);
    // cover(o_duty_cycle == 100);
`endif

endmodule
