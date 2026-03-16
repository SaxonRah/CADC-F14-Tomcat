module CATC (
    input  wire        clk,
    input  wire        rst,
    input  wire [19:0] instr,
    input  wire [19:0] data_in,
    output reg  [19:0] data_out,
    output reg  [6:0]  pc,
    output reg         halt
);

    // Data memory (128 x 20-bit, separate from instruction ROM)
    reg [19:0] memory [0:127];

    // Register file (16 x 20-bit)
    reg [19:0] registers [0:15];

    // HI register for MUL upper result / DIV remainder
    reg [19:0] hi;

    // --- Instruction decode (combinational) ---
    wire [3:0] opcode = instr[19:16];
    wire [3:0] rA     = instr[15:12];
    wire [3:0] rB     = instr[11:8];
    wire [7:0] imm    = instr[7:0];

    // --- PMU (multiply unit) ---
    wire [39:0] mul_result;
    PMU pmu_inst (
        .operand_a(registers[rA]),
        .operand_b(registers[rB]),
        .result(mul_result)
    );

    // --- PDU (division unit) ---
    wire [19:0] div_quotient;
    wire [19:0] div_remainder;
    PDU pdu_inst (
        .dividend(registers[rA]),
        .divisor(registers[rB]),
        .quotient(div_quotient),
        .remainder(div_remainder)
    );

    // Branch control (blocking assigns used as combinational temps)
    reg        branch_taken;
    reg  [6:0] branch_target;

    integer i;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            pc       <= 7'b0;
            halt     <= 1'b0;
            data_out <= 20'b0;
            hi       <= 20'b0;
            for (i = 0; i < 16; i = i + 1)
                registers[i] <= 20'b0;
            for (i = 0; i < 128; i = i + 1)
                memory[i] <= 20'b0;
        end else if (!halt) begin
            branch_taken  = 1'b0;
            branch_target = 7'b0;

            case (opcode)
                4'b0000: begin // NOP or MFHI
                    if (rA != 4'b0)
                        registers[rA] <= hi;
                end

                4'b0001: registers[rA] <= memory[imm[6:0]];               // LOAD
                4'b0010: memory[imm[6:0]] <= registers[rA];               // STORE
                4'b0011: registers[rA] <= {12'b0, imm};                   // MOVI
                4'b0100: registers[rA] <= registers[rB] + {12'b0, imm};   // ADDI
                4'b0101: registers[rA] <= registers[rB] - {12'b0, imm};   // SUBI
                4'b0110: registers[rA] <= registers[rA] & registers[rB];  // AND
                4'b0111: registers[rA] <= registers[rA] | registers[rB];  // OR
                4'b1000: registers[rA] <= registers[rA] ^ registers[rB];  // XOR
                4'b1001: registers[rA] <= ~registers[rA];                  // NOT
                4'b1010: registers[rA] <= registers[rA] << imm[4:0];      // SHL
                4'b1011: registers[rA] <= registers[rA] >> imm[4:0];      // SHR

                4'b1100: begin // MUL — {HI, rA} = rA * rB
                    registers[rA] <= mul_result[19:0];
                    hi             <= mul_result[39:20];
                end

                4'b1101: begin // DIV — rA = rA / rB, HI = rA % rB
                    registers[rA] <= div_quotient;
                    hi             <= div_remainder;
                end

                4'b1110: begin // IO
                    if (rB[0] == 1'b0)
                        registers[rA] <= data_in;  // IN
                    else
                        data_out <= registers[rA];  // OUT
                end

                4'b1111: begin // BRANCH group
                    case (rA)
                        4'b0000: begin // JMP
                            branch_taken  = 1'b1;
                            branch_target = imm[6:0];
                        end
                        4'b0001: begin // BEQ
                            if (registers[rB] == 20'b0) begin
                                branch_taken  = 1'b1;
                                branch_target = imm[6:0];
                            end
                        end
                        4'b0010: begin // BNE
                            if (registers[rB] != 20'b0) begin
                                branch_taken  = 1'b1;
                                branch_target = imm[6:0];
                            end
                        end
                        4'b0011: halt <= 1'b1; // HALT
                        default: ;
                    endcase
                end
            endcase

            // Advance program counter
            if (branch_taken)
                pc <= branch_target;
            else
                pc <= pc + 7'b1;
        end
    end

endmodule
