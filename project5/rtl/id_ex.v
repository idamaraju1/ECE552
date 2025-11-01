`default_nettype none

module id_ex (
    input  wire        i_clk,
    input  wire        i_rst,
    input  wire        i_flush,   // 1 = insert bubble
    input  wire        i_valid,
    
    // Data signals from ID stage
    input  wire [31:0] i_pc,
    input  wire [31:0] i_pc_plus_4,
    input  wire [31:0] i_rs1_rdata,
    input  wire [31:0] i_rs2_rdata,
    input  wire [31:0] i_immediate,
    input  wire [31:0] i_instruction,
    
    // Address signals from ID stage
    input  wire [ 4:0] i_rs1_addr,
    input  wire [ 4:0] i_rs2_addr,
    input  wire [ 4:0] i_rd_addr,
    
    // Control signals from ID stage
    input  wire        i_alu_src1,
    input  wire        i_alu_src2,
    input  wire [ 3:0] i_alu_ctrl,
    input  wire        i_is_bne,
    input  wire        i_lui,
    input  wire        i_branch,
    input  wire        i_jump,
    input  wire        i_mem_read,
    input  wire        i_mem_write,
    input  wire        i_reg_write,
    input  wire        i_mem_to_reg,
    input  wire        i_retire_halt,
    
    // Data signals to EX stage
    output reg         o_valid,
    output reg  [31:0] o_pc,
    output reg  [31:0] o_pc_plus_4,
    output reg  [31:0] o_rs1_rdata,
    output reg  [31:0] o_rs2_rdata,
    output reg  [31:0] o_immediate,
    output reg  [31:0] o_instruction,
    
    // Address signals to EX stage
    output reg  [ 4:0] o_rs1_addr,
    output reg  [ 4:0] o_rs2_addr,
    output reg  [ 4:0] o_rd_addr,
    
    // Control signals to EX stage
    output reg         o_alu_src1,
    output reg         o_alu_src2,
    output reg  [ 3:0] o_alu_ctrl,
    output reg         o_is_bne,
    output reg         o_lui,
    output reg         o_branch,
    output reg         o_jump,
    output reg         o_mem_read,
    output reg         o_mem_write,
    output reg         o_reg_write,
    output reg         o_mem_to_reg,
    output reg         o_retire_halt
);

    always @(posedge i_clk) begin
        if (i_rst) begin
            o_pc <= 32'h00000000;
            o_pc_plus_4 <= 32'h00000004;
            o_rs1_rdata <= 32'h00000000;
            o_rs2_rdata <= 32'h00000000;
            o_immediate <= 32'h00000000;
            o_instruction <= 32'h00000013;  // NOP, ADDI x0,x0,0
            o_valid <= 1'b0;
            
            o_rs1_addr <= 5'd0;
            o_rs2_addr <= 5'd0;
            o_rd_addr <= 5'd0;
            
            o_alu_src1 <= 1'b0;
            o_alu_src2 <= 1'b0;
            o_alu_ctrl <= 4'b0000;
            o_is_bne <= 1'b0;
            o_lui <= 1'b0;
            o_branch <= 1'b0;
            o_jump <= 1'b0;
            o_mem_read <= 1'b0;
            o_mem_write <= 1'b0;
            o_reg_write <= 1'b0;
            o_mem_to_reg <= 1'b0;
            o_retire_halt <= 1'b0;
        end else if (i_flush) begin
            o_pc <= i_pc;
            o_pc_plus_4 <= i_pc_plus_4;
            o_rs1_rdata <= 32'h00000000;
            o_rs2_rdata <= 32'h00000000;
            o_immediate <= 32'h00000000;
            o_instruction <= 32'h00000013;  // NOP, ADDI x0,x0,0
            o_valid <= 1'b0;
            
            o_rs1_addr <= 5'd0;
            o_rs2_addr <= 5'd0;
            o_rd_addr <= 5'd0;
            
            o_alu_src1 <= 1'b0;
            o_alu_src2 <= 1'b0;
            o_alu_ctrl <= 4'b0000;
            o_is_bne <= 1'b0;
            o_lui <= 1'b0;
            o_branch <= 1'b0;
            o_jump <= 1'b0;
            o_mem_read <= 1'b0;
            o_mem_write <= 1'b0;
            o_reg_write <= 1'b0;
            o_mem_to_reg <= 1'b0;
            o_retire_halt <= 1'b0;
        end else begin
            // Data signals
            o_pc <= i_pc;
            o_pc_plus_4 <= i_pc_plus_4;
            o_rs1_rdata <= i_rs1_rdata;
            o_rs2_rdata <= i_rs2_rdata;
            o_immediate <= i_immediate;
            o_instruction <= i_instruction;
            o_valid <= i_valid;
            
            // Address signals
            o_rs1_addr <= i_rs1_addr;
            o_rs2_addr <= i_rs2_addr;
            o_rd_addr <= i_rd_addr;
            
            // Control signals
            o_alu_src1 <= i_alu_src1;
            o_alu_src2 <= i_alu_src2;
            o_alu_ctrl <= i_alu_ctrl;
            o_is_bne <= i_is_bne;
            o_lui <= i_lui;
            o_branch <= i_branch;
            o_jump <= i_jump;
            o_mem_read <= i_mem_read;
            o_mem_write <= i_mem_write;
            o_reg_write <= i_reg_write;
            o_mem_to_reg <= i_mem_to_reg;
            o_retire_halt <= i_retire_halt;
        end
    end

endmodule

`default_nettype wire