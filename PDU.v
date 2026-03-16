module PDU (
    input  wire [19:0] dividend,
    input  wire [19:0] divisor,
    output reg  [19:0] quotient,
    output reg  [19:0] remainder
);

    reg [20:0] partial;
    reg [19:0] q_temp;
    integer i;

    always @(*) begin
        if (divisor == 20'b0) begin
            quotient  = 20'hFFFFF;
            remainder = 20'b0;
        end else begin
            partial = 21'b0;
            q_temp  = 20'b0;

            for (i = 19; i >= 0; i = i - 1) begin
                partial = {partial[19:0], dividend[i]};
                if (partial >= {1'b0, divisor}) begin
                    partial = partial - {1'b0, divisor};
                    q_temp[i] = 1'b1;
                end
            end

            quotient  = q_temp;
            remainder = partial[19:0];
        end
    end

endmodule
