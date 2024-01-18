module PDU (
  input wire [19:0] dividend,
  input wire [19:0] divisor,
  output reg [19:0] quotient,
  output reg [19:0] remainder
);

always @(dividend or divisor) begin
  // Initialize vars
  reg [19:0] temp_dividend;
  reg [19:0] temp_quotient;
  reg [4:0] count;

  // Reset vars
  temp_dividend = dividend;
  temp_quotient = 0;
  count = 20'd0;

  // Division loop
  while (count < 20'd20) begin
    if (temp_dividend >= divisor) begin
      temp_dividend = temp_dividend - divisor;
      temp_quotient[count] = 1;
    end
    temp_dividend = temp_dividend << 1;
    count = count + 1;
  end

  // Assign outputs
  quotient = temp_quotient;
  remainder = temp_dividend;
end

endmodule
