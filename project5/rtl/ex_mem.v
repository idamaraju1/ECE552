`default_nettype none

module ex_mem (
    input  wire        i_clk,
    
    // Computation results from EX stage
    input  wire [31:0] i_alu_result,
    
    // Data that continues to propagate
    input  wire [31:0] i_rs1_rdata,
    input  wire [31:0] i_rs2_rdata,
    input  wire [31:0] i_pc,
    input  wire [31:0] i_pc_plus_4,
    input  wire [31:0] i_instruction,
    
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
    
    // Computation results to MEM stage
    output reg  [31:0] o_alu_result,
    
    // Data that continues to propagate
    output reg  [31:0] o_rs1_rdata,
    output reg  [31:0] o_rs2_rdata,
    output reg  [31:0] o_pc,
    output reg  [31:0] o_pc_plus_4,
    output reg  [31:0] o_instruction,
    
    // Address signals
    output reg  [ 4:0] o_rs1_addr,
    output reg  [ 4:0] o_rs2_addr,
    output reg  [ 4:0] o_rd_addr,
    
    // Control signals for MEM and WB stages
    output reg         o_mem_read,
    output reg         o_mem_write,
    output reg         o_reg_write,
    output reg         o_jump,
    output reg         o_mem_to_reg
);

    always @(posedge i_clk) begin
        // Computation results
        o_alu_result <= i_alu_result;
        
        // Data signals
        o_rs1_rdata <= i_rs1_rdata;
        o_rs2_rdata <= i_rs2_rdata;
        o_pc <= i_pc;
        o_pc_plus_4 <= i_pc_plus_4;
        o_instruction <= i_instruction;
        
        // Address signals
        o_rs1_addr <= i_rs1_addr;
        o_rs2_addr <= i_rs2_addr;
        o_rd_addr <= i_rd_addr;
        
        // Control signals
        o_mem_read <= i_mem_read;
        o_mem_write <= i_mem_write;
        o_reg_write <= i_reg_write;
        o_mem_to_reg <= i_mem_to_reg;
        o_jump <= i_jump;
    end

endmodule

`default_nettype wire