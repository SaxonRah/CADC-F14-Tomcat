module CATC (
    input  wire        clk,
    input  wire        rst,
    input  wire [19:0] instr,
    input  wire [19:0] data_in,
    output reg  [19:0] data_out,
    output reg  [11:0] pc,
    output reg         halt,
    // Peripheral ports
    input  wire [19:0] gpio_in,
    output reg  [19:0] gpio_out,
    // External memory bus
    output wire [19:0] ext_addr,
    output wire [19:0] ext_wdata,
    output wire        ext_we,
    output wire        ext_re,
    input  wire [19:0] ext_rdata
);

    // ---------------------------------------------------------------
    // Constants
    // ---------------------------------------------------------------
    localparam SP_REG          = 4'd15;
    localparam SP_INIT         = 20'd119;
    localparam ISR_VECTOR      = 12'd1;
    localparam PERIPH_BASE     = 20'd120;
    localparam PERIPH_END      = 20'd128;
    localparam SRAM_SIZE       = 128;

    // Peripheral offsets from PERIPH_BASE
    localparam P_GPIO_OUT      = 3'd0;   // 120
    localparam P_GPIO_IN       = 3'd1;   // 121
    localparam P_TIMER_VAL     = 3'd2;   // 122
    localparam P_TIMER_CTRL    = 3'd3;   // 123
    localparam P_TIMER_CMP     = 3'd4;   // 124
    localparam P_IRQ_FLAGS     = 3'd5;   // 125

    // ---------------------------------------------------------------
    // State
    // ---------------------------------------------------------------
    reg [19:0] sram      [0:SRAM_SIZE-1];
    reg [19:0] registers [0:15];
    reg [19:0] hi;

    // Flags (set by CMP / CMPI only)
    reg        flag_z;
    reg        flag_n;

    // Interrupt
    reg        ie_flag;
    reg        irq_timer_pending;

    // Timer
    reg [19:0] timer_count;
    reg        timer_en;
    reg        timer_irq_en;
    reg [19:0] timer_cmp;
    reg        timer_match_prev;

    // ---------------------------------------------------------------
    // Instruction decode (combinational)
    // ---------------------------------------------------------------
    wire [3:0] opcode = instr[19:16];
    wire [3:0] rA     = instr[15:12];
    wire [3:0] rB     = instr[11:8];
    wire [7:0] imm    = instr[7:0];

    // ---------------------------------------------------------------
    // PMU / PDU (always computing, results latched only for MUL/DIV)
    // ---------------------------------------------------------------
    wire [39:0] mul_result;
    PMU pmu_inst (
        .operand_a(registers[rA]),
        .operand_b(registers[rB]),
        .result(mul_result)
    );

    wire [19:0] div_quotient;
    wire [19:0] div_remainder;
    PDU pdu_inst (
        .dividend(registers[rA]),
        .divisor(registers[rB]),
        .quotient(div_quotient),
        .remainder(div_remainder)
    );

    // ---------------------------------------------------------------
    // Timer match (combinational, edge-detected in clocked block)
    // ---------------------------------------------------------------
    wire timer_match = (timer_count == timer_cmp) && timer_en;

    // ---------------------------------------------------------------
    // Interrupt condition
    // ---------------------------------------------------------------
    wire irq_pending = irq_timer_pending;
    wire irq_active  = irq_pending && ie_flag && !halt;

    // ---------------------------------------------------------------
    // Combinational memory interface
    //   Computes effective address, read/write control, and write data
    //   for the current operation (interrupt entry OR normal instruction)
    // ---------------------------------------------------------------
    reg  [19:0] eff_addr;
    reg         mem_we_comb;
    reg         mem_re_comb;
    reg  [19:0] mem_wdata_comb;

    always @(*) begin
        eff_addr      = 20'b0;
        mem_we_comb   = 1'b0;
        mem_re_comb   = 1'b0;
        mem_wdata_comb = 20'b0;

        if (irq_active) begin
            // Interrupt entry: push current PC to stack
            eff_addr       = registers[SP_REG];
            mem_we_comb    = 1'b1;
            mem_wdata_comb = {8'b0, pc};
        end else if (!halt && !rst) begin
            case (opcode)
                4'b0001: begin // LOAD
                    eff_addr    = registers[rB] + {12'b0, imm};
                    mem_re_comb = 1'b1;
                end
                4'b0010: begin // STORE
                    eff_addr       = registers[rB] + {12'b0, imm};
                    mem_we_comb    = 1'b1;
                    mem_wdata_comb = registers[rA];
                end
                4'b0000: begin
                    case (rB)
                        4'b0001: begin // PUSH
                            eff_addr       = registers[SP_REG];
                            mem_we_comb    = 1'b1;
                            mem_wdata_comb = registers[rA];
                        end
                        4'b0010: begin // POP
                            eff_addr    = registers[SP_REG] + 20'd1;
                            mem_re_comb = 1'b1;
                        end
                        default: ;
                    endcase
                end
                4'b1111: begin
                    case (rA)
                        4'b1000: begin // CALL
                            eff_addr       = registers[SP_REG];
                            mem_we_comb    = 1'b1;
                            mem_wdata_comb = {8'b0, pc + 12'd1};
                        end
                        4'b1001, 4'b1010: begin // RET, RETI
                            eff_addr    = registers[SP_REG] + 20'd1;
                            mem_re_comb = 1'b1;
                        end
                        default: ;
                    endcase
                end
                default: ;
            endcase
        end
    end

    // ---------------------------------------------------------------
    // Address decode
    // ---------------------------------------------------------------
    wire addr_is_sram   = (eff_addr < PERIPH_BASE);
    wire addr_is_periph = (eff_addr >= PERIPH_BASE) && (eff_addr < PERIPH_END);
    wire addr_is_ext    = (eff_addr >= PERIPH_END);

    // ---------------------------------------------------------------
    // Peripheral read mux (combinational)
    // ---------------------------------------------------------------
    reg [19:0] periph_rdata;
    always @(*) begin
        case (eff_addr[2:0])
            P_GPIO_OUT:   periph_rdata = gpio_out;
            P_GPIO_IN:    periph_rdata = gpio_in;
            P_TIMER_VAL:  periph_rdata = timer_count;
            P_TIMER_CTRL: periph_rdata = {18'b0, timer_irq_en, timer_en};
            P_TIMER_CMP:  periph_rdata = timer_cmp;
            P_IRQ_FLAGS:  periph_rdata = {19'b0, irq_timer_pending};
            default:      periph_rdata = 20'b0;
        endcase
    end

    // ---------------------------------------------------------------
    // Memory read data mux (combinational)
    // ---------------------------------------------------------------
    wire [19:0] mem_rdata = addr_is_sram   ? sram[eff_addr[6:0]] :
                            addr_is_periph ? periph_rdata         :
                            ext_rdata;

    // ---------------------------------------------------------------
    // External bus drive (active only for external addresses)
    // ---------------------------------------------------------------
    assign ext_addr  = eff_addr;
    assign ext_wdata = mem_wdata_comb;
    assign ext_we    = mem_we_comb && addr_is_ext && !rst;
    assign ext_re    = mem_re_comb && addr_is_ext && !rst;

    // ---------------------------------------------------------------
    // Temporaries
    // ---------------------------------------------------------------
    reg        branch_taken;
    reg [11:0] branch_target;
    reg [19:0] cmp_result;

    integer i;

    // ---------------------------------------------------------------
    // Main clocked execution
    // ---------------------------------------------------------------
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            pc                <= 12'b0;
            halt              <= 1'b0;
            data_out          <= 20'b0;
            hi                <= 20'b0;
            flag_z            <= 1'b0;
            flag_n            <= 1'b0;
            ie_flag           <= 1'b0;
            irq_timer_pending <= 1'b0;
            timer_count       <= 20'b0;
            timer_en          <= 1'b0;
            timer_irq_en      <= 1'b0;
            timer_cmp         <= 20'b0;
            timer_match_prev  <= 1'b0;
            gpio_out          <= 20'b0;
            for (i = 0; i < 16; i = i + 1)
                registers[i] <= (i == SP_REG) ? SP_INIT : 20'b0;
            for (i = 0; i < SRAM_SIZE; i = i + 1)
                sram[i] <= 20'b0;
        end else if (!halt) begin

            // --- Timer update (runs every cycle when enabled) ---
            if (timer_en) begin
                if (timer_count == timer_cmp)
                    timer_count <= 20'b0;        // auto-reload
                else
                    timer_count <= timer_count + 20'd1;
            end

            // --- Timer edge detection ---
            timer_match_prev <= timer_match;
            if (timer_match && !timer_match_prev && timer_irq_en)
                irq_timer_pending <= 1'b1;

            // ===========================================================
            // INTERRUPT ENTRY (takes priority over instruction execution)
            // ===========================================================
            if (irq_active) begin
                // Stack push (write handled by combinational interface)
                if (addr_is_sram)
                    sram[eff_addr[6:0]] <= mem_wdata_comb;
                // External push: ext_we is already asserted combinationally

                registers[SP_REG] <= registers[SP_REG] - 20'd1;
                ie_flag           <= 1'b0;
                pc                <= ISR_VECTOR;

            // ===========================================================
            // NORMAL INSTRUCTION EXECUTION
            // ===========================================================
            end else begin
                branch_taken  = 1'b0;
                branch_target = 12'b0;

                case (opcode)
                    // ===================================================
                    // 0000 — MISC group
                    // ===================================================
                    4'b0000: begin
                        case (rB)
                            4'b0000: begin // NOP / MFHI
                                if (rA != 4'b0)
                                    registers[rA] <= hi;
                            end
                            4'b0001: begin // PUSH rA
                                if (addr_is_sram)
                                    sram[eff_addr[6:0]] <= mem_wdata_comb;
                                registers[SP_REG] <= registers[SP_REG] - 20'd1;
                            end
                            4'b0010: begin // POP rA
                                registers[rA]     <= mem_rdata;
                                registers[SP_REG] <= registers[SP_REG] + 20'd1;
                            end
                            4'b0011: begin // CMP rA, reg[imm[3:0]]
                                cmp_result = registers[rA] - registers[imm[3:0]];
                                flag_z <= (cmp_result == 20'b0);
                                flag_n <= cmp_result[19];
                            end
                            4'b0100: begin // CMPI rA, imm
                                cmp_result = registers[rA] - {12'b0, imm};
                                flag_z <= (cmp_result == 20'b0);
                                flag_n <= cmp_result[19];
                            end
                            4'b0101: ie_flag <= 1'b1;              // EI
                            4'b0110: ie_flag <= 1'b0;              // DI
                            4'b0111: registers[rA] <= {imm, 12'b0}; // LUI
                            default: ;
                        endcase
                    end

                    // ===================================================
                    // 0001 — LOAD rA, [rB + imm]
                    // ===================================================
                    4'b0001: registers[rA] <= mem_rdata;

                    // ===================================================
                    // 0010 — STORE rA, [rB + imm]
                    // ===================================================
                    4'b0010: begin
                        if (addr_is_sram)
                            sram[eff_addr[6:0]] <= mem_wdata_comb;
                        else if (addr_is_periph) begin
                            case (eff_addr[2:0])
                                P_GPIO_OUT: gpio_out <= registers[rA];
                                P_TIMER_CTRL: begin
                                    timer_en     <= registers[rA][0];
                                    timer_irq_en <= registers[rA][1];
                                    timer_count  <= 20'b0;
                                end
                                P_TIMER_CMP: timer_cmp <= registers[rA];
                                P_IRQ_FLAGS: begin
                                    if (registers[rA][0])
                                        irq_timer_pending <= 1'b0;
                                end
                                default: ; // read-only / reserved
                            endcase
                        end
                        // External: ext_we driven combinationally
                    end

                    4'b0011: registers[rA] <= {12'b0, imm};                   // MOVI
                    4'b0100: registers[rA] <= registers[rB] + {12'b0, imm};   // ADDI
                    4'b0101: registers[rA] <= registers[rB] - {12'b0, imm};   // SUBI
                    4'b0110: registers[rA] <= registers[rA] & registers[rB];   // AND
                    4'b0111: registers[rA] <= registers[rA] | registers[rB];   // OR
                    4'b1000: registers[rA] <= registers[rA] ^ registers[rB];   // XOR
                    4'b1001: registers[rA] <= ~registers[rA];                   // NOT
                    4'b1010: registers[rA] <= registers[rA] << imm[4:0];       // SHL
                    4'b1011: registers[rA] <= registers[rA] >> imm[4:0];       // SHR

                    4'b1100: begin // MUL
                        registers[rA] <= mul_result[19:0];
                        hi            <= mul_result[39:20];
                    end

                    4'b1101: begin // DIV
                        registers[rA] <= div_quotient;
                        hi            <= div_remainder;
                    end

                    4'b1110: begin // IO
                        if (rB[0] == 1'b0)
                            registers[rA] <= data_in;
                        else
                            data_out <= registers[rA];
                    end

                    // ===================================================
                    // 1111 — BRANCH group
                    // ===================================================
                    4'b1111: begin
                        case (rA)
                            4'b0000: begin // JMP
                                branch_taken  = 1'b1;
                                branch_target = {rB, imm};
                            end
                            4'b0001: begin // BEQ (short: 8-bit target)
                                if (flag_z) begin
                                    branch_taken  = 1'b1;
                                    branch_target = {4'b0, imm};
                                end
                            end
                            4'b0010: begin // BNE (short: 8-bit target)
                                if (!flag_z) begin
                                    branch_taken  = 1'b1;
                                    branch_target = {4'b0, imm};
                                end
                            end
                            4'b0011: halt <= 1'b1; // HALT
                            4'b0100: begin // BGT
                                if (!flag_z && !flag_n) begin
                                    branch_taken  = 1'b1;
                                    branch_target = {rB, imm};
                                end
                            end
                            4'b0101: begin // BLT
                                if (flag_n) begin
                                    branch_taken  = 1'b1;
                                    branch_target = {rB, imm};
                                end
                            end
                            4'b0110: begin // BGE
                                if (!flag_n) begin
                                    branch_taken  = 1'b1;
                                    branch_target = {rB, imm};
                                end
                            end
                            4'b0111: begin // BLE
                                if (flag_z || flag_n) begin
                                    branch_taken  = 1'b1;
                                    branch_target = {rB, imm};
                                end
                            end
                            4'b1000: begin // CALL
                                if (addr_is_sram)
                                    sram[eff_addr[6:0]] <= mem_wdata_comb;
                                registers[SP_REG] <= registers[SP_REG] - 20'd1;
                                branch_taken  = 1'b1;
                                branch_target = {rB, imm};
                            end
                            4'b1001: begin // RET
                                registers[SP_REG] <= registers[SP_REG] + 20'd1;
                                branch_taken  = 1'b1;
                                branch_target = mem_rdata[11:0];
                            end
                            4'b1010: begin // RETI
                                registers[SP_REG] <= registers[SP_REG] + 20'd1;
                                ie_flag           <= 1'b1;
                                branch_taken  = 1'b1;
                                branch_target = mem_rdata[11:0];
                            end
                            default: ;
                        endcase
                    end
                endcase

                // --- Program counter ---
                if (branch_taken)
                    pc <= branch_target;
                else
                    pc <= pc + 12'd1;
            end

            // --- R0 hardwired to zero (overrides any writes above) ---
            registers[0] <= 20'b0;
        end
    end

endmodule
