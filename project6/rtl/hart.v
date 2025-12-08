`default_nettype none

// Comment/uncomment this line to enable/disable cache
//`define USE_CACHE

module hart #(
    parameter RESET_ADDR = 32'h00000000
) (
    // Global clock.
    input  wire        i_clk,
    // Synchronous active-high reset.
    input  wire        i_rst,
    // Instruction memory interface (external memory)
    input  wire        i_imem_ready,
    output wire [31:0] o_imem_raddr,
    output wire        o_imem_ren,
    input  wire        i_imem_valid,
    input  wire [31:0] i_imem_rdata,
    // Data memory interface (external memory)
    input  wire        i_dmem_ready,
    output wire [31:0] o_dmem_addr,
    output wire        o_dmem_ren,
    output wire        o_dmem_wen,
    output wire [31:0] o_dmem_wdata,
    output wire [ 3:0] o_dmem_mask,
    input  wire        i_dmem_valid,
    input  wire [31:0] i_dmem_rdata,
    // Retire interface
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
    output wire [31:0] o_retire_dmem_addr,
    output wire [ 3:0] o_retire_dmem_mask,
    output wire        o_retire_dmem_ren,
    output wire        o_retire_dmem_wen,
    output wire [31:0] o_retire_dmem_rdata,
    output wire [31:0] o_retire_dmem_wdata,
    output wire [31:0] o_retire_pc,
    output wire [31:0] o_retire_next_pc

`ifdef RISCV_FORMAL
    ,`RVFI_OUTPUTS
`endif
);
    
    ////////////////////////////////////////////////////////////////////////////////
    // ALL WIRE DECLARATIONS
    ////////////////////////////////////////////////////////////////////////////////
    
    // IF Stage wires
    wire [31:0] if_pc;
    wire [31:0] if_next_pc;
    
    // IF/ID Stage wires
    wire [31:0] id_pc;
    wire [31:0] id_instruction;
    wire [31:0] id_pc_plus_4;
    wire        id_valid;
    wire        flush_if_id;
    
    // ID Stage wires - Control signals
    wire        id_RegWrite;
    wire [5:0]  id_inst_format;
    wire        id_ALUSrc1;
    wire        id_ALUSrc2;
    wire [1:0]  id_ALUop;
    wire        id_lui;
    wire        id_MemtoReg;
    wire        id_Jump;
    wire        id_Branch;
    wire        id_dmem_ren;
    wire        id_dmem_wen;
    wire        id_retire_halt;
    wire        id_retire_trap;
    
    // ID Stage wires - Register file
    wire [4:0]  id_rs1_addr;
    wire [4:0]  id_rs2_addr;
    wire [4:0]  id_rd_addr;
    wire [31:0] id_rs1_rdata;
    wire [31:0] id_rs2_rdata;
    
    // ID Stage wires - Immediate and ALU control
    wire [31:0] id_immediate;
    wire [3:0]  id_alu_ctrl;
    wire        id_is_bne;
    
    // ID/EX Stage wires
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
    wire [3:0]  ex_alu_ctrl;
    wire        ex_is_bne;
    wire        ex_lui;
    wire        ex_branch;
    wire        ex_jump;
    wire        ex_mem_read;
    wire        ex_mem_write;
    wire        ex_reg_write;
    wire        ex_mem_to_reg;
    wire        ex_retire_halt;
    wire        ex_valid;
    
    // EX Stage wires
    wire [31:0] ex_alu_op1;
    wire [31:0] ex_alu_op2;
    wire [31:0] ex_alu_result;
    wire        ex_branch_condition;
    wire [31:0] ex_branch_mux;
    wire [31:0] ex_jump_mux;
    wire        ex_pc_redirect;
    wire [31:0] jump_target;
    wire [31:0] branch_target;
    wire [31:0] ex_next_pc_target;
    
    // EX/MEM Stage wires
    wire [31:0] mem_alu_result;
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
    wire        mem_retire_halt;
    wire [31:0] mem_next_pc_target;
    wire        mem_valid;
    
    // MEM Stage wires
    wire [31:0] mem_dmem_addr_aligned;
    wire [1:0]  mem_byte_offset;
    wire [3:0]  mem_dmem_mask;
    wire [31:0] mem_dmem_wdata;
    wire [31:0] mem_load_data;
    
    // MEM/WB Stage wires
    wire [31:0] wb_alu_result;
    wire [31:0] wb_load_data;
    wire [31:0] wb_pc_plus_4;
    wire [31:0] wb_pc;
    wire [31:0] wb_instruction;
    wire [4:0]  wb_rs1_addr;
    wire [4:0]  wb_rs2_addr;
    wire [4:0]  wb_rd_waddr;
    wire        wb_jump;
    wire        wb_mem_to_reg;
    wire [31:0] wb_next_pc_target;
    wire        wb_valid;
    wire [31:0] wb_dmem_addr;
    wire [3:0]  wb_dmem_mask;
    wire        wb_dmem_ren;
    wire        wb_dmem_wen;
    wire [31:0] wb_dmem_rdata;
    wire [31:0] wb_dmem_wdata;
    wire        wb_RegWrite;
    wire [31:0] wb_rd_wdata;
    wire        wb_retire_halt;
    wire [1:0]  wb_mem_byte_offset;

    // Hazards, forwarding, and reset initialization
    wire        hazard_stall;
    wire        stall_if_id;
    wire        stall_pc;
    wire        flush_id_ex;

    reg first_cycle;
    reg if_valid;
    wire pc_write_enable;

    wire [1:0] forward_a;
    wire [1:0] forward_b;

    wire [31:0] mem_forward_data;
    wire [31:0] wb_forward_data;

    wire [31:0] forward_rs1_data;
    wire [31:0] forward_rs2_data;

    wire [31:0] ex_rs1_fwd_data;
    wire [31:0] ex_rs2_fwd_data;
    wire [31:0] mem_rs1_fwd_data;
    wire [31:0] mem_rs2_fwd_data;
    wire [31:0] wb_rs1_fwd_data;
    wire [31:0] wb_rs2_fwd_data;

    // Memory read data source (from cache or direct)
    wire [31:0] mem_rdata_source;

    ////////////////////////////////////////////////////////////////////////////////
    // CACHE INTEGRATION (or bypass)
    ////////////////////////////////////////////////////////////////////////////////
    
`ifdef USE_CACHE
    // Instruction cache signals
    wire        icache_busy;
    wire [31:0] icache_req_addr;
    wire        icache_req_ren;
    wire [31:0] icache_res_rdata;
    
    // Data cache signals
    wire        dcache_busy;
    wire [31:0] dcache_req_addr;
    wire        dcache_req_ren;
    wire        dcache_req_wen;
    wire [3:0]  dcache_req_mask;
    wire [31:0] dcache_req_wdata;
    wire [31:0] dcache_res_rdata;
    
    // Cache stall signals - stall the entire pipeline when either cache is busy
    wire cache_stall;
    assign cache_stall = icache_busy | dcache_busy;
    
    // Memory read data source
    assign mem_rdata_source = dcache_res_rdata;
    
    // Instruction Cache
    cache icache (
        .i_clk(i_clk),
        .i_rst(i_rst),
        // External memory interface
        .i_mem_ready(i_imem_ready),
        .o_mem_addr(o_imem_raddr),
        .o_mem_ren(o_imem_ren),
        .o_mem_wen(),              // Instruction cache is read-only
        .o_mem_wdata(),            // Instruction cache is read-only
        .i_mem_rdata(i_imem_rdata),
        .i_mem_valid(i_imem_valid),
        // CPU interface
        .o_busy(icache_busy),
        .i_req_addr(icache_req_addr),
        .i_req_ren(icache_req_ren),
        .i_req_wen(1'b0),          // Instruction cache is read-only
        .i_req_mask(4'b1111),      // Always full word for instructions
        .i_req_wdata(32'b0),       // Instruction cache is read-only
        .o_res_rdata(icache_res_rdata)
    );
    
    // Data Cache
    cache dcache (
        .i_clk(i_clk),
        .i_rst(i_rst),
        // External memory interface
        .i_mem_ready(i_dmem_ready),
        .o_mem_addr(o_dmem_addr),
        .o_mem_ren(o_dmem_ren),
        .o_mem_wen(o_dmem_wen),
        .o_mem_wdata(o_dmem_wdata),
        .i_mem_rdata(i_dmem_rdata),
        .i_mem_valid(i_dmem_valid),
        // CPU interface
        .o_busy(dcache_busy),
        .i_req_addr(dcache_req_addr),
        .i_req_ren(dcache_req_ren),
        .i_req_wen(dcache_req_wen),
        .i_req_mask(dcache_req_mask),
        .i_req_wdata(dcache_req_wdata),
        .o_res_rdata(dcache_res_rdata)
    );
    
    // Note: dmem_mask is handled internally by the cache
    assign o_dmem_mask = 4'b1111;  // Cache always does word accesses to memory
    
`else
    // ============================================================================
    // NO CACHE MODE - Direct memory connection for testing
    // ============================================================================
    
    // No cache stall in bypass mode
    wire cache_stall;
    assign cache_stall = 1'b0;
    
    // Memory read data source - direct from memory
    assign mem_rdata_source = i_dmem_rdata;
    
    // Instruction memory - direct connection
    assign o_imem_raddr = if_pc;
    assign o_imem_ren = 1'b1;  // Always reading instructions
    
    // Data memory - direct connection
    assign o_dmem_addr = mem_dmem_addr_aligned;
    assign o_dmem_ren = mem_mem_read & mem_valid;
    assign o_dmem_wen = mem_mem_write & mem_valid;
    assign o_dmem_wdata = mem_dmem_wdata;
    assign o_dmem_mask = mem_dmem_mask;
    
`endif

    ////////////////////////////////////////////////////////////////////////////////
    // IF Stage - Instruction Fetch
    ////////////////////////////////////////////////////////////////////////////////

    // Latch PC if not stalled or halted
    assign pc_write_enable = ~wb_retire_halt & ~stall_pc & ~cache_stall;
    
    // PC register
    pc PC (
        .i_clk(i_clk),
        .i_rst(i_rst),
        .i_write(pc_write_enable),
        .i_next_pc(if_next_pc),
        .o_pc(if_pc)
    );

    // Setup help for fetch stage on reset
    always @(posedge i_clk) begin
        if (i_rst) begin
            first_cycle <= 1'b1;
            if_valid <= 1'b0;
        end else if (!cache_stall) begin
            first_cycle <= 1'b0;
            if_valid <= 1'b1;
        end
    end

    // Update next PC to use branch/jump target, PC + 4, or reset
    assign if_next_pc =
        first_cycle       ? 32'h00000000 :
        ex_pc_redirect    ? ex_jump_mux :
                            if_pc + 32'd4;

`ifdef USE_CACHE
    // Instruction cache request - always request current PC
    assign icache_req_addr = if_pc;
    // Request when not in first cycle (need PC to be valid)
    // Don't request during cache stall - cache is handling miss
    assign icache_req_ren = ~first_cycle & ~cache_stall;
`endif
    
    ////////////////////////////////////////////////////////////////////////////////
    // IF/ID Pipeline Register
    ////////////////////////////////////////////////////////////////////////////////
    
    if_id IF_ID (
        .i_clk(i_clk),
        .i_rst(i_rst),
        .i_flush(flush_if_id),
        .i_pc(if_pc),
        .i_pc_plus_4(if_pc + 32'd4),
`ifdef USE_CACHE
        .i_instruction(icache_res_rdata),
        .i_valid(if_valid & ~icache_busy),
`else
        .i_instruction(i_imem_rdata),  // Direct from memory
        .i_valid(if_valid),
`endif
        .i_stall(stall_if_id | cache_stall),
        .o_instruction(id_instruction),
        .o_pc(id_pc),
        .o_pc_plus_4(id_pc_plus_4),
        .o_valid(id_valid)
    );
    
    ////////////////////////////////////////////////////////////////////////////////
    // ID Stage - Instruction Decode
    ////////////////////////////////////////////////////////////////////////////////

    // Hazard unit
    hazard_unit HZ (
        .i_mem_read_ex(ex_mem_read),
        .i_valid_ex(ex_valid),
        .i_ex_rd(ex_rd_addr),
        .i_id_rs1(id_rs1_addr),
        .i_id_rs2(id_rs2_addr),
        .o_hazard_stall(hazard_stall)
    );

    // Hazard stall logic
    assign stall_pc     = hazard_stall;
    assign stall_if_id  = hazard_stall;
    
    // Control unit
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
    assign id_rs1_addr = id_instruction[19:15];
    assign id_rs2_addr = id_instruction[24:20];
    assign id_rd_addr = id_instruction[11:7];

    // Register file (with bypassing enabled)
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
    imm ImmGen (
        .i_inst(id_instruction),
        .i_format(id_inst_format),
        .o_immediate(id_immediate)
    );

    // ALU control
    alu_ctrl ALU_control (
        .i_ALUop(id_ALUop),
        .i_funct3(id_instruction[14:12]),
        .i_funct7_bit5(id_instruction[30]),
        .o_alu_ctrl(id_alu_ctrl),
        .o_is_bne(id_is_bne)
    );
    
    ////////////////////////////////////////////////////////////////////////////////
    // ID/EX Pipeline Register
    ////////////////////////////////////////////////////////////////////////////////
    
    id_ex ID_EX (
        .i_clk(i_clk),
        .i_rst(i_rst), 
        .i_flush(flush_id_ex),
        .i_stall(cache_stall),
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
        .i_alu_ctrl(id_alu_ctrl),
        .i_is_bne(id_is_bne),
        .i_lui(id_lui),
        .i_branch(id_Branch),
        .i_jump(id_Jump),
        .i_mem_read(id_dmem_ren),
        .i_mem_write(id_dmem_wen),
        .i_reg_write(id_RegWrite),
        .i_mem_to_reg(id_MemtoReg),
        .i_retire_halt(id_retire_halt),
        .i_valid(id_valid),
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
        .o_alu_ctrl(ex_alu_ctrl),
        .o_is_bne(ex_is_bne),
        .o_lui(ex_lui),
        .o_branch(ex_branch),
        .o_jump(ex_jump),
        .o_mem_read(ex_mem_read),
        .o_mem_write(ex_mem_write),
        .o_reg_write(ex_reg_write),
        .o_mem_to_reg(ex_mem_to_reg),
        .o_retire_halt(ex_retire_halt),
        .o_valid(ex_valid)
    );
    
    ////////////////////////////////////////////////////////////////////////////////
    // EX Stage - Execute
    //////////////////////////////////////////////////////////////////////////////// 

    // Forwarding unit
    forward_unit FU (
        .i_ex_rs1(ex_rs1_addr),
        .i_ex_rs2(ex_rs2_addr),
        .i_mem_reg_write(mem_reg_write),
        .i_mem_rd(mem_rd_addr),
        .i_wb_reg_write(wb_RegWrite),
        .i_wb_rd(wb_rd_waddr),
        .o_forward_a(forward_a),
        .o_forward_b(forward_b)
    );

    // Compute forwarding data from MEM stage
    assign mem_forward_data = mem_jump ? mem_pc_plus_4 : mem_alu_result;

    // Compute forwarding data from WB stage
    assign wb_forward_data = wb_jump ? wb_pc_plus_4 : 
                            wb_mem_to_reg ? wb_load_data : 
                            wb_alu_result;

    // Select forwarded data for rs1
    assign forward_rs1_data =
        (forward_a == 2'b10) ? mem_forward_data :  // MEM→EX (EX-EX)
        (forward_a == 2'b01) ? wb_forward_data  :  // WB→EX (MEM-EX)
                            ex_rs1_rdata;          // From ID/EX

    // Select forwarded data for rs2
    assign forward_rs2_data =
        (forward_b == 2'b10) ? mem_forward_data :  // MEM→EX (EX-EX)
        (forward_b == 2'b01) ? wb_forward_data  :  // WB→EX (MEM-EX)
                            ex_rs2_rdata;          // From ID/EX
    
    // ALU operand selection
    assign ex_alu_op1 = ex_alu_src1 ? (ex_lui ? 32'd0 : ex_pc) : forward_rs1_data;
    assign ex_alu_op2 = ex_alu_src2 ? ex_immediate : forward_rs2_data;
    
    // ALU
    alu ALU (
        .i_op1(ex_alu_op1),
        .i_op2(ex_alu_op2),
        .i_opsel(ex_alu_ctrl),
        .i_is_bne(ex_is_bne),
        .o_result(ex_alu_result),
        .o_jump_condition(ex_branch_condition)
    );
    
    // Branch/Jump logic for next PC
    assign ex_branch_mux = (ex_branch & ex_branch_condition) ? (ex_pc + ex_immediate) : (ex_pc + 32'd4);
    assign ex_jump_mux = ex_jump ? 
                              ((~ex_instruction[3]) ? {ex_alu_result[31:1], 1'b0} : ex_alu_result) :
                              ex_branch_mux;

    // PC redirect and flush signals - only when not stalled by cache
    assign ex_pc_redirect = ((ex_branch & ex_branch_condition) | ex_jump) & ~cache_stall;
    assign flush_if_id = ex_pc_redirect;
    assign flush_id_ex = (ex_pc_redirect | hazard_stall) & ~cache_stall;
    
    // Propagate next_pc_target to retire target testbench
    assign jump_target = (~ex_instruction[3]) ? {ex_alu_result[31:1], 1'b0} : ex_alu_result;
    assign branch_target = (ex_branch & ex_branch_condition) ? (ex_pc + ex_immediate) : ex_pc_plus_4;
    assign ex_next_pc_target = ex_jump ? jump_target : branch_target;

    ////////////////////////////////////////////////////////////////////////////////
    // EX/MEM Pipeline Register
    ////////////////////////////////////////////////////////////////////////////////
    
    ex_mem EX_MEM (
        .i_clk(i_clk),
        .i_rst(i_rst),
        .i_stall(cache_stall),
        // Computation results
        .i_alu_result(ex_alu_result),
        // Data signals
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
        .i_retire_halt(ex_retire_halt),
        .i_next_pc_target(ex_next_pc_target),
        .i_valid(ex_valid),
        // Outputs to MEM stage
        .o_alu_result(mem_alu_result),
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
        .o_jump(mem_jump),
        .o_retire_halt(mem_retire_halt),
        .o_next_pc_target(mem_next_pc_target),
        .o_valid(mem_valid),

        // Forwarding
        .i_rs1_fwd_data(forward_rs1_data),
        .i_rs2_fwd_data(forward_rs2_data),
        .o_rs1_fwd_data(mem_rs1_fwd_data),
        .o_rs2_fwd_data(mem_rs2_fwd_data)
    );
    
    ////////////////////////////////////////////////////////////////////////////////
    // MEM Stage - Memory Access
    ////////////////////////////////////////////////////////////////////////////////
    
    // Calculate aligned address (clear lower 2 bits)
    assign mem_dmem_addr_aligned = {mem_alu_result[31:2], 2'b00};
    
    // Get byte offset from address
    assign mem_byte_offset = mem_alu_result[1:0];
    
    // Adjust mask based on address offset
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
    assign mem_dmem_wdata = 
        // SB: shift left by byte offset
        (mem_instruction[6:0] == 7'b0100011 && mem_instruction[14:12] == 3'b000) ? (mem_rs2_fwd_data << (mem_byte_offset * 8)) :
        // SH: shift left by half-word offset
        (mem_instruction[6:0] == 7'b0100011 && mem_instruction[14:12] == 3'b001) ? (mem_rs2_fwd_data << (mem_byte_offset[1] * 16)) :
        // SW: no shift needed
        mem_rs2_fwd_data;
    
`ifdef USE_CACHE
    // Connect to data cache - only issue request when not already processing a miss
    assign dcache_req_addr = mem_dmem_addr_aligned;
    assign dcache_req_ren = mem_mem_read & mem_valid & ~dcache_busy;
    assign dcache_req_wen = mem_mem_write & mem_valid & ~dcache_busy;
    assign dcache_req_mask = mem_dmem_mask;
    assign dcache_req_wdata = mem_dmem_wdata;
`endif

    // Extract load data in MEM stage for passing to MEM/WB
    assign mem_load_data = 
        // LW - no adjustment needed
        (mem_instruction[14:12] == 3'b010) ? mem_rdata_source :
        // LH - extract half-word and sign extend
        (mem_instruction[14:12] == 3'b001) ? 
            (mem_byte_offset[1] ? {{16{mem_rdata_source[31]}}, mem_rdata_source[31:16]} :
                                  {{16{mem_rdata_source[15]}}, mem_rdata_source[15:0]}) :
        // LHU - extract half-word and zero extend  
        (mem_instruction[14:12] == 3'b101) ?
            (mem_byte_offset[1] ? {16'd0, mem_rdata_source[31:16]} :
                                  {16'd0, mem_rdata_source[15:0]}) :
        // LB - extract byte and sign extend
        (mem_instruction[14:12] == 3'b000) ?
            (mem_byte_offset == 2'b00 ? {{24{mem_rdata_source[7]}}, mem_rdata_source[7:0]} :
             mem_byte_offset == 2'b01 ? {{24{mem_rdata_source[15]}}, mem_rdata_source[15:8]} :
             mem_byte_offset == 2'b10 ? {{24{mem_rdata_source[23]}}, mem_rdata_source[23:16]} :
                                        {{24{mem_rdata_source[31]}}, mem_rdata_source[31:24]}) :
        // LBU - extract byte and zero extend
        (mem_byte_offset == 2'b00 ? {24'd0, mem_rdata_source[7:0]} :
         mem_byte_offset == 2'b01 ? {24'd0, mem_rdata_source[15:8]} :
         mem_byte_offset == 2'b10 ? {24'd0, mem_rdata_source[23:16]} :
                                    {24'd0, mem_rdata_source[31:24]});
    
    ////////////////////////////////////////////////////////////////////////////////
    // MEM/WB Pipeline Register
    ////////////////////////////////////////////////////////////////////////////////
    
    mem_wb MEM_WB (
        .i_clk(i_clk),
        .i_rst(i_rst),
        .i_stall(cache_stall),
        // Writeback data candidates
        .i_alu_result(mem_alu_result),
        .i_load_data(mem_load_data),
        .i_pc_plus_4(mem_pc_plus_4),
        // Original data
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
        .i_dmem_wdata(mem_dmem_wdata),
        .i_mem_byte_offset(mem_byte_offset),
        // Control signals
        .i_reg_write(mem_reg_write),
        .i_mem_to_reg(mem_mem_to_reg),
        .i_jump(mem_jump),
        .i_retire_halt(mem_retire_halt),
        .i_next_pc_target(mem_next_pc_target),
        .i_valid(mem_valid),

        // Outputs to WB stage
        .o_alu_result(wb_alu_result),
        .o_load_data(wb_load_data),
        .o_pc_plus_4(wb_pc_plus_4),
        .o_pc(wb_pc),
        .o_instruction(wb_instruction),
        .o_rs1_addr(wb_rs1_addr),
        .o_rs2_addr(wb_rs2_addr),
        .o_rd_addr(wb_rd_waddr),
        .o_dmem_addr(wb_dmem_addr),
        .o_dmem_mask(wb_dmem_mask),
        .o_dmem_ren(wb_dmem_ren),
        .o_dmem_wen(wb_dmem_wen),
        .o_dmem_wdata(wb_dmem_wdata),
        .o_reg_write(wb_RegWrite),
        .o_mem_to_reg(wb_mem_to_reg),
        .o_jump(wb_jump),
        .o_retire_halt(wb_retire_halt),
        .o_next_pc_target(wb_next_pc_target),
        .o_valid(wb_valid),
        .o_mem_byte_offset(wb_mem_byte_offset),

        // Forwarding
        .i_rs1_fwd_data(mem_rs1_fwd_data),
        .i_rs2_fwd_data(mem_rs2_fwd_data),
        .o_rs1_fwd_data(wb_rs1_fwd_data),
        .o_rs2_fwd_data(wb_rs2_fwd_data)
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
    assign o_retire_valid = wb_valid & ~cache_stall;
    assign o_retire_inst = wb_instruction;
    assign o_retire_trap = 1'b0;
    assign o_retire_halt = wb_retire_halt;
    assign o_retire_rs1_raddr = wb_rs1_addr;
    assign o_retire_rs2_raddr = wb_rs2_addr;
    assign o_retire_rs1_rdata = wb_rs1_fwd_data;
    assign o_retire_rs2_rdata = wb_rs2_fwd_data;
    assign o_retire_rd_waddr = wb_RegWrite ? wb_rd_waddr : 5'd0;
    assign o_retire_rd_wdata = wb_rd_wdata;
    
    // Connect retire_dmem signals from WB stage
    assign o_retire_dmem_addr = wb_dmem_addr;
    assign o_retire_dmem_ren = wb_dmem_ren;
    assign o_retire_dmem_wen = wb_dmem_wen;
    assign o_retire_dmem_mask = wb_dmem_mask;
    assign o_retire_dmem_wdata = wb_dmem_wdata;
    assign o_retire_dmem_rdata = mem_rdata_source;
    assign o_retire_next_pc = wb_next_pc_target;
    assign o_retire_pc = wb_pc;
    
endmodule

`default_nettype wire
