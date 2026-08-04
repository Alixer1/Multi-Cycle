
`include "Definitions.v"

module Control_Unit (
    input wire clk,
    input wire rst,
    input wire [5:0] opcode,
    input wire [5:0] funct,
    input wire cache_hit,
    input wire fpu_done,
    input wire simd_done,
    input wire mem_ready,
    
    output reg pc_write,
    output reg[1:0] pc_source,
    output reg i_or_d,
    output reg mem_read,
    output reg mem_write,
    output reg ir_write,
    output reg [1:0] reg_dst,
    output reg reg_write,
    output reg [1:0] alu_srcA,
    output reg [1:0] alu_srcB,
    output reg [2:0] alu_control,
    
    output reg fpu_start,
    output reg fpu_reg_write,
    output reg simd_start,
    output reg simd_reg_write,
    output reg cache_stall, 
    output reg pc_write_cond
);

    reg [4:0] current_state, next_state;

    always @(posedge clk or posedge rst) begin
        if (rst) current_state <= `ST_FETCH;		// fetch an instruction
        else current_state <= next_state;
    end

    always @(*) begin		// find machine's next state(available in fsm diagram) 
				// we make a transition at each clock cycle(now depending on the instruction, it may take 4 cycles to go back to ST_FETCH on one instruction, it may take 6 for another)
        case (current_state)
            `ST_FETCH: begin
                if (cache_hit) next_state = `ST_DECODE;		// is instruction in cache?
                else next_state = `ST_CACHE_MISS;
            end
            
            `ST_CACHE_MISS: begin
                if (mem_ready) next_state = `ST_FETCH;		// has instruction been brought in cache yet?
    		else next_state = `ST_CACHE_MISS;		// still not
            end
            
            `ST_DECODE: begin	// check opcode
                case (opcode)
                    `OP_RTYPE: next_state = `ST_EXEC_R;
                    `OP_ADDI: next_state = `ST_EXEC_R; 	// r-type =>next state=execute r-type
                    `OP_LW: next_state = `ST_MEM_ADR; 
                    `OP_SW: next_state = `ST_MEM_ADR; 	// lw/sw => next staet=mem_adr
                    `OP_BEQ: next_state = `ST_BEQ_EX;		// branch
                    `OP_J: next_state = `ST_J_EX;		// jump
                    `OP_FPU: next_state = `ST_FPU_EXEC; 	// floating point
                    `OP_SIMD: next_state = `ST_SIMD_EX1; 	// vector
                    default:   next_state = `ST_FETCH;
                endcase
            end

            `ST_EXEC_R: next_state = `ST_ALU_WB;
            `ST_ALU_WB: next_state = `ST_FETCH;
            
            `ST_MEM_ADR: begin
                if (opcode == `OP_LW) next_state = `ST_MEM_RD;
                else next_state = `ST_MEM_WR;
            end
            
            `ST_MEM_RD: begin
    		if (mem_ready) next_state = `ST_MEM_WB;	// wait until data is ready(retreived from memory)
    		else next_state = `ST_MEM_RD;
	    end

	    `ST_MEM_WR: begin
    		if (mem_ready) next_state = `ST_FETCH;	// wait until data is ready(saved to memory)
    		else next_state = `ST_MEM_WR;
	    end

            `ST_BEQ_EX: next_state = `ST_FETCH;
            `ST_J_EX:   next_state = `ST_FETCH;

            `ST_FPU_EXEC: begin
                if (fpu_done) next_state = `ST_FPU_WB;
                else next_state = `ST_FPU_EXEC;
            end
            `ST_FPU_WB: next_state = `ST_FETCH;

            `ST_SIMD_EX1: next_state = simd_done ? `ST_SIMD_WB : `ST_SIMD_EX1;
            `ST_SIMD_WB: next_state = `ST_FETCH;

            default: next_state = `ST_FETCH;
        endcase
    end

    always @(*) begin		// tune flags based on state with clock pulse
        pc_write = 0; pc_source = 2'b00; i_or_d = 0; mem_read = 0; mem_write = 0;
        ir_write = 0; reg_dst = 0; reg_write = 0; alu_srcA = 0; alu_srcB = 0;
        alu_control = 3'b000; fpu_start = 0; fpu_reg_write = 0;
        simd_start = 0; simd_reg_write = 0; cache_stall = 0; pc_write_cond = 0;		// initial values

        case (current_state)
            `ST_FETCH: begin
                mem_read = 1;
                ir_write = 1;
                alu_srcA = 2'b00; 
                alu_srcB = 2'b01; 
                alu_control = 3'b000; 
                pc_source = 2'b00;
                pc_write = cache_hit; 
            end

            `ST_CACHE_MISS: begin
                cache_stall = 1;
		mem_read = 1;   // read from main memory
		i_or_d = 0;     // Ensure address source is PC, not ALUOut
            end

            `ST_DECODE: begin
                alu_srcA = 2'b00;
                alu_srcB = 2'b11; // During this cycle, the processor reads the values from integer register file alu is idle, so we calculate branch target here assuming 
					// it's going to be a branch instruction this calculated address is safely captured and stored inside the ALUOut register.
 					// however, if it wasn't in fact a branch instruction, well what we computed is simply ignored. win win
                alu_control = 3'b000;
            end

            `ST_EXEC_R: begin
                alu_srcA = 2'b01; 
                alu_srcB = 2'b00; 
                if (opcode == `OP_ADDI) begin
                    alu_srcB = 2'b10; 
                    alu_control = 3'b000;
                end else begin
                    case (funct)
                        `FUNCT_ADD: alu_control = 3'b000; 
                        `FUNCT_SUB: alu_control = 3'b001; 
                        `FUNCT_AND: alu_control = 3'b010; 
                        `FUNCT_OR: alu_control = 3'b011; 
                        `FUNCT_SLT: alu_control = 3'b100; 
                    endcase
                end
            end

            `ST_ALU_WB: begin
                reg_dst = (opcode == `OP_ADDI) ? 2'b00 : 2'b01; 
                reg_write = 1;
            end

            `ST_MEM_ADR: begin
                alu_srcA = 2'b01;
                alu_srcB = 2'b10; 
                alu_control = 3'b000; 
            end

            `ST_MEM_RD: begin
                i_or_d = 1;
                mem_read = 1;
            end

            `ST_MEM_WB: begin
                reg_dst = 2'b00; 
                reg_write = 1;
            end

            `ST_MEM_WR: begin
                i_or_d = 1;
                mem_write = 1;
            end

            `ST_BEQ_EX: begin
                alu_srcA = 2'b01;
                alu_srcB = 2'b00;
                alu_control = 3'b001; 
                pc_source = 2'b01;
		pc_write_cond = 1;
            end

	    `ST_J_EX: begin // jump
                pc_write = 1;
                pc_source = 2'b10; // control signal
            end

            `ST_FPU_EXEC: fpu_start = 1;
            `ST_FPU_WB:   fpu_reg_write = 1;
            `ST_SIMD_EX1: simd_start = 1;
            `ST_SIMD_WB:  simd_reg_write = 1;

        endcase
    end
endmodule
