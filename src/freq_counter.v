`timescale 1ns / 1ps

module freq_counter # (
    parameter CLK_FREQ = 500_000,
    parameter RESOLVE_WAIT_CYCLE = 5,
    parameter WATCHDOG_TICK = 1_000_000
) (
    input wire i_pwm,
    input wire i_clk,
    input wire i_resetn,

    output wire [13:0] o_freq_khz,
    output reg [2:0] o_status
);

reg [17:0] counter_live, counter_calc;  // 9999 < 2^17
reg [7:0] counter_cycle;
reg [31:0] watchdog_cntr;
reg cntr_latch;
wire w_pwm_re;
reg [13:0] freq;

// COUNTER LOGIC (FREQ)

localparam LO_THRESHOLD = CLK_FREQ / 1000; // calculation for under 1 kHz does not need to be precise

always @(posedge i_clk or negedge i_resetn) begin
    if (!i_resetn) begin
        counter_live <= 0;
        counter_calc <= 0;
        cntr_latch <= 0;
    end else begin
        if (w_pwm_re) begin
            counter_live <= 0;
            counter_calc <= counter_live + 1;
            cntr_latch <= 1;
        end else begin
            if (cntr_latch)
                if (counter_live < LO_THRESHOLD)
                    counter_live <= counter_live + 1;
        end
    end
end

// COUNTER LOGIC (FREQ RESOLVE)

always @(posedge i_clk or negedge i_resetn) begin
    if (!i_resetn) begin
        counter_cycle <= 0;
    end else begin
        if (w_pwm_re) begin
            if (counter_cycle == RESOLVE_WAIT_CYCLE)
                counter_cycle <= 0;
            else
                counter_cycle <= counter_cycle + 1;
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

// REGISTERED OUTPUT CALCULATION

localparam CLK_FREQ_KHZ = CLK_FREQ / 1000;
localparam HI_THRESHOLD = CLK_FREQ_KHZ / (9999 + 1); // compile time constant (= 10 for 100 MHz)

always @(posedge i_clk or negedge i_resetn) begin
    if (!i_resetn) begin
        freq <= 0;
    end else begin
        if (counter_cycle == RESOLVE_WAIT_CYCLE) begin
            if (counter_calc <= HI_THRESHOLD)
                freq <= 14'h3FFF; // Sentinel: overflow, > 9999 guaranteed
            else
                freq <= CLK_FREQ / (1000 * counter_calc);
                //freq <= 13'd50000;
        end
    end
end

assign o_freq_khz = freq[13:0];

// STATUS HANDLING

always @(*) begin
    if (watchdog_cntr == WATCHDOG_TICK - 1)
        o_status <= 3'b111;
    else if (freq > 9999)
        o_status <= 3'b100;
    else if (freq <= 0)
        o_status <= 3'b001;
    else
        o_status <= 3'b000;
end

rising_edge_detect pwm_re
(
    .clk(i_clk),
    .resetn(i_resetn),
    .level(i_pwm),
    .tick(w_pwm_re)
);

`ifdef FORMAL
    // R1/R5: o_status must always be one of the four valid states
    always @(*) begin
        assert(o_status == 3'b000 ||
               o_status == 3'b001 ||
               o_status == 3'b100 ||
               o_status == 3'b111);
    end

    // R5: when watchdog counter reaches its limit, status must be ERR
    always @(*) begin
        if (watchdog_cntr >= WATCHDOG_TICK - 1)
            assert(o_status == 3'b111);
    end

    // R1: when status is normal, frequency must be within valid range 1 to 9999 kHz
    always @(*) begin
        if (o_status == 3'b000)
            assert(o_freq_khz >= 1 && o_freq_khz <= 9999);
    end

    // R1/R5: all four status values must be reachable
    always @(*) begin
        cover(o_status == 3'b000);
        cover(o_status == 3'b001);
        cover(o_status == 3'b100);
        cover(o_status == 3'b111);
    end
`endif

endmodule