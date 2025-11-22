`default_nettype none
module forward_unit (

    // input src register addresses from EX stage
    input wire [4:0] i_ex_rs1,
    input wire [4:0] i_ex_rs2,

    // input control signals from MEM and WB stages
    input wire       i_mem_reg_write,
    input wire       i_wb_reg_write,

    // input dest register addresses from MEM and WB stages
    input wire [4:0] i_mem_rd,
    input wire [4:0] i_wb_rd,

    // output signals for selecting forwarded data
    output wire [1:0] o_forward_a,
    output wire [1:0] o_forward_b
);

    // RS1 WB→EX(MEM-EX) and MEM→EX(EX-EX) forwarding
    assign o_forward_a = (i_mem_reg_write && (i_mem_rd != 5'd0) && (i_mem_rd == i_ex_rs1)) ? 2'b10 :
                         (i_wb_reg_write  && (i_wb_rd  != 5'd0) && (i_wb_rd  == i_ex_rs1)) ? 2'b01 :
                         2'b00;

    // RS2 WB→EX(MEM-EX) and MEM→EX(EX-EX) forwarding
    assign o_forward_b = (i_mem_reg_write && (i_mem_rd != 5'd0) && (i_mem_rd == i_ex_rs2)) ? 2'b10 :
                         (i_wb_reg_write  && (i_wb_rd  != 5'd0) && (i_wb_rd  == i_ex_rs2)) ? 2'b01 :
                         2'b00;

endmodule
`default_nettype wire