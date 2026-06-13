module shift_subtract_divider #(
    parameter WIDTH_A = 17,
    parameter WIDTH_B = 17
) (
    input wire clk,
    input wire resetn,
    input wire start,              // pulse: start new division
    input wire [WIDTH_A-1:0] dividend,
    input wire [WIDTH_B-1:0] divisor,
    output reg [WIDTH_A-1:0] quotient,
    output reg busy,
    output reg done                // pulse: 1 clk duration, result valid
);

reg [WIDTH_A-1:0] remainder;
reg [WIDTH_B-1:0] div_reg;
reg [$clog2(WIDTH_A):0] count;

always @(posedge clk or negedge resetn) begin
    if (!resetn) begin
        busy <= 0;
        done <= 0;
        quotient <= 0;
    end else begin
        done <= 0; // default: reset pulse

        if (start && !busy) begin
            remainder <= dividend;
            div_reg <= divisor;
            quotient <= 0;
            count <= WIDTH_A;
            busy <= 1;
        end else if (busy) begin
            if (remainder >= (div_reg << (count-1))) begin
                remainder <= remainder - (div_reg << (count-1));
                quotient <= quotient | (1 << (count-1));
            end
            count <= count - 1;
            if (count == 1) begin
                busy <= 0;
                done <= 1;
            end
        end
    end
end

endmodule