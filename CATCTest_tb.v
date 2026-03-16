`timescale 1ns / 1ps

module CATCTest_tb;

    parameter CLK_PERIOD = 10;

    reg         clk;
    reg         rst;
    reg  [19:0] data_in;
    wire [19:0] data_out;
    wire        halt;
    reg  [19:0] gpio_in;
    wire [19:0] gpio_out;

    // External memory bus
    wire [19:0] ext_addr;
    wire [19:0] ext_wdata;
    wire        ext_we;
    wire        ext_re;
    wire [19:0] ext_rdata;

    // ---------------------------------------------------------------
    // External RAM model (async read, sync write)
    // ---------------------------------------------------------------
    reg [19:0] ext_ram [0:65535];

    assign ext_rdata = ext_ram[ext_addr[15:0]];

    integer j;
    initial begin
        for (j = 0; j < 65536; j = j + 1)
            ext_ram[j] = 20'b0;
    end

    always @(posedge clk) begin
        if (ext_we)
            ext_ram[ext_addr[15:0]] <= ext_wdata;
    end

    // ---------------------------------------------------------------
    // DUT
    // ---------------------------------------------------------------
    CATC_top uut (
        .clk(clk),
        .rst(rst),
        .data_in(data_in),
        .data_out(data_out),
        .halt(halt),
        .gpio_in(gpio_in),
        .gpio_out(gpio_out),
        .ext_addr(ext_addr),
        .ext_wdata(ext_wdata),
        .ext_we(ext_we),
        .ext_re(ext_re),
        .ext_rdata(ext_rdata)
    );

    // ---------------------------------------------------------------
    // Clock
    // ---------------------------------------------------------------
    initial begin
        clk = 0;
        forever #(CLK_PERIOD / 2) clk = ~clk;
    end

    // ---------------------------------------------------------------
    // Shortcuts
    // ---------------------------------------------------------------
    `define CPU  uut.cpu_inst
    `define REGS uut.cpu_inst.registers

    integer pass_count;
    integer fail_count;

    task check;
        input [199:0] label;
        input [19:0]  actual;
        input [19:0]  expected;
        begin
            if (actual === expected) begin
                $display("  [PASS] %0s = %0d", label, actual);
                pass_count = pass_count + 1;
            end else begin
                $display("  [FAIL] %0s = %0d (expected %0d)", label, actual, expected);
                fail_count = fail_count + 1;
            end
        end
    endtask

    task check_nonzero;
        input [199:0] label;
        input [19:0]  actual;
        begin
            if (actual > 20'd0) begin
                $display("  [PASS] %0s = %0d (> 0)", label, actual);
                pass_count = pass_count + 1;
            end else begin
                $display("  [FAIL] %0s = %0d (expected > 0)", label, actual);
                fail_count = fail_count + 1;
            end
        end
    endtask

    // ---------------------------------------------------------------
    // Main test
    // ---------------------------------------------------------------
    initial begin
        $dumpfile("catc_tb.vcd");
        $dumpvars(0, CATCTest_tb);

        pass_count = 0;
        fail_count = 0;

        gpio_in = 20'hA5A5A;
        data_in = 20'b0;

        // Reset
        rst = 1;
        #(CLK_PERIOD * 5);
        rst = 0;

        // Run until HALT or timeout
        fork
            wait (halt == 1'b1);
            #(CLK_PERIOD * 500);
        join_any

        #(CLK_PERIOD);

        $display("");
        $display("==========================================================");
        $display("  CATC Post-Execution Verification");
        $display("==========================================================");

        // --- R0 hardwired zero ---
        check("R0  (hardwired 0)  ", `REGS[0],  20'd0);

        // --- ALU results ---
        check("R1  (restored 30)  ", `REGS[1],  20'd30);
        check("R2  (restored 3)   ", `REGS[2],  20'd3);
        check("R3  (DIV 15/3)     ", `REGS[3],  20'd5);
        check("R4  (SUBI 15-2)    ", `REGS[4],  20'd13);
        check("R5  (MFHI)         ", `REGS[5],  20'd0);

        // --- Branch (BGT taken → R10=42, not 99) ---
        check("R10 (BGT taken)    ", `REGS[10], 20'd42);

        // --- External memory (R11 read back from ext RAM) ---
        check("R11 (ext RAM read) ", `REGS[11], 20'd42);

        // --- Stack pointer restored ---
        check("R15/SP (restored)  ", `REGS[15], 20'd119);

        // --- GPIO peripheral ---
        check("gpio_out           ", gpio_out,  20'd42);

        // --- Interrupt counter (at least one timer IRQ fired) ---
        check_nonzero("R13 (IRQ count)    ", `REGS[13]);

        // --- data_out should match R13 (OUT R13 was last output) ---
        check("data_out (=R13)    ", data_out,  `REGS[13]);

        // --- Timer was running ---
        if (`CPU.timer_en) begin
            $display("  [PASS] timer still enabled");
            pass_count = pass_count + 1;
        end else begin
            $display("  [INFO] timer disabled (DI may have stopped it)");
        end

        // --- External RAM verify (address 4096 should hold 42) ---
        check("ext_ram[4096]      ", ext_ram[4096], 20'd42);

        // --- PC at HALT ---
        check("PC (at HALT)       ", {8'b0, `CPU.pc}, 20'd54);

        // --- Halt flag ---
        if (halt) begin
            $display("  [PASS] halt asserted");
            pass_count = pass_count + 1;
        end else begin
            $display("  [FAIL] halt not asserted (timeout?)");
            fail_count = fail_count + 1;
        end

        $display("==========================================================");
        $display("  Results: %0d passed, %0d failed", pass_count, fail_count);
        $display("==========================================================");
        $display("");

        #(CLK_PERIOD * 2);
        $finish;
    end

    // ---------------------------------------------------------------
    // Cycle trace
    // ---------------------------------------------------------------
    always @(posedge clk) begin
        if (!rst && !halt)
            $display("t=%0t  PC=%3d  instr=%5h  op=%b  rA=%2d  rB=%2d  imm=%3d | dout=%0d  gpio=%0d  ie=%b  irq=%b  tmr=%0d  SP=%0d  halt=%b",
                     $time, `CPU.pc, uut.rom_inst.data_out,
                     `CPU.opcode, `CPU.rA, `CPU.rB, `CPU.imm,
                     data_out, gpio_out,
                     `CPU.ie_flag, `CPU.irq_timer_pending,
                     `CPU.timer_count, `REGS[15],
                     halt);
    end

endmodule
