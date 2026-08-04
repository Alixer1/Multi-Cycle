`include "Definitions.v"

module FPU (
    input wire clk,
    input wire rst,
    input wire start,
    input wire [1:0] fpu_op, 
    input wire [31:0] operand_a,
    input wire [31:0] operand_b,
    output reg [31:0] result,
    output reg done,          
    output reg overflow,
    output reg underflow
);
    reg [3:0] cycle_count;
    reg busy; 

    // Detect rising edge of start signal to resolve Ghost Execution bug
    reg start_d1;
    always @(posedge clk or posedge rst) begin
        if (rst) start_d1 <= 1'b0;
        else     start_d1 <= start;
    end
    wire start_edge = start && !start_d1;

    // Extract floating-point components based on IEEE 754 standard
    wire sign_a = operand_a[31];
    wire [7:0] exp_a = operand_a[30:23];
    wire [23:0] mant_a = (exp_a == 8'b0) ? {1'b0, operand_a[22:0]} : {1'b1, operand_a[22:0]};

    wire sign_b = operand_b[31];
    wire [7:0] exp_b = operand_b[30:23];
    wire [23:0] mant_b = (exp_b == 8'b0) ? {1'b0, operand_b[22:0]} : {1'b1, operand_b[22:0]};

    // Internal registers for calculations
    reg sign_res;
    reg [7:0] exp_res;  
    reg [24:0] mant_sum; 
    reg [23:0] mant_final;
    reg [47:0] mant_mul;
    reg [23:0] shifted_mant;

    // Early overflow check for multiplication (10-bit to prevent bit overflow)
    wire [9:0] check_fmul_exp = {2'b00, exp_a} + {2'b00, exp_b};
    wire fmul_early_overflow = (fpu_op == 2'b11 && (check_fmul_exp > 10'd381 || exp_a == 8'hFF || exp_b == 8'hFF));

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            cycle_count <= 4'd0;
            busy        <= 1'b0;
            done        <= 1'b0;
            result      <= 32'h0;
            overflow    <= 1'b0;
            underflow   <= 1'b0;
        end else begin
            if (start_edge && !busy) begin
                busy        <= 1'b1;
                cycle_count <= 4'd0;
                done        <= 1'b0;
                overflow    <= 1'b0;
                underflow   <= 1'b0;
            end else if (busy) begin
                
                // Smart cycle counter management to fix add/sub normalization bug
                if ((fpu_op == 2'b01 || fpu_op == 2'b10) && cycle_count == 4'd3 && mant_final[23] == 1'b0 && exp_res > 0) begin
                    cycle_count <= 4'd3; 
                end else begin
                    cycle_count <= cycle_count + 1;
                end
                
                case (fpu_op)
                    // ---------------- FMOV (Data Transfer) ----------------
                    2'b00: begin 
                        if (cycle_count == 4'd0) begin
                            result <= operand_a;
                        end
                        else if (cycle_count == 4'd1) begin
                            done   <= 1'b1;
                            busy   <= 1'b0; 
                        end
                    end

                    // ---------------- FADD / FSUB (Addition / Subtraction) ----------------
                    2'b01, 2'b10: begin 
                        if (cycle_count == 4'd0) begin
                            if (exp_a >= exp_b) begin
                                exp_res      <= exp_a;
                                shifted_mant <= mant_b >> (exp_a - exp_b);
                                mant_final   <= mant_a;
                            end else begin
                                exp_res      <= exp_b;
                                shifted_mant <= mant_a >> (exp_b - exp_a);
                                mant_final   <= mant_b;
                            end
                        end
                        else if (cycle_count == 4'd1) begin
                            if ((fpu_op == 2'b01 && (sign_a ^ sign_b == 1'b0)) || 
                                (fpu_op == 2'b10 && (sign_a ^ sign_b == 1'b1))) begin
                                mant_sum <= mant_final + shifted_mant;
                                sign_res <= (exp_a >= exp_b) ? sign_a : (fpu_op == 2'b01 ? sign_b : ~sign_b);
                            end else begin
                                if (exp_a > exp_b || (exp_a == exp_b && mant_a >= mant_b)) begin
                                    mant_sum <= mant_final - shifted_mant;
                                    sign_res <= sign_a;
                                end else begin
                                    mant_sum <= shifted_mant - mant_final;
                                    sign_res <= (fpu_op == 2'b01) ? sign_b : ~sign_b;
                                end
                            end
                        end
                        else if (cycle_count == 4'd2) begin
                            if (mant_sum[24]) begin 
                                mant_final <= mant_sum[24:1];
                                exp_res    <= exp_res + 1;
                            end else begin
                                mant_final <= mant_sum[23:0];
                            end
                        end
                        else if (cycle_count == 4'd3) begin
                            if (mant_final[23] == 1'b0 && exp_res > 0) begin
                                mant_final <= mant_final << 1;
                                exp_res    <= exp_res - 1;
                            end
                        end
                        else if (cycle_count == 4'd4) begin
                            if (exp_res >= 8'hFF) begin
                                overflow <= 1'b1;
                                result   <= {sign_res, 8'hFF, 23'h0}; 
                            end else if (exp_res == 8'b0 || mant_final == 24'b0) begin
                                underflow <= 1'b1;
                                result    <= {sign_res, 32'h0};       
                            end else begin
                                result <= {sign_res, exp_res, mant_final[22:0]};
                            end
                        end
                        else if (cycle_count == 4'd5) begin
                            done <= 1'b1;
                            busy <= 1'b0;
                        end
                    end

                    // ---------------- FMUL (Floating-Point Multiplication) ----------------
                    2'b11: begin 
                        // Step 0: Fix bit overflow bug using 10-bit check_fmul_exp
                        if (cycle_count == 4'd0) begin
                            sign_res <= sign_a ^ sign_b;
                            if (operand_a[30:0] == 31'b0 || operand_b[30:0] == 31'b0) begin
                                exp_res <= 8'b0;
                            end else begin
                                if (check_fmul_exp < 10'd127) begin
                                    exp_res <= 8'b0; 
                                end else begin
                                    exp_res <= check_fmul_exp - 10'd127;
                                end
                            end
                        end
                        // Step 1: Perform multiplication on mantissas
                        else if (cycle_count == 4'd1) begin
                            if (operand_a[30:0] == 31'b0 || operand_b[30:0] == 31'b0) begin
                                mant_mul <= 48'b0;
                            end else begin
                                mant_mul <= mant_a * mant_b;
                            end
                        end
                        // Step 2: Normalize the mantissa product
                        else if (cycle_count == 4'd2) begin
                            if (operand_a[30:0] == 31'b0 || operand_b[30:0] == 31'b0) begin
                                mant_final <= 24'b0;
                            end else begin
                                if (mant_mul[47]) begin
                                    mant_final <= mant_mul[47:24];
                                    exp_res    <= exp_res + 1;
                                end else begin
                                    mant_final <= mant_mul[46:23];
                                end
                            end
                        end
                        // Step 3: Final check for exceptions with corrected exponent subtraction condition
                        else if (cycle_count == 4'd3) begin
                            if (operand_a[30:0] == 31'b0 || operand_b[30:0] == 31'b0) begin
                                overflow  <= 1'b0;
                                underflow <= 1'b0;
                                result    <= {sign_res, 31'b0}; 
                            end else begin
                                if (fmul_early_overflow || exp_res >= 8'hFF) begin
                                    overflow <= 1'b1;
                                    result   <= {sign_res, 8'hFF, 23'h0};
                                end else if (exp_res == 8'b0 || (check_fmul_exp < 10'd127)) begin
                                    underflow <= 1'b1;
                                    result    <= {sign_res, 23'h0};
                                end else begin
                                    result <= {sign_res, exp_res, mant_final[22:0]};
                                end
                            end
                        end
                        else if (cycle_count == 4'd4) begin
                            done <= 1'b1;
                            busy <= 1'b0;
                        end
                    end
                endcase
            end else begin
                done <= 1'b0; 
            end
        end
    end

    // Internal monitoring section for accurate simulation tracking
    always @(posedge clk) begin
        if (!rst && (busy || start || done)) begin
            $display("[FPU INTERNAL] Time=%0t ns | Op=%b | Start=%b | Busy=%b | Cycle=%d | Done=%b | Result=0x%h", 
                     $time, fpu_op, start, busy, cycle_count, done, result);
        end
    end
endmodule
