module duty_cycle_counter # (
    parameter CLK_FREQ = 10_000_000
) (
    input wire i_pwm,
    input wire i_clk,
    input wire i_resetn,

    output reg [6:0] o_duty_cycle
);

// counters limited to 17 bits: at 1 kHz min PWM and 100 MHz clock,
// one period = 100_000 ticks < 2^17
localparam LO_THRESHOLD = CLK_FREQ / 1000; // = 100_000, max valid tick count

// reg [31:0] counter_live_re, counter_live_fe, counter_calc_re_re, counter_calc_re_fe;
reg [16:0] counter_live_re, counter_live_fe, counter_calc_re_re, counter_calc_re_fe;

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
            cntr_latch_fe <= 0;
        end else if (w_pwm_fe) begin
            counter_calc_re_fe <= counter_live_fe + 1;
            cntr_latch_fe <= 1;
        end else begin
            if (cntr_latch) begin
                // stop counting at LO_THRESHOLD so 17 bits never overflow
                if (counter_live_re < LO_THRESHOLD)
                    counter_live_re <= counter_live_re + 1;
                if (counter_live_fe < LO_THRESHOLD)
                    counter_live_fe <= counter_live_fe + 1;
            end
        end
    end
end

wire [23:0] dividend = counter_calc_re_fe * 7'd100;
wire [23:0] div_result;
wire div_busy, div_done;

// generate a one-cycle start pulse from the (level) cntr_latch_fe
reg cntr_latch_fe_prev;
always @(posedge i_clk or negedge i_resetn) begin
    if (!i_resetn) cntr_latch_fe_prev <= 0;
    else cntr_latch_fe_prev <= cntr_latch_fe;
end
wire start_pulse = cntr_latch_fe && !cntr_latch_fe_prev;

shift_subtract_divider #(.WIDTH_A(24), .WIDTH_B(17)) div_inst (
    .clk(i_clk),
    .resetn(i_resetn),
    .start(start_pulse),
    .dividend(dividend),
    .divisor(counter_calc_re_re),
    .quotient(div_result),
    .busy(div_busy),
    .done(div_done)
);

always @(posedge i_clk or negedge i_resetn) begin
    if (!i_resetn)
        o_duty_cycle <= 0;
    else if (div_done)
        o_duty_cycle <= div_result[6:0];
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