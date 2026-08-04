// Definitions.v
`define WORD_SIZE 32

// Opcodes (6-bit)
`define OP_RTYPE   6'b000000
`define OP_ADDI    6'b001000
`define OP_LW      6'b100011
`define OP_SW      6'b101011
`define OP_BEQ     6'b000100
`define OP_J       6'b000010
`define OP_FPU     6'b110001  
`define OP_SIMD    6'b110010

// Funct Codes for R-Type (6-bit)
`define FUNCT_ADD  6'b100000
`define FUNCT_SUB  6'b100010
`define FUNCT_AND  6'b100100
`define FUNCT_OR   6'b100101
`define FUNCT_SLT  6'b101010

// Funct Codes for FPU (6-bit)
`define FUNCT_FADD 6'b000001
`define FUNCT_FSUB 6'b000010
`define FUNCT_FMUL 6'b000011
`define FUNCT_FMOV 6'b000100

// Funct Codes for SIMD (6-bit)
`define FUNCT_VADD 6'b001001
`define FUNCT_VMUL 6'b001010

// State Encodings using Macros for classic Verilog compatibility
`define ST_FETCH      5'd0
`define ST_DECODE     5'd1
`define ST_MEM_ADR    5'd2
`define ST_MEM_RD     5'd3
`define ST_MEM_WB     5'd4
`define ST_MEM_WR     5'd5
`define ST_EXEC_R     5'd6
`define ST_ALU_WB     5'd7
`define ST_BEQ_EX     5'd8
`define ST_J_EX       5'd9
`define ST_FPU_EXEC   5'd10
`define ST_FPU_WB     5'd11
`define ST_SIMD_EX1   5'd12
`define ST_SIMD_WB    5'd14
`define ST_CACHE_MISS 5'd15
