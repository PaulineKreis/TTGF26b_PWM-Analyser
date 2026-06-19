module freq_counter # (
    parameter CLK_FREQ = 50_000_000,
    parameter RESOLVE_WAIT_CYCLE = 5,
    parameter WATCHDOG_TICK = CLK_FREQ
) (
    input wire i_pwm,
    input wire i_clk,
    input wire i_resetn,

    output wire [13:0] o_freq_khz,
    output reg [2:0] o_status
);

localparam CLK_FREQ_KHZ = CLK_FREQ / 1000;
localparam HI_THRESHOLD = CLK_FREQ_KHZ / (9999 + 1);    // min tick count per period at 9999 kHz max PWM frequency
localparam LO_THRESHOLD = CLK_FREQ_KHZ;                 // max tick count per period at 1 kHz minimum PWM frequency
localparam CNTR_W  = $clog2(LO_THRESHOLD + 1);          // 15 bit @ 25 MHz
localparam CYCLE_W = $clog2(RESOLVE_WAIT_CYCLE + 1);    // 3 bit
localparam WD_W    = $clog2(WATCHDOG_TICK + 1);         // 25 bit @ 25 MHz
localparam HOLD_W  = $clog2(CLK_FREQ / 10 + 1);         // 22 bit @ 25 MHz
localparam DIV_W   = $clog2(CLK_FREQ_KHZ + 1);          // 15 bit @ 25 MHz

reg cntr_latch;
wire w_pwm_re;
reg [13:0] freq;    // max value possible on 4-digit display: 9999 < 2^14
reg [13:0] freq_held;
wire div_busy, div_done;
reg resolve_prev;
reg pwm;

reg [CNTR_W-1:0]  counter_live, counter_calc;  // capped at LO_THRESHOLD, width scales with CLK_FREQ
reg [CYCLE_W-1:0] counter_cycle;               // counts up to RESOLVE_WAIT_CYCLE
reg [WD_W-1:0]    watchdog_cntr;               // counts up to WATCHDOG_TICK, width scales with CLK_FREQ
reg [HOLD_W-1:0]  hold_counter;                // counts up to CLK_FREQ/10, width derived via $clog2
wire [DIV_W-1:0]  div_result;

// input synchroniser: single flip-flop stage to avoid metastability on i_pwm
always @(posedge i_clk or negedge i_resetn) begin
    if (!i_resetn) begin
        pwm <= 0;
    end else begin
        pwm <= i_pwm;
    end
end

// COUNTER LOGIC (FREQ)

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

// pulse generation: start_pulse is high for exactly one clock
// when counter_cycle first reaches RESOLVE_WAIT_CYCLE
wire resolve_now = (counter_cycle == RESOLVE_WAIT_CYCLE);

always @(posedge i_clk or negedge i_resetn) begin
    if (!i_resetn) resolve_prev <= 0;
    else resolve_prev <= resolve_now;
end

wire start_pulse = resolve_now && !resolve_prev;

shift_subtract_divider #(.WIDTH_A(DIV_W), .WIDTH_B(CNTR_W)) div_inst (
    .clk(i_clk),
    .resetn(i_resetn),
    .start(start_pulse && counter_calc > HI_THRESHOLD),
    .dividend(CLK_FREQ_KHZ[DIV_W-1:0]),
    .divisor(counter_calc[CNTR_W-1:0]),
    .quotient(div_result),
    .busy(div_busy),
    .done(div_done)
);

always @(posedge i_clk or negedge i_resetn) begin
    if (!i_resetn) freq <= 0;
    else if (div_done) freq <= div_result;
    else if (start_pulse && counter_calc <= HI_THRESHOLD)
        freq <= 14'h3FFF;   // // signal HI: PWM frequency above measurable range (> 9999 kHz)
end

// output is held for HOLD_CYCLES ticks to ensure stable display readability
assign o_freq_khz = freq_held;

// SAMPLE & HOLD: latch freq every HOLD_CYCLES ticks (= 100 ms at default CLK_FREQ)
localparam HOLD_CYCLES = CLK_FREQ / 10;

always @(posedge i_clk or negedge i_resetn) begin
    if (!i_resetn) begin
        hold_counter <= 0;
        freq_held    <= 0;
    end else begin
        if (hold_counter == HOLD_CYCLES - 1) begin
            hold_counter <= 0;
            freq_held    <= freq;       // latch current result
        end else begin
            hold_counter <= hold_counter + 1;
            // freq_held remains unchanged -> hold display value
        end
    end
end

// STATUS HANDLING

always @(*) begin
    if (watchdog_cntr == WATCHDOG_TICK - 1)
        o_status = 3'b111;
    else if (freq > 9999)
        o_status = 3'b100;
    else if (freq == 0)
        o_status = 3'b001;
    else
        o_status = 3'b000;
end

rising_edge_detect pwm_re
(
    .clk(i_clk),
    .resetn(i_resetn),
    .level(pwm),
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