module ROM (
    input  wire [6:0]  addr,
    output wire [19:0] data_out
);

    reg [19:0] memory [0:127];

    initial begin
        $readmemh("program.mem", memory);
    end

    assign data_out = memory[addr];

endmodule
