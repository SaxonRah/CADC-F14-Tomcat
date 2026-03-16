`timescale 1ns / 1ps

module CATCTest_tb;

    parameter CLK_PERIOD = 10;

    reg         clk;
    reg         rst;
    reg  [19:0] data_in;
    wire [19:0] data_out;
    wire        halt;

    // Instantiate top-level
    CATC_top uut (
        .clk(clk),
        .rst(rst),
        .data_in(data_in),
        .data_out(data_out),
        .halt(halt)
    );

    // Clock
    initial begin
        clk = 0;
        forever #(CLK_PERIOD / 2) clk = ~clk;
    end

    // Main test
    initial begin
        $dumpfile("catc_tb.vcd");
        $dumpvars(0, CATCTest_tb);

        // Reset
        rst     = 1;
        data_in = 20'b0;
        #(CLK_PERIOD * 5);
        rst = 0;

        // Let the program run until HALT or timeout
        wait (halt == 1'b1 || $time > 10000);

        // --- Post-execution checks ---
        $display("=== CATC Post-Execution Register State ===");
        $display("  R1  = %0d (expect 30)",  uut.cpu_inst.registers[1]);
        $display("  R2  = %0d (expect 6)",   uut.cpu_inst.registers[2]);
        $display("  R3  = %0d (expect 5)",   uut.cpu_inst.registers[3]);
        $display("  R4  = %0d (expect 13)",  uut.cpu_inst.registers[4]);
        $display("  R5  = %0d (expect 3)",   uut.cpu_inst.registers[5]);
        $display("  R6  = %0d (expect ~3)",  uut.cpu_inst.registers[6]);
        $display("  R7  = %0d (expect 30)",  uut.cpu_inst.registers[7]);
        $display("  R9  = %0d (expect 0)",   uut.cpu_inst.registers[9]);
        $display("  R10 = %0d (expect 0)",   uut.cpu_inst.registers[10]);
        $display("  R11 = %0d (expect 1)",   uut.cpu_inst.registers[11]);
        $display("  HI  = %0d (expect 0)",   uut.cpu_inst.hi);
        $display("  PC  = %0d (expect 25)",  uut.cpu_inst.pc);
        $display("  data_out = %0d (expect 5)", data_out);
        $display("  halt = %b", halt);
        $display("==========================================");

        #(CLK_PERIOD * 2);
        $finish;
    end

    // Cycle-by-cycle trace
    always @(posedge clk) begin
        if (!rst)
            $display("t=%0t  PC=%0d  instr=%h  op=%b  rA=%0d  rB=%0d  imm=%0d  data_out=%0d  halt=%b",
                     $time,
                     uut.cpu_inst.pc,
                     uut.rom_inst.data_out,
                     uut.cpu_inst.opcode,
                     uut.cpu_inst.rA,
                     uut.cpu_inst.rB,
                     uut.cpu_inst.imm,
                     data_out,
                     halt);
    end

endmodule
