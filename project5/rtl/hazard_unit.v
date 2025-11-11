`default_nettype none

module hazard_unit (
    // IF/ID stage source registers
    input  wire [4:0] i_if_id_rs1,
    input  wire [4:0] i_if_id_rs2,
    
    // ID/EX stage destination register
    input  wire [4:0] i_id_ex_rd,
    input  wire       i_id_ex_reg_write,
    
    // EX/MEM stage destination register
    input  wire [4:0] i_ex_mem_rd,
    input  wire       i_ex_mem_reg_write,
    
    // MEM/WB stage destination register
    input  wire [4:0] i_mem_wb_rd,
    input  wire       i_mem_wb_reg_write,
    
    // Output stall signal
    output wire       o_stall
);

    // Hazard detection logic based on RAW (Read After Write) dependencies
    // Stall if:
    // 1. Rs1 or Rs2 in IF/ID stage is non-zero (not x0)
    // 2. Rs1 or Rs2 matches a destination register in ID/EX, EX/MEM, or MEM/WB stage
    // 3. That stage is actually writing to a register (reg_write == 1)
    
    wire rs1_hazard_id_ex;
    wire rs1_hazard_ex_mem;
    wire rs1_hazard_mem_wb;
    wire rs1_hazard;
    
    wire rs2_hazard_id_ex;
    wire rs2_hazard_ex_mem;
    wire rs2_hazard_mem_wb;
    wire rs2_hazard;
    
    // Check for Rs1 hazards
    assign rs1_hazard_id_ex = (i_if_id_rs1 != 5'd0) && 
                              (i_if_id_rs1 == i_id_ex_rd) && 
                              i_id_ex_reg_write;
    
    assign rs1_hazard_ex_mem = (i_if_id_rs1 != 5'd0) && 
                               (i_if_id_rs1 == i_ex_mem_rd) && 
                               i_ex_mem_reg_write;
    
    assign rs1_hazard_mem_wb = (i_if_id_rs1 != 5'd0) && 
                               (i_if_id_rs1 == i_mem_wb_rd) && 
                               i_mem_wb_reg_write;
    
    assign rs1_hazard = rs1_hazard_id_ex || rs1_hazard_ex_mem || rs1_hazard_mem_wb;
    
    // Check for Rs2 hazards
    assign rs2_hazard_id_ex = (i_if_id_rs2 != 5'd0) && 
                              (i_if_id_rs2 == i_id_ex_rd) && 
                              i_id_ex_reg_write;
    
    assign rs2_hazard_ex_mem = (i_if_id_rs2 != 5'd0) && 
                               (i_if_id_rs2 == i_ex_mem_rd) && 
                               i_ex_mem_reg_write;
    
    assign rs2_hazard_mem_wb = (i_if_id_rs2 != 5'd0) && 
                               (i_if_id_rs2 == i_mem_wb_rd) && 
                               i_mem_wb_reg_write;
    
    assign rs2_hazard = rs2_hazard_id_ex || rs2_hazard_ex_mem || rs2_hazard_mem_wb;
    
    // Stall if either Rs1 or Rs2 has a hazard
    assign o_stall = rs1_hazard || rs2_hazard;

endmodule

`default_nettype wire

