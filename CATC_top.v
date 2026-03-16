module CATC_top (
    input  wire        clk,
    input  wire        rst,
    input  wire [19:0] data_in,
    output wire [19:0] data_out,
    output wire        halt,
    // Peripheral ports
    input  wire [19:0] gpio_in,
    output wire [19:0] gpio_out,
    // External memory bus (directly exposed for external RAM)
    output wire [19:0] ext_addr,
    output wire [19:0] ext_wdata,
    output wire        ext_we,
    output wire        ext_re,
    input  wire [19:0] ext_rdata
);

    wire [11:0] pc;
    wire [19:0] instr;

    ROM rom_inst (
        .addr(pc),
        .data_out(instr)
    );

    CATC cpu_inst (
        .clk(clk),
        .rst(rst),
        .instr(instr),
        .data_in(data_in),
        .data_out(data_out),
        .pc(pc),
        .halt(halt),
        .gpio_in(gpio_in),
        .gpio_out(gpio_out),
        .ext_addr(ext_addr),
        .ext_wdata(ext_wdata),
        .ext_we(ext_we),
        .ext_re(ext_re),
        .ext_rdata(ext_rdata)
    );

endmodule
