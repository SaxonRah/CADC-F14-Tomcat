module ROM (
  input wire clk,
  input wire rst_n,
  output reg [19:0] data_out
);

// 128 words of 20-bit data
reg [19:0] memory [127:0] = {
  20'b00000000000000000000, // Pattern for word 0
  // Add patterns for word 0 to word 127 here
  // ...
  20'b11111111111111111111  // Pattern for word 127
};

reg [6:0] counter = 0; // 7-bit counter for 128 words

always @(posedge clk or negedge rst_n) begin
  if (~rst_n) begin
    // Reset logic if needed
    counter <= 7'b0;
    data_out <= 20'b0;
  end else begin
    // Increment counter on each clock cycle
    counter <= counter + 1;

    // Read from memory based on the counter
    data_out <= memory[counter];
  end
end

endmodule
