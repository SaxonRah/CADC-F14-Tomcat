module CATCTest;

reg clk;
reg rst;
reg [19:0] addr;
reg [19:0] data_in;
wire [19:0] data_out;

// Instantiate the microprocessor
CATC uut (
    .clk(clk),
    .rst(rst),
    .addr(addr),
    .data_in(data_in),
    .data_out(data_out)
);

// Clock generation
always #5 clk = ~clk;

// Test stimulus
initial begin
    clk = 0;
    rst = 1;
    addr = 20'b0;
    data_in = 20'b0;

    // Reset and wait for a few clock cycles
    #10 rst = 0;
    #10;

    // Test case 1: ADD operation
    addr = 4'h0; // Set opcode
    data_in = 20'b00000000000000000001; // Set regA value
    #5;
    addr = 4'h1; // Set regB value
    data_in = 20'b00000000000000000010;
    #5;
    addr = 4'h3; // Execute ADD and store result in memory
    #5;

    // Test case 2: Memory read
    addr = 4'h0; // Set opcode
    data_in = 20'b00000000000000000001; // Set regA value
    #5;
    addr = 4'h1; // Set regB value
    data_in = 20'b00000000000000000010;
    #5;
    addr = 4'h3; // Execute ADD and store result in memory
    #5;
    addr = 4'h2; // Set opcode for memory read
    data_in = 20'b00000000000000000000; // Memory read address
    #5;

    // Add more test cases

    #10 $stop; // Stop simulation after all test cases
end

endmodule
