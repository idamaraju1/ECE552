`default_nettype none
module hazard_unit (

    input  wire [4:0] i_if_id_rs1,
    input  wire [4:0] i_if_id_rs2,

    input  wire [4:0] i_id_ex_rd,
    input  wire [4:0] i_ex_mem_rd,

    output wire o_hazard_stall
);

    wire rs1_hazard;
    wire rs2_hazard;

    assign rs1_hazard = (i_if_id_rs1 != 0 &&
                          (i_if_id_rs1 == i_id_ex_rd ||
                           i_if_id_rs1 == i_ex_mem_rd));

    assign rs2_hazard = (i_if_id_rs2 != 0 &&
                          (i_if_id_rs2 == i_id_ex_rd ||
                           i_if_id_rs2 == i_ex_mem_rd));

    assign o_hazard_stall = rs1_hazard || rs2_hazard;

endmodule
`default_nettype wire