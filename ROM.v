module ROM (
  input wire [3:0] address,
  output reg [19:0] data_out
);

// 128 words of 20-bit data
reg [19:0] memory [127:0] = {
  20'b00000000000000000000, // Pattern for word 0
  // Add patterns for word 0 to word 127 here
  // ...
  20'b11111111111111111111  // Pattern for word 127
};

always @(posedge clk or posedge rst_n) begin
  if (~rst_n) begin
    // Reset logic if needed
    data_out <= 20'b0;
  end else begin
    // Read from memory based on the address
    data_out <= memory[address];
  end
end

endmodule
