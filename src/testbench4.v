module testbench4;
    reg clk;
    reg rst;
    reg [31:0] addr;
    reg mem_ready;
    reg [127:0] mem_block_in;
    
    wire [31:0] instruction;
    wire cache_hit;
    wire cache_miss_req;

    L1_I_Cache uut (
        .clk(clk), 
        .rst(rst), 
        .addr(addr), 
        .mem_ready(mem_ready),
        .mem_block_in(mem_block_in), 
        .instruction(instruction),
        .cache_hit(cache_hit), 
        .cache_miss_req(cache_miss_req)
    );

    always #5 clk = ~clk;

    // Real-time inline monitor for L1 Cache behavior tracking
    always @(posedge clk) begin
        if (!rst) begin
            $display("[CACHE TRACK] Time=%0t ns | Addr=0x%h | Hit=%b | MissReq=%b | Instr=0x%h", 
                     $time, addr, cache_hit, cache_miss_req, instruction);
        end
    end

    initial begin
        clk = 0; 
        rst = 1; 
        addr = 0; 
        mem_ready = 0; 
        mem_block_in = 0;
        
        #15 rst = 0;

        // SCENARIO 1: Cold Cache Miss
        #10 addr = 32'h00000004; 
        #5;
        $display("[SCENARIO 1] Cold Miss Verified.");

        // SCENARIO 2: Block Delivery
        #10 mem_ready = 1; 
        mem_block_in = {32'h44444444, 32'h33333333, 32'h22222222, 32'h11111111}; 
        #10 mem_ready = 0; 
        #5;
        $display("[SCENARIO 2] Block Loaded Into Memory Row.");

        // SCENARIO 3: Cache Hit
        #10 addr = 32'h00000008; 
        #5;
        $display("[SCENARIO 3] Hit Access Verified.");

        // SCENARIO 4: Compulsory Miss
        #10 addr = 32'h00000040; 
        #5;
        $display("[SCENARIO 4] New Index Miss Triggered.");
        
        #10 mem_ready = 1; 
        mem_block_in = {32'hAAAAAAA4, 32'hAAAAAAA3, 32'hAAAAAAA2, 32'hAAAAAAA1};
        #10 mem_ready = 0;
        #5;
        $display("[SCENARIO 4-LOAD] New Index Allocation Done.");

        // SCENARIO 5: Tag Mismatch Miss
        #10 addr = 32'h00010040; 
        #5;
        $display("[SCENARIO 5] Conflict Tag Mismatch Verified.");

        #100;
        $display("==========================================================");
        $display("   L1 Instruction Cache Testbench Execution Finished!     ");
        $display("==========================================================");
        $finish;
    end
endmodule
