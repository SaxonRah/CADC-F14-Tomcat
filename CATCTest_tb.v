`timescale 1ns / 1ps

module CATCTest_tb;

// Parameters
parameter CLOCK_PERIOD = 10; // Clock period in ns

// Signals
reg clk;
reg rst;
reg [19:0] instr;
reg [19:0] data_in;
wire [19:0] data_out;

// Instantiate the microprocessor module
CATCTest_tb uut (
    .clk(clk),
    .rst(rst),
    .instr(instr),
    .data_in(data_in),
    .data_out(data_out)
);

// Clock generation
initial begin
    clk = 0;
    forever #((CLOCK_PERIOD)/2) clk = ~clk;
end

// Test procedure
initial begin
    // Reset
    rst = 1;
    #50;
    rst = 0;

    // Load data into register 1
    instr = {4'b0001, 4'b0000, 4'b0001, 10'b0000000101}; // STORE R1, 5
    data_in = 20'b10101010101010101010;
    #10;

    // Load data into register 2
    instr = {4'b0001, 4'b0000, 4'b0010, 10'b0000000110}; // STORE R2, 6
    data_in = 20'b11001100110011001100;
    #10;

    // Perform ADDI operation
    instr = {4'b0010, 4'b0001, 4'b0010, 10'b0000000010}; // ADDI R1, R2, 2
    data_in = 20'b0;
    #10;

    // Perform SUBI operation
    instr = {4'b0011, 4'b0010, 4'b0011, 10'b0000000001}; // SUBI R3, R2, 1
    data_in = 20'b0;
    #10;

    // Perform AND operation
    instr = {4'b0100, 4'b0010, 4'b0011, 10'b0000000000}; // AND R2, R3
    data_in = 20'b0;
    #10;

    // Perform OR operation
    instr = {4'b0101, 4'b0001, 4'b0100, 10'b0000000000}; // OR R1, R4
    data_in = 20'b0;
    #10;

    // Perform XOR operation
    instr = {4'b0110, 4'b0001, 4'b0101, 10'b0000000000}; // XOR R1, R5
    data_in = 20'b0;
    #10;

    // Perform NOT operation
    instr = {4'b0111, 4'b0010, 4'b0110, 10'b0000000000}; // NOT R2
    data_in = 20'b0;
    #10;

    // Add more test cases as needed

    // Stop simulation
    $stop;
end

endmodule
