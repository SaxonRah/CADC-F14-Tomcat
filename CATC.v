module CATC (
    input wire clk,          // Clock signal
    input wire rst,          // Reset signal
    input wire [19:0] addr,  // Address bus (20 bits)
    input wire [19:0] data_in, // Input data bus (20 bits)
    output reg [19:0] data_out // Output data bus (20 bits)
);

// Memory definition (2560 bits)
reg [19:0] memory [0:127];

// Register definition
reg [19:0] regA;
reg [19:0] regB;
reg [19:0] result;

// Control signals
reg [2:0] opcode;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        // Reset values
        regA <= 20'b0;
        regB <= 20'b0;
        result <= 20'b0;
        data_out <= 20'b0;
        memory <= 128 * 20'b0;
    end else begin
        // Memory read operation
        data_out <= memory[addr];

        // ALU operations based on opcode
        case (opcode)
            3'b000: result <= regA + regB; // ADD
            3'b001: result <= regA - regB; // SUB
            3'b010: result <= regA & regB; // AND
            3'b011: result <= regA | regB; // OR
            // Add more operations as needed
            default: result <= 20'b0; // Default case
        endcase
    end
end

always @(posedge clk or posedge rst) begin
    if (rst) begin
        // Reset values
        opcode <= 3'b000;
    end else begin
        // Instruction decoding based on address
        // Example: Assuming address 0 to 3 are reserved for instructions
        case (addr)
            4'h0: opcode <= data_in[2:0]; // Opcode is in the first 3 bits of the instruction
            4'h1: regA <= data_in;
            4'h2: regB <= data_in;
            4'h3: memory[addr[7:0]] <= data_in; // Store instruction result in memory
            // Add more cases as needed
            default: opcode <= 3'b000; // Default case
        endcase
    end
end

endmodule
