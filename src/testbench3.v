module testbench3;
    reg clk;
    reg rst;
    reg start;
    reg simd_op;
    reg [127:0] vec_a;
    reg [127:0] vec_b;
    wire [127:0] vec_out;
    wire done;

    SIMD_Unit uut (
        .clk(clk), .rst(rst), .start(start), .simd_op(simd_op),
        .vec_a(vec_a), .vec_b(vec_b), .vec_out(vec_out), .done(done)
    );

    always #5 clk = ~clk;

    // Real-time internal trace for SIMD status monitoring
    always @(posedge clk) begin
        if (!rst && (start || !done)) begin
            $display("[SIMD MONITOR] Time=%0t ns | Start=%b | Done=%b | Out={%d, %d, %d, %d}", 
                     $time, start, done, $signed(vec_out[127:96]), $signed(vec_out[95:64]), $signed(vec_out[63:32]), $signed(vec_out[31:0]));
        end
    end

    initial begin
        clk = 0; rst = 1; start = 0; simd_op = 0; vec_a = 0; vec_b = 0;
        #15 rst = 0;

        // Scenario 1: VADD
        #10; @(posedge clk);
        vec_a = {32'd4, 32'd3, 32'd2, 32'd1};
        vec_b = {32'd8, 32'd7, 32'd6, 32'd5};
        simd_op = 1'b0;
        start = 1;
        @(posedge clk); #1 start = 0; 

        while (!done) @(posedge clk); #2;
        $display("[RESULT SIMD 1] VADD: {%d, %d, %d, %d}", 
                 $signed(vec_out[127:96]), $signed(vec_out[95:64]), $signed(vec_out[63:32]), $signed(vec_out[31:0]));

        // Scenario 2: VMUL
        #10; @(posedge clk);
        vec_a = {32'd4, 32'd3, 32'd2, 32'd1};
        vec_b = {32'd2, 32'd2, 32'd2, 32'd2};
        simd_op = 1'b1;
        start = 1;
        @(posedge clk); #1 start = 0;

        while (!done) @(posedge clk); #2;
        $display("[RESULT SIMD 2] VMUL: {%d, %d, %d, %d}", 
                 $signed(vec_out[127:96]), $signed(vec_out[95:64]), $signed(vec_out[63:32]), $signed(vec_out[31:0]));

        // Scenario 3: Signed VADD
        #10; @(posedge clk);
        vec_a = {32'd10, -32'd5, 32'd0, -32'd1};
        vec_b = {-32'd2, 32'd5, 32'd10, -32'd9};
        simd_op = 1'b0;
        start = 1;
        @(posedge clk); #1 start = 0;

        while (!done) @(posedge clk); #2;
        $display("[RESULT SIMD 3] Signed VADD: {%d, %d, %d, %d}", 
                 $signed(vec_out[127:96]), $signed(vec_out[95:64]), $signed(vec_out[63:32]), $signed(vec_out[31:0]));

        // Scenario 4: Signed VMUL
        #10; @(posedge clk);
        vec_a = {32'd100, -32'd4, 32'd5, 32'd0};
        vec_b = {32'd0, -32'd2, 32'd3, 32'd99};
        simd_op = 1'b1;
        start = 1;
        @(posedge clk); #1 start = 0;

        while (!done) @(posedge clk); #2;
        $display("[RESULT SIMD 4] Signed VMUL: {%d, %d, %d, %d}", 
                 $signed(vec_out[127:96]), $signed(vec_out[95:64]), $signed(vec_out[63:32]), $signed(vec_out[31:0]));

        // Scenario 5: Boundary VADD
        #10; @(posedge clk);
        vec_a = {32'd5000, 32'd0, 32'd0, 32'd12345};
        vec_b = {32'd5000, 32'd0, 32'd0, 32'd54321};
        simd_op = 1'b0;
        start = 1;
        @(posedge clk); #1 start = 0;

        while (!done) @(posedge clk); #2;
        $display("[RESULT SIMD 5] Boundary VADD: {%d, %d, %d, %d}", 
                 $signed(vec_out[127:96]), $signed(vec_out[95:64]), $signed(vec_out[63:32]), $signed(vec_out[31:0]));

        #100; $finish;
    end
endmodule
