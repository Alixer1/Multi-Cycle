`include "Definitions.v"

module Top_Processor (
    input wire clk,
    input wire rst,
    
	// data buses to talk to memory(handle in test bench)
    input wire mem_ready,		// done fetch block from memory element
    input wire [127:0] mem_block_in,	// input (rom) 4 words(for cache)
    input wire [31:0] mem_data_in,	// actuall data read from memory(like lw)
    output wire [31:0] mem_addr,	// Tells the external memory where we want to read or write
    output wire [31:0] mem_write_data,	// the data we wanna write, obviously. 
    output wire mem_global_read,
    output wire mem_global_write	// tells memory whether we wanna perform read or write
);

    reg [31:0] PC;
    wire [31:0] instr;
    reg [31:0] IR;	// instruction register(IF)
    reg [31:0] MDR;	// mem/wb register

    wire [5:0] opcode = IR[31:26];
    wire [4:0] rs = IR[25:21];
    wire [4:0] rt = IR[20:16];
    wire [4:0] rd = IR[15:11];
    wire [5:0] funct = IR[5:0];
    wire [15:0] imm = IR[15:0];			// could be invalid tho, but still

    // control wires
    wire pc_write, i_or_d, mem_read, mem_write, ir_write, reg_write, pc_write_cond;		// write an address in pc   -  pc_write => active when condition instruction(beq)
	// i/d: 0: address goes from pc(fetch) 1: address goes from alu(lw/sw)  -  ir/w => write in instruction register  -  reg_write => write in registers bank
    wire[1:0] pc_source; // pc_src => 00:pc+4. 01: branch. 10: jump


    wire [1:0] reg_dst, alu_srcA, alu_srcB;	// 00: rt , 01: rd  -  00: pc , 01: rs  -  00: rt , 01: 4 , 10: immediate , 11: jump offset
    wire [2:0] alu_control;


    wire fpu_start, fpu_reg_write, simd_start, simd_reg_write, cache_hit, cache_stall;
    wire fpu_done;
    wire simd_done;
    wire [31:0] rf_data1, rf_data2;


    // registers and internal buffers
    reg [31:0] RegA, RegB;		// temporary registers holding data because it gets owerwritten
    wire [31:0] alu_result;
    reg [31:0] ALUOut;
    wire alu_zero;

    // memory logic
    assign mem_addr = i_or_d ? ALUOut : PC;
    assign mem_write_data = RegB;
    assign mem_global_read = mem_read;
    assign mem_global_write = mem_write;

    // 1. Instruction Cache Unit
    L1_I_Cache instruction_cache (
        .clk(clk), .rst(rst), .addr(PC), .mem_ready(mem_ready && cache_stall),	// Only pass mem_ready to cache if the controller is actively stalling for an I-Cache miss
        .mem_block_in(mem_block_in), .instruction(instr),
        .cache_hit(cache_hit), .cache_miss_req()		// todo: cache_miss_req=> dangling output. it's ok, it's just ~cashe_hit
    );

    always @(posedge clk or posedge rst) begin		// ID and mem/wb registers values update here. 
        if (rst) begin
            IR  <= 32'h0;
            MDR <= 32'h0;
        end else begin
            if (ir_write && cache_hit) 
                IR <= instr;
            if (mem_read && i_or_d)    
                MDR <= mem_data_in; // store address red from memmory to mem/wb reg(for lw)
        end
    end

    // 2. Main Control Unit
    Control_Unit controller (
        .clk(clk), .rst(rst), .opcode(opcode), .funct(funct), .cache_hit(cache_hit),
        .fpu_done(fpu_done), .simd_done(simd_done), .mem_ready(mem_ready), .pc_write(pc_write), .pc_source(pc_source),
        .i_or_d(i_or_d), .mem_read(mem_read), .mem_write(mem_write), .ir_write(ir_write),
        .reg_dst(reg_dst), .reg_write(reg_write), .alu_srcA(alu_srcA), .alu_srcB(alu_srcB),
        .alu_control(alu_control), .fpu_start(fpu_start), .fpu_reg_write(fpu_reg_write),
        .simd_start(simd_start), .simd_reg_write(simd_reg_write), .cache_stall(cache_stall), .pc_write_cond(pc_write_cond)
    );

    // 3. Integer Execution Path
    wire [4:0] write_reg_target = (reg_dst == 2'b01) ? rd : rt;
    reg [31:0] reg_write_data;

    always @(*) begin
        if (opcode == `OP_LW) // lw => register data comes from memory register. else(add) comes from alu
            reg_write_data = MDR;	// read data we wanna write in register bank from mem/Wb register
        else 
            reg_write_data = ALUOut;	// add e.g.
    end


    RegisterFile_Int int_reg_file (
        .clk(clk), .reg_write(reg_write), .read_reg1(rs), .read_reg2(rt),
        .write_reg(write_reg_target), .write_data(reg_write_data),
        .read_data1(rf_data1), .read_data2(rf_data2)
    );

    always @(posedge clk) begin		// if we don't store them they will be owerwitten!	ID/EX register equivalent
        RegA <= rf_data1;
        RegB <= rf_data2;
        // Only update ALUOut if we are NOT waiting on a memory read/write operation
        if (!((mem_read || mem_write) && !mem_ready)) begin
            ALUOut <= alu_result;
        end
    end

    reg [31:0] alu_muxA, alu_muxB;
    always @(*) begin
        case (alu_srcA)		// choose alu src_a based on alu_srca control signal received from control unit
            2'b00: alu_muxA = PC;	// for example at counting pc+offset
            2'b01: alu_muxA = RegA;	// for example at add
            default: alu_muxA = PC;
        endcase

        case (alu_srcB)		// choose alu src_b based on alu_srcb control signal received from control unit
            2'b00: alu_muxB = RegB;	// e.g. add
            2'b01: alu_muxB = 32'd4;	// for example at pc+4 computation
            2'b10: alu_muxB = {{16{imm[15]}}, imm};                 // sign extend for LW, SW, ADDI
	    2'b11: alu_muxB = {{14{imm[15]}}, imm, 2'b00};          // For BEQ (Shifted Left by 2)
	    default: alu_muxB = RegB;
        endcase
    end

    ALU_Int main_integer_alu (		// feed chosen inputs(by muxes) to alu and receive output. 
        .a(alu_muxA), .b(alu_muxB), .alu_control(alu_control),
        .result(alu_result), .zero(alu_zero)
    );

	// find next pc address(do we branch?)
    wire pc_cond_write = alu_zero? pc_write_cond : 0;   // if branch instruction validated

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            PC <= 32'h00000000;		// move back to the start of program
        end else if (pc_write || pc_cond_write) begin		// if pc_write! it is only assigned to 1 when we actually finish an instruction! handled in cotrol unit
            case (pc_source)
                2'b00: PC <= alu_result;                   // (PC + 4)
                2'b01: PC <= ALUOut;                       // BEQ
                2'b10: PC <= {PC[31:28], IR[25:0], 2'b00}; // Jump
                default: PC <= alu_result;	// branch address in aluOut reg because alu result is tampered with when we validate if branch holds.
            endcase
        end
    end




    // 4. Floating Point Path Connection
    wire [31:0] fpu_rf_out1, fpu_rf_out2, fpu_final_result;
    wire fpu_ovf, fpu_unf;

    wire [1:0] fpu_op_mapped = (funct == `FUNCT_FADD) ? 2'b01 :
                               (funct == `FUNCT_FSUB) ? 2'b10 :
                               (funct == `FUNCT_FMUL) ? 2'b11 : 2'b00;

    RegisterFile_Float fpu_reg_file (
        .clk(clk), .reg_write(fpu_reg_write), .read_reg1(rs), .read_reg2(rt),
        .write_reg(rd), .write_data(fpu_final_result),
        .read_data1(fpu_rf_out1), .read_data2(fpu_rf_out2)
    );

    FPU floating_point_unit (
        .clk(clk), .rst(rst), .start(fpu_start), .fpu_op(fpu_op_mapped),
        .operand_a(fpu_rf_out1), .operand_b(fpu_rf_out2),
        .result(fpu_final_result), .done(fpu_done),
        .overflow(fpu_ovf), .underflow(fpu_unf)
    );

    // 5. SIMD Vector Execution Path Connection
    wire [127:0] vec_rf_out1, vec_rf_out2, vec_final_result;
    RegisterFile_Vector simd_reg_file (
        .clk(clk), .reg_write(simd_reg_write), .read_reg1(rs[3:0]), .read_reg2(rt[3:0]),
        .write_reg(rd[3:0]), .write_data(vec_final_result),
        .read_data1(vec_rf_out1), .read_data2(vec_rf_out2)
    );

    SIMD_Unit SIMD_Vector_Processing_Unit (
        .clk(clk), .rst(rst), .start(simd_start), .simd_op(funct[1]), // FIXED: Use bit 1 instead of bit 0
        .vec_a(vec_rf_out1), .vec_b(vec_rf_out2),
        .vec_out(vec_final_result), .done(simd_done)
    );

endmodule
