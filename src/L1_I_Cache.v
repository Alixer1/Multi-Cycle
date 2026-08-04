

module L1_I_Cache (
    input wire clk,
    input wire rst,
    input wire [31:0] addr,
    input wire mem_ready,             // when i miss happens, cpu must fetch 4 words from memory, when that finally happens(valid mem_block_in), mem_ready is set to 1 so cache stores that
    input wire [127:0] mem_block_in,  // 4 word block from main memory
    output reg [31:0] instruction,
    output reg cache_hit,
    output reg cache_miss_req         // Triggers main memory read
);

    // Cache line structure: 1 bit Valid, 22 bits Tag, 128 bits Data (4 * 32-bit words)
    reg valid [0:63];
    reg [21:0] tags [0:63];
    reg [31:0] data_store [0:63][0:3];  	// 64 rows, with 4 words per row

    wire [5:0] index = addr[9:4];		// picks exactly which of the 64 rows in your cache array to check
    wire [21:0] current_tag = addr[31:10];	// unique "ID" of the memory block
    wire [1:0] word_sel = addr[3:2];		// picks which of the 4 instructions inside the cache row we want to read

    integer i;

    always @(*) begin
        if (valid[index] && (tags[index] == current_tag)) begin	// address is indeed in cache
            cache_hit = 1'b1;
            cache_miss_req = 1'b0;
            instruction = data_store[index][word_sel];
        end else begin	// look for it in rom
            cache_hit = 1'b0;
            cache_miss_req = 1'b1;
            instruction = 32'h00000000; // No operation cache missed. just wait to retireive from memory
        end
    end

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            for (i = 0; i < 64; i = i + 1) begin
                valid[i] <= 1'b0;	// flags every row as invalid
                tags[i]  <= 22'b0;
                data_store[i][0] <= 32'b0;
                data_store[i][1] <= 32'b0;
                data_store[i][2] <= 32'b0;
                data_store[i][3] <= 32'b0;
            end
        end else if (cache_miss_req && mem_ready) begin
            // read 4 instructions
            valid[index] <= 1'b1;	// mark row as valid
            tags[index]  <= current_tag;	// fill id tag
            data_store[index][0] <= mem_block_in[31:0];
            data_store[index][1] <= mem_block_in[63:32];
            data_store[index][2] <= mem_block_in[95:64];
            data_store[index][3] <= mem_block_in[127:96];
        end
    end
endmodule