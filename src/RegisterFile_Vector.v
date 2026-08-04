
module RegisterFile_Vector (
    input wire clk,
    input wire reg_write,
    input wire [3:0] read_reg1,
    input wire [3:0] read_reg2,
    input wire [3:0] write_reg,
    input wire [127:0] write_data,
    output wire [127:0] read_data1,
    output wire [127:0] read_data2
);
    reg [127:0] registers [0:15];

    assign read_data1 = registers[read_reg1];
    assign read_data2 = registers[read_reg2];

    integer i;
    initial begin
        for(i=0; i<16; i=i+1) registers[i] = 128'b0;
    end

    always @(posedge clk) begin
        if (reg_write) begin
            registers[write_reg] <= write_data;
        end
    end
endmodule
