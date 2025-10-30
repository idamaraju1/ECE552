`default_nettype none

module hart #(
    parameter RESET_ADDR = 32'h00000000
) (
    input  wire        i_clk,
    input  wire        i_rst,
    output wire [31:0] o_imem_raddr,
    input  wire [31:0] i_imem_rdata,
    output wire [31:0] o_dmem_addr,
    output wire        o_dmem_ren,
    output wire        o_dmem_wen,
    output wire [31:0] o_dmem_wdata,
    output wire [ 3:0] o_dmem_mask,
    input  wire [31:0] i_dmem_rdata,
    output wire        o_retire_valid,
    output wire [31:0] o_retire_inst,
    output wire        o_retire_trap,
    output wire        o_retire_halt,
    output wire [ 4:0] o_retire_rs1_raddr,
    output wire [ 4:0] o_retire_rs2_raddr,
    output wire [31:0] o_retire_rs1_rdata,
    output wire [31:0] o_retire_rs2_rdata,
    output wire [ 4:0] o_retire_rd_waddr,
    output wire [31:0] o_retire_rd_wdata,
    output wire [31:0] o_retire_pc,
    output wire [31:0] o_retire_next_pc,
    // Additional retire signals for data memory (for verification)
    output wire [31:0] o_retire_dmem_addr,
    output wire        o_retire_dmem_ren,
    output wire        o_retire_dmem_wen,
    output wire [ 3:0] o_retire_dmem_mask,
    output wire [31:0] o_retire_dmem_wdata,
    output wire [31:0] o_retire_dmem_rdata
);
    
    ////////////////////////////////////////////////////////////////////////////////
    // IF Stage - Instruction Fetch
    ////////////////////////////////////////////////////////////////////////////////
    wire [31:0] if_pc;
    wire [31:0] if_next_pc;
    
    // PC register
    pc PC (
        .i_clk(i_clk),
        .i_rst(i_rst),
        .i_next_pc(if_next_pc),
        .o_pc(if_pc),
        .o_retire_valid(o_retire_valid)
    );
    
    // Connect PC to instruction memory
    assign o_imem_raddr = if_pc;
    
    ////////////////////////////////////////////////////////////////////////////////
    // IF/ID Pipeline Register
    ////////////////////////////////////////////////////////////////////////////////
    wire [31:0] id_pc;
    wire [31:0] id_instruction;
    wire [31:0] id_pc_plus_4;
    
    if_id IF_ID (
        .i_clk(i_clk),
        .i_rst(i_rst),
        .i_pc(if_pc),
        .i_instruction(i_imem_rdata),
        .i_pc_plus_4(if_pc + 32'd4),
        .o_pc(id_pc),
        .o_pc_plus_4(id_pc_plus_4),
        .o_instruction(id_instruction)
    );
    
    ////////////////////////////////////////////////////////////////////////////////
    // ID Stage - Instruction Decode
    ////////////////////////////////////////////////////////////////////////////////
    
    // Control signals
    wire       id_RegWrite;
    wire [5:0] id_inst_format;
    wire       id_ALUSrc1;
    wire       id_ALUSrc2;
    wire [1:0] id_ALUop;
    wire       id_lui;
    wire       id_MemtoReg;
    wire       id_Jump;
    wire       id_Branch;
    wire       id_dmem_ren;
    wire       id_dmem_wen;
    wire       id_retire_halt;
    wire       id_retire_trap;
    
    ctrl Control (
        .i_inst(id_instruction),
        .o_RegWrite(id_RegWrite),
        .o_inst_format(id_inst_format),
        .o_ALUSrc1(id_ALUSrc1),
        .o_ALUSrc2(id_ALUSrc2),
        .o_ALUop(id_ALUop),
        .o_lui(id_lui),
        .o_dmem_ren(id_dmem_ren),
        .o_dmem_wen(id_dmem_wen),
        .o_MemtoReg(id_MemtoReg),
        .o_Jump(id_Jump),
        .o_Branch(id_Branch),
        .o_retire_halt(id_retire_halt)
    );
    
    // Register file addresses
    wire [4:0] id_rs1_addr;
    wire [4:0] id_rs2_addr;
    wire [4:0] id_rd_addr;
    
    assign id_rs1_addr = id_instruction[19:15];
    assign id_rs2_addr = id_instruction[24:20];
    assign id_rd_addr = id_instruction[11:7];
    // TODO: check underneath
    // Register file (with bypassing enabled)
    wire [31:0] id_rs1_rdata;
    wire [31:0] id_rs2_rdata;
    
    // Connect writeback from WB stage
    wire [31:0] wb_rd_wdata;
    wire [4:0]  wb_rd_waddr;
    wire        wb_RegWrite;
    
    rf #(.BYPASS_EN(1)) RegisterFile (
        .i_clk(i_clk),
        .i_rst(i_rst),
        .i_rs1_raddr(id_rs1_addr),
        .i_rs2_raddr(id_rs2_addr),
        .i_rd_waddr(wb_RegWrite ? wb_rd_waddr : 5'd0),
        .i_rd_wdata(wb_rd_wdata),
        .o_rs1_rdata(id_rs1_rdata),
        .o_rs2_rdata(id_rs2_rdata)
    );
    
    // Immediate generator
    wire [31:0] id_immediate;
    
    imm ImmGen (
        .i_inst(id_instruction),
        .i_format(id_inst_format),
        .o_immediate(id_immediate)
    );
    
    ////////////////////////////////////////////////////////////////////////////////
    // ID/EX Pipeline Register
    ////////////////////////////////////////////////////////////////////////////////
    wire [31:0] ex_pc;
    wire [31:0] ex_pc_plus_4;
    wire [31:0] ex_rs1_rdata;
    wire [31:0] ex_rs2_rdata;
    wire [31:0] ex_immediate;
    wire [31:0] ex_instruction;
    wire [4:0]  ex_rs1_addr;
    wire [4:0]  ex_rs2_addr;
    wire [4:0]  ex_rd_addr;
    wire        ex_alu_src1;
    wire        ex_alu_src2;
    wire [1:0]  ex_alu_op;
    wire        ex_lui;
    wire        ex_branch;
    wire        ex_jump;
    wire        ex_mem_read;
    wire        ex_mem_write;
    wire        ex_reg_write;
    wire        ex_mem_to_reg;
    
    id_ex ID_EX (
        .i_clk(i_clk),
        .i_rst(i_rst), 
        // Data signals
        .i_pc(id_pc),
        .i_pc_plus_4(id_pc_plus_4),
        .i_rs1_rdata(id_rs1_rdata),
        .i_rs2_rdata(id_rs2_rdata),
        .i_immediate(id_immediate),
        .i_instruction(id_instruction),
        // Address signals
        .i_rs1_addr(id_rs1_addr),
        .i_rs2_addr(id_rs2_addr),
        .i_rd_addr(id_rd_addr),
        // Control signals
        .i_alu_src1(id_ALUSrc1),
        .i_alu_src2(id_ALUSrc2),
        .i_alu_op(id_ALUop),
        .i_lui(id_lui),
        .i_branch(id_Branch),
        .i_jump(id_Jump),
        .i_mem_read(id_dmem_ren),
        .i_mem_write(id_dmem_wen),
        .i_reg_write(id_RegWrite),
        .i_mem_to_reg(id_MemtoReg),
        // Outputs to EX stage
        .o_pc(ex_pc),
        .o_pc_plus_4(ex_pc_plus_4),
        .o_rs1_rdata(ex_rs1_rdata),
        .o_rs2_rdata(ex_rs2_rdata),
        .o_immediate(ex_immediate),
        .o_instruction(ex_instruction),
        .o_rs1_addr(ex_rs1_addr),
        .o_rs2_addr(ex_rs2_addr),
        .o_rd_addr(ex_rd_addr),
        .o_alu_src1(ex_alu_src1),
        .o_alu_src2(ex_alu_src2),
        .o_alu_op(ex_alu_op),
        .o_lui(ex_lui),
        .o_branch(ex_branch),
        .o_jump(ex_jump),
        .o_mem_read(ex_mem_read),
        .o_mem_write(ex_mem_write),
        .o_reg_write(ex_reg_write),
        .o_mem_to_reg(ex_mem_to_reg)
    );
    
    ////////////////////////////////////////////////////////////////////////////////
    // EX Stage - Execute
    ////////////////////////////////////////////////////////////////////////////////
    
    // ALU control
    wire [3:0] ex_alu_ctrl;
    wire       ex_is_bne;
    
    alu_ctrl ALU_control (
        .i_ALUop(ex_alu_op),
        .i_funct3(ex_instruction[14:12]),
        .i_funct7_bit5(ex_instruction[30]),
        .o_alu_ctrl(ex_alu_ctrl),
        .o_is_bne(ex_is_bne)
    );
    
    // ALU operand selection
    wire [31:0] ex_alu_op1;
    wire [31:0] ex_alu_op2;
    
    assign ex_alu_op1 = ex_alu_src1 ? (ex_lui ? 32'd0 : ex_pc) : ex_rs1_rdata;
    assign ex_alu_op2 = ex_alu_src2 ? ex_immediate : ex_rs2_rdata;
    
    // ALU
    wire [31:0] ex_alu_result;
    wire        ex_branch_condition;
    
    alu ALU (
        .i_op1(ex_alu_op1),
        .i_op2(ex_alu_op2),
        .i_opsel(ex_alu_ctrl),
        .i_is_bne(ex_is_bne),
        .o_result(ex_alu_result),
        .o_jump_condition(ex_branch_condition)
    );
    
    // Branch/Jump logic for next PC
    wire        ex_take_branch;
    wire [31:0] ex_branch_target;
    
    assign ex_take_branch = (ex_branch & ex_branch_condition) | ex_jump;
    assign ex_branch_target = ex_jump ? 
                              ((~ex_instruction[3]) ? {ex_alu_result[31:1], 1'b0} : ex_alu_result) :
                              (ex_pc + ex_immediate);
    
    assign if_next_pc = ex_take_branch ? ex_branch_target : (if_pc + 32'd4);
    
    ////////////////////////////////////////////////////////////////////////////////
    // EX/MEM Pipeline Register
    ////////////////////////////////////////////////////////////////////////////////
    wire [31:0] mem_alu_result;
    wire [31:0] mem_rs1_rdata;
    wire [31:0] mem_rs2_rdata;
    wire [31:0] mem_pc;
    wire [31:0] mem_pc_plus_4;
    wire [31:0] mem_instruction;
    wire [4:0]  mem_rs1_addr;
    wire [4:0]  mem_rs2_addr;
    wire [4:0]  mem_rd_addr;
    wire        mem_mem_read;
    wire        mem_mem_write;
    wire        mem_reg_write;
    wire        mem_mem_to_reg;
    wire        mem_jump;
    
    ex_mem EX_MEM (
        .i_clk(i_clk),
        .i_rst(i_rst),
        // Computation results
        .i_alu_result(ex_alu_result),
        // Data signals
        .i_rs1_rdata(ex_rs1_rdata),
        .i_rs2_rdata(ex_rs2_rdata),
        .i_pc(ex_pc),
        .i_pc_plus_4(ex_pc_plus_4),
        .i_instruction(ex_instruction),
        // Address signals
        .i_rs1_addr(ex_rs1_addr),
        .i_rs2_addr(ex_rs2_addr),
        .i_rd_addr(ex_rd_addr),
        // Control signals
        .i_mem_read(ex_mem_read),
        .i_mem_write(ex_mem_write),
        .i_reg_write(ex_reg_write),
        .i_mem_to_reg(ex_mem_to_reg),
        .i_jump(ex_jump),
        // Outputs to MEM stage
        .o_alu_result(mem_alu_result),
        .o_rs1_rdata(mem_rs1_rdata),
        .o_rs2_rdata(mem_rs2_rdata),
        .o_pc(mem_pc),
        .o_pc_plus_4(mem_pc_plus_4),
        .o_instruction(mem_instruction),
        .o_rs1_addr(mem_rs1_addr),
        .o_rs2_addr(mem_rs2_addr),
        .o_rd_addr(mem_rd_addr),
        .o_mem_read(mem_mem_read),
        .o_mem_write(mem_mem_write),
        .o_reg_write(mem_reg_write),
        .o_mem_to_reg(mem_mem_to_reg),
        .o_jump(mem_jump)
    );
    
    ////////////////////////////////////////////////////////////////////////////////
    // MEM Stage - Memory Access
    ////////////////////////////////////////////////////////////////////////////////
    
    // Calculate aligned address (clear lower 2 bits)
    wire [31:0] mem_dmem_addr_aligned;
    assign mem_dmem_addr_aligned = {mem_alu_result[31:2], 2'b00};
    
    // Get byte offset from address
    wire [1:0] mem_byte_offset;
    assign mem_byte_offset = mem_alu_result[1:0];
    
    // Adjust mask based on address offset
    wire [3:0] mem_dmem_mask;
    assign mem_dmem_mask = 
        // For byte access (SB/LB/LBU)
        (mem_instruction[6:0] == 7'b0100011 && mem_instruction[14:12] == 3'b000) ? (4'b0001 << mem_byte_offset) : // SB
        (mem_instruction[6:0] == 7'b0000011 && mem_instruction[14:12] == 3'b000) ? (4'b0001 << mem_byte_offset) : // LB
        (mem_instruction[6:0] == 7'b0000011 && mem_instruction[14:12] == 3'b100) ? (4'b0001 << mem_byte_offset) : // LBU
        // For half-word access (SH/LH/LHU)  
        (mem_instruction[6:0] == 7'b0100011 && mem_instruction[14:12] == 3'b001) ? (mem_byte_offset[1] ? 4'b1100 : 4'b0011) : // SH
        (mem_instruction[6:0] == 7'b0000011 && mem_instruction[14:12] == 3'b001) ? (mem_byte_offset[1] ? 4'b1100 : 4'b0011) : // LH
        (mem_instruction[6:0] == 7'b0000011 && mem_instruction[14:12] == 3'b101) ? (mem_byte_offset[1] ? 4'b1100 : 4'b0011) : // LHU
        // For word access (SW/LW) or any instructions of other types
        4'b1111;
    
    // Adjust write data position (shift to correct byte lane)
    wire [31:0] mem_dmem_wdata;
    assign mem_dmem_wdata = 
        // SB: shift left by byte offset
        (mem_instruction[6:0] == 7'b0100011 && mem_instruction[14:12] == 3'b000) ? (mem_rs2_rdata << (mem_byte_offset * 8)) :
        // SH: shift left by half-word offset
        (mem_instruction[6:0] == 7'b0100011 && mem_instruction[14:12] == 3'b001) ? (mem_rs2_rdata << (mem_byte_offset[1] * 16)) :
        // SW: no shift needed
        mem_rs2_rdata;
    
    // Extract and extend load data based on offset
    wire [31:0] mem_load_data;
    assign mem_load_data = 
        // LW - no adjustment needed
        (mem_instruction[14:12] == 3'b010) ? i_dmem_rdata :
        // LH - extract half-word and sign extend
        (mem_instruction[14:12] == 3'b001) ? 
            (mem_byte_offset[1] ? {{16{i_dmem_rdata[31]}}, i_dmem_rdata[31:16]} :
                                  {{16{i_dmem_rdata[15]}}, i_dmem_rdata[15:0]}) :
        // LHU - extract half-word and zero extend  
        (mem_instruction[14:12] == 3'b101) ?
            (mem_byte_offset[1] ? {16'd0, i_dmem_rdata[31:16]} :
                                  {16'd0, i_dmem_rdata[15:0]}) :
        // LB - extract byte and sign extend
        (mem_instruction[14:12] == 3'b000) ?
            (mem_byte_offset == 2'b00 ? {{24{i_dmem_rdata[7]}}, i_dmem_rdata[7:0]} :
             mem_byte_offset == 2'b01 ? {{24{i_dmem_rdata[15]}}, i_dmem_rdata[15:8]} :
             mem_byte_offset == 2'b10 ? {{24{i_dmem_rdata[23]}}, i_dmem_rdata[23:16]} :
                                        {{24{i_dmem_rdata[31]}}, i_dmem_rdata[31:24]}) :
        // LBU - extract byte and zero extend
        (mem_byte_offset == 2'b00 ? {24'd0, i_dmem_rdata[7:0]} :
         mem_byte_offset == 2'b01 ? {24'd0, i_dmem_rdata[15:8]} :
         mem_byte_offset == 2'b10 ? {24'd0, i_dmem_rdata[23:16]} :
                                    {24'd0, i_dmem_rdata[31:24]});
    
    // Connect memory interface outputs
    assign o_dmem_addr = mem_dmem_addr_aligned;
    assign o_dmem_ren = mem_mem_read;
    assign o_dmem_wen = mem_mem_write;
    assign o_dmem_mask = mem_dmem_mask;
    assign o_dmem_wdata = mem_dmem_wdata;
    
    ////////////////////////////////////////////////////////////////////////////////
    // MEM/WB Pipeline Register
    ////////////////////////////////////////////////////////////////////////////////
    wire [31:0] wb_alu_result;
    wire [31:0] wb_load_data;
    wire [31:0] wb_pc_plus_4;
    wire [31:0] wb_rs1_rdata;
    wire [31:0] wb_rs2_rdata;
    wire [31:0] wb_pc;
    wire [31:0] wb_instruction;
    wire [4:0]  wb_rs1_addr;
    wire [4:0]  wb_rs2_addr;
    wire        wb_jump;
    wire        wb_mem_to_reg;
    
    // Memory interface signals for retire
    wire [31:0] wb_dmem_addr;
    wire [3:0]  wb_dmem_mask;
    wire        wb_dmem_ren;
    wire        wb_dmem_wen;
    wire [31:0] wb_dmem_rdata;
    wire [31:0] wb_dmem_wdata;
    
    mem_wb MEM_WB (
        .i_clk(i_clk),
        .i_rst(i_rst),
        // Writeback data candidates
        .i_alu_result(mem_alu_result),
        .i_load_data(mem_load_data),
        .i_pc_plus_4(mem_pc_plus_4),
        // Original data
        .i_rs1_rdata(mem_rs1_rdata),
        .i_rs2_rdata(mem_rs2_rdata),
        .i_pc(mem_pc),
        .i_instruction(mem_instruction),
        // Address signals
        .i_rs1_addr(mem_rs1_addr),
        .i_rs2_addr(mem_rs2_addr),
        .i_rd_addr(mem_rd_addr),
        // Memory interface
        .i_dmem_addr(mem_dmem_addr_aligned),
        .i_dmem_mask(mem_dmem_mask),
        .i_dmem_ren(mem_mem_read),
        .i_dmem_wen(mem_mem_write),
        .i_dmem_rdata(i_dmem_rdata),
        .i_dmem_wdata(mem_dmem_wdata),
        // Control signals
        .i_reg_write(mem_reg_write),
        .i_mem_to_reg(mem_mem_to_reg),
        .i_jump(mem_jump),
        // Outputs to WB stage
        .o_alu_result(wb_alu_result),
        .o_load_data(wb_load_data),
        .o_pc_plus_4(wb_pc_plus_4),
        .o_rs1_rdata(wb_rs1_rdata),
        .o_rs2_rdata(wb_rs2_rdata),
        .o_pc(wb_pc),
        .o_instruction(wb_instruction),
        .o_rs1_addr(wb_rs1_addr),
        .o_rs2_addr(wb_rs2_addr),
        .o_rd_addr(wb_rd_waddr),
        .o_dmem_addr(wb_dmem_addr),
        .o_dmem_mask(wb_dmem_mask),
        .o_dmem_ren(wb_dmem_ren),
        .o_dmem_wen(wb_dmem_wen),
        .o_dmem_rdata(wb_dmem_rdata),
        .o_dmem_wdata(wb_dmem_wdata),
        .o_reg_write(wb_RegWrite),
        .o_mem_to_reg(wb_mem_to_reg),
        .o_jump(wb_jump)
    );
    
    ////////////////////////////////////////////////////////////////////////////////
    // WB Stage - Write Back
    ////////////////////////////////////////////////////////////////////////////////
    
    // Calculate write-back data
    assign wb_rd_wdata = 
        (wb_jump) ? wb_pc_plus_4 :
        (wb_mem_to_reg) ? wb_load_data :
        wb_alu_result;
    
    ////////////////////////////////////////////////////////////////////////////////
    // Retire Interface - Connected to WB stage outputs
    ////////////////////////////////////////////////////////////////////////////////
    assign o_retire_inst = wb_instruction;
    assign o_retire_pc = wb_pc;
    assign o_retire_rs1_raddr = wb_rs1_addr;
    assign o_retire_rs2_raddr = wb_rs2_addr;
    assign o_retire_rs1_rdata = wb_rs1_rdata;
    assign o_retire_rs2_rdata = wb_rs2_rdata;
    assign o_retire_rd_waddr = wb_RegWrite ? wb_rd_waddr : 5'd0;
    assign o_retire_rd_wdata = wb_rd_wdata;
    
    // Calculate next PC for retire
    wire        wb_retire_halt;
    wire        wb_retire_trap;
    
    ctrl WB_Control (
        .i_inst(wb_instruction),
        .i_o_retire_trap(wb_retire_trap),
        .o_RegWrite(),  // Not used
        .o_inst_format(),
        .o_ALUSrc1(),
        .o_ALUSrc2(),
        .o_ALUop(),
        .o_lui(),
        .o_dmem_ren(),
        .o_dmem_wen(),
        .o_MemtoReg(),
        .o_Jump(),
        .o_Branch(),
        .o_retire_halt(wb_retire_halt)
    );
    
    assign o_retire_halt = wb_retire_halt;
    assign o_retire_next_pc = wb_retire_halt ? wb_pc : (wb_pc + 32'd4);
    
    // Trap signal
    trap Trap(
        .i_inst(wb_instruction),
        .i_dmem_addr(wb_dmem_addr),
        .i_imem_addr(wb_pc),
        .o_trap(wb_retire_trap)
    );
    
    assign o_retire_trap = wb_retire_trap;
    
    // Connect retire_dmem signals from WB stage
    assign o_retire_dmem_addr = wb_dmem_addr;
    assign o_retire_dmem_ren = wb_dmem_ren;
    assign o_retire_dmem_wen = wb_dmem_wen;
    assign o_retire_dmem_mask = wb_dmem_mask;
    assign o_retire_dmem_wdata = wb_dmem_wdata;
    assign o_retire_dmem_rdata = wb_dmem_rdata;
    
endmodule

`default_nettype wire