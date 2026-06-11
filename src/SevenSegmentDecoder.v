module SevenSegmentDecoder
#(
    parameter CLK_HZ = 100_000,      // input clock frequency in Hz
    parameter DIGIT_REFRESH_HZ = 1000,  // digit switching frequency in Hz

    parameter COMMON_ANODE = 1  // specifies type of display that is used (common anode or cathode)
)
(
    input wire i_clk,               // clock signal
    input wire i_aresetn,           // asynchronous negated reset
    input wire [13:0] i_value,      // measured duty cycle (0 to 100) or pwm frequency (1 to 9999 kHz)
    input wire [2:0] i_status,      // display status: 111=ERR, 100=HI, 001=LO, 010=duty mode

    output reg [6:0] o_seg,         // active segment pattern for current digit: {a,b,c,d,e,f,g}
    output reg o_dp,                // decimal point
    output reg [3:0] o_digit_en     // digit enable for multiplexing four display digits
);

// counter params
localparam integer REFRESH_COUNT_MAX = CLK_HZ / DIGIT_REFRESH_HZ;       // clock cycles per digit refresh
localparam integer REFRESH_COUNTER_WIDTH = $clog2(REFRESH_COUNT_MAX);   // refresh counter width in bits

// character codes
localparam [4:0] CHAR_0     = 5'd0;
localparam [4:0] CHAR_1     = 5'd1;
localparam [4:0] CHAR_2     = 5'd2;
localparam [4:0] CHAR_3     = 5'd3;
localparam [4:0] CHAR_4     = 5'd4;
localparam [4:0] CHAR_5     = 5'd5;
localparam [4:0] CHAR_6     = 5'd6;
localparam [4:0] CHAR_7     = 5'd7;
localparam [4:0] CHAR_8     = 5'd8;
localparam [4:0] CHAR_9     = 5'd9;

localparam [4:0] CHAR_BLANK = 5'd10;
localparam [4:0] CHAR_E     = 5'd11;
localparam [4:0] CHAR_R     = 5'd12;
localparam [4:0] CHAR_H     = 5'd13;
localparam [4:0] CHAR_I     = 5'd14;
localparam [4:0] CHAR_L     = 5'd15;
localparam [4:0] CHAR_O     = 5'd16;

// counter regs
reg [REFRESH_COUNTER_WIDTH-1:0] refresh_counter;
reg [1:0] active_digit;
reg [3:0] digit_en_raw;

// display character storage
reg [4:0] char0;        // rightmost digit
reg [4:0] char1;
reg [4:0] char2;
reg [4:0] char3;        // leftmost digit
reg [4:0] current_char;

// split value (into digits)
reg [3:0] digit_ones;
reg [3:0] digit_tens;
reg [3:0] digit_hundreds;
reg [3:0] digit_thousands;

// refresh and digit counters
always @(posedge i_clk or negedge i_aresetn) begin

    if(!i_aresetn)
    begin
        refresh_counter <= 0;
        active_digit <= 0;
    end

    else
    begin
        if (refresh_counter == REFRESH_COUNT_MAX - 1)
        begin
            refresh_counter <= 0;
            active_digit <= active_digit + 1'b1;
        end

        else
        begin
            refresh_counter <= refresh_counter + 1'b1;
        end
    end

end

// digit multiplexing
always @(*) begin   // combinational logic, therefore *
    case(active_digit)
    2'd0: digit_en_raw = 4'b0001;
    2'd1: digit_en_raw = 4'b0010;
    2'd2: digit_en_raw = 4'b0100;
    2'd3: digit_en_raw = 4'b1000;
    default: digit_en_raw = 4'b0001;
    endcase

    o_digit_en = COMMON_ANODE ? ~digit_en_raw : digit_en_raw;
end

// split input value into decimal digits
always @(*) begin
    digit_ones      = i_value % 10;
    digit_tens      = (i_value / 10) % 10;
    digit_hundreds  = (i_value / 100) % 10;
    digit_thousands = (i_value / 1000) % 10;
end

// prepare display characters
always @(*) begin

    // default: show numeric value
    char0 = digit_ones;
    char1 = digit_tens;
    char2 = digit_hundreds;
    char3 = digit_thousands;

    // status overrides
    case(i_status)
        3'b111: // ERR
        begin
            char0 = CHAR_R;
            char1 = CHAR_R;
            char2 = CHAR_E;
            char3 = CHAR_BLANK;
        end

        3'b100: // HI
        begin
            char0 = CHAR_I;
            char1 = CHAR_H;
            char2 = CHAR_BLANK;
            char3 = CHAR_BLANK;
        end

        3'b001: // LO
        begin
            char0 = CHAR_O;
            char1 = CHAR_L;
            char2 = CHAR_BLANK;
            char3 = CHAR_BLANK;
        end

        default: // keep numeric value
        begin
        end
    endcase
end



// select active character
always @(*) begin
    case(active_digit)
        2'd0: current_char = char0;
        2'd1: current_char = char1;
        2'd2: current_char = char2;
        2'd3: current_char = char3;
        default: current_char = CHAR_BLANK;
    endcase
end

// convert selected character to segment pattern
always @(*) begin
    case(current_char)
        CHAR_0:     o_seg = 7'b1111110;
        CHAR_1:     o_seg = 7'b0110000;
        CHAR_2:     o_seg = 7'b1101101;
        CHAR_3:     o_seg = 7'b1111001;
        CHAR_4:     o_seg = 7'b0110011;
        CHAR_5:     o_seg = 7'b1011011;
        CHAR_6:     o_seg = 7'b1011111;
        CHAR_7:     o_seg = 7'b1110000;
        CHAR_8:     o_seg = 7'b1111111;
        CHAR_9:     o_seg = 7'b1111011;

        CHAR_BLANK: o_seg = 7'b0000000;
        CHAR_E:     o_seg = 7'b1001111;
        CHAR_R:     o_seg = 7'b0000101;
        CHAR_H:     o_seg = 7'b0110111;
        CHAR_I:     o_seg = 7'b0110000;
        CHAR_L:     o_seg = 7'b0001110;
        CHAR_O:     o_seg = 7'b1111110;

        default:    o_seg = 7'b0000000;
    endcase

    if (COMMON_ANODE)
        o_seg = ~o_seg;
end

// decimal point control
always @(*) begin
    if ((i_status == 3'b010) && (active_digit == 2'd2))
        o_dp = COMMON_ANODE ? 1'b0 : 1'b1; // decimal point on
    else
        o_dp = COMMON_ANODE ? 1'b1 : 1'b0; // decimal point off
end

// formal verification tests
`ifdef FORMAL
    // R8: exactly one digit must be active at all times (one-hot)
    always @(*) begin
        assert($onehot(digit_en_raw));
    end

    // R3: when status is LO, char0 must be O, char1 must be L and char2/3 must be blank
    always @(*) begin
        if (i_status == 3'b001) begin
            assert(char0 == CHAR_O);
            assert(char1 == CHAR_L);
            assert(char2 == CHAR_BLANK);
            assert(char3 == CHAR_BLANK);
        end
    end

    // R4: when status is HI, char0 must be I, char1 must be H and char2/3 must be blank
    always @(*) begin
        if (i_status == 3'b100) begin
            assert(char0 == CHAR_I);
            assert(char1 == CHAR_H);
            assert(char2 == CHAR_BLANK);
            assert(char3 == CHAR_BLANK);
        end
    end

    // R5: when status is ERR, char0 must be R, char1 must be R, char2 must be E and char3 must be blank
    always @(*) begin
        if (i_status == 3'b111) begin
            assert(char0 == CHAR_R);
            assert(char1 == CHAR_R);
            assert(char2 == CHAR_E);
            assert(char3 == CHAR_BLANK);
        end
    end

    // R7: decimal point is only active in duty cycle mode (status 010) on digit 2
    always @(*) begin
        if ((i_status == 3'b010) && (active_digit == 2'd2))
            assert(o_dp == 1'b0); // active low for common anode
        else
            assert(o_dp == 1'b1); // inactive
    end

    // R8: all four digits must be reachable (cyclic switching)
    always @(*) begin
        cover(active_digit == 2'd0);
        cover(active_digit == 2'd1);
        cover(active_digit == 2'd2);
        cover(active_digit == 2'd3);
    end
`endif

endmodule