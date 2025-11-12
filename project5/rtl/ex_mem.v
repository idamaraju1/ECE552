`default_nettype none

module ex_mem (
    input  wire        i_clk,
    input  wire        i_rst,
    input  wire        i_valid,

    // Computation results from EX stage
    input  wire [31:0] i_alu_result,
    
    // Data that continues to propagate
    input  wire [31:0] i_pc,
    input  wire [31:0] i_pc_plus_4,
    input  wire [31:0] i_instruction,
    input  wire [31:0] i_next_pc_target,
    
    // Address signals
    input  wire [ 4:0] i_rs1_addr,
    input  wire [ 4:0] i_rs2_addr,
    input  wire [ 4:0] i_rd_addr,
    
    // Control signals for MEM and WB stages
    input  wire        i_mem_read,
    input  wire        i_mem_write,
    input  wire        i_reg_write,
    input  wire        i_mem_to_reg,
    input  wire        i_jump,
    input  wire        i_retire_halt,
    
    // Computation results to MEM stage
    output reg  [31:0] o_alu_result,
    
    // Data that continues to propagate
    output reg  [31:0] o_pc,
    output reg  [31:0] o_pc_plus_4,
    output reg  [31:0] o_instruction,
    output reg  [31:0] o_next_pc_target,
    
    // Address signals
    output reg  [ 4:0] o_rs1_addr,
    output reg  [ 4:0] o_rs2_addr,
    output reg  [ 4:0] o_rd_addr,
    
    // Control signals for MEM and WB stages
    output reg         o_mem_read,
    output reg         o_mem_write,
    output reg         o_reg_write,
    output reg         o_jump,
    output reg         o_mem_to_reg,
    output reg         o_retire_halt,
    output reg         o_valid,

    // ADDED for forwarding
    input  wire [31:0] i_rs1_fwd_data,  // Actual rs1 value used (after forwarding)
    input  wire [31:0] i_rs2_fwd_data,  // Actual rs2 value used (after forwarding)
    output reg  [31:0] o_rs1_fwd_data,
    output reg  [31:0] o_rs2_fwd_data
);

    always @(posedge i_clk) begin
        if (i_rst) begin
            o_alu_result <= 32'h00000000;
            o_pc <= 32'h00000000;
            o_pc_plus_4 <= 32'h00000004;
            o_instruction <= 32'h00000013;  // NOP
            o_next_pc_target <= 32'h00000000;
            
            o_rs1_addr <= 5'd0;
            o_rs2_addr <= 5'd0;
            o_rd_addr <= 5'd0;
            
            o_mem_read <= 1'b0;
            o_mem_write <= 1'b0;
            o_reg_write <= 1'b0;
            o_mem_to_reg <= 1'b0;
            o_jump <= 1'b0;
            o_retire_halt <= 1'b0;
            o_valid <= 1'b0;

            // ADDED for forwarding
            o_rs1_fwd_data <= 32'h00000000;
            o_rs2_fwd_data <= 32'h00000000;

        end else begin
            // Computation results
            o_alu_result <= i_alu_result;
            
            // Data signals
            o_pc <= i_pc;
            o_pc_plus_4 <= i_pc_plus_4;
            o_instruction <= i_instruction;
            o_next_pc_target <= i_next_pc_target;

            // Address signals
            o_rs1_addr <= i_rs1_addr;
            o_rs2_addr <= i_rs2_addr;
            o_rd_addr <= i_rd_addr;
            o_valid <= i_valid;
            
            // Control signals
            o_mem_read <= i_mem_read;
            o_mem_write <= i_mem_write;
            o_reg_write <= i_reg_write;
            o_mem_to_reg <= i_mem_to_reg;
            o_jump <= i_jump;
            o_retire_halt <= i_retire_halt;

            // ADDED for forwarding
            o_rs1_fwd_data <= i_rs1_fwd_data;
            o_rs2_fwd_data <= i_rs2_fwd_data;
        end
    end

endmodule

`default_nettype wire