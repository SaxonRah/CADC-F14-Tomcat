module CATC (
    input  wire        clk,
    input  wire        rst,
    input  wire [19:0] instr,
    input  wire [19:0] data_in,
    output reg  [19:0] data_out,
    output reg  [6:0]  pc,
    output reg         halt,
    // Peripherals
    input  wire [19:0] gpio_in,
    output reg  [19:0] gpio_out,
    output wire [19:0] timer_val
);

    // ---------------------------------------------------------------
    // Constants
    // ---------------------------------------------------------------
    localparam SP_REG       = 4'd15;
    localparam SP_INIT      = 20'd123;
    localparam ADDR_GPIO_OUT  = 7'd124;
    localparam ADDR_GPIO_IN   = 7'd125;
    localparam ADDR_TIMER_VAL = 7'd126;
    localparam ADDR_TIMER_CTRL= 7'd127;

    // ---------------------------------------------------------------
    // State
    // ---------------------------------------------------------------
    reg [19:0] memory    [0:123]; // Data memory (124 words, 0–123)
    reg [19:0] registers [0:15];  // Register file (R0–R15, R15=SP)
    reg [19:0] hi;                // HI register (MUL upper / DIV remainder)
    reg        flag_z;            // Zero flag
    reg        flag_n;            // Negative/sign flag
    reg [19:0] timer_count;       // Free-running timer counter
    reg        timer_en;          // Timer enable

    assign timer_val = timer_count;

    // ---------------------------------------------------------------
    // Instruction decode (combinational)
    // ---------------------------------------------------------------
    wire [3:0] opcode = instr[19:16];
    wire [3:0] rA     = instr[15:12];
    wire [3:0] rB     = instr[11:8];
    wire [7:0] imm    = instr[7:0];

    // ---------------------------------------------------------------
    // PMU (multiply unit) — always computes, result ignored unless MUL
    // ---------------------------------------------------------------
    wire [39:0] mul_result;
    PMU pmu_inst (
        .operand_a(registers[rA]),
        .operand_b(registers[rB]),
        .result(mul_result)
    );

    // ---------------------------------------------------------------
    // PDU (division unit) — always computes, result ignored unless DIV
    // ---------------------------------------------------------------
    wire [19:0] div_quotient;
    wire [19:0] div_remainder;
    PDU pdu_inst (
        .dividend(registers[rA]),
        .divisor(registers[rB]),
        .quotient(div_quotient),
        .remainder(div_remainder)
    );

    // ---------------------------------------------------------------
    // Memory-read helper (data memory + peripheral registers)
    // ---------------------------------------------------------------
    function [19:0] mem_read;
        input [6:0] addr;
        begin
            case (addr)
                ADDR_GPIO_OUT:   mem_read = gpio_out;
                ADDR_GPIO_IN:    mem_read = gpio_in;
                ADDR_TIMER_VAL:  mem_read = timer_count;
                ADDR_TIMER_CTRL: mem_read = {19'b0, timer_en};
                default:         mem_read = memory[addr];
            endcase
        end
    endfunction

    // ---------------------------------------------------------------
    // Temporaries (used as blocking assigns inside clocked block)
    // ---------------------------------------------------------------
    reg        branch_taken;
    reg [6:0]  branch_target;
    reg [19:0] cmp_temp;
    reg [19:0] ret_addr;

    integer i;

    // ---------------------------------------------------------------
    // Main execution
    // ---------------------------------------------------------------
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            pc          <= 7'b0;
            halt        <= 1'b0;
            data_out    <= 20'b0;
            hi          <= 20'b0;
            flag_z      <= 1'b0;
            flag_n      <= 1'b0;
            gpio_out    <= 20'b0;
            timer_count <= 20'b0;
            timer_en    <= 1'b0;
            for (i = 0; i < 16; i = i + 1)
                registers[i] <= (i == SP_REG) ? SP_INIT : 20'b0;
            for (i = 0; i < 124; i = i + 1)
                memory[i] <= 20'b0;
        end else if (!halt) begin
            branch_taken  = 1'b0;
            branch_target = 7'b0;

            // Timer (free-running when enabled)
            if (timer_en)
                timer_count <= timer_count + 20'b1;

            case (opcode)
                // ===================================================
                // 0000 — MISC group (sub-function selected by rB)
                // ===================================================
                4'b0000: begin
                    case (rB)
                        4'b0000: begin // NOP (rA==0) / MFHI rA (rA!=0)
                            if (rA != 4'b0)
                                registers[rA] <= hi;
                        end
                        4'b0001: begin // PUSH rA
                            memory[registers[SP_REG][6:0]] <= registers[rA];
                            registers[SP_REG] <= registers[SP_REG] - 20'b1;
                        end
                        4'b0010: begin // POP rA
                            registers[rA]     <= mem_read(registers[SP_REG][6:0] + 7'b1);
                            registers[SP_REG] <= registers[SP_REG] + 20'b1;
                        end
                        4'b0011: begin // CMP rA, R[imm[3:0]]
                            cmp_temp = registers[rA] - registers[imm[3:0]];
                            flag_z  <= (cmp_temp == 20'b0);
                            flag_n  <= cmp_temp[19];
                        end
                        4'b0100: begin // CMPI rA, imm
                            cmp_temp = registers[rA] - {12'b0, imm};
                            flag_z  <= (cmp_temp == 20'b0);
                            flag_n  <= cmp_temp[19];
                        end
                        default: ; // reserved
                    endcase
                end

                // ===================================================
                // 0001 — LOAD rA, [imm]  (memory-mapped aware)
                // ===================================================
                4'b0001: registers[rA] <= mem_read(imm[6:0]);

                // ===================================================
                // 0010 — STORE rA, [imm] (memory-mapped aware)
                // ===================================================
                4'b0010: begin
                    case (imm[6:0])
                        ADDR_GPIO_OUT: gpio_out <= registers[rA];
                        ADDR_GPIO_IN:  ; // read-only, ignore
                        ADDR_TIMER_VAL:; // read-only, ignore
                        ADDR_TIMER_CTRL: begin
                            timer_en    <= registers[rA][0];
                            timer_count <= 20'b0;
                        end
                        default: memory[imm[6:0]] <= registers[rA];
                    endcase
                end

                4'b0011: registers[rA] <= {12'b0, imm};                     // MOVI
                4'b0100: registers[rA] <= registers[rB] + {12'b0, imm};     // ADDI
                4'b0101: registers[rA] <= registers[rB] - {12'b0, imm};     // SUBI
                4'b0110: registers[rA] <= registers[rA] & registers[rB];    // AND
                4'b0111: registers[rA] <= registers[rA] | registers[rB];    // OR
                4'b1000: registers[rA] <= registers[rA] ^ registers[rB];    // XOR
                4'b1001: registers[rA] <= ~registers[rA];                   // NOT
                4'b1010: registers[rA] <= registers[rA] << imm[4:0];        // SHL
                4'b1011: registers[rA] <= registers[rA] >> imm[4:0];        // SHR

                4'b1100: begin // MUL — {HI, rA} = rA * rB
                    registers[rA] <= mul_result[19:0];
                    hi            <= mul_result[39:20];
                end

                4'b1101: begin // DIV — rA = rA / rB, HI = rA % rB
                    registers[rA] <= div_quotient;
                    hi            <= div_remainder;
                end

                4'b1110: begin // IO
                    if (rB[0] == 1'b0)
                        registers[rA] <= data_in;   // IN
                    else
                        data_out <= registers[rA];   // OUT
                end

                // ===================================================
                // 1111 — BRANCH group (sub-function selected by rA)
                // ===================================================
                4'b1111: begin
                    case (rA)
                        4'b0000: begin // JMP imm
                            branch_taken  = 1'b1;
                            branch_target = imm[6:0];
                        end
                        4'b0001: begin // BEQ — if reg[rB]==0
                            if (registers[rB] == 20'b0) begin
                                branch_taken  = 1'b1;
                                branch_target = imm[6:0];
                            end
                        end
                        4'b0010: begin // BNE — if reg[rB]!=0
                            if (registers[rB] != 20'b0) begin
                                branch_taken  = 1'b1;
                                branch_target = imm[6:0];
                            end
                        end
                        4'b0011: halt <= 1'b1; // HALT
                        4'b0100: begin // BGT — Z==0 && N==0
                            if (!flag_z && !flag_n) begin
                                branch_taken  = 1'b1;
                                branch_target = imm[6:0];
                            end
                        end
                        4'b0101: begin // BLT — N==1
                            if (flag_n) begin
                                branch_taken  = 1'b1;
                                branch_target = imm[6:0];
                            end
                        end
                        4'b0110: begin // BGE — N==0
                            if (!flag_n) begin
                                branch_taken  = 1'b1;
                                branch_target = imm[6:0];
                            end
                        end
                        4'b0111: begin // BLE — Z==1 || N==1
                            if (flag_z || flag_n) begin
                                branch_taken  = 1'b1;
                                branch_target = imm[6:0];
                            end
                        end
                        4'b1000: begin // CALL imm
                            memory[registers[SP_REG][6:0]] <= {13'b0, pc + 7'b1};
                            registers[SP_REG] <= registers[SP_REG] - 20'b1;
                            branch_taken  = 1'b1;
                            branch_target = imm[6:0];
                        end
                        4'b1001: begin // RET
                            ret_addr = mem_read(registers[SP_REG][6:0] + 7'b1);
                            registers[SP_REG] <= registers[SP_REG] + 20'b1;
                            branch_taken  = 1'b1;
                            branch_target = ret_addr[6:0];
                        end
                        default: ; // reserved
                    endcase
                end
            endcase

            // Program counter update
            if (branch_taken)
                pc <= branch_target;
            else
                pc <= pc + 7'b1;
        end
    end

endmodule
