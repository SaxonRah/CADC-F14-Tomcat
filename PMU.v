module PMU (
    input  wire [19:0] operand_a,
    input  wire [19:0] operand_b,
    output reg  [39:0] result
);

    always @(*) begin
        result = operand_a * operand_b;
    end

endmodule
