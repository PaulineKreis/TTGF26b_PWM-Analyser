module shift_subtract_divider #(
    parameter WIDTH_A = 17,   // dividend width
    parameter WIDTH_B = 17    // divisor width
) (
    input wire clk,
    input wire resetn,
    input wire start,                       // pulse: start new division
    input wire [WIDTH_A-1:0] dividend,
    input wire [WIDTH_B-1:0] divisor,
    output reg [WIDTH_A-1:0] quotient,
    output reg busy,
    output reg done                         // pulse: 1 clk duration, result valid
);

// Restoring division:
// shift the (remainder:quotient) pair left by one each step,
// then try to subtract the divisor from the top part.

reg [WIDTH_A-1:0] quo;                       // quotient being built
reg [WIDTH_A:0]   rem;                        // running remainder (1 extra bit headroom)
reg [WIDTH_A-1:0] dvd;                        // dividend being consumed
reg [$clog2(WIDTH_A+1)-1:0] count;            // counts down WIDTH_A iterations

wire [WIDTH_A:0] rem_shifted = {rem[WIDTH_A-1:0], dvd[WIDTH_A-1]};
wire [WIDTH_A:0] rem_sub     = rem_shifted - divisor;
wire             can_sub     = (rem_shifted >= divisor);

always @(posedge clk or negedge resetn) begin
    if (!resetn) begin
        busy     <= 0;
        done     <= 0;
        quotient <= 0;
        quo      <= 0;
        rem      <= 0;
        dvd      <= 0;
        count    <= 0;
    end else begin
        done <= 0; // default: reset pulse

        if (start && !busy) begin
            rem   <= 0;
            quo   <= 0;
            dvd   <= dividend;
            count <= WIDTH_A;
            busy  <= 1;
        end else if (busy) begin
            // shift remainder up, pull in next dividend bit
            if (can_sub) begin
                rem <= rem_sub;
                quo <= {quo[WIDTH_A-2:0], 1'b1};
            end else begin
                rem <= rem_shifted;
                quo <= {quo[WIDTH_A-2:0], 1'b0};
            end
            dvd   <= {dvd[WIDTH_A-2:0], 1'b0};  // shift dividend left
            count <= count - 1;

            if (count == 1) begin
                busy     <= 0;
                done     <= 1;
                quotient <= can_sub ? {quo[WIDTH_A-2:0], 1'b1}
                                    : {quo[WIDTH_A-2:0], 1'b0};
            end
        end
    end
end

endmodule