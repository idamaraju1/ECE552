`default_nettype none

module mem_wb (
    input  wire        i_clk,
    
    // Writeback data candidates from MEM stage
    input  wire [31:0] i_alu_result,
    input  wire [31:0] i_load_data,
    input  wire [31:0] i_pc_plus_4,
    
    // Original data needed by retire
    input  wire [31:0] i_rs1_rdata,
    input  wire [31:0] i_rs2_rdata,
    input  wire [31:0] i_pc,
    input  wire [31:0] i_instruction,
    
    // Address signals
    input  wire [ 4:0] i_rs1_addr,
    input  wire [ 4:0] i_rs2_addr,
    input  wire [ 4:0] i_rd_addr,
    
    // Data memory interface signals (for retire_dmem_*)
    input  wire [31:0] i_dmem_addr,
    input  wire [ 3:0] i_dmem_mask,
    input  wire        i_dmem_ren,
    input  wire        i_dmem_wen,
    input  wire [31:0] i_dmem_rdata,
    input  wire [31:0] i_dmem_wdata,
    
    // Control signals for WB stage
    input  wire        i_reg_write,
    input  wire        i_mem_to_reg,
    input  wire        i_jump,
    
    // Writeback data candidates to WB stage
    output reg  [31:0] o_alu_result,
    output reg  [31:0] o_load_data,
    output reg  [31:0] o_pc_plus_4,
    
    // Original data for retire
    output reg  [31:0] o_rs1_rdata,
    output reg  [31:0] o_rs2_rdata,
    output reg  [31:0] o_pc,
    output reg  [31:0] o_instruction,
    
    // Address signals
    output reg  [ 4:0] o_rs1_addr,
    output reg  [ 4:0] o_rs2_addr,
    output reg  [ 4:0] o_rd_addr,
    
    // Data memory interface signals (for retire_dmem_*)
    output reg  [31:0] o_dmem_addr,
    output reg  [ 3:0] o_dmem_mask,
    output reg         o_dmem_ren,
    output reg         o_dmem_wen,
    output reg  [31:0] o_dmem_rdata,
    output reg  [31:0] o_dmem_wdata,
    
    // Control signals for WB stage
    output reg         o_jump,
    output reg         o_reg_write,
    output reg         o_mem_to_reg
);

    always @(posedge i_clk) begin
        // Writeback data candidates
        o_alu_result <= i_alu_result;
        o_load_data <= i_load_data;
        o_pc_plus_4 <= i_pc_plus_4;
        
        // Original data
        o_rs1_rdata <= i_rs1_rdata;
        o_rs2_rdata <= i_rs2_rdata;
        o_pc <= i_pc;
        o_instruction <= i_instruction;
        
        // Address signals
        o_rs1_addr <= i_rs1_addr;
        o_rs2_addr <= i_rs2_addr;
        o_rd_addr <= i_rd_addr;
        
        // Data memory interface
        o_dmem_addr <= i_dmem_addr;
        o_dmem_mask <= i_dmem_mask;
        o_dmem_ren <= i_dmem_ren;
        o_dmem_wen <= i_dmem_wen;
        o_dmem_rdata <= i_dmem_rdata;
        o_dmem_wdata <= i_dmem_wdata;
        
        // Control signals
        o_reg_write <= i_reg_write;
        o_mem_to_reg <= i_mem_to_reg;
        o_jump <= i_jump;
    end

endmodule

`default_nettype wire