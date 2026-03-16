module CATC_top (
    input  wire        clk,
    input  wire        rst,
    input  wire [19:0] data_in,
    output wire [19:0] data_out,
    output wire        halt,
    // Peripheral ports
    input  wire [19:0] gpio_in,
    output wire [19:0] gpio_out,
    output wire [19:0] timer_val
);

    wire [6:0]  pc;
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
        .timer_val(timer_val)
    );

endmodule
