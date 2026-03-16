module CATC_top (
    input  wire        clk,
    input  wire        rst,
    input  wire [19:0] data_in,
    output wire [19:0] data_out,
    output wire        halt
);

    wire [6:0]  pc;
    wire [19:0] instr;

    // Instruction ROM (async read — combinational path from PC to instr)
    ROM rom_inst (
        .addr(pc),
        .data_out(instr)
    );

    // Processor core
    CATC cpu_inst (
        .clk(clk),
        .rst(rst),
        .instr(instr),
        .data_in(data_in),
        .data_out(data_out),
        .pc(pc),
        .halt(halt)
    );

endmodule
