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
    wire [19:0] timer_val;

    CATC_top uut (
        .clk(clk),
        .rst(rst),
        .data_in(data_in),
        .data_out(data_out),
        .halt(halt),
        .gpio_in(gpio_in),
        .gpio_out(gpio_out),
        .timer_val(timer_val)
    );

    // Clock
    initial begin
        clk = 0;
        forever #(CLK_PERIOD / 2) clk = ~clk;
    end

    // Shorthand access to CPU internals
    `define CPU  uut.cpu_inst
    `define REGS uut.cpu_inst.registers

    integer pass_count;
    integer fail_count;

    task check;
        input [159:0] label;  // 20-char string
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

    initial begin
        $dumpfile("catc_tb.vcd");
        $dumpvars(0, CATCTest_tb);

        pass_count = 0;
        fail_count = 0;

        // Drive peripheral inputs
        gpio_in = 20'hA5A5A;
        data_in = 20'b0;

        // Reset
        rst = 1;
        #(CLK_PERIOD * 5);
        rst = 0;

        // Run until HALT or timeout
        fork
            wait (halt == 1'b1);
            #(CLK_PERIOD * 200);
        join_any

        // Let final writes settle
        #(CLK_PERIOD);

        $display("");
        $display("==========================================================");
        $display("  CATC Post-Execution Verification");
        $display("==========================================================");

        // ALU results
        check("R1 (restored)  ", `REGS[1],  20'd30);
        check("R2 (restored)  ", `REGS[2],  20'd3);
        check("R3 (DIV 15/3)  ", `REGS[3],  20'd5);
        check("R4 (SUBI 15-2) ", `REGS[4],  20'd13);
        check("R5 (MFHI)      ", `REGS[5],  20'd0);

        // Branch verification — R10 should be 42 (BGT taken), not 99
        check("R10 (BGT taken)", `REGS[10], 20'd42);

        // Stack pointer restored to init
        check("R15/SP         ", `REGS[15], 20'd123);

        // GPIO peripheral
        check("gpio_out       ", gpio_out,  20'd42);

        // Timer ran for at least a couple cycles
        if (timer_val > 20'd0) begin
            $display("  [PASS] timer_val = %0d (>0, timer ran)", timer_val);
            pass_count = pass_count + 1;
        end else begin
            $display("  [FAIL] timer_val = 0 (timer didn't run)");
            fail_count = fail_count + 1;
        end

        // Program counter should be at HALT instruction (25)
        check("PC (at HALT)   ", {13'b0, `CPU.pc}, 20'd25);

        // Halt flag
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

    // Cycle trace
    always @(posedge clk) begin
        if (!rst && !halt)
            $display("t=%0t  PC=%2d  instr=%5h  op=%b  rA=%2d  rB=%2d  imm=%3d  dout=%0d  gpio=%0d  halt=%b",
                     $time, `CPU.pc, uut.rom_inst.data_out,
                     `CPU.opcode, `CPU.rA, `CPU.rB, `CPU.imm,
                     data_out, gpio_out, halt);
    end

endmodule
