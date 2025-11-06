`default_nettype none
module hazard_unit (
    // ID stage register uses
    input  wire [4:0] i_id_rs1,
    input  wire [4:0] i_id_rs2,
    input  wire [6:0] i_id_opcode,

    // EX stage
    input  wire [4:0] i_ex_rd,
    input  wire       i_ex_reg_write,
    input  wire       i_ex_mem_read,   // load in EX?

    // stall controls
    output wire       o_pc_write,
    output wire       o_if_id_write,
    output wire       o_id_ex_flush
);

    // ----------------------------
    // Does ID use rs1/rs2?
    // ----------------------------
    reg need_rs1, need_rs2;
    always @(*) begin
        case (i_id_opcode)
            7'b0110011,   // R     (rs1,rs2)
            7'b0100011,   // SW    (rs1,rs2)
            7'b1100011:   // BEQ   (rs1,rs2) ← even if you don’t handle control, still uses
                begin
                    need_rs1 = 1'b1;
                    need_rs2 = 1'b1;
                end

            7'b0010011,   // I-type ALU (rs1)
            7'b0000011,   // LOAD  (rs1)
            7'b1100111:   // JALR  (rs1)
                begin
                    need_rs1 = 1'b1;
                    need_rs2 = 1'b0;
                end

            default: begin
                need_rs1 = 1'b0;
                need_rs2 = 1'b0;
            end
        endcase
    end

    // ----------------------------
    // Load-use hazard
    // ----------------------------
    wire hazard_rs1 =
        i_ex_mem_read &&
        (i_ex_rd != 0) &&
        need_rs1 &&
        (i_id_rs1 == i_ex_rd);

    wire hazard_rs2 =
        i_ex_mem_read &&
        (i_ex_rd != 0) &&
        need_rs2 &&
        (i_id_rs2 == i_ex_rd);

    wire load_use_stall = hazard_rs1 | hazard_rs2;

    // ----------------------------
    // Outputs
    // ----------------------------
    // Stall PC + IF/ID when hazard
    assign o_pc_write    = ~load_use_stall;
    assign o_if_id_write = ~load_use_stall;

    // Insert bubble into EX
    assign o_id_ex_flush = load_use_stall;

endmodule
`default_nettype wire