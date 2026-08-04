module testbench2;
    reg clk;
    reg rst;
    reg start;
    reg [1:0] fpu_op;
    reg [31:0] operand_a;
    reg [31:0] operand_b;

    wire [31:0] result;
    wire done;
    wire overflow;
    wire underflow;

    integer i;

    FPU uut (
        .clk(clk), 
        .rst(rst), 
        .start(start), 
        .fpu_op(fpu_op),
        .operand_a(operand_a), 
        .operand_b(operand_b),
        .result(result), 
        .done(done), 
        .overflow(overflow), 
        .underflow(underflow)
    );

    always #5 clk = ~clk;

    initial begin
        clk = 0;
        rst = 1;
        start = 0;
        fpu_op = 2'b00;
        operand_a = 32'h0;
        operand_b = 32'h0;

        #30;
        rst = 0;
        #10;

        // TEST 1: FMOV
        @(posedge clk); #1;
        operand_a = 32'h40A00000; 
        operand_b = 32'h00000000;
        fpu_op = 2'b00;
        start = 1; 
        
        @(posedge clk); #1;
        start = 0; 

        i = 0;
        while (!done && i < 20) begin
            @(posedge clk);
            i = i + 1;
        end
       
        $display("[TEST 1 - FMOV] Result: 0x%h | Done: %b", result, done);
        #2;
        // TEST 2: FADD
        @(posedge clk); #1;
        operand_a = 32'h40200000; 
        operand_b = 32'h40200000; 
        fpu_op = 2'b01;
        start = 1;
        
        @(posedge clk); #1;
        start = 0;

        i = 0;
        while (!done && i < 20) begin
            @(posedge clk);
            i = i + 1;
        end
        
        $display("[TEST 2 - FADD] Result: 0x%h | Done: %b", result, done);
        #2;

        // TEST 3: FSUB
        @(posedge clk); #1;
        operand_a = 32'h40A00000; 
        operand_b = 32'h40200000; 
        fpu_op = 2'b10;
        start = 1;
        
        @(posedge clk); #1;
        start = 0;

        i = 0;
        while (!done && i < 20) begin
            @(posedge clk);
            i = i + 1;
        end
        
        $display("[TEST 3 - FSUB] Result: 0x%h | Done: %b", result, done);
        #2;
        // TEST 4: FMUL
        @(posedge clk); #1;
        operand_a = 32'h40000000; 
        operand_b = 32'h40400000; 
        fpu_op = 2'b11;
        start = 1;
        
        @(posedge clk); #1;
        start = 0;

        i = 0;
        while (!done && i < 20) begin
            @(posedge clk);
            i = i + 1;
        end
        
        $display("[TEST 4 - FMUL] Result: 0x%h | Done: %b", result, done);
        #2;
        // TEST 5: OVERFLOW
        @(posedge clk); #1;
        operand_a = 32'h7F7FFFFF; 
        operand_b = 32'h42000000; 
        fpu_op = 2'b11;
        start = 1;
        
        @(posedge clk); #1;
        start = 0;

        i = 0;
        while (!done && i < 20) begin
            @(posedge clk);
            i = i + 1;
        end
        
        $display("[TEST 5 - OVERFLOW] OVF Flag: %b | Done: %b", overflow, done);
        #2;
        #200;
        $finish;
    end
endmodule
