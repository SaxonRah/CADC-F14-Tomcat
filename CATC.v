module CATC (
    input  wire        clk,
    input  wire        rst,
    input  wire [19:0] instr,
    input  wire [19:0] data_in,
    output reg  [19:0] data_out
);

    // Memory (128 x 20-bit)
    reg [19:0] memory [0:127];

    // Registers (16 x 20-bit)
    reg [19:0] registers [0:15];

    // Combinational instruction decode
    wire [3:0] opcode = instr[19:16];
    wire [3:0] rA     = instr[15:12];
    wire [3:0] rB     = instr[11:8];
    wire [7:0] imm    = instr[7:0];

    integer i;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            data_out <= 20'b0;
            for (i = 0; i < 16; i = i + 1)
                registers[i] <= 20'b0;
            for (i = 0; i < 128; i = i + 1)
                memory[i] <= 20'b0;
        end else begin
            case (opcode)
                4'b0000: data_out <= memory[imm[6:0]];                   // LOAD  data_out = mem[imm]
                4'b0001: memory[imm[6:0]] <= registers[rA];              // STORE mem[imm] = rA
                4'b0010: registers[rA] <= registers[rB] + {12'b0, imm};  // ADDI  rA = rB + imm
                4'b0011: registers[rA] <= registers[rB] - {12'b0, imm};  // SUBI  rA = rB - imm
                4'b0100: registers[rA] <= registers[rA] & registers[rB]; // AND   rA = rA & rB
                4'b0101: registers[rA] <= registers[rA] | registers[rB]; // OR    rA = rA | rB
                4'b0110: registers[rA] <= registers[rA] ^ registers[rB]; // XOR   rA = rA ^ rB
                4'b0111: registers[rA] <= ~registers[rA];                // NOT   rA = ~rA
                4'b1000: registers[rA] <= registers[rA] << imm[4:0];     // SHL   rA = rA << imm
                4'b1001: registers[rA] <= registers[rA] >> imm[4:0];     // SHR   rA = rA >> imm
                4'b1010: registers[rA] <= {12'b0, imm};                  // MOVI  rA = imm
                4'b1011: registers[rA] <= data_in;                       // IN    rA = data_in
                4'b1100: data_out <= registers[rA];                      // OUT   data_out = rA
                default: ; // NOP
            endcase
        end
    end

endmodule
