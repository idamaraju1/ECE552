`default_nettype none
module ctrl (
    input  wire [31:0] i_inst,
    // Output control signals:
    output wire        o_RegWrite,
    output wire [5:0]  o_inst_format,
    output wire        o_ALUSrc1,
    output wire        o_ALUSrc2,
    output wire [1:0]  o_ALUop,
    output wire        o_lui,
    output wire        o_dmem_ren,
    output wire [3:0]  o_dmem_mask,
    output wire        o_MemtoReg,
    output wire        o_Jump,
    output wire        o_Branch
);
    // CODE HERE: implement the control signal generation logic

endmodule
`default_nettype wire