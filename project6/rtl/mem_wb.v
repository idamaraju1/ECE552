`default_nettype none

module mem_wb (
    input  wire        i_clk,
    input  wire        i_rst,
    input  wire        i_valid,
    
    // Writeback data candidates from MEM stage
    input  wire [31:0] i_alu_result,
    input  wire [31:0] i_load_data,
    input  wire [31:0] i_pc_plus_4,
    
    // Original data needed by retire
    input  wire [31:0] i_pc,
    input  wire [31:0] i_instruction,
    input  wire [31:0] i_next_pc_target,
    
    // Address signals
    input  wire [ 4:0] i_rs1_addr,
    input  wire [ 4:0] i_rs2_addr,
    input  wire [ 4:0] i_rd_addr,
    
    // Data memory interface signals (for retire_dmem_*)
    input  wire [31:0] i_dmem_addr,
    input  wire [ 3:0] i_dmem_mask,
    input  wire        i_dmem_ren,
    input  wire        i_dmem_wen,
    input  wire [31:0] i_dmem_wdata,
    input  wire [ 1:0] i_mem_byte_offset,
    
    // Control signals for WB stage
    input  wire        i_reg_write,
    input  wire        i_mem_to_reg,
    input  wire        i_jump,
    input  wire        i_retire_halt,
    
    // Writeback data candidates to WB stage
    output reg  [31:0] o_alu_result,
    output reg  [31:0] o_load_data,
    output reg  [31:0] o_pc_plus_4,
    
    // Original data for retire
    output reg  [31:0] o_pc,
    output reg  [31:0] o_instruction,
    output reg  [31:0] o_next_pc_target,
    
    // Address signals
    output reg  [ 4:0] o_rs1_addr,
    output reg  [ 4:0] o_rs2_addr,
    output reg  [ 4:0] o_rd_addr,
    
    // Data memory interface signals (for retire_dmem_*)
    output reg  [31:0] o_dmem_addr,
    output reg  [ 3:0] o_dmem_mask,
    output reg         o_dmem_ren,
    output reg         o_dmem_wen,
    output reg  [31:0] o_dmem_wdata,
    output reg  [ 1:0] o_mem_byte_offset,
    
    // Control signals for WB stage
    output reg         o_valid,
    output reg         o_jump,
    output reg         o_reg_write,
    output reg         o_mem_to_reg,
    output reg         o_retire_halt,

    // ADDED for forwarding
    input  wire [31:0] i_rs1_fwd_data,  // Actual rs1 value used (after forwarding)
    input  wire [31:0] i_rs2_fwd_data,  // Actual rs2 value used (after forwarding)
    output reg  [31:0] o_rs1_fwd_data,
    output reg  [31:0] o_rs2_fwd_data
);

    always @(posedge i_clk) begin
        if (i_rst) begin
            o_alu_result <= 32'h00000000;
            o_load_data <= 32'h00000000;
            o_pc_plus_4 <= 32'h00000004;
            
            o_pc <= 32'h00000000;
            o_instruction <= 32'h00000013;  // NOP
            o_next_pc_target <= 32'h00000000;
            
            o_rs1_addr <= 5'd0;
            o_rs2_addr <= 5'd0;
            o_rd_addr <= 5'd0;
            
            o_dmem_addr <= 32'h00000000;
            o_dmem_mask <= 4'h0;
            o_dmem_ren <= 1'b0;
            o_dmem_wen <= 1'b0;
            o_dmem_wdata <= 32'h00000000;
            o_mem_byte_offset <= 2'b00;
            
            o_valid <= 1'b0;
            o_reg_write <= 1'b0;
            o_mem_to_reg <= 1'b0;
            o_jump <= 1'b0;
            o_retire_halt <= 1'b0;

            // ADDED for forwarding
            o_rs1_fwd_data <= 32'h00000000;
            o_rs2_fwd_data <= 32'h00000000;
        end else begin
            // Writeback data candidates
            o_alu_result <= i_alu_result;
            o_load_data <= i_load_data;
            o_pc_plus_4 <= i_pc_plus_4;
            
            // Original data
            o_pc <= i_pc;
            o_instruction <= i_instruction;
            o_next_pc_target <= i_next_pc_target;
            
            // Address signals
            o_rs1_addr <= i_rs1_addr;
            o_rs2_addr <= i_rs2_addr;
            o_rd_addr <= i_rd_addr;
            
            // Data memory interface
            o_dmem_addr <= i_dmem_addr;
            o_dmem_mask <= i_dmem_mask;
            o_dmem_ren <= i_dmem_ren;
            o_dmem_wen <= i_dmem_wen;
            o_dmem_wdata <= i_dmem_wdata;
            
            // Control signals
            o_reg_write <= i_reg_write;
            o_mem_to_reg <= i_mem_to_reg;
            o_jump <= i_jump;
            o_retire_halt <= i_retire_halt;
            o_valid <= i_valid;
            o_mem_byte_offset <= i_mem_byte_offset;

            // ADDED for forwarding
            o_rs1_fwd_data <= i_rs1_fwd_data;
            o_rs2_fwd_data <= i_rs2_fwd_data;
        end
    end

endmodule

`default_nettype wire