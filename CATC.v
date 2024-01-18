module CATC (
    input wire clk,          // Clock signal
    input wire rst,          // Reset signal
    input wire [19:0] instr, // Instruction bus (20 bits)
    input wire [19:0] data_in, // Input data bus (20 bits)
    output reg [19:0] data_out // Output data bus (20 bits)
);

// Memory definition (2560 bits)
reg [19:0] memory [0:127];

// Register definition
reg [19:0] registers [0:15];

// Control signals
reg [3:0] opcode;
reg [3:0] src_reg;
reg [3:0] dest_reg;
reg [9:0] immediate;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        // Reset values
        opcode <= 4'b0000;
        src_reg <= 4'b0000;
        dest_reg <= 4'b0000;
        immediate <= 10'b0000000000;
        data_out <= 20'b0;
        registers <= 16 * 20'b0;
        memory <= 128 * 20'b0;
    end else begin
        // Instruction decoding
        opcode <= instr[19:16];
        src_reg <= instr[15:12];
        dest_reg <= instr[11:8];
        immediate <= instr[7:0];

        // Execute instruction based on opcode
        case (opcode)
            4'b0000: data_out <= registers[src_reg]; // LOAD
            4'b0001: registers[dest_reg] <= data_in; // STORE
            4'b0010: data_out <= data_in + immediate; // ADDI
            4'b0011: data_out <= data_in - immediate; // SUBI
            4'b0100: data_out <= registers[src_reg] & registers[dest_reg]; // AND
            4'b0101: data_out <= registers[src_reg] | registers[dest_reg]; // OR
            4'b0110: data_out <= registers[src_reg] ^ registers[dest_reg]; // XOR
            4'b0111: data_out <= ~data_in; // NOT
            // Add more operations
            default: data_out <= 20'b0; // Default case
        endcase
    end
end

endmodule
