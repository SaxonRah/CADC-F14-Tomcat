module ROM (
    input  wire [11:0] addr,
    output wire [19:0] data_out
);

    reg [19:0] memory [0:4095];

    initial begin
        $readmemh("program.mem", memory);
    end

    assign data_out = memory[addr];

endmodule
