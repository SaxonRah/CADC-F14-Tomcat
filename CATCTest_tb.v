`timescale 1ns / 1ps

module CATCTest_tb;

    parameter CLOCK_PERIOD = 10;

    reg         clk;
    reg         rst;
    reg  [19:0] instr;
    reg  [19:0] data_in;
    wire [19:0] data_out;

    // Instantiate the processor
    CATC uut (
        .clk(clk),
        .rst(rst),
        .instr(instr),
        .data_in(data_in),
        .data_out(data_out)
    );

    // Clock generation
    initial begin
        clk = 0;
        forever #(CLOCK_PERIOD / 2) clk = ~clk;
    end

    // Helper: build instruction word
    // [19:16] opcode, [15:12] rA, [11:8] rB, [7:0] imm
    `define INSTR(op, ra, rb, im) {op, ra, rb, im}

    initial begin
        // Reset
        rst = 1;
        instr = 20'b0;
        data_in = 20'b0;
        #50;
        rst = 0;

        // MOVI R1, 10        ---  R1 = 10
        instr = `INSTR(4'b1010, 4'd1, 4'd0, 8'd10);
        #CLOCK_PERIOD;

        // MOVI R2, 3         ---  R2 = 3
        instr = `INSTR(4'b1010, 4'd2, 4'd0, 8'd3);
        #CLOCK_PERIOD;

        // ADDI R3, R1, 5     ---  R3 = R1 + 5 = 15
        instr = `INSTR(4'b0010, 4'd3, 4'd1, 8'd5);
        #CLOCK_PERIOD;

        // SUBI R4, R3, 2     ---  R4 = R3 - 2 = 13
        instr = `INSTR(4'b0011, 4'd4, 4'd3, 8'd2);
        #CLOCK_PERIOD;

        // AND R5, R1 (=R5&R1, but R5=0 so result=0)
        instr = `INSTR(4'b0100, 4'd5, 4'd1, 8'd0);
        #CLOCK_PERIOD;

        // OR R5, R2          ---  R5 = R5 | R2 = 3
        instr = `INSTR(4'b0101, 4'd5, 4'd2, 8'd0);
        #CLOCK_PERIOD;

        // XOR R6, R1         ---  R6 = R6 ^ R1 (R6=0, so R6=10)
        instr = `INSTR(4'b0110, 4'd6, 4'd1, 8'd0);
        #CLOCK_PERIOD;

        // NOT R6             ---  R6 = ~R6
        instr = `INSTR(4'b0111, 4'd6, 4'd0, 8'd0);
        #CLOCK_PERIOD;

        // SHL R1, 2          ---  R1 = 10 << 2 = 40
        instr = `INSTR(4'b1000, 4'd1, 4'd0, 8'd2);
        #CLOCK_PERIOD;

        // SHR R1, 1          ---  R1 = 40 >> 1 = 20
        instr = `INSTR(4'b1001, 4'd1, 4'd0, 8'd1);
        #CLOCK_PERIOD;

        // STORE R1, [addr 0] ---  mem[0] = R1
        instr = `INSTR(4'b0001, 4'd1, 4'd0, 8'd0);
        #CLOCK_PERIOD;

        // LOAD [addr 0]      ---  data_out = mem[0] (should be 20)
        instr = `INSTR(4'b0000, 4'd0, 4'd0, 8'd0);
        #CLOCK_PERIOD;

        // IN R7 from data_in
        data_in = 20'd42;
        instr = `INSTR(4'b1011, 4'd7, 4'd0, 8'd0);
        #CLOCK_PERIOD;

        // OUT R7             ---  data_out should be 42
        instr = `INSTR(4'b1100, 4'd7, 4'd0, 8'd0);
        #CLOCK_PERIOD;

        // NOP
        instr = 20'b0;
        data_in = 20'b0;
        #(CLOCK_PERIOD * 2);

        $display("=== CATC Test Complete ===");
        $stop;
    end

    // Monitor key signals
    initial begin
        $monitor("t=%0t | op=%b rA=%0d rB=%0d imm=%0d | data_out=%0d",
                 $time, uut.opcode, uut.rA, uut.rB, uut.imm, data_out);
    end

endmodule
