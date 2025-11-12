`default_nettype none
module hazard_unit (

    // input control signals from EX stage
    input wire i_mem_read_ex,
    input wire i_valid_ex,

    // input src/dest register addresses from ID and EX stages
    input wire [4:0] i_ex_rd,
    input wire [4:0] i_id_rs1,
    input wire [4:0] i_id_rs2,

    // output signal to stall pipeline
    output wire o_hazard_stall
);

    // only have to worry about load-use hazard with forwarding
    wire load_use_hazard;
    assign load_use_hazard = i_valid_ex & i_mem_read_ex & (i_ex_rd != 5'd0) & ((i_id_rs1 == i_ex_rd) || (i_id_rs2 == i_ex_rd));

    assign o_hazard_stall = load_use_hazard;

endmodule
`default_nettype wire