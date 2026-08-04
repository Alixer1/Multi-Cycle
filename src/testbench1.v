
`include "Definitions.v"

module Top_Processor_tb;

    // Inputs to the Processor
    reg clk;
    reg rst;
    
    // Memory Bus Connections
    wire mem_ready;
    wire [127:0] mem_block_in;
    wire [31:0] mem_data_in;
    wire [31:0] mem_addr;
    wire [31:0] mem_write_data;
    wire mem_global_read;
    wire mem_global_write;

    // Instantiate the Unit Under Test (UUT)
    Top_Processor uut (
        .clk(clk),
        .rst(rst),
        .mem_ready(mem_ready),
        .mem_block_in(mem_block_in),
        .mem_data_in(mem_data_in),
        .mem_addr(mem_addr),
        .mem_write_data(mem_write_data),
        .mem_global_read(mem_global_read),
        .mem_global_write(mem_global_write)
    );

    // tip 7: 2 seperate memory banks
    reg [31:0] instruction_memory [0:255]; // Isolated Instruction Bank
    reg [31:0] data_memory        [0:255]; // Isolated Data Bank
    
    // to simulate latency
    reg [1:0] memory_latency_counter;
    reg mem_ready_reg;

    always #10 clk = ~clk;

    // memory controller - 2-cycle response delay	basically it says if you wanna read from ram, it takes 2 cycles to assign mem_ready=1
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            memory_latency_counter <= 2'b00;
            mem_ready_reg <= 1'b0;
        end else begin
            if ((mem_global_read || mem_global_write) && !mem_ready_reg) begin
                if (memory_latency_counter == 2'd2) begin
                    mem_ready_reg <= 1'b1; // Memory operations take 2 clock cycles to become ready
                    memory_latency_counter <= 2'b00;
                end else begin
                    memory_latency_counter <= memory_latency_counter + 2'b01;
                end
            end else begin
                mem_ready_reg <= 1'b0;
                memory_latency_counter <= 2'b00;
            end
        end
    end

    assign mem_ready = mem_ready_reg;

    // mem address
    wire [29:0] word_idx = mem_addr[31:2];
    // block address for cache
    wire [29:0] block_base_idx = {mem_addr[31:4], 2'b00}; 

    assign mem_block_in = {
        instruction_memory[block_base_idx + 3],
        instruction_memory[block_base_idx + 2],
        instruction_memory[block_base_idx + 1],
        instruction_memory[block_base_idx]
    };
    
    assign mem_data_in = data_memory[word_idx];

    // Handle Write requests from SW instruction
    always @(posedge clk) begin
        if (mem_global_write && mem_ready) begin
            data_memory[word_idx] <= mem_write_data;
            $display("[MEM WRITE] Written Value 0x%h to Word Address %d", mem_write_data, word_idx);
        end
    end

    // Test Scenarios
    integer i;
    initial begin
        // Initialize Memory Arrays
        for (i = 0; i < 256; i = i + 1) begin
            instruction_memory[i] = 32'h00000000;
	    data_memory[i]        = 32'h00000000;
        end

	// -------------------------------------------------------------------------
	// TEST PROGRAM: Full 11-Instruction Scenario to clear University Rubric
	// -------------------------------------------------------------------------
	// Word 0: ADDI $1, $0, 10    -> Reg[1] = 10
	instruction_memory[0] = 32'h2001000A; 

	// Word 1: ADDI $2, $0, -5    -> Reg[2] = -5 
	instruction_memory[1] = 32'h2002FFFB; 

	// Word 2: ADD  $3, $1, $2    -> Reg[3] = 10 + (-5) = 5
	instruction_memory[2] = 32'h00221820; 

	// Word 3: SUB  $4, $1, $3    -> Reg[4] = 10 - 5 = 5
	instruction_memory[3] = 32'h00232022;

	// Word 4: AND  $5, $1, $3    -> Reg[5] = 10 & 5 = 0
	instruction_memory[4] = 32'h00232824;

	// Word 5: OR   $6, $1, $3    -> Reg[6] = 10 | 5 = 15
	instruction_memory[5] = 32'h00233025;

	// Word 6: SLT  $7, $2, $1    -> Reg[7] = (-5 < 10) ? 1 -> evaluates to 1
	instruction_memory[6] = 32'h0041382A;

	// Word 7: SW   $3, 100($0)   -> Store 5 at memory word index 25
	instruction_memory[7] = 32'hAC030064; 

	// Word 8: LW   $8, 100($0)   -> Read 5 from memory index 25 into Reg[8]
	instruction_memory[8] = 32'h8C080064; 

	// Word 9: BEQ  $3, $8, 1     -> Since Reg[3] == Reg[8], branch forward by 1 instruction (skips Word 10)
	instruction_memory[9] = 32'h10680001; 

	// Word 10: ADDI $9, $0, 99   -> SHOULD BE SKIPPED
	instruction_memory[10] = 32'h20090063; 

	// Word 11: J    0            -> Jump back to loop
	instruction_memory[11] = 32'h08000000;

        // System Startup
        clk = 0;
        rst = 1;
        #25;
        rst = 0; // Release Reset

        // Run simulation long enough to observe multiple loops and cache behaviors
        #1500;
        $display("Simulation finished. Check output traces.");
        $finish;
    end

    // Comprehensive Execution Monitor Output to console
    always @(posedge clk) begin
        if (!rst) begin
            $display("Time=%0t ns | PC=0x%h | IR=0x%h | State=%d | CacheHit=%b", 
                     $time, uut.PC, uut.IR, uut.controller.current_state, uut.cache_hit);
            
            // Track key internal state updates 
            if (uut.controller.current_state == 5'd4) begin // Assuming ST_ALU_WB equivalent code status
                $display(" >>> [REG WRITEBACK] Target Register changed to value: 0x%h", uut.reg_write_data);
            end
        end
    end

// Temporary Handshake Debug Monitor
always @(posedge clk) begin
    if (!rst && uut.controller.current_state == 5'd15) begin
        $display("[DIAGNOSTIC] Stuck in State 15! | CPU Read Strobe=%b | TB Counter=%d | TB MemReady=%b", 
                 mem_global_read, memory_latency_counter, mem_ready);
    end
end

// Specialized LW Instruction Debug Monitor
always @(posedge clk) begin
    if (!rst && uut.IR == 32'h8C040064) begin // Triggers only when IR holds LW $4, 100($0)
        $display("[LW DEEP DEBUG] Time=%0t ns | State=%d | BusAddr=%d (Word Index=%d) | ReadStrobe=%b | MemReady=%b | Testbench_mem_data_in=0x%h", 
                 $time, uut.controller.current_state, mem_addr, word_idx, mem_global_read, mem_ready, mem_data_in);
    end
end

endmodule
