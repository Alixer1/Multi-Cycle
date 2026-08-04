
module RegisterFile_Float (
    input wire clk,
    input wire reg_write,
    input wire [4:0] read_reg1,
    input wire [4:0] read_reg2,
    input wire [4:0] write_reg,
    input wire [31:0] write_data,
    output wire [31:0] read_data1,
    output wire [31:0] read_data2
);
    reg [31:0] registers [0:31];

    assign read_data1 = registers[read_reg1];
    assign read_data2 = registers[read_reg2];

    integer i;
    initial begin
        for(i=0; i<32; i=i+1) registers[i] = 32'b0;
    end

    always @(posedge clk) begin
        if (reg_write) begin
            registers[write_reg] <= write_data;
        end
    end
endmodule
