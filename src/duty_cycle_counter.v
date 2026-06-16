module duty_cycle_counter # (
    parameter CLK_FREQ = 50_000_000,
    parameter WATCHDOG_TICK = 50_000_000
) (
    input wire i_pwm,
    input wire i_clk,
    input wire i_resetn,

    output wire [6:0] o_duty_cycle
);

// counters limited to 17 bits: at 1 kHz min PWM and 100 MHz clock,
// one period = 100_000 ticks < 2^17
localparam LO_THRESHOLD = CLK_FREQ / 1000; // = 100_000, max valid tick count

// reg [31:0] counter_live_re, counter_live_fe, counter_calc_re_re, counter_calc_re_fe;
reg [16:0] counter_live_re, counter_live_fe, counter_calc_re_re, counter_calc_re_fe;

reg cntr_latch, cntr_latch_fe;
reg [31:0] watchdog_cntr;
wire w_pwm_re, w_pwm_fe;

reg [22:0] hold_counter;   // zählt bis 6.000.000 -> 23 Bit nötig (2^22 = 4.194.304 reicht nicht)
reg [13:0] duty_cycle_held;

reg pwm;

always @(posedge i_clk or negedge i_resetn) begin
    if (!i_resetn) begin
        pwm <= 0;
    end else begin
        pwm <= i_pwm;
    end
end

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

// always @(*) begin
//     if (watchdog_cntr == WATCHDOG_TICK - 1) begin
//         if (pwm)
//             o_duty_cycle = 7'd100;
//         else 
//             o_duty_cycle = 7'd0;
//     end else begin
//         o_duty_cycle = duty_cycle_held;
//     end
// end

assign o_duty_cycle = (watchdog_cntr == WATCHDOG_TICK - 1) ? ((pwm) ? 7'd100 : 7'd0) : duty_cycle_held;

localparam HOLD_CYCLES = CLK_FREQ / 10; //100ms wait

always @(posedge i_clk or negedge i_resetn) begin
    if (!i_resetn) begin
        hold_counter <= 0;
        duty_cycle_held    <= 0;
    end else begin
        if (hold_counter == HOLD_CYCLES - 1) begin
            hold_counter <= 0;
            duty_cycle_held <= div_result[6:0];       // aktuellen Wert übernehmen
        end else begin
            hold_counter <= hold_counter + 1;
            // freq_held bleibt unverändert -> "festgehalten"
        end
    end
end

// COUNTER LOGIC (WATCHDOG)

always @(posedge i_clk or negedge i_resetn) begin
    if (!i_resetn) begin
        watchdog_cntr <= 0;
    end else begin
        if (w_pwm_re)
            watchdog_cntr <= 0;
        else if (watchdog_cntr == WATCHDOG_TICK - 1)
            watchdog_cntr <= watchdog_cntr;
        else
            watchdog_cntr <= watchdog_cntr + 1;
    end
end

falling_edge_detect pwm_fe
(
    .clk(i_clk),
    .resetn(i_resetn),
    .level(pwm),
    .tick(w_pwm_fe)
);

rising_edge_detect pwm_re
(
    .clk(i_clk),
    .resetn(i_resetn),
    .level(pwm),
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