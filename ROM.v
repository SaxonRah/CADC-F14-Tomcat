module ROM (
    input  wire        clk,
    input  wire        rst_n,
    input  wire [6:0]  addr,
    output reg  [19:0] data_out
);

    reg [19:0] memory [0:127];

    // Load contents from file
    // populate rom_data.mem with patterns
    initial begin
        $readmemb("rom_data.mem", memory);
    end

    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            data_out <= 20'b0;
        end else begin
            data_out <= memory[addr];
        end
    end

endmodule
