module SIMD_Unit (
    input wire clk,
    input wire rst,
    input wire start,
    input wire simd_op, // 0: VADD, 1: VMUL
    input wire [127:0] vec_a,
    input wire [127:0] vec_b,
    output reg [127:0] vec_out,
    output wire done
);
    reg step;
    reg done_reg; // Internal register added for precise control of the done signal
    
    assign done = done_reg;
    
    // Extracting 32-bit signed integers
    wire signed [31:0] a0 = vec_a[31:0],   b0 = vec_b[31:0];
    wire signed [31:0] a1 = vec_a[63:32],  b1 = vec_b[63:32];
    wire signed [31:0] a2 = vec_a[95:64],  b2 = vec_b[95:64];
    wire signed [31:0] a3 = vec_a[127:96], b3 = vec_b[127:96];

    // Muxing inputs for the 2 shared ALUs based on the current step
    wire signed [31:0] alu1_inA = (step == 0) ? a0 : a2;
    wire signed [31:0] alu1_inB = (step == 0) ? b0 : b2;
    wire signed [31:0] alu2_inA = (step == 0) ? a1 : a3;
    wire signed [31:0] alu2_inB = (step == 0) ? b1 : b3;
    
    // ALU operations
    wire signed [31:0] alu1_out = (simd_op == 1'b0) ? (alu1_inA + alu1_inB) : (alu1_inA * alu1_inB);
    wire signed [31:0] alu2_out = (simd_op == 1'b0) ? (alu2_inA + alu2_inB) : (alu2_inA * alu2_inB);

    // Corrected sequential logic (Always Block)
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            step <= 0;
            vec_out <= 128'b0;
            done_reg <= 1'b0;
        end else begin
            if (step == 1) begin
                // Second processing cycle: Store upper channel data (E2 and E3)
                vec_out[95:64]  <= alu1_out;
                vec_out[127:96] <= alu2_out;
                step <= 0;         // Prepare for the next instruction
                done_reg <= 1'b1;  // Assert end of vector operation
            end else if (start) begin
                // First processing cycle: Store lower channel data (E0 and E1)
                vec_out[31:0]  <= alu1_out;
                vec_out[63:32] <= alu2_out;
                step <= 1;         // Move to the next step
                done_reg <= 1'b0;  // Operation not yet complete
            end else begin
                done_reg <= 1'b0;  // In Idle state, done signal remains zero
            end
        end
    end
endmodule
